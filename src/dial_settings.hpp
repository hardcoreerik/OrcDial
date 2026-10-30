#pragma once
#include <Preferences.h>
#include <cstdint>
#include "control/diagnostics.hpp"
#include "control/secure_session.hpp"
#include "sound.hpp"

namespace orc {
// Dial Settings: what the Dial itself remembers (not the pairing, which the secure session stores).
struct DialSettings {
  uint8_t brightness = 200;   // 15..255
  uint8_t sleep = 0;          // 0 never, 1 30 s, 2 1 min, 3 5 min
  uint8_t accel = 1;          // knob acceleration: 0 off, 1 normal, 2 fast
  bool invert = false;        // reverse the knob direction
  bool click = false;         // a short tick per detent
  sound::Settings sound;
};
constexpr uint32_t sleep_ms[4] = {0, 30000, 60000, 300000};
constexpr const char* sleep_names[4] = {"NEVER", "30 SEC", "1 MIN", "5 MIN"};
constexpr const char* accel_names[3] = {"OFF", "NORMAL", "FAST"};

inline void load_settings(DialSettings& s) {
  Preferences p;
  if (!p.begin("dialset", true)) return;
  const uint8_t brightness = p.getUChar("bright", s.brightness);
  s.brightness = brightness < 15 ? 15 : brightness;
  s.sleep = p.getUChar("sleep", s.sleep) % 4;
  const uint8_t accel = p.getUChar("accel", s.accel);
  s.accel = accel > 2 ? 1 : accel;
  s.invert = p.getBool("invert", s.invert);
  s.click = p.getBool("click", s.click);
  s.sound.enabled = p.getBool("snd_on", s.sound.enabled);
  s.sound.muted = p.getBool("snd_mute", s.sound.muted);
  s.sound.volume = p.getUChar("snd_vol", s.sound.volume);
  s.sound.events = p.getUChar("snd_events", s.sound.events) & sound::kAllEvents;
  p.end();
}
// False when the storage could not be opened (the change still applies until the next boot).
inline bool save_settings(const DialSettings& s) {
  Preferences p;
  if (!p.begin("dialset", false)) return false;
  p.putUChar("bright", s.brightness);
  p.putUChar("sleep", s.sleep);
  p.putUChar("accel", s.accel);
  p.putBool("invert", s.invert);
  p.putBool("click", s.click);
  const bool sound_saved = p.putBool("snd_on", s.sound.enabled) == 1 &&
      p.putBool("snd_mute", s.sound.muted) == 1 &&
      p.putUChar("snd_vol", s.sound.volume) == 1 &&
      p.putUChar("snd_events", s.sound.events) == 1;
  p.end();
  return sound_saved;
}
inline bool erase_settings() {
  Preferences p;
  if (!p.begin("dialset", false)) return false;
  p.clear();
  p.end();
  return true;
}

// The vertical menu. PAIRING opens the existing pairing screen; the rest are pages.
enum class Page : uint8_t { pairing, link, display, knob, sound, about, reset, back };
constexpr int page_count = 8;
constexpr const char* page_names[page_count] = {"PAIRING", "LINK", "DISPLAY", "KNOB", "SOUND", "ABOUT", "RESET", "BACK"};
// Settings screens return to Home after this long without input.
constexpr uint32_t settings_idle_ms = 60000;
inline int page_rows(Page page) { return page == Page::display ? 2 : page == Page::knob ? 3 : page == Page::sound ? 8 : 0; }

struct SettingsView {
  int menu = 0;
  Page page = Page::link;
  int row = 0;
  bool reset_armed = false;
  bool linked = false;
  DialSettings settings;
  LinkDiagnostics link;
  secure::Status security;
  char mac[18] = "";
};
} // namespace orc
