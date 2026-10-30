#include "../src/ui_motion.hpp"
#include <cassert>
#include <cstdint>
#include <iostream>

int main() {
  using namespace orc::motion;
  static_assert(phase_degrees(0, 3600) == 0);
  static_assert(phase_degrees(900, 3600) == 90);
  static_assert(phase_degrees(3600, 3600) == 0);
  static_assert(phase_degrees(900, 3600, 180) == 270);
  static_assert(phase_degrees(12, 0) == 0);
  static_assert(breath(0, 2400) == 0);
  static_assert(breath(1200, 2400) == 255);
  static_assert(breath(2400, 2400) == 0);
  static_assert(breath(500, 1) == 0);
  static_assert(progress(0, 1000) == 0);
  static_assert(progress(1000, 1000) == 255);
  static_assert(progress(1500, 1000) == 255);
  static_assert(progress(10, 0) == 255);
  static_assert(recent(25, UINT32_MAX - 20, 100)); // timer wraps
  static_assert(!recent(25, UINT32_MAX - 20, 20));
  static_assert(!recent(100, 0, 500)); // "no event" sentinel
  for (uint32_t period = 2; period <= 5000; ++period) {
    for (uint32_t elapsed = 0; elapsed < period * 2; elapsed += 37) {
      assert(phase_degrees(elapsed, period) < 360);
      assert(breath(elapsed, period) <= 255);
    }
  }
  std::cout << "ui_motion_test PASS\n";
}
