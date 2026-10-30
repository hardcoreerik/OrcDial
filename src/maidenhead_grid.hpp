#pragma once
#include <cstdint>
#include <cstddef>

// Decode Maidenhead *area center* for a local, offline locator view.
// This is NOT transmitter GPS or registration address. Even a valid locator
// is only useful for this receiver when its owner has associated it to a CQ.
namespace orc::maidenhead {
struct Center {
  double latitude = 0.0;
  double longitude = 0.0;
  uint8_t precision = 0;
  bool valid = false;
};
constexpr char upper(char ch) {
  return ch >= 'a' && ch <= 'z' ? char(ch - ('a' - 'A')) : ch;
}
inline Center center(const char* grid) {
  Center out{};
  if (!grid) return out;
  size_t n = 0;
  while (n <= 8 && grid[n]) ++n;
  if (n != 4 && n != 6 && n != 8) return out;
  const char a = upper(grid[0]), b = upper(grid[1]);
  if (a < 'A' || a > 'R' || b < 'A' || b > 'R' ||
      grid[2] < '0' || grid[2] > '9' ||
      grid[3] < '0' || grid[3] > '9') return out;
  double lon = -180.0 + (a - 'A') * 20.0 + (grid[2] - '0') * 2.0;
  double lat = -90.0 + (b - 'A') * 10.0 + (grid[3] - '0') * 1.0;
  double width_lon = 2.0, width_lat = 1.0;
  if (n >= 6) {
    const char c = upper(grid[4]), d = upper(grid[5]);
    if (c < 'A' || c > 'X' || d < 'A' || d > 'X') return out;
    width_lon /= 24.0; width_lat /= 24.0;
    lon += (c - 'A') * width_lon;
    lat += (d - 'A') * width_lat;
  }
  if (n == 8) {
    if (grid[6] < '0' || grid[6] > '9' ||
        grid[7] < '0' || grid[7] > '9') return out;
    width_lon /= 10.0; width_lat /= 10.0;
    lon += (grid[6] - '0') * width_lon;
    lat += (grid[7] - '0') * width_lat;
  }
  out.longitude = lon + width_lon / 2.0;
  out.latitude = lat + width_lat / 2.0;
  out.precision = uint8_t(n);
  out.valid = true;
  return out;
}
} // namespace orc::maidenhead
