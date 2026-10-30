#pragma once
#include "control/protocol.hpp"
#include "control/projection_capabilities.hpp"
#include "maidenhead_grid.hpp"
#include <cstddef>
#include <cstdint>
#include <cstring>

// A strictly bounded v4 *application* extension; the encrypted 64-byte outer
// transport, pairing protocol and existing command numbering do not change.
// This is receiver->Dial observation metadata, never a remote-control command.
// The Tab5 producer MUST gate it on an explicitly negotiated peer capability.
namespace orc::ft8_projection {
constexpr uint8_t kTimeValid = 1u << 0;
constexpr uint8_t kSnrValid = 1u << 1;
constexpr uint8_t kGridAssociated = 1u << 2;
constexpr uint8_t kAssisted = 1u << 3;
constexpr uint8_t kMessageTruncated = 1u << 4;
constexpr uint8_t kKnownFlags = kTimeValid | kSnrValid | kGridAssociated | kAssisted | kMessageTruncated;

struct Card {
  uint32_t sender = 0;
  uint32_t record_id = 0;
  uint32_t utc_epoch = 0;
  uint32_t dial_hz = 0;
  int8_t snr_db = 0;
  uint8_t flags = 0;
  uint8_t mode = 0; // Tab5 ft8::DigitalMode; unsupported values are rejected
  char callsign[16]{};
  char grid[9]{};
  char message[40]{}; // bounded preview; no guessing beyond received text
  bool valid = false;
  bool message_received = false;
};

// Keep the existing v4 framing: header (0..19), 40-byte application data
// (20..59), CRC32 (60..63). No dynamic allocations, no arbitrary reassembly.
inline bool printable_cstr(const uint8_t* wire, size_t n, char* dest, size_t capacity) {
  if (!wire || !dest || n != capacity || !n) return false;
  size_t i = 0;
  for (; i < n && wire[i]; ++i) {
    if (wire[i] < 32 || wire[i] > 126) return false;
    dest[i] = char(wire[i]);
  }
  if (i == n) return false; // bounded, null-terminated only
  dest[i] = 0;
  for (++i; i < n; ++i) if (wire[i] != 0) return false; // reject hidden data
  return true;
}

inline bool valid_frequency(uint32_t hz) { return hz >= 24000 && hz <= 1766000000u; }
inline bool valid_mode(uint8_t mode) { return mode <= 6; }

inline bool decode_brief(const uint8_t wire[packet_size], Card& out) {
  Packet p{};
  if (!decode(wire, packet_size, p) || p.role != Role::receiver ||
      p.type != Type::ft8_decode_brief || !p.sender || !p.sequence || p.band || p.ack) return false;
  Card card{};
  card.sender = p.sender;
  card.record_id = p.sequence;
  card.utc_epoch = get32(wire + 20);
  card.dial_hz = get32(wire + 24);
  card.snr_db = static_cast<int8_t>(wire[53]);
  card.flags = wire[54];
  card.mode = wire[55];
  if (!valid_frequency(card.dial_hz) || !valid_mode(card.mode) ||
      (card.flags & ~kKnownFlags) != 0 || wire[56] || wire[57] || wire[58] || wire[59] ||
      (!((card.flags & kTimeValid) != 0) && card.utc_epoch != 0) ||
      !printable_cstr(wire + 28, 16, card.callsign, 16) ||
      !printable_cstr(wire + 44, 9, card.grid, 9)) return false;
  if (!(card.flags & kGridAssociated) && card.grid[0]) return false;
  if ((card.flags & kGridAssociated) && (!card.callsign[0] || !maidenhead::center(card.grid).valid)) return false;
  if ((card.flags & kTimeValid) && !card.utc_epoch) return false;
  if (!(card.flags & kSnrValid) && card.snr_db != 0) return false;
  card.valid = true;
  out = card;
  return true;
}

inline bool decode_text(const uint8_t wire[packet_size], Card& card) {
  Packet p{};
  if (!decode(wire, packet_size, p) || p.role != Role::receiver ||
      p.type != Type::ft8_decode_text || !card.valid || p.sender != card.sender ||
      p.sequence != card.record_id || p.band || p.ack) return false;
  char text[40]{};
  if (!printable_cstr(wire + 20, 40, text, sizeof(text))) return false;
  std::memcpy(card.message, text, sizeof(text));
  card.message_received = true;
  return true;
}

// UI-task cache. Expiry retains the high-water record so retransmission cannot
// revive an expired decode. Context changes deliberately establish a new cache.
class Receiver {
 public:
  void reset() { *this = {}; }
  void context(uint32_t sender, bool active, uint32_t capabilities) {
    const bool enabled = active && (capabilities & projection::kFt8V1);
    if (sender != sender_ || enabled != enabled_) { reset(); sender_ = sender; enabled_ = enabled; }
  }
  bool receive(const uint8_t* wire, uint32_t now) {
    expire(now);
    if (!enabled_) return false;
    Packet p{};
    if (!decode(wire, packet_size, p) || p.sender != sender_) return false;
    if (p.type == Type::ft8_decode_brief) {
      Card next{};
      if (!decode_brief(wire, next) || !newer_sequence(next.record_id, record_)) return false;
      card_ = next; record_ = next.record_id; at_ = now;
      return true;
    }
    return p.type == Type::ft8_decode_text && decode_text(wire, card_);
  }
  void expire(uint32_t now) { if (card_.valid && uint32_t(now-at_) >= projection::kFreshMs) card_ = {}; }
  const Card& card() const { return card_; }
 private:
  Card card_{};
  uint32_t sender_ = 0, record_ = 0, at_ = 0;
  bool enabled_ = false;
};

// Encode helpers for a receiver-side host test or future negotiated Tab5
// producer. Never call these from the Dial: receiver-only fields.
inline void put_string(uint8_t* out, size_t capacity, const char* in) {
  std::memset(out, 0, capacity);
  if (!in) return;
  for (size_t i = 0; i + 1 < capacity && in[i]; ++i) {
    const uint8_t ch = uint8_t(in[i]);
    if (ch < 32 || ch > 126) break;
    out[i] = ch;
  }
}
inline void encode_brief(const Card& c, uint8_t wire[packet_size]) {
  Packet p{};
  p.type = Type::ft8_decode_brief;
  p.role = Role::receiver;
  p.sender = c.sender;
  p.sequence = c.record_id;
  encode(p, wire);
  put32(wire + 20, c.flags & kTimeValid ? c.utc_epoch : 0);
  put32(wire + 24, c.dial_hz);
  put_string(wire + 28, 16, c.callsign);
  put_string(wire + 44, 9, c.flags & kGridAssociated ? c.grid : nullptr);
  wire[53] = c.flags & kSnrValid ? static_cast<uint8_t>(c.snr_db) : 0;
  wire[54] = c.flags & kKnownFlags;
  wire[55] = c.mode;
  std::memset(wire + 56, 0, 4);
  put32(wire + 60, crc32(wire, 60));
}
inline void encode_text(const Card& c, uint8_t wire[packet_size]) {
  Packet p{};
  p.type = Type::ft8_decode_text;
  p.role = Role::receiver;
  p.sender = c.sender;
  p.sequence = c.record_id;
  encode(p, wire);
  put_string(wire + 20, 40, c.message);
  put32(wire + 60, crc32(wire, 60));
}
} // namespace orc::ft8_projection
