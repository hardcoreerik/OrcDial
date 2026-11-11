#!/usr/bin/env bash
# Open, update, or close the firmware nightly failure issue.
#
# .github/workflows/firmware-nightly.yml runs this after gate, build, and publish.
# It talks to GitHub only through the gh CLI and the job's GITHUB_TOKEN
# (issues: write, actions: read). A cancelled run returns before any issue write.
#
#   bash .github/scripts/nightly-failure-alert_test.sh
set -euo pipefail

LABEL="${ALERT_LABEL:-nightly-failure}"
ASSIGNEE="${ALERT_ASSIGNEE:-hardcoreerik}"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
RUN_ID="${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"
SERVER="${GITHUB_SERVER_URL:-https://github.com}"
EVENT="${GITHUB_EVENT_NAME:-unknown}"
ATTEMPT="${GITHUB_RUN_ATTEMPT:-1}"
REF_NAME="${GITHUB_REF_NAME:-}"
GATE_RESULT="${GATE_RESULT:?GATE_RESULT is required}"
BUILD_RESULT="${BUILD_RESULT:?BUILD_RESULT is required}"
PUBLISH_RESULT="${PUBLISH_RESULT:?PUBLISH_RESULT is required}"
GATE_BUILD="${GATE_BUILD:-}"
retries="${ALERT_API_RETRIES:-4}"
delay="${ALERT_API_DELAY:-3}"
LOG_TAIL_LINES=60
LOG_TAIL_BYTES=4000

SHA="${GATE_SHA:-}"
if [ -z "$SHA" ]; then
  SHA="${GITHUB_SHA:-unknown}"
fi
SHORT="${SHA:0:7}"
RUN_URL="${SERVER}/${REPO}/actions/runs/${RUN_ID}"
RUN_NEEDLE="Run: ${RUN_URL} (attempt ${ATTEMPT})"

export GH_PROMPT_DISABLED=1
export GH_NO_UPDATE_NOTIFIER=1

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
jobs_json="$tmpdir/jobs.json"
printf '%s\n' '{"jobs":[]}' >"$jobs_json"

log() { printf '%s\n' "$*" >&2; }

is_bad() {
  case "$1" in
    failure|timed_out|action_required) return 0 ;;
    *) return 1 ;;
  esac
}

decide_mode() {
  if is_bad "$GATE_RESULT" || is_bad "$BUILD_RESULT" || is_bad "$PUBLISH_RESULT"; then
    printf '%s\n' failure
    return 0
  fi
  if [ "$GATE_RESULT" = "success" ] && [ "$BUILD_RESULT" = "success" ] && [ "$PUBLISH_RESULT" = "success" ]; then
    printf '%s\n' success
    return 0
  fi
  # The gate job is the only place a run is intentionally not built. build and
  # publish are then skipped, and the workflow itself is green.
  if [ "$GATE_RESULT" = "success" ] && [ "$BUILD_RESULT" = "skipped" ] && [ "$PUBLISH_RESULT" = "skipped" ] && [ "$GATE_BUILD" != "true" ]; then
    printf '%s\n' skip
    return 0
  fi
  printf '%s\n' unrecognized
}

sanitize() {
  sed -E \
    -e 's/\x1b\[[0-9;?]*[A-Za-z]//g' \
    -e 's/\r$//' \
    -e 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z //' \
    -e 's/\t[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z /\t/' \
    -e 's/(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{8,}/[REDACTED]/g' \
    -e 's/github_pat_[A-Za-z0-9_]{8,}/[REDACTED]/g' \
    -e 's/Bearer[[:space:]]+[A-Za-z0-9._~+\/=-]{8,}/Bearer [REDACTED]/g' \
    -e 's/([A-Za-z0-9_]*(token|secret|password)[[:space:]]*[=:][[:space:]]*)[^[:space:]]+/\1[REDACTED]/Ig'
}

fetch_jobs() {
  local i=1 part="$tmpdir/jobs.part"
  while [ "$i" -le "$retries" ]; do
    if gh api "/repos/${REPO}/actions/runs/${RUN_ID}/jobs?per_page=100&filter=latest" >"$part" \
        && jq -e '.jobs | type == "array"' "$part" >/dev/null; then
      mv "$part" "$jobs_json"
      return 0
    fi
    i=$((i + 1))
    if [ "$i" -le "$retries" ]; then
      sleep "$delay"
    fi
  done
  return 1
}

