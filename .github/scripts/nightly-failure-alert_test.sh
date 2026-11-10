#!/usr/bin/env bash
# Host checks for .github/scripts/nightly-failure-alert.sh. Uses a fake gh, no network.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SCRIPT="$ROOT/.github/scripts/nightly-failure-alert.sh"
WORKFLOW="$ROOT/.github/workflows/firmware-nightly.yml"
case=""
WORK=""
MOCK_LOG=""
MOCK_DIR=""
expect_status=0

fail() {
  printf 'FAIL [%s] %s\n' "$case" "$*" >&2
  if [ -n "${WORK:-}" ]; then
    echo "----- stderr -----" >&2
    cat "$WORK/out/stderr" >&2 || true
    echo "----- stdout -----" >&2
    cat "$WORK/out/stdout" >&2 || true
    if [ -f "${MOCK_LOG:-}" ]; then
      echo "----- gh -----" >&2
      cat "$MOCK_LOG" >&2 || true
    fi
  fi
  exit 1
}

pass() { printf 'ok  %s\n' "$case"; }

assert_contains() {
  local file=$1 needle=$2
  [ -f "$file" ] || fail "missing $file (looking for [$needle])"
  if ! grep -F -q -- "$needle" "$file"; then
    echo "----- $file -----" >&2
    cat "$file" >&2
    fail "expected [$needle] in $file"
  fi
}

assert_not_contains() {
  local file=$1 needle=$2
  if [ -f "$file" ] && grep -F -q -- "$needle" "$file"; then
    echo "----- $file -----" >&2
    cat "$file" >&2
    fail "did not expect [$needle] in $file"
  fi
}

assert_absent() {
  [ ! -e "$1" ] || fail "unexpected file $1"
}

setup() {
  WORK=$(mktemp -d)
  MOCK_DIR="$WORK/fixtures"
  MOCK_LOG="$WORK/out/gh.log"
  mkdir -p "$WORK/bin" "$MOCK_DIR" "$WORK/out"
  cat >"$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
  echo "----"
  printf '%q ' "$@"
  echo
} >>"${MOCK_LOG:?}"

cmd=$1
shift
dir=${MOCK_DIR:?}

copy_body() {
  local dest=$1 prev="" arg
  shift
  for arg in "$@"; do
    if [ "$prev" = "--body-file" ]; then
      cp "$arg" "$dest"
      return 0
    fi
    prev=$arg
  done
  echo "gh mock: missing --body-file" >&2
  exit 1
}

