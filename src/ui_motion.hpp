#pragma once
#include <cstdint>

// Deterministic, allocation-free UI timing for the 240x240 M5Dial.
// All motion is presentation only. Never interpret it as RF energy, FT8
// synchronization, receiver strength, station movement, or sensor evidence.
namespace orc::motion {
constexpr uint16_t phase_degrees(uint32_t elapsed_ms, uint32_t period_ms, uint16_t offset = 0) {
  return period_ms ? uint16_t((uint64_t(elapsed_ms % period_ms) * 360u / period_ms + offset) % 360u) : 0;
}
// Deliberately non-sinusoidal: cheap on the MCU and deterministic under millis() wrap.
constexpr uint8_t breath(uint32_t elapsed_ms, uint32_t period_ms = 2400) {
  if (period_ms < 2) return 0;
  const uint32_t half = period_ms / 2;
  const uint32_t x = elapsed_ms % period_ms;
  return uint8_t((x < half ? x : period_ms - x) * 255u / half);
}
constexpr uint8_t progress(uint32_t elapsed_ms, uint32_t duration_ms) {
  return duration_ms == 0 || elapsed_ms >= duration_ms ? 255 :
      uint8_t(uint64_t(elapsed_ms) * 255u / duration_ms);
}
// Supports wraparound on millis(): subtraction is defined modulo 2^32.
constexpr bool recent(uint32_t now_ms, uint32_t event_ms, uint32_t window_ms) {
  return event_ms != 0 && uint32_t(now_ms - event_ms) < window_ms;
}
constexpr int16_t orbit_x(uint16_t heading) { // cardinal-only anchor for cheap host tests
  return heading < 90 ? 1 : heading < 180 ? 0 : heading < 270 ? -1 : 0;
}
} // namespace orc::motion
