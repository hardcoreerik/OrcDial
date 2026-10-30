#include "../src/ft8_projection.hpp"
#include <cassert>
#include <cstring>
#include <iostream>
using namespace orc;
int main() {
  ft8_projection::Card original{};
  original.sender = 123; original.record_id = 808;
  original.utc_epoch = 1793303100;
  original.dial_hz = 14074000;
  original.flags = ft8_projection::kTimeValid | ft8_projection::kSnrValid |
                   ft8_projection::kGridAssociated;
  original.snr_db = -12;
  std::strcpy(original.callsign, "W1AW");
  std::strcpy(original.grid, "FN31");
  std::strcpy(original.message, "CQ W1AW FN31");
  uint8_t brief[packet_size]{}, text[packet_size]{};
  ft8_projection::encode_brief(original, brief);
  ft8_projection::encode_text(original, text);
  ft8_projection::Card decoded{};
  assert(ft8_projection::decode_brief(brief, decoded));
  assert(decoded.valid && !decoded.message_received);
  assert(decoded.sender == original.sender && decoded.record_id == original.record_id);
  assert(decoded.utc_epoch == original.utc_epoch && decoded.dial_hz == original.dial_hz);
  assert(decoded.snr_db == -12 && decoded.flags == original.flags);
  assert(std::strcmp(decoded.callsign, "W1AW") == 0);
  assert(std::strcmp(decoded.grid, "FN31") == 0);
  assert(ft8_projection::decode_text(text, decoded));
  assert(decoded.message_received && std::strcmp(decoded.message, "CQ W1AW FN31") == 0);
  assert(!ft8_projection::decode_text(brief, decoded));
  uint8_t tampered[packet_size]{};
  std::memcpy(tampered, text, packet_size);
  tampered[20] ^= 1;
  assert(!ft8_projection::decode_text(tampered, decoded)); // CRC check
  put32(text + 12, 809); put32(text + 60, crc32(text,60));
  assert(!ft8_projection::decode_text(text, decoded)); // wrong record id
  // No station location inferred when grid is not actually associated.
  original.flags = ft8_projection::kSnrValid;
  original.grid[0] = 0;
  original.utc_epoch = 0;
  ft8_projection::encode_brief(original, brief);
  assert(ft8_projection::decode_brief(brief, decoded));
  assert(decoded.grid[0] == 0 && decoded.utc_epoch == 0);
  // Corrupt flags with valid CRC must be rejected by semantic parser.
  brief[54] |= 0x80; put32(brief + 60, crc32(brief,60));
  assert(!ft8_projection::decode_brief(brief, decoded));
  ft8_projection::encode_brief(original, brief);
  brief[28] = 0x0A; put32(brief + 60, crc32(brief,60));
  assert(!ft8_projection::decode_brief(brief, decoded)); // control char
  ft8_projection::encode_brief(original, brief);
  brief[43] = 0x41; put32(brief + 60, crc32(brief,60));
  assert(!ft8_projection::decode_brief(brief, decoded)); // unterminated callsign
  std::cout << "ft8_projection_test PASS\n";
}