case "$cmd" in
  api)
    silent=0
    endpoint=""
    for arg in "$@"; do
      case "$arg" in
        --silent) silent=1 ;;
        --allow-escape-sequences|--method|GET) ;;
        /*) endpoint=$arg ;;
      esac
    done
    if [ "$silent" -eq 1 ]; then
      if [ -f "$dir/label-exists" ]; then
        exit 0
      fi
      exit 1
    fi
    case "$endpoint" in
      */actions/runs/*/jobs*)
        cat "$dir/jobs.json"
        ;;
      */actions/jobs/*/logs)
        id=${endpoint#*/actions/jobs/}
        id=${id%/logs}
        if [ -f "$dir/job-${id}.log" ]; then
          cat "$dir/job-${id}.log"
        else
          echo "gh mock: no log for job $id" >&2
          exit 1
        fi
        ;;
      *)
        echo "gh mock: unexpected api $endpoint" >&2
        exit 1
        ;;
    esac
    ;;
  run)
    if [ -f "$dir/log-failed.txt" ]; then
      cat "$dir/log-failed.txt"
      exit 0
    fi
    echo "gh mock: no failed log" >&2
    exit 1
    ;;
  label)
    printf '%s\n' "created label" >>"$dir/label-created.txt"
    ;;
  issue)
    sub=$1
    shift
    case "$sub" in
      list)
        cat "$dir/issues.json"
        ;;
      view)
        num=$1
        if [ -f "$dir/view-${num}.json" ]; then
          cat "$dir/view-${num}.json"
        else
          printf '%s\n' '{"body":"","comments":[]}'
        fi
        ;;
      create)
        if [ "${MOCK_FAIL_ASSIGNEE:-}" = 1 ] && printf '%s\n' "$@" | grep -q -F -- '--assignee'; then
          echo "could not assign user" >&2
          exit 1
        fi
        copy_body "$dir/created-body.md" "$@"
        printf '%s\n' "https://github.com/hardcoreerik/OrcDial/issues/4242"
        ;;
      comment)
        num=$1
        copy_body "$dir/comment-${num}.md" "$@"
        printf '%s\n' "https://github.com/hardcoreerik/OrcDial/issues/${num}#issuecomment-1"
        ;;
      close)
        num=$1
        if [ "${MOCK_FAIL_CLOSE:-}" = 1 ]; then
          echo "close failed" >&2
          exit 1
        fi
        printf '%s\n' "$*" >"$dir/close-${num}.txt"
        ;;
      edit)
        num=$1
        printf '%s\n' "$*" >"$dir/edit-${num}.txt"
        if [ "${MOCK_FAIL_EDIT:-}" = 1 ]; then
          echo "edit failed" >&2
          exit 1
        fi
        ;;
      *)
        echo "gh mock: unexpected issue $sub" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "gh mock: unexpected command $cmd" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$WORK/bin/gh"
  : >"$MOCK_LOG"
  printf '%s\n' '[]' >"$MOCK_DIR/issues.json"
  printf '%s\n' '{"jobs":[]}' >"$MOCK_DIR/jobs.json"

  export MOCK_LOG MOCK_DIR
  export PATH="$WORK/bin:/usr/bin:/bin"
  export GH_TOKEN="local-test-token-should-not-leak"
  export GITHUB_REPOSITORY="hardcoreerik/OrcDial"
  export GITHUB_RUN_ID="999"
  export GITHUB_SERVER_URL="https://github.com"
  export GITHUB_EVENT_NAME="schedule"
  export GITHUB_RUN_ATTEMPT="1"
  export GITHUB_REF_NAME="main"
  export GITHUB_SHA="abcdef1234567890abcdef1234567890abcdef12"
  export GATE_SHA="abcdef1234567890abcdef1234567890abcdef12"
  export ALERT_ASSIGNEE="hardcoreerik"
  export ALERT_LABEL="nightly-failure"
  export ALERT_API_RETRIES="1"
  export ALERT_API_DELAY="0"
  export GATE_RESULT BUILD_RESULT PUBLISH_RESULT
  unset GATE_BUILD MOCK_FAIL_ASSIGNEE MOCK_FAIL_CLOSE MOCK_FAIL_EDIT || true
  expect_status=0
}

run_script() {
  # Assignments above are not exported until here, so a value set after setup reaches the script.
  export GATE_RESULT BUILD_RESULT PUBLISH_RESULT GITHUB_EVENT_NAME GITHUB_SHA GITHUB_REF_NAME GITHUB_RUN_ATTEMPT
  if [ "${GATE_SHA+x}" = x ]; then export GATE_SHA; else unset GATE_SHA; fi
  if [ "${GATE_BUILD+x}" = x ]; then export GATE_BUILD; else unset GATE_BUILD; fi
  set +e
  bash "$SCRIPT" >"$WORK/out/stdout" 2>"$WORK/out/stderr"
  local status=$?
  set -e
  if [ "$status" -ne "$expect_status" ]; then
    fail "exit $status, expected $expect_status"
  fi
}

write_build_failure_jobs() {
  cat >"$MOCK_DIR/jobs.json" <<'EOF'
{
  "jobs": [
    {
      "id": 11,
      "name": "gate",
      "conclusion": "success",
      "html_url": "https://github.com/hardcoreerik/OrcDial/actions/runs/999/job/11",
      "steps": [{"number": 3, "name": "Run set -euo pipefail", "conclusion": "success"}]
    },
    {
      "id": 22,
      "name": "build",
      "conclusion": "failure",
      "html_url": "https://github.com/hardcoreerik/OrcDial/actions/runs/999/job/22",
      "steps": [
        {"number": 1, "name": "Set up job", "conclusion": "success"},
        {"number": 6, "name": "Tests and both firmware builds (tools/release_check.py, no hardware)", "conclusion": "failure"}
      ]
    },
    {"id": 33, "name": "publish", "conclusion": "skipped", "steps": []}
  ]
}
EOF
}

run_url() { printf '%s\n' "https://github.com/hardcoreerik/OrcDial/actions/runs/999"; }

# --- cases ---

