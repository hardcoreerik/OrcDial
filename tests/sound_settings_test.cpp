#include "../src/dial_settings.hpp"
#include <cassert>
#include <cstdio>
int main() {
  orc::DialSettings s;orc::load_settings(s);assert(!s.sound.enabled && !s.sound.muted);
  s.sound.enabled=true;s.sound.muted=true;s.sound.volume=32;s.sound.events=5;
  assert(orc::save_settings(s));orc::DialSettings loaded;orc::load_settings(loaded);
  assert(loaded.sound.enabled && loaded.sound.muted && loaded.sound.volume==32 && loaded.sound.events==5);
  Preferences::values["snd_events"]=255;orc::load_settings(loaded);assert(loaded.sound.events==orc::sound::kAllEvents);
  Preferences::fail=true;assert(!orc::save_settings(s));Preferences::fail=false;
  std::puts("sound settings persistence PASS");
}
