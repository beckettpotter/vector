#include "vector_packet.h"

#include <string.h>

// Byte offsets inside the 34-byte packet (see protocol/PROTOCOL.md).
enum {
  OFF_VERSION = 0,
  OFF_ROCKET_ID = 1,
  OFF_SEQ = 3,
  OFF_TIME_MS = 5,
  OFF_LAT = 9,
  OFF_LON = 13,
  OFF_GPS_ALT = 17,
  OFF_BARO_ALT = 21,
  OFF_VSPEED = 25,
  OFF_BATTERY = 27,
  OFF_GPS_STATUS = 29,
  OFF_PHASE = 30,
  OFF_FLAGS = 31,
  OFF_CRC = 32,
};

static void put16(uint8_t* b, uint16_t v) {
  b[0] = (uint8_t)(v & 0xFF);
  b[1] = (uint8_t)(v >> 8);
}

static void put32(uint8_t* b, uint32_t v) {
  b[0] = (uint8_t)(v & 0xFF);
  b[1] = (uint8_t)((v >> 8) & 0xFF);
  b[2] = (uint8_t)((v >> 16) & 0xFF);
  b[3] = (uint8_t)((v >> 24) & 0xFF);
}

static uint16_t get16(const uint8_t* b) { return (uint16_t)(b[0] | (b[1] << 8)); }

static uint32_t get32(const uint8_t* b) {
  return (uint32_t)b[0] | ((uint32_t)b[1] << 8) | ((uint32_t)b[2] << 16) | ((uint32_t)b[3] << 24);
}

uint16_t vx_crc16(const uint8_t* data, size_t len) {
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < len; i++) {
    crc ^= (uint16_t)data[i] << 8;
    for (int bit = 0; bit < 8; bit++) {
      crc = (crc & 0x8000) ? (uint16_t)((crc << 1) ^ 0x1021) : (uint16_t)(crc << 1);
    }
  }
  return crc;
}

VxError vx_encode(const VxPacket& p, uint8_t out[VX_PACKET_SIZE]) {
  if (p.sats > 63 || p.fix_type > 3) return VX_BAD_FIELD;
  out[OFF_VERSION] = p.version;
  put16(out + OFF_ROCKET_ID, p.rocket_id);
  put16(out + OFF_SEQ, p.seq);
  put32(out + OFF_TIME_MS, p.time_ms);
  put32(out + OFF_LAT, (uint32_t)p.lat_e7);
  put32(out + OFF_LON, (uint32_t)p.lon_e7);
  put32(out + OFF_GPS_ALT, (uint32_t)p.gps_alt_cm);
  put32(out + OFF_BARO_ALT, (uint32_t)p.baro_alt_cm);
  put16(out + OFF_VSPEED, (uint16_t)p.vspeed_cms);
  put16(out + OFF_BATTERY, p.battery_mv);
  out[OFF_GPS_STATUS] = (uint8_t)((p.fix_type << 6) | p.sats);
  out[OFF_PHASE] = p.phase;
  out[OFF_FLAGS] = p.flags;
  put16(out + OFF_CRC, vx_crc16(out, OFF_CRC));
  return VX_OK;
}

VxError vx_decode(const uint8_t* data, size_t len, VxPacket& out) {
  if (data == nullptr || len != VX_PACKET_SIZE) return VX_BAD_LENGTH;
  if (vx_crc16(data, OFF_CRC) != get16(data + OFF_CRC)) return VX_BAD_CRC;
  if (data[OFF_VERSION] != VX_PROTOCOL_VERSION) return VX_BAD_VERSION;
  if (data[OFF_PHASE] > VX_PHASE_LANDED) return VX_BAD_PHASE;
  out.version = data[OFF_VERSION];
  out.rocket_id = get16(data + OFF_ROCKET_ID);
  out.seq = get16(data + OFF_SEQ);
  out.time_ms = get32(data + OFF_TIME_MS);
  out.lat_e7 = (int32_t)get32(data + OFF_LAT);
  out.lon_e7 = (int32_t)get32(data + OFF_LON);
  out.gps_alt_cm = (int32_t)get32(data + OFF_GPS_ALT);
  out.baro_alt_cm = (int32_t)get32(data + OFF_BARO_ALT);
  out.vspeed_cms = (int16_t)get16(data + OFF_VSPEED);
  out.battery_mv = get16(data + OFF_BATTERY);
  out.sats = data[OFF_GPS_STATUS] & 0x3F;
  out.fix_type = data[OFF_GPS_STATUS] >> 6;
  out.phase = data[OFF_PHASE];
  out.flags = data[OFF_FLAGS];
  return VX_OK;
}

VxError vx_make_ground_frame(const uint8_t* packet, size_t len, int8_t rssi_dbm, int8_t snr_db,
                             uint8_t out[VX_GROUND_FRAME_SIZE]) {
  VxPacket check;
  VxError e = vx_decode(packet, len, check);
  if (e != VX_OK) return e;
  memcpy(out, packet, VX_PACKET_SIZE);
  out[VX_PACKET_SIZE] = (uint8_t)rssi_dbm;
  out[VX_PACKET_SIZE + 1] = (uint8_t)snr_db;
  return VX_OK;
}

const char* vx_error_name(VxError e) {
  switch (e) {
    case VX_OK: return "ok";
    case VX_BAD_LENGTH: return "bad_length";
    case VX_BAD_CRC: return "bad_crc";
    case VX_BAD_VERSION: return "bad_version";
    case VX_BAD_PHASE: return "bad_phase";
    case VX_BAD_FIELD: return "bad_field";
  }
  return "unknown";
}