case="failure opens an issue with the run, step, and redacted log"
setup
GATE_RESULT=success
BUILD_RESULT=failure
PUBLISH_RESULT=skipped
GATE_BUILD=true
GITHUB_EVENT_NAME=workflow_dispatch
unset GATE_SHA
GITHUB_SHA="1234567890abcdef1234567890abcdef12345678"
touch "$MOCK_DIR/label-exists"
write_build_failure_jobs
# Built at runtime so the source file does not contain a contiguous personal-access-token string.
leaked=$(printf '%s%s' 'gh'"p_" 'abcdefghijklmnopqrstuvwxyz0123456789')
step='Tests and both firmware builds (tools/release_check.py, no hardware)'
{
  printf '%s\n' "build	${step}	2026-11-10T10:27:01.0000000Z firmware assertion failed"
  printf '%s\n' "build	${step}	2026-11-10T10:27:02.0000000Z token=${leaked}"
  printf '%s\n' "build	${step}	2026-11-10T10:27:03.0000000Z Authorization: Bearer supersecrettoken"
  printf '%s\n' "build	${step}	2026-11-10T10:27:04.0000000Z password: hunter2"
  printf '%s\n' "build	${step}	2026-11-10T10:27:05.0000000Z ##[error]Process completed with exit code 1."
  printf '%s\n' "build	${step}	2026-11-10T10:27:06.0000000Z literal \$(touch /tmp/should-not-run) and \`touch /tmp/should-not-run-either\`"
} >"$MOCK_DIR/log-failed.txt"
run_script
body="$MOCK_DIR/created-body.md"
assert_contains "$body" "@hardcoreerik"
assert_contains "$body" "$(run_url) (attempt 1)"
assert_contains "$body" "workflow_dispatch"
assert_contains "$body" "1234567"
assert_contains "$body" "Tests and both firmware builds (tools/release_check.py, no hardware)"
assert_contains "$body" "step 6:"
assert_contains "$WORK/out/stderr" "build_output=true"
assert_contains "$body" "https://github.com/hardcoreerik/OrcDial/actions/runs/999/job/22"
assert_contains "$body" "Process completed with exit code 1."
assert_contains "$body" "[REDACTED]"
assert_not_contains "$body" "$leaked"
assert_not_contains "$body" "supersecrettoken"
assert_not_contains "$body" "hunter2"
assert_not_contains "$body" "$GH_TOKEN"
# shellcheck disable=SC2016 # the failure log must keep this command substitution literal
assert_contains "$body" '$(touch /tmp/should-not-run)'
assert_absent /tmp/should-not-run
assert_absent /tmp/should-not-run-either
assert_contains "$MOCK_LOG" "--assignee"
assert_contains "$MOCK_LOG" "hardcoreerik"
assert_not_contains "$MOCK_LOG" "label create"
assert_absent "$MOCK_DIR/close-42.txt"
# Mention stays outside the log fence.
mention_line=$(head -n 1 "$body")
[ "$mention_line" = "@hardcoreerik The firmware nightly failed." ] || fail "mention moved: $mention_line"
pass

case="failure creates the label when it is missing"
setup
GATE_RESULT=failure
BUILD_RESULT=skipped
PUBLISH_RESULT=skipped
cat >"$MOCK_DIR/jobs.json" <<'EOF'
{
  "jobs": [
    {
      "id": 11,
      "name": "gate",
      "conclusion": "failure",
      "steps": [{"number": 3, "name": "Run set -euo pipefail", "conclusion": "failure"}]
    },
    {"id": 22, "name": "build", "conclusion": "skipped", "steps": []},
    {"id": 33, "name": "publish", "conclusion": "skipped", "steps": []}
  ]
}
EOF
printf '%s\n' 'gate	Run set -euo pipefail	##[error]gate blew up' >"$MOCK_DIR/log-failed.txt"
run_script
assert_contains "$MOCK_DIR/label-created.txt" "created label"
assert_contains "$MOCK_DIR/created-body.md" "step 3:"
assert_contains "$MOCK_DIR/created-body.md" "Run set -euo pipefail"
assert_contains "$MOCK_DIR/created-body.md" "gate=\`failure\`"
assert_not_contains "$MOCK_DIR/created-body.md" "Published the rolling nightly"
pass

