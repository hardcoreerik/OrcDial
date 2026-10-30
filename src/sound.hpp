#pragma once
#include <cstdint>

namespace orc::sound {
enum class Event : uint8_t { receive, complete, saved, error, link_lost, count };
constexpr uint8_t kAllEvents = (1u << uint8_t(Event::count)) - 1;
struct Settings {
  bool enabled = false; // alerts are opt-in; existing knob clicks remain separate
  bool muted = false;   // one master mute covers alerts AND knob clicks
  uint8_t volume = 64;
  uint8_t events = kAllEvents;
};
constexpr const char* names[] = {"RECEIVE", "COMPLETE", "SAVED", "ERROR", "LINK_LOST"};
constexpr uint16_t frequencies[] = {880,1320,1760,330,440};
constexpr uint16_t durations[] = {60,120,80,180,150};
inline bool muted(const Settings& s) { return s.muted || s.volume == 0; }
inline bool allowed(const Settings& s, Event event) {
  return uint8_t(event) < uint8_t(Event::count) && s.enabled && !muted(s) &&
         (s.events & (1u << uint8_t(event)));
}
// Top-left speaker control, outside the keypad's first key and Back button.
constexpr bool mute_hit(int x, int y) { return x >= 16 && x < 40 && y >= 49 && y < 84; }

// One pending event, short bounded tones, no allocations or radio work.
// Speaker supplies stop(), setVolume() and tone(hz, duration), as M5Unified does.
class Player {
 public:
  template<class Speaker> void stop(Speaker& speaker) {
    speaker.stop(); pending_ = false; active_ = false;
  }
  template<class Speaker> void configure(const Settings& next, Speaker& speaker) {
    settings_ = next;
    settings_.events &= kAllEvents;
    // Cancel stale sound even when changing a single category or the volume.
    stop(speaker); speaker.setVolume(settings_.volume);
  }
  bool notify(Event event, uint32_t identity) {
    const auto index = uint8_t(event);
    if (index >= uint8_t(Event::count) || !identity ||
        (seen_[index] && int32_t(identity-seen_[index]) <= 0)) return false;
    seen_[index] = identity; // muted/disabled observations never replay on unmute
    if (!allowed(settings_, event)) return false;
    pending_event_ = event; pending_ = true; return true;
  }
  bool test(Event event) {
    if (!allowed(settings_, event)) return false;
    pending_event_ = event; pending_ = true; return true;
  }
  template<class Speaker> bool tick(uint32_t now, Speaker& speaker) {
    if (active_ && uint32_t(now-started_) >= durations[uint8_t(active_event_)]) active_ = false;
    if (!pending_ || active_ || (played_ && uint32_t(now-started_) < 500)) return false;
    const Event event = pending_event_; pending_ = false;
    if (!allowed(settings_, event)) return false;
    if (!speaker.tone(frequencies[uint8_t(event)], durations[uint8_t(event)])) return false;
    active_event_ = event; started_ = now; active_ = true; played_ = true; ++played_count_;
    return true;
  }
  template<class Speaker> void click(Speaker& speaker) {
    if (!muted(settings_) && !active_ && !pending_) speaker.tone(3200, 6);
  }
  bool active() const { return active_; }
  bool pending() const { return pending_; }
  uint32_t played_count() const { return played_count_; }
 private:
  Settings settings_{};
  uint32_t seen_[uint8_t(Event::count)]{};
  uint32_t started_ = 0, played_count_ = 0;
  Event pending_event_ = Event::receive, active_event_ = Event::receive;
  bool pending_ = false, active_ = false, played_ = false;
};
} // namespace orc::sound