build_summary() {
  local summary
  summary=$(jq -r '
    .jobs[]?
    | select(.conclusion == "failure" or .conclusion == "timed_out" or .conclusion == "action_required")
    | . as $job
    | (
        if ($job.html_url // "") != "" then
          "- **[\($job.name | gsub("`"; ""))](\($job.html_url))** (`\($job.conclusion)`)"
        else
          "- **\($job.name | gsub("`"; ""))** (`\($job.conclusion)`)"
        end
      ),
      (
        $job.steps[]?
        | select(.conclusion == "failure" or .conclusion == "timed_out" or .conclusion == "action_required")
        | "  - step \(.number): \(.name | gsub("`"; "")) (`\(.conclusion)`)"
      )
  ' "$jobs_json" || true)
  if [ -n "$summary" ]; then
    printf '%s\n' "$summary"
    return 0
  fi
  printf '%s\n' \
    "- gate: \`${GATE_RESULT}\`" \
    "- build: \`${BUILD_RESULT}\`" \
    "- publish: \`${PUBLISH_RESULT}\`"
}

error_window() {
  awk '
    { line[NR] = $0 }
    /##\[error\]/ { err = NR }
    /Post job cleanup\./ && post == 0 { post = NR }
    END {
      if (NR == 0) exit
      if (err > 0) end = err
      else if (post > 1) end = post - 1
      else end = NR
      start = end - 79
      if (start < 1) start = 1
      for (i = start; i <= end; i++) print line[i]
    }
  '
}

fallback_logs() {
  local id name logf
  jq -r '
    .jobs[]?
    | select(.conclusion == "failure" or .conclusion == "timed_out" or .conclusion == "action_required")
    | select(.id != null)
    | [.id, .name] | @tsv
  ' "$jobs_json" >"$tmpdir/failed-jobs.tsv" || true
  while IFS=$'\t' read -r id name; do
    [ -n "${id:-}" ] || continue
    logf="$tmpdir/job-${id}.log"
    printf '## %s\n' "$name"
    if gh api --allow-escape-sequences "/repos/${REPO}/actions/jobs/${id}/logs" >"$logf"; then
      error_window <"$logf"
    else
      printf '%s\n' "(log unavailable)"
    fi
  done <"$tmpdir/failed-jobs.tsv"
}

build_log_tail() {
  local raw="$tmpdir/log-failed.txt" tailed="$tmpdir/tailed.txt" i=1 bytes
  : >"$raw"
  while [ "$i" -le "$retries" ]; do
    if gh run view "$RUN_ID" --repo "$REPO" --log-failed >"$raw" && [ -s "$raw" ]; then
      break
    fi
    : >"$raw"
    i=$((i + 1))
    if [ "$i" -le "$retries" ]; then
      sleep "$delay"
    fi
  done
  if [ ! -s "$raw" ]; then
    fallback_logs >"$raw" || true
  fi
  # grep treats a NUL pattern as empty and matches every file, so compare sizes instead.
  if [ ! -s "$raw" ] || [ "$(wc -c <"$raw" | tr -d ' ')" != "$(tr -d '\000' <"$raw" | wc -c | tr -d ' ')" ]; then
    printf '%s\n' "(log tail unavailable)"
    return 0
  fi
  tail -n "$LOG_TAIL_LINES" "$raw" | sanitize >"$tailed"
  bytes=$(wc -c <"$tailed" | tr -d ' ')
  if [ "$bytes" -gt "$LOG_TAIL_BYTES" ]; then
    {
      printf '%s\n' "...(truncated)"
      tail -c "$LOG_TAIL_BYTES" "$tailed"
    } >"$tmpdir/capped.txt"
    mv "$tmpdir/capped.txt" "$tailed"
  fi
  cat "$tailed"
}

fence_for() {
  local text=$1 fence='~~~~'
  while printf '%s' "$text" | grep -q -F -- "$fence"; do
    fence="${fence}~"
    if [ "${#fence}" -gt 12 ]; then
      break
    fi
  done
  printf '%s' "$fence"
}

open_numbers() {
  gh issue list --repo "$REPO" --label "$LABEL" --state open --limit 20 \
    --json number,createdAt >"$tmpdir/issues.json"
  jq -r 'sort_by(.createdAt) | .[].number' "$tmpdir/issues.json"
}

mentions_run() {
  local num=$1
  local view="$tmpdir/view-${num}.json"
  local rendered
  gh issue view "$num" --repo "$REPO" --json body,comments >"$view"
  rendered=$(jq -r '[.body // "", (.comments[]?.body // empty)] | join("\n")' "$view")
  printf '%s' "$rendered" | grep -F -q -- "$RUN_NEEDLE"
}

ensure_label() {
  if gh api --silent "/repos/${REPO}/labels/${LABEL}"; then
    return 0
  fi
  gh label create "$LABEL" --repo "$REPO" --color d73a4a \
    --description "Open while the firmware nightly workflow is failing"
}

create_issue() {
  local body=$1 out="$tmpdir/create.out" err="$tmpdir/create.err"
  if gh issue create --repo "$REPO" \
      --title "Firmware nightly failed (${SHORT})" \
      --body-file "$body" \
      --label "$LABEL" \
      --assignee "$ASSIGNEE" >"$out" 2>"$err"; then
    cat "$out"
    return 0
  fi
  if grep -q 'https://' "$out"; then
    log "Issue was created; assigning ${ASSIGNEE} may have failed:"
    cat "$err" >&2
    cat "$out"
    return 0
  fi
  log "Opening the issue assigned to ${ASSIGNEE} failed:"
  cat "$err" >&2
  log "Retrying without an assignee. The body still mentions @${ASSIGNEE}."
  gh issue create --repo "$REPO" \
    --title "Firmware nightly failed (${SHORT})" \
    --body-file "$body" \
    --label "$LABEL"
}

write_failure_body() {
  local dest=$1 summary=$2 logtail=$3 fence logsection refbit=""
  if [ "$logtail" = "(log tail unavailable)" ]; then
    logsection="Log tail unavailable."
  else
    fence=$(fence_for "$logtail")
    logsection="${fence}text
${logtail}
${fence}"
  fi
  if [ -n "$REF_NAME" ]; then
    refbit="- Ref: \`${REF_NAME}\`
"
  fi
  {
    printf '%s\n' "@${ASSIGNEE} The firmware nightly failed."
    printf '%s\n' ""
    printf '%s\n' "- ${RUN_NEEDLE}"
    printf '%s\n' "- Event: ${EVENT}"
    printf '%s' "$refbit"
    printf '%s\n' "- Commit: \`${SHORT}\`"
    printf '%s\n' "- Workflow: Firmware nightly (\`.github/workflows/firmware-nightly.yml\`)"
    printf '%s\n' "- Jobs: gate=\`${GATE_RESULT}\`, build=\`${BUILD_RESULT}\`, publish=\`${PUBLISH_RESULT}\`"
    printf '%s\n' ""
    printf '%s\n' "### Failing jobs and steps"
    printf '%s\n' ""
    printf '%s\n' "$summary"
    printf '%s\n' ""
    printf '%s\n' "### Log tail"
    printf '%s\n' ""
    printf '%s\n' "$logsection"
    printf '%s\n' ""
    printf '%s\n' "This issue stays open until a later nightly publishes, or the gate skips the build because nothing firmware-relevant changed."
  } >"$dest"
}

gate_decision_line() {
  local id logf line
  id=$(jq -r '.jobs[]? | select(.name == "gate" and .id != null) | .id' "$jobs_json" | head -n 1)
  [ -n "$id" ] || return 0
  logf="$tmpdir/gate.log"
  if ! gh api --allow-escape-sequences "/repos/${REPO}/actions/jobs/${id}/logs" >"$logf"; then
    return 0
  fi
  line=$(sanitize <"$logf" | grep -E 'build=(true|false) \(' | tail -n 1 || true)
  printf '%s' "$line"
}

write_recovery_body() {
  local dest=$1 decision=$2 result refbit=""
  if [ "$mode" = "success" ]; then
    result="Published the rolling nightly."
  else
    result="The gate skipped the firmware build because nothing firmware-relevant changed (main matches the last published nightly or the release, or only docs and CI changed)."
  fi
  if [ -n "$REF_NAME" ]; then
    refbit="- Ref: \`${REF_NAME}\`
"
  fi
  {
    printf '%s\n' "@${ASSIGNEE} The firmware nightly is healthy again, so this issue is closed."
    printf '%s\n' ""
    printf '%s\n' "- ${RUN_NEEDLE}"
    printf '%s\n' "- Event: ${EVENT}"
    printf '%s' "$refbit"
    printf '%s\n' "- Commit: \`${SHORT}\`"
    printf '%s\n' "- Result: ${result}"
    if [ -n "$decision" ]; then
      printf '%s\n' ""
      printf '%s\n' "Gate:"
      printf '%s\n' ""
      printf '%s\n' "> ${decision}"
    fi
  } >"$dest"
}

load_numbers() {
  local line
  numbers=()
  open_numbers >"$tmpdir/numbers.txt"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    numbers+=("$line")
  done <"$tmpdir/numbers.txt"
}

handle_failure() {
  local summary logtail body
  fetch_jobs || log "Could not list jobs for run ${RUN_ID}; the issue will use the job results only."
  summary=$(build_summary)
  logtail=$(build_log_tail)
  body="$tmpdir/failure.md"
  write_failure_body "$body" "$summary" "$logtail"
  load_numbers
  if [ "${#numbers[@]}" -eq 0 ]; then
    ensure_label
    create_issue "$body"
    return 0
  fi
  local oldest="${numbers[0]}"
  if mentions_run "$oldest"; then
    log "Failure of run ${RUN_ID} is already recorded on #${oldest}."
    return 0
  fi
  gh issue comment "$oldest" --repo "$REPO" --body-file "$body"
  gh issue edit "$oldest" --repo "$REPO" --add-assignee "$ASSIGNEE" \
    || log "Could not assign ${ASSIGNEE} on #${oldest}; the comment mentions them."
  if [ "${#numbers[@]}" -gt 1 ]; then
    log "Commented on the oldest ${LABEL} issue #${oldest}; also open: ${numbers[*]:1}."
  fi
}

handle_recovery() {
  local body decision num
  load_numbers
  if [ "${#numbers[@]}" -eq 0 ]; then
    log "No open ${LABEL} issue."
    return 0
  fi
  fetch_jobs || log "Could not list jobs for run ${RUN_ID}; closing without the gate's decision line."
  decision=$(gate_decision_line || true)
  body="$tmpdir/recovery.md"
  write_recovery_body "$body" "$decision"
  for num in "${numbers[@]}"; do
    if mentions_run "$num"; then
      log "Run ${RUN_ID} is already recorded on #${num}."
    else
      gh issue comment "$num" --repo "$REPO" --body-file "$body"
    fi
    gh issue close "$num" --repo "$REPO" --reason completed
  done
}

case "$EVENT" in
  schedule|workflow_dispatch) ;;
  *)
    log "Event ${EVENT} is not a scheduled or manual nightly; not opening or closing an issue."
    exit 0
    ;;
esac

for result in "$GATE_RESULT" "$BUILD_RESULT" "$PUBLISH_RESULT"; do
  if [ "$result" = "cancelled" ]; then
    log "A needed job was cancelled (gate=${GATE_RESULT} build=${BUILD_RESULT} publish=${PUBLISH_RESULT}); not opening or closing an issue."
    exit 0
  fi
done

mode=$(decide_mode)
log "Nightly alert mode=${mode} gate=${GATE_RESULT} build=${BUILD_RESULT} publish=${PUBLISH_RESULT} build_output=${GATE_BUILD:-} run=${RUN_URL}"

case "$mode" in
  failure) handle_failure ;;
  success|skip) handle_recovery ;;
  *)
    log "Unrecognized job results (gate=${GATE_RESULT} build=${BUILD_RESULT} publish=${PUBLISH_RESULT} build_output=${GATE_BUILD:-}); leaving the nightly-failure issue unchanged."
    exit 0
    ;;
esac
