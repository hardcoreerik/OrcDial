"""Compile the production FT8 screen against a recording display (no SDK/device)."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def function(source, marker):
    start = source.index(marker)
    brace = source.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]


class Ft8LiveLayoutTest(unittest.TestCase):
    def test_selected_tuning_survives_decode_updates_and_band_changes(self):
        source = (ROOT / 'src/ui.cpp').read_text(encoding='utf-8')
        production = '\n'.join(function(source, marker) for marker in [
            'static void draw_text(', 'static void frequency(',
            'static const char* ft8_band_label(', 'static void ft8_screen(', 'static void sstv_screen('])
        harness = r'''
#include "src/state.hpp"
#include "src/ft8_projection.hpp"
#include "src/ft8_control.hpp"
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>
namespace lgfx {
struct Label { std::string text; int x,y,height; };
class LGFXBase {
 public:
  std::vector<Label> labels;
  int clears=0;
  struct Style { float size_x=1; } style;
  Style getTextStyle() const { return style; }
  void setTextSize(float size) { style.size_x=size; }
  int fontHeight() const { return int(8*style.size_x); }
  int textWidth(const char* text) const { return int(std::strlen(text)*6*style.size_x); }
  void drawString(const char* text,int x,int y) { labels.push_back({text,x,y,fontHeight()}); }
  template<class... T> void setTextColor(T...) {}
  template<class... T> void drawCircle(T...) {}
  template<class... T> void fillRoundRect(T...) {}
  template<class... T> void drawRoundRect(T...) {}
  template<class... T> void fillScreen(T...) { ++clears; }
};
}
namespace orc {
constexpr uint32_t bg=0,panel=1,cyan=2,green=3,ink=4,dim=5,trace_bright=6;
ft8_projection::Card current_ft8_card;
bool sstv_tune=false;uint8_t sstv_confirmation=0;
void back_button(lgfx::LGFXBase&) {}
uint32_t link_color(bool) { return 0; }
int map_calls=0;
void ft8_locator_map(lgfx::LGFXBase&,const ft8_projection::Card&) { ++map_calls; }
'''
        checks = r'''
}
int main() {
  using namespace orc;
  lgfx::LGFXBase display;
  RadioState state{};state.dashboard=Dashboard::ft8;state.selected=6;state.frequency_hz=14074000;
  auto has=[&](const std::string& text) { for(const auto& l:display.labels)if(l.text==text)return true;return false; };
  auto paint=[&] { display.labels.clear();ft8_screen(display,state,true,false,false,false); };
  paint();assert(has("20m") && has("14.074"));
  current_ft8_card.valid=true;current_ft8_card.dial_hz=14074000;
  std::strcpy(current_ft8_card.callsign,"W1AW");
  std::strcpy(current_ft8_card.message,"CQ W1AW FN31");
  std::strcpy(current_ft8_card.grid,"FN31");
  current_ft8_card.flags=ft8_projection::kGridAssociated|ft8_projection::kSnrValid;
  current_ft8_card.snr_db=-12;current_ft8_card.message_received=true;
  paint();assert(has("20m  14.074 MHz") && has("W1AW") && has("CQ W1AW FN31"));
  std::vector<lgfx::Label> body;
  for(const auto& l:display.labels)if(l.y>=100 && l.y<=156)body.push_back(l);
  for(size_t i=1;i<body.size();++i)assert(body[i-1].y+body[i-1].height/2 < body[i].y-body[i].height/2);
  // A station update must not displace the receiver-owned tuning context.
  std::strcpy(current_ft8_card.callsign,"KJ4KFJ");paint();
  assert(has("20m  14.074 MHz") && has("KJ4KFJ"));
  // The knob's acknowledged band change must show 60m, never the old card's band.
  state.selected=3;state.frequency_hz=5357000;paint();
  assert(has("60m") && has("5.357") && !has("KJ4KFJ"));
  current_ft8_card.dial_hz=5357000;paint();
  assert(has("60m  5.357 MHz") && has("KJ4KFJ"));
  state.frequency_hz=5357123;current_ft8_card.dial_hz=5357123;paint();
  assert(has("60m  5.357123 MHz")); // do not round a receiver-owned fine frequency
  state.frequency_hz=5357000;current_ft8_card.dial_hz=5357000;
  state.capabilities=ft8_control::kExpertTuning;paint();
  assert(has("60m") && has("5.357") && !has("KJ4KFJ"));
  state.capabilities=0;display.labels.clear();ft8_screen(display,state,false,false,false,false);
  assert(!has("60m") && !has("KJ4KFJ"));
  state.view=static_cast<uint8_t>(ft8_control::View::map);state.selected=1;
  display.labels.clear();ft8_screen(display,state,true,false,false,false);assert(map_calls==1);
  state.frequency_hz=14074000;display.labels.clear();ft8_screen(display,state,true,false,false,false);
  assert(map_calls==1); // cached station from another frequency must not draw
  state.dashboard=Dashboard::sstv;state.frequency_hz=14230000;state.step_hz=1000;
  state.sstv.valid=true;state.sstv.mode=1;state.sstv.state=4;state.sstv.row=120;state.sstv.rows=240;
  auto sstv_paint=[&] {display.labels.clear();sstv_screen(display,state,Focus::vfo,true,false);};
  sstv_paint();assert(has("RECEIVE") && has("14.230") && has("ROBOT36") && has("LINES 120 / 240"));
  state.sstv.row=121;sstv_paint();assert(has("LINES 121 / 240"));
  sstv_confirmation=2;sstv_paint();assert(has("CONFIRM ABORT?"));
  sstv_tune=true;sstv_paint();assert(has("TUNE") && has("FREQUENCY") && has("STEP 1000 Hz"));
  state.sstv.valid=false;sstv_paint();assert(has("UPDATE TAB5 FOR SSTV"));
  assert(display.clears==0); // this screen path adds no full-screen clear
  std::cout << "FT8 Live tuning/decode layout PASS\n";
}
'''
        (ROOT / '.pio').mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='ft8-layout-', dir=ROOT / '.pio') as temp:
            directory = Path(temp)
            cpp, binary = directory / 'layout.cpp', directory / 'layout-test'
            cpp.write_text(harness + production + checks, encoding='utf-8')
            prefix = [] if shutil.which('g++') else ['wsl.exe', '-d', 'Ubuntu', '--']

            def path(value):
                value = str(value)
                return value if not prefix else '/mnt/' + value[0].lower() + value[2:].replace('\\', '/')

            subprocess.run(prefix + ['g++', '-std=c++17', '-O2', '-Wall', '-Wextra', '-Werror',
                                     '-I' + path(ROOT), path(cpp), '-o', path(binary)], check=True)
            subprocess.run(prefix + [path(binary)], check=True)


if __name__ == '__main__':
    unittest.main()
