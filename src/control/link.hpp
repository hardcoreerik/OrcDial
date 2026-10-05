#pragma once
#include "protocol.hpp"
#include "secure_runtime.hpp"
#include "../state.hpp"
#include "../controller.hpp"
#include <Arduino.h>
#include <esp_now.h>
#include <freertos/queue.h>

namespace orc {
class Link {
 public:
  bool begin();
  void poll();
  void start_pairing();
  void cancel_pairing() { secure_.action(secure::Action::cancel); }
  void confirm_pairing(uint32_t code) { secure_.action(secure::Action::confirm,code); }
  void connect() { secure_.action(secure::Action::connect); }
  void forget() { secure_.action(secure::Action::forget); }
  void boot_connect(bool enabled) { secure_.action(secure::Action::boot,enabled); }
  secure::Status security_status() const { return secure_.status(); }
  void disconnect(bool notify = true);
  bool paused() const { return paused_; }
  bool command(Type type, int32_t value);
  bool command_action(Action action);
  bool connected() const { return connected_ && secure_.status().state==secure::State::connected; }
  bool pairing() const { auto s=secure_.status().state;return s==secure::State::searching || s==secure::State::exchanging || s==secure::State::verify; }
  bool pending() const { return pending_sequence_ != 0; }
  uint32_t pending_sequence() const { return pending_sequence_; }
  const RadioState& state() const { return state_; }
  uint32_t last_ack() const { return last_ack_; }
 private:
  struct Incoming { uint8_t mac[6]; uint8_t data[packet_size]; uint8_t size; };
  static void receive(const uint8_t* mac, const uint8_t* data, int size);
  static bool transmit(const uint8_t* mac,const uint8_t* wire);
  static void scan(uint8_t channel);
  void handle(const Incoming& incoming);
  bool send(Type type, int32_t value = 0, uint32_t sequence = 0, ActionKind action = ActionKind::none);
  uint32_t device_id_ = 0;
  uint32_t next_sequence_ = 1;
  uint32_t pending_sequence_ = 0;
  uint32_t last_ack_ = 0;
  uint32_t last_sender_ = 0;
  uint32_t last_state_sequence_ = 0;
  uint32_t last_rx_ms_ = 0;
  uint32_t last_tx_ms_ = 0;
  uint32_t pending_ms_ = 0;
  uint8_t retries_ = 0;
  bool connected_ = false;
  bool paused_ = false;
  Packet pending_{};
  RadioState state_{};
  secure::Runtime secure_;
  static Link* active_;
};
} // namespace orc