case="failure comments on the oldest open issue instead of creating one"
setup
GATE_RESULT=success
BUILD_RESULT=failure
PUBLISH_RESULT=skipped
GATE_BUILD=true
touch "$MOCK_DIR/label-exists"
write_build_failure_jobs
printf '%s\n' 'build	Tests	##[error]still broken' >"$MOCK_DIR/log-failed.txt"
cat >"$MOCK_DIR/issues.json" <<'EOF'
[
  {"number": 9, "createdAt": "2026-11-02T00:00:00Z"},
  {"number": 7, "createdAt": "2026-11-01T00:00:00Z"}
]
EOF
run_script
assert_absent "$MOCK_DIR/created-body.md"
assert_absent "$MOCK_DIR/comment-9.md"
assert_contains "$MOCK_DIR/comment-7.md" "@hardcoreerik"
assert_contains "$MOCK_DIR/comment-7.md" "$(run_url) (attempt 1)"
assert_contains "$MOCK_DIR/comment-7.md" "still broken"
assert_contains "$MOCK_DIR/edit-7.txt" "--add-assignee"
assert_contains "$MOCK_DIR/edit-7.txt" "hardcoreerik"
assert_not_contains "$MOCK_LOG" "label create"
pass

case="failure rerun does not comment twice"
setup
GATE_RESULT=success
BUILD_RESULT=failure
PUBLISH_RESULT=skipped
GATE_BUILD=true
write_build_failure_jobs
printf '%s\n' 'build	Tests	##[error]still broken' >"$MOCK_DIR/log-failed.txt"
printf '%s\n' '[{"number": 42, "createdAt": "2026-11-01T00:00:00Z"}]' >"$MOCK_DIR/issues.json"
cat >"$MOCK_DIR/view-42.json" <<EOF
{"body":"","comments":[{"body":"Run: $(run_url) (attempt 1)\\nalready filed"}]}
EOF
run_script
assert_absent "$MOCK_DIR/created-body.md"
assert_absent "$MOCK_DIR/comment-42.md"
assert_contains "$WORK/out/stderr" "already recorded"
pass

case="assignee rejection still opens an issue that mentions the owner"
setup
GATE_RESULT=success
BUILD_RESULT=timed_out
PUBLISH_RESULT=skipped
export MOCK_FAIL_ASSIGNEE=1
touch "$MOCK_DIR/label-exists"
cat >"$MOCK_DIR/jobs.json" <<'EOF'
{"jobs":[{"id":22,"name":"build","conclusion":"timed_out","steps":[{"number":4,"name":"Build the release image","conclusion":"timed_out"}]}]}
EOF
printf '%s\n' 'build	Build the release image	##[error]The job has exceeded the maximum execution time' >"$MOCK_DIR/log-failed.txt"
run_script
assert_contains "$MOCK_DIR/created-body.md" "@hardcoreerik"
assert_contains "$MOCK_DIR/created-body.md" "Build the release image"
assert_contains "$MOCK_DIR/created-body.md" "timed_out"
creates=$(grep -c 'issue create' "$MOCK_LOG" || true)
[ "$creates" -eq 2 ] || fail "expected 2 create attempts, got $creates"
pass

case="missing logs still file the failing step"
setup
GATE_RESULT=success
BUILD_RESULT=success
PUBLISH_RESULT=failure
touch "$MOCK_DIR/label-exists"
cat >"$MOCK_DIR/jobs.json" <<'EOF'
{
  "jobs": [
    {"id": 11, "name": "gate", "conclusion": "success", "steps": []},
    {"id": 22, "name": "build", "conclusion": "success", "steps": []},
    {"id": 33, "name": "publish", "conclusion": "failure", "steps": [
      {"number": 3, "name": "Upload assets, drop stale ones, then the build-info.json marker", "conclusion": "failure"}
    ]}
  ]
}
EOF
run_script
assert_contains "$MOCK_DIR/created-body.md" "Upload assets, drop stale ones, then the build-info.json marker"
assert_contains "$MOCK_DIR/created-body.md" "log unavailable"
assert_contains "$MOCK_DIR/created-body.md" "publish=\`failure\`"
pass

