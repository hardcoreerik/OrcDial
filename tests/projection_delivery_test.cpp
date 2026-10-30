#include "../src/ft8_projection.hpp"
#include <cassert>
#include <cstring>
#include <iostream>
using namespace orc;

int main() {
  projection::Peer peer;
  Packet heartbeat{}; heartbeat.type=Type::heartbeat; heartbeat.role=Role::dial;
  heartbeat.sender=41; heartbeat.sequence=10;
  peer.observe(heartbeat, 100); assert(!peer.enabled(100)); // old Dial
  projection::request(heartbeat); heartbeat.sequence++;
  peer.observe(heartbeat, 101); assert(peer.enabled(101));
  peer.observe(heartbeat, 3500); assert(!peer.enabled(3601)); // duplicates cannot renew
  heartbeat.sequence++; heartbeat.revision++;
  peer.observe(heartbeat, 3602); assert(!peer.enabled(3602)); // unknown schema
  projection::request(heartbeat); heartbeat.sequence++;
  peer.observe(heartbeat, UINT32_MAX-10); assert(peer.enabled(10));
  heartbeat.sender=42; heartbeat.sequence=1; heartbeat.capabilities=0;
  peer.observe(heartbeat, 20); assert(!peer.enabled(20)); // peer change
  peer.reset(); assert(!peer.enabled(0));

  ft8_projection::Card c{}; c.sender=123; c.record_id=808; c.dial_hz=14074000;
  std::strcpy(c.message, "CQ W1AW FN31");
  uint8_t brief[64]{},text[64]{};
  ft8_projection::encode_brief(c,brief); ft8_projection::encode_text(c,text);
  ft8_projection::Receiver rx;
  rx.context(123,true,0); assert(!rx.receive(brief,10)); // old receiver
  rx.context(123,true,projection::kFt8V1);
  assert(!rx.receive(text,10)); // delayed summary: retry is needed
  assert(rx.receive(brief,11)); assert(rx.receive(text,12));
  assert(rx.card().message_received && !rx.card().flags && !rx.card().callsign[0]);
  assert(!rx.receive(brief,20)); assert(rx.card().message_received); // duplicate retains text
  c.record_id=807; ft8_projection::encode_brief(c,brief); assert(!rx.receive(brief,21));
  c.record_id=809; ft8_projection::encode_brief(c,brief); assert(rx.receive(brief,22));
  assert(!rx.receive(text,23)); // old text cannot attach to a newer summary
  ft8_projection::encode_text(c,text); text[21]^=1; assert(!rx.receive(text,24));
  ft8_projection::encode_text(c,text); assert(rx.receive(text,25));
  rx.expire(60022); assert(!rx.card().valid);
  assert(!rx.receive(brief,60023)); assert(!rx.receive(text,60023)); // cannot resurrect
  rx.context(123,false,projection::kFt8V1); assert(!rx.card().valid);
  rx.context(123,true,projection::kFt8V1); assert(rx.receive(brief,60024));
  rx.context(456,true,projection::kFt8V1); assert(!rx.receive(brief,60025));
  rx.reset(); assert(!rx.receive(brief,60026)); // disconnect/session generation

  // Reserved fields, hidden bytes and false grid associations are rejected.
  ft8_projection::Card decoded{};
  brief[16]=1; put32(brief+60,crc32(brief,60)); assert(!ft8_projection::decode_brief(brief,decoded));
  c.flags=ft8_projection::kGridAssociated; std::strcpy(c.grid,"ZZ99");
  std::strcpy(c.callsign,"W1AW"); ft8_projection::encode_brief(c,brief);
  assert(!ft8_projection::decode_brief(brief,decoded));
  std::strcpy(c.grid,"FN31"); ft8_projection::encode_brief(c,brief);
  assert(ft8_projection::decode_brief(brief,decoded));
  brief[35]='X';put32(brief+60,crc32(brief,60));assert(!ft8_projection::decode_brief(brief,decoded));
  std::cout << "projection_delivery_test PASS\n";
}
