#include "../src/maidenhead_grid.hpp"
#include <cassert>
#include <cmath>
#include <iostream>
using namespace orc::maidenhead;
int main() {
  auto c=center("FN31");
  assert(c.valid && c.precision == 4);
  assert(std::abs(c.longitude - (-73.0)) < 0.0001);
  assert(std::abs(c.latitude - 41.5) < 0.0001);
  auto fine=center("FN31aa");
  assert(fine.valid && fine.precision == 6);
  assert(fine.longitude < c.longitude && fine.latitude < c.latitude);
  auto very_fine=center("FN31aa00");
  assert(very_fine.valid && very_fine.precision == 8);
  assert(very_fine.longitude <= fine.longitude && very_fine.latitude <= fine.latitude);
  assert(center("fn31").valid && center("fn31").longitude == c.longitude);
  assert(!center(nullptr).valid);
  assert(!center("").valid);
  assert(!center("ZZ99").valid);
  assert(!center("FN3").valid);
  assert(!center("FN31zz").valid);
  assert(!center("FN31aaXY").valid);
  assert(!center("FN31aa000").valid);
  std::cout << "maidenhead_grid_test PASS\n";
}