case="raw job log is used when log-failed is empty, without post-job cleanup"
setup
GATE_RESULT=success
BUILD_RESULT=failure
PUBLISH_RESULT=skipped
touch "$MOCK_DIR/label-exists"
write_build_failure_jobs
cat >"$MOCK_DIR/job-22.log" <<'EOF'
2026-11-10T10:27:01.0000000Z compiling
2026-11-10T10:27:02.0000000Z ##[error]Process completed with exit code 1.
2026-11-10T10:27:03.0000000Z Post job cleanup.
2026-11-10T10:27:04.0000000Z POST_CLEANUP_MARKER
EOF
run_script
assert_contains "$MOCK_DIR/created-body.md" "Process completed with exit code 1."
assert_not_contains "$MOCK_DIR/created-body.md" "POST_CLEANUP_MARKER"
pass

case="log tail keeps the end and lengthens the fence"
setup
GATE_RESULT=success
BUILD_RESULT=failure
PUBLISH_RESULT=skipped
touch "$MOCK_DIR/label-exists"
write_build_failure_jobs
{
  echo "DROP_ME_UNIQUE"
  i=2
  while [ "$i" -le 69 ]; do
    printf 'filler %s ~~~~\n' "$i"
    i=$((i + 1))
  done
  echo "KEEP_ME_UNIQUE"
} >"$MOCK_DIR/log-failed.txt"
run_script
assert_contains "$MOCK_DIR/created-body.md" "KEEP_ME_UNIQUE"
assert_not_contains "$MOCK_DIR/created-body.md" "DROP_ME_UNIQUE"
# A line of the log is ~~~~, so the fence must be longer than that.
assert_contains "$MOCK_DIR/created-body.md" "~~~~~text"
pass

case="success closes every open nightly-failure issue"
setup
GATE_RESULT=success
BUILD_RESULT=success
PUBLISH_RESULT=success
GATE_BUILD=true
cat >"$MOCK_DIR/issues.json" <<'EOF'
[
  {"number": 9, "createdAt": "2026-11-02T00:00:00Z"},
  {"number": 7, "createdAt": "2026-11-01T00:00:00Z"}
]
EOF
cat >"$MOCK_DIR/jobs.json" <<'EOF'
{"jobs":[
  {"id":11,"name":"gate","conclusion":"success","steps":[]},
  {"id":22,"name":"build","conclusion":"success","steps":[]},
  {"id":33,"name":"publish","conclusion":"success","steps":[]}
]}
EOF
printf '%s\n' '2026-11-10T10:27:55.0000000Z main abcdef1, last nightly 1111111, 4 commits since orcdial-v0.2.0-beta.1: build=true (main changed)' >"$MOCK_DIR/job-11.log"
run_script
for n in 7 9; do
  assert_contains "$MOCK_DIR/comment-${n}.md" "@hardcoreerik"
  assert_contains "$MOCK_DIR/comment-${n}.md" "$(run_url) (attempt 1)"
  assert_contains "$MOCK_DIR/comment-${n}.md" "Published the rolling nightly."
  assert_contains "$MOCK_DIR/comment-${n}.md" "build=true (main changed)"
  assert_contains "$MOCK_DIR/close-${n}.txt" "--reason"
  assert_contains "$MOCK_DIR/close-${n}.txt" "completed"
done
assert_absent "$MOCK_DIR/created-body.md"
assert_not_contains "$MOCK_LOG" "--log-failed"
pass

case="deliberate skip closes the issue and does not publish"
setup
GATE_RESULT=success
BUILD_RESULT=skipped
PUBLISH_RESULT=skipped
GATE_BUILD=false
printf '%s\n' '[{"number":42,"createdAt":"2026-11-01T00:00:00Z"}]' >"$MOCK_DIR/issues.json"
cat >"$MOCK_DIR/jobs.json" <<'EOF'
{"jobs":[
  {"id":11,"name":"gate","conclusion":"success","steps":[]},
  {"id":22,"name":"build","conclusion":"skipped","steps":[]},
  {"id":33,"name":"publish","conclusion":"skipped","steps":[]}
]}
EOF
printf '%s\n' '2026-11-10T10:27:55.0000000Z main abcdef1, last nightly abcdef1, 0 commits since orcdial-v0.2.0-beta.1: build=false (main unchanged since the last nightly)' >"$MOCK_DIR/job-11.log"
run_script
assert_contains "$MOCK_DIR/comment-42.md" "@hardcoreerik"
assert_contains "$MOCK_DIR/comment-42.md" "$(run_url) (attempt 1)"
assert_contains "$MOCK_DIR/comment-42.md" "skipped the firmware build"
assert_contains "$MOCK_DIR/comment-42.md" "main unchanged since the last nightly"
assert_contains "$WORK/out/stderr" "build_output=false"
assert_not_contains "$MOCK_DIR/comment-42.md" "Published the rolling nightly."
assert_contains "$MOCK_DIR/close-42.txt" "completed"
assert_absent "$MOCK_DIR/created-body.md"
pass

