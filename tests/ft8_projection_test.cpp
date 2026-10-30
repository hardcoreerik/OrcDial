#include "../src/ft8_projection.hpp"
#include <cassert>
#include <cstddef>
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
  // Golden wire vectors deliberately shared with the opposite repository.
  auto matches_hex = [](const uint8_t* bytes, const char* hex) {
    auto nibble = [](char c) -> unsigned {
      return c >= '0' && c <= '9' ? unsigned(c-'0') :
             c >= 'a' && c <= 'f' ? unsigned(c-'a'+10) : 255u;
    };
    for (size_t i=0; i<64; ++i) {
      const unsigned hi=nibble(hex[i*2]),lo=nibble(hex[i*2+1]);
      if (hi>15 || lo>15 || bytes[i] != uint8_t(hi*16+lo)) return false;
    }
    return hex[128] == 0;
  };
  assert(matches_hex(brief,"4f52444c041102007b00000028030000000000003ca2e36a90c0d60057314157000000000000000000000000464e33310000000000f407000000000037845473"));
  assert(matches_hex(text, "4f52444c041202007b00000028030000000000004351205731415720464e3331000000000000000000000000000000000000000000000000000000007ded8e35"));
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
