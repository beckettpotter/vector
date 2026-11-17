// Native tests for the packet library. Run with:  pio test -e native
// Every test is driven by protocol/vectors.h, which is generated from the Python
// reference implementation, so these tests prove the C++ code matches it byte for byte.
#include <string.h>
#include <unity.h>

#include "vector_packet.h"
#include "vectors.h"

#define CHECK_EQ(actual, expected, name) \
  TEST_ASSERT_TRUE_MESSAGE((long long)(actual) == (long long)(expected), name)

void setUp(void) {}
void tearDown(void) {}

static VxPacket packet_from(const VxVectorValid& v) {
  VxPacket p;
  p.version = v.version;
  p.rocket_id = v.rocket_id;
  p.seq = v.seq;
  p.time_ms = v.time_ms;
  p.lat_e7 = v.lat_e7;
  p.lon_e7 = v.lon_e7;
  p.gps_alt_cm = v.gps_alt_cm;
  p.baro_alt_cm = v.baro_alt_cm;
  p.vspeed_cms = v.vspeed_cms;
  p.battery_mv = v.battery_mv;
  p.sats = v.sats;
  p.fix_type = v.fix_type;
  p.phase = v.phase;
  p.flags = v.flags;
  return p;
}

void test_crc_check_value(void) {
  const uint8_t text[] = {'1', '2', '3', '4', '5', '6', '7', '8', '9'};
  CHECK_EQ(vx_crc16(text, sizeof(text)), VX_CRC_CHECK_VALUE, "crc check value");
}

void test_encode_matches_every_valid_vector(void) {
  for (size_t i = 0; i < VX_VALID_COUNT; i++) {
    uint8_t out[VX_PACKET_SIZE];
    VxPacket p = packet_from(VX_VALID[i]);
    CHECK_EQ(vx_encode(p, out), VX_OK, VX_VALID[i].name);
    TEST_ASSERT_EQUAL_MEMORY_MESSAGE(VX_VALID[i].bytes, out, VX_PACKET_SIZE, VX_VALID[i].name);
  }
}

void test_decode_matches_every_valid_vector(void) {
  for (size_t i = 0; i < VX_VALID_COUNT; i++) {
    const VxVectorValid& v = VX_VALID[i];
    VxPacket p;
    CHECK_EQ(vx_decode(v.bytes, VX_PACKET_SIZE, p), VX_OK, v.name);
    CHECK_EQ(p.version, v.version, v.name);
    CHECK_EQ(p.rocket_id, v.rocket_id, v.name);
    CHECK_EQ(p.seq, v.seq, v.name);
    CHECK_EQ(p.time_ms, v.time_ms, v.name);
    CHECK_EQ(p.lat_e7, v.lat_e7, v.name);
    CHECK_EQ(p.lon_e7, v.lon_e7, v.name);
    CHECK_EQ(p.gps_alt_cm, v.gps_alt_cm, v.name);
    CHECK_EQ(p.baro_alt_cm, v.baro_alt_cm, v.name);
    CHECK_EQ(p.vspeed_cms, v.vspeed_cms, v.name);
    CHECK_EQ(p.battery_mv, v.battery_mv, v.name);
    CHECK_EQ(p.sats, v.sats, v.name);
    CHECK_EQ(p.fix_type, v.fix_type, v.name);
    CHECK_EQ(p.phase, v.phase, v.name);
    CHECK_EQ(p.flags, v.flags, v.name);
  }
}

void test_every_invalid_vector_is_rejected_with_its_error(void) {
  for (size_t i = 0; i < VX_INVALID_COUNT; i++) {
    VxPacket p;
    VxError e = vx_decode(VX_INVALID[i].bytes, VX_INVALID[i].len, p);
    TEST_ASSERT_EQUAL_STRING_MESSAGE(VX_INVALID[i].error, vx_error_name(e), VX_INVALID[i].name);
  }
}

void test_encode_rejects_out_of_range_fields(void) {
  uint8_t out[VX_PACKET_SIZE];
  VxPacket p = packet_from(VX_VALID[0]);
  p.sats = 64;
  CHECK_EQ(vx_encode(p, out), VX_BAD_FIELD, "sats 64");
  p = packet_from(VX_VALID[0]);
  p.fix_type = 4;
  CHECK_EQ(vx_encode(p, out), VX_BAD_FIELD, "fix_type 4");
}

void test_ground_frames_match_every_vector(void) {
  for (size_t i = 0; i < VX_GROUND_COUNT; i++) {
    uint8_t out[VX_GROUND_FRAME_SIZE];
    VxError e = vx_make_ground_frame(VX_GROUND[i].bytes, VX_PACKET_SIZE, VX_GROUND[i].rssi_dbm,
                                     VX_GROUND[i].snr_db, out);
    CHECK_EQ(e, VX_OK, VX_GROUND[i].name);
    TEST_ASSERT_EQUAL_MEMORY_MESSAGE(VX_GROUND[i].bytes, out, VX_GROUND_FRAME_SIZE, VX_GROUND[i].name);
  }
}

void test_ground_frame_refuses_a_corrupted_packet(void) {
  uint8_t bad[VX_PACKET_SIZE];
  memcpy(bad, VX_VALID[0].bytes, VX_PACKET_SIZE);
  bad[10] ^= 0xFF;
  uint8_t out[VX_GROUND_FRAME_SIZE];
  CHECK_EQ(vx_make_ground_frame(bad, VX_PACKET_SIZE, -50, 5, out), VX_BAD_CRC, "corrupted packet");
}

int main(int argc, char** argv) {
  (void)argc;
  (void)argv;
  UNITY_BEGIN();
  RUN_TEST(test_crc_check_value);
  RUN_TEST(test_encode_matches_every_valid_vector);
  RUN_TEST(test_decode_matches_every_valid_vector);
  RUN_TEST(test_every_invalid_vector_is_rejected_with_its_error);
  RUN_TEST(test_encode_rejects_out_of_range_fields);
  RUN_TEST(test_ground_frames_match_every_vector);
  RUN_TEST(test_ground_frame_refuses_a_corrupted_packet);
  return UNITY_END();
}