case="healthy run with no open issue does not create one"
setup
GATE_RESULT=success
BUILD_RESULT=success
PUBLISH_RESULT=success
run_script
assert_absent "$MOCK_DIR/created-body.md"
assert_not_contains "$MOCK_LOG" "issue create"
assert_not_contains "$MOCK_LOG" "issue close"
assert_contains "$WORK/out/stderr" "No open nightly-failure issue."
pass

case="skip with no open issue does not create one"
setup
GATE_RESULT=success
BUILD_RESULT=skipped
PUBLISH_RESULT=skipped
GATE_BUILD=false
run_script
assert_absent "$MOCK_DIR/created-body.md"
assert_not_contains "$MOCK_LOG" "issue create"
assert_not_contains "$MOCK_LOG" "issue close"
pass

case="already recorded recovery still closes"
setup
GATE_RESULT=success
BUILD_RESULT=success
PUBLISH_RESULT=success
printf '%s\n' '[{"number":42,"createdAt":"2026-11-01T00:00:00Z"}]' >"$MOCK_DIR/issues.json"
cat >"$MOCK_DIR/view-42.json" <<EOF
{"body":"Run: $(run_url) (attempt 1)","comments":[]}
EOF
run_script
assert_absent "$MOCK_DIR/comment-42.md"
assert_contains "$MOCK_DIR/close-42.txt" "completed"
pass

case="close failure is reported"
setup
GATE_RESULT=success
BUILD_RESULT=success
PUBLISH_RESULT=success
export MOCK_FAIL_CLOSE=1
expect_status=1
printf '%s\n' '[{"number":42,"createdAt":"2026-11-01T00:00:00Z"}]' >"$MOCK_DIR/issues.json"
run_script
assert_contains "$MOCK_DIR/comment-42.md" "$(run_url) (attempt 1)"
assert_absent "$MOCK_DIR/close-42.txt"
pass

case="edit failure still leaves the failure comment"
setup
GATE_RESULT=success
BUILD_RESULT=failure
PUBLISH_RESULT=skipped
export MOCK_FAIL_EDIT=1
touch "$MOCK_DIR/label-exists"
write_build_failure_jobs
printf '%s\n' 'build	Tests	##[error]still broken' >"$MOCK_DIR/log-failed.txt"
printf '%s\n' '[{"number":42,"createdAt":"2026-11-01T00:00:00Z"}]' >"$MOCK_DIR/issues.json"
run_script
assert_contains "$MOCK_DIR/comment-42.md" "still broken"
assert_contains "$WORK/out/stderr" "Could not assign"
pass

case="cancelled run writes nothing even if another job failed"
setup
GATE_RESULT=failure
BUILD_RESULT=cancelled
PUBLISH_RESULT=skipped
printf '%s\n' '[{"number":42,"createdAt":"2026-11-01T00:00:00Z"}]' >"$MOCK_DIR/issues.json"
run_script
assert_not_contains "$MOCK_LOG" "issue"
assert_absent "$MOCK_DIR/created-body.md"
assert_absent "$MOCK_DIR/comment-42.md"
assert_contains "$WORK/out/stderr" "cancelled"
pass

case="a fully cancelled run writes nothing"
setup
GATE_RESULT=cancelled
BUILD_RESULT=cancelled
PUBLISH_RESULT=cancelled
run_script
assert_not_contains "$MOCK_LOG" "issue"
assert_absent "$MOCK_DIR/created-body.md"
pass

case="other events are ignored"
setup
GITHUB_EVENT_NAME=pull_request
GATE_RESULT=failure
BUILD_RESULT=failure
PUBLISH_RESULT=failure
run_script
assert_not_contains "$MOCK_LOG" "issue"
assert_contains "$WORK/out/stderr" "not a scheduled or manual nightly"
pass

