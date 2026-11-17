// Vector packet codec. Matches protocol/PROTOCOL.md and tools/vector_packet.py.
// No hardware or Arduino dependencies: it runs on a rocket tracker, on a ground
// node, and in the native tests.
#pragma once

#include <stddef.h>
#include <stdint.h>

#define VX_PROTOCOL_VERSION 1
#define VX_PACKET_SIZE 34        // bytes sent over the LoRa radio
#define VX_GROUND_FRAME_SIZE 36  // packet + rssi + snr, sent over the WebSocket

enum VxPhase : uint8_t {
  VX_PHASE_PAD = 0,
  VX_PHASE_BOOST = 1,
  VX_PHASE_COAST = 2,
  VX_PHASE_APOGEE = 3,
  VX_PHASE_DESCENT = 4,
  VX_PHASE_LANDED = 5,
};

enum VxFix : uint8_t { VX_FIX_NONE = 0, VX_FIX_2D = 1, VX_FIX_3D = 2 };

#define VX_FLAG_ARMED 0x01
#define VX_FLAG_LOW_BATTERY 0x02

enum VxError : uint8_t {
  VX_OK = 0,
  VX_BAD_LENGTH,
  VX_BAD_CRC,
  VX_BAD_VERSION,
  VX_BAD_PHASE,
  VX_BAD_FIELD,
};

struct VxPacket {
  uint8_t version;      // always VX_PROTOCOL_VERSION
  uint16_t rocket_id;
  uint16_t seq;
  uint32_t time_ms;     // milliseconds since the tracker booted
  int32_t lat_e7;       // degrees * 10^7
  int32_t lon_e7;       // degrees * 10^7
  int32_t gps_alt_cm;   // centimeters above sea level
  int32_t baro_alt_cm;  // centimeters above the pad reference
  int16_t vspeed_cms;   // centimeters per second, up is positive
  uint16_t battery_mv;
  uint8_t sats;         // 0..63
  uint8_t fix_type;     // 0 none, 1 2D, 2 3D, 3 reserved
  uint8_t phase;        // VxPhase
  uint8_t flags;        // VX_FLAG_*
};

// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF). vx_crc16("123456789") == 0x29B1.
uint16_t vx_crc16(const uint8_t* data, size_t len);

// VxPacket -> 34 bytes. Returns VX_BAD_FIELD if sats > 63 or fix_type > 3.
VxError vx_encode(const VxPacket& p, uint8_t out[VX_PACKET_SIZE]);

// 34 bytes -> VxPacket. Checks, in order: length, CRC, version, phase.
VxError vx_decode(const uint8_t* data, size_t len, VxPacket& out);

// Ground node: take a 34-byte packet received over LoRa, check it, and build the
// 36-byte frame for the app. Returns the same errors as vx_decode if the packet is bad.
VxError vx_make_ground_frame(const uint8_t* packet, size_t len, int8_t rssi_dbm, int8_t snr_db,
                             uint8_t out[VX_GROUND_FRAME_SIZE]);

// "ok", "bad_length", "bad_crc", "bad_version", "bad_phase", "bad_field".
const char* vx_error_name(VxError e);
