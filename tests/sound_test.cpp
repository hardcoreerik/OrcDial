#include "../src/sound.hpp"
#include <cassert>
#include <cstdio>
using namespace orc::sound;
struct Speaker {
  unsigned tones=0,stops=0,volume=0,hz=0,duration=0;
  bool playing=false,accept=true;
  void stop(){++stops;playing=false;}
  void setVolume(unsigned value){volume=value;}
  bool tone(unsigned frequency,unsigned milliseconds){
    ++tones;hz=frequency;duration=milliseconds;playing=accept;return accept;
  }
};
int main() {
  Settings settings;Player player;Speaker speaker;
  player.configure(settings,speaker);
  assert(!player.notify(Event::complete,1)); // opt-in alerts
  assert(!player.tick(0,speaker));assert(speaker.tones==0);
  settings.enabled=true;player.configure(settings,speaker);
  assert(!player.notify(Event::complete,1)); // disabled observations never replay
  assert(player.notify(Event::complete,2));assert(player.tick(0,speaker));
  assert(speaker.playing && speaker.duration<=180 && player.played_count()==1);
  assert(!player.notify(Event::complete,2));assert(!player.notify(Event::complete,1));
  assert(player.notify(Event::saved,2));assert(player.pending());
  settings.muted=true;player.configure(settings,speaker);
  assert(!speaker.playing && !player.pending() && !player.active());
  const auto tones=speaker.tones;
  assert(!player.notify(Event::error,3));player.click(speaker);assert(!player.test(Event::complete));
  assert(!player.tick(1000,speaker));assert(speaker.tones==tones);
  settings.muted=false;player.configure(settings,speaker);
  assert(!player.tick(1001,speaker));assert(!player.notify(Event::error,3));
  settings.volume=0;player.configure(settings,speaker);player.click(speaker);
  assert(!player.test(Event::complete) && speaker.tones==tones);
  settings.volume=32;settings.events &= ~(1u<<uint8_t(Event::complete));
  player.configure(settings,speaker);assert(speaker.volume==32);
  assert(!player.notify(Event::complete,4));assert(!player.test(Event::complete));
  settings.events=kAllEvents;player.configure(settings,speaker);
  assert(player.test(Event::complete));assert(player.tick(1500,speaker));
  player.stop(speaker);assert(!speaker.playing && !player.pending());
  assert(player.notify(Event::receive,10));assert(!player.tick(1600,speaker)); // rate limit
  assert(player.tick(2000,speaker));
  player.tick(2100,speaker);assert(!player.active());
  settings.enabled=false;player.configure(settings,speaker);
  assert(!player.notify(Event::link_lost,1));assert(!player.tick(3000,speaker));
  player.click(speaker);assert(speaker.duration==6); // clicks independent of alert enable
  settings.muted=true;player.configure(settings,speaker);const auto before=speaker.tones;
  player.click(speaker);assert(speaker.tones==before);
  settings.muted=false;settings.enabled=true;player.configure(settings,speaker);
  assert(player.notify(Event::link_lost,2));assert(player.tick(UINT32_MAX-100,speaker));
  player.tick(100,speaker);assert(!player.active()); // wrap-safe duration
  assert(!player.notify(Event::count,9));
  assert(mute_hit(28,65) && !mute_hit(42,65) && !mute_hit(100,210));
  std::puts("sound_test PASS: mute/stop, bounded tones, dedup, volume, categories, wrap, quick-hit bounds");
}