case="unrecognized results leave an open issue alone"
setup
GATE_RESULT=success
BUILD_RESULT=success
PUBLISH_RESULT=skipped
GATE_BUILD=true
printf '%s\n' '[{"number":42,"createdAt":"2026-11-01T00:00:00Z"}]' >"$MOCK_DIR/issues.json"
run_script
assert_not_contains "$MOCK_LOG" "issue"
assert_absent "$MOCK_DIR/comment-42.md"
assert_absent "$MOCK_DIR/created-body.md"
assert_contains "$WORK/out/stderr" "Unrecognized"
pass

case="gate failure is not treated as a deliberate skip"
setup
GATE_RESULT=failure
BUILD_RESULT=skipped
PUBLISH_RESULT=skipped
GATE_BUILD=false
touch "$MOCK_DIR/label-exists"
printf '%s\n' '[{"number":42,"createdAt":"2026-11-01T00:00:00Z"}]' >"$MOCK_DIR/issues.json"
cat >"$MOCK_DIR/jobs.json" <<'EOF'
{"jobs":[
  {"id":11,"name":"gate","conclusion":"failure","steps":[{"number":2,"name":"Run actions/checkout","conclusion":"failure"}]},
  {"id":22,"name":"build","conclusion":"skipped","steps":[]},
  {"id":33,"name":"publish","conclusion":"skipped","steps":[]}
]}
EOF
printf '%s\n' 'gate	Run actions/checkout	##[error]checkout failed' >"$MOCK_DIR/log-failed.txt"
run_script
assert_contains "$MOCK_DIR/comment-42.md" "checkout failed"
assert_contains "$MOCK_DIR/comment-42.md" "gate=\`failure\`"
assert_absent "$MOCK_DIR/close-42.txt"
assert_not_contains "$MOCK_DIR/comment-42.md" "healthy again"
pass

case="a requested build that did not run is not a healthy skip"
setup
GATE_RESULT=success
BUILD_RESULT=skipped
PUBLISH_RESULT=skipped
GATE_BUILD=true
printf '%s\n' '[{"number":42,"createdAt":"2026-11-01T00:00:00Z"}]' >"$MOCK_DIR/issues.json"
run_script
assert_absent "$MOCK_DIR/comment-42.md"
assert_absent "$MOCK_DIR/close-42.txt"
assert_absent "$MOCK_DIR/created-body.md"
assert_contains "$WORK/out/stderr" "build_output=true"
assert_contains "$WORK/out/stderr" "Unrecognized"
pass

case="workflow only adds a report job around the existing nightly"
setup
assert_contains "$WORKFLOW" "if: \${{ always() && !cancelled() }}"
assert_contains "$WORKFLOW" "issues: write"
assert_contains "$WORKFLOW" "actions: read"
assert_contains "$WORKFLOW" "continue-on-error: true"
assert_contains "$WORKFLOW" "bash .github/scripts/nightly-failure-alert.sh"
assert_contains "$WORKFLOW" "ALERT_ASSIGNEE: hardcoreerik"
assert_contains "$WORKFLOW" "cron: '27 10 * * *'"
assert_contains "$WORKFLOW" "cancel-in-progress: false"
# shellcheck disable=SC2016 # these are literal workflow lines, not this script's expansions
assert_contains "$WORKFLOW" 'python tools/release_check.py --mbedtls-source "$MBEDTLS_SOURCE" --pio pio'
assert_contains "$WORKFLOW" 'bash tools/ci/build-dial.sh --out dist --build-id'
# shellcheck disable=SC2016
assert_contains "$WORKFLOW" 'gh release upload "$NIGHTLY_TAG"'
assert_contains "$WORKFLOW" 'repository_dispatch if SITE_DISPATCH_TOKEN'
# Workflow-level token stays read-only; issue writes are only on the report job.
perms=$(awk '
  /^permissions:/ { n++; if (n == 1) { grab = 1; next } }
  grab && /^[^ ]/ { exit }
  grab { print }
' "$WORKFLOW")
printf '%s\n' "$perms" | grep -q 'contents: read' || fail "workflow permissions changed: $perms"
if printf '%s\n' "$perms" | grep -q 'issues:'; then
  fail "workflow-level permissions must not grant issues: $perms"
fi
# gate, build, and publish are still the firmware jobs, in that order, before report.
order=$(grep -E '^  (gate|build|publish|report):' "$WORKFLOW" | tr -d ' :')
[ "$order" = $'gate\nbuild\npublish\nreport' ] || fail "job order changed: $order"
pass

echo "all nightly alert checks passed"
