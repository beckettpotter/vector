// Native tests for the phase detector. Run with:  pio test -e native
// The flight is built here from simple made-up numbers (10 samples per second).
#include <math.h>
#include <stdlib.h>
#include <unity.h>

#include "phase_detector.h"

void setUp(void) {}
void tearDown(void) {}

enum { PAD = 0, BOOST = 1, COAST = 2, APOGEE = 3, DESCENT = 4, LANDED = 5 };

static const uint32_t STEP_MS = 100;

struct Change {
  uint8_t phase;
  uint32_t time_ms;
};

// Made-up flight: 3 s on the pad, 1.5 s boost at 80 m/s^2 net, coast under
// gravity plus light drag until the speed reaches 0, a 1 s free fall, then a
// parachute at a steady 6.5 m/s down to the pad level, then 10 s on the ground.
// Records every phase change; returns how many there were.
static int fly(Change* changes, int max_changes, int32_t jitter_cm, uint32_t* apogee_ms_out,
               uint32_t* touchdown_ms_out) {
  VxPhaseDetector d;
  vx_phase_init(&d);
  double alt = 0, vel = 0;
  uint32_t t = 0;
  int n = 0;
  bool chute = false, landed = false;
  uint32_t apogee_ms = 0, touchdown_ms = 0, landed_for_ms = 0;
  srand(42);
  uint8_t last = PAD;
  while (t < 200000) {
    const double dt = STEP_MS / 1000.0;
    if (t >= 3000 && !landed) {
      if (t < 4500) {
        vel += 80.0 * dt;
      } else if (!chute) {
        vel += (-9.81 - 0.0004 * vel * fabs(vel)) * dt;
        if (vel <= 0 && apogee_ms == 0) apogee_ms = t;
        if (apogee_ms && t >= apogee_ms + 1000) chute = true;
      } else {
        vel = -6.5;
      }
      alt += vel * dt;
      if (alt <= 0 && apogee_ms) {
        alt = 0;
        vel = 0;
        landed = true;
        touchdown_ms = t;
      }
    }
    int32_t noise = jitter_cm ? (rand() % (2 * jitter_cm + 1)) - jitter_cm : 0;
    uint8_t p = vx_phase_update(&d, (int32_t)lround(alt * 100) + noise, (int32_t)lround(vel * 100) + noise, t);
    if (p != last && n < max_changes) {
      changes[n].phase = p;
      changes[n].time_ms = t;
      n++;
      last = p;
    }
    if (landed) {
      landed_for_ms += STEP_MS;
      if (landed_for_ms > 10000) break;
    }
    t += STEP_MS;
  }
  if (apogee_ms_out) *apogee_ms_out = apogee_ms;
  if (touchdown_ms_out) *touchdown_ms_out = touchdown_ms;
  return n;
}

void test_phase_sequence_and_times(void) {
  Change c[10];
  uint32_t apogee_ms = 0, touchdown_ms = 0;
  int n = fly(c, 10, 0, &apogee_ms, &touchdown_ms);
  TEST_ASSERT_EQUAL_INT_MESSAGE(5, n, "five phase changes");
  const uint8_t expected[5] = {BOOST, COAST, APOGEE, DESCENT, LANDED};
  for (int i = 0; i < 5; i++) TEST_ASSERT_EQUAL_INT_MESSAGE(expected[i], c[i].phase, "phase order");
  // Boost: at 80 m/s^2 the speed passes 10 m/s after 0.2 s, but altitude only passes 10 m at 0.5 s.
  TEST_ASSERT_INT_WITHIN_MESSAGE(100, 3500, (int)c[0].time_ms, "launch time");
  // Burnout at 4.5 s; speed peaks at the last boost sample, coast declared 0.3 s later.
  TEST_ASSERT_INT_WITHIN_MESSAGE(100, 4700, (int)c[1].time_ms, "burnout time");
  TEST_ASSERT_INT_WITHIN_MESSAGE(100, (int)apogee_ms, (int)c[2].time_ms, "apogee time");
  TEST_ASSERT_EQUAL_INT_MESSAGE((int)(c[2].time_ms + 2000), (int)c[3].time_ms, "descent 2 s after apogee");
  // Landed: within 5 m and 1 m/s for 5 s. Under the chute it is still falling at 6.5 m/s, so the
  // 5 s hold starts at touchdown.
  TEST_ASSERT_INT_WITHIN_MESSAGE(100, (int)(touchdown_ms + 5000), (int)c[4].time_ms, "landed time");
}

void test_pad_jitter_does_not_launch(void) {
  VxPhaseDetector d;
  vx_phase_init(&d);
  srand(7);
  for (uint32_t t = 0; t < 600000; t += STEP_MS) {
    int32_t alt = (rand() % 201) - 100;     // +-1 m of barometer noise
    int32_t vs = (rand() % 1201) - 600;     // +-6 m/s of speed noise
    TEST_ASSERT_EQUAL_INT_MESSAGE(PAD, vx_phase_update(&d, alt, vs, t), "jitter launched");
  }
}

void test_fast_speed_reading_low_down_does_not_launch(void) {
  VxPhaseDetector d;
  vx_phase_init(&d);
  // A gust or a bump: big speed reading, but the rocket is still within 10 m of the pad.
  TEST_ASSERT_EQUAL_INT(PAD, vx_phase_update(&d, 300, 2500, 0));
  TEST_ASSERT_EQUAL_INT(PAD, vx_phase_update(&d, 900, 2500, 100));
  // High altitude reading alone is not enough either.
  TEST_ASSERT_EQUAL_INT(PAD, vx_phase_update(&d, 2000, 500, 200));
}

void test_noisy_flight_still_runs_in_order(void) {
  Change c[10];
  int n = fly(c, 10, 30, 0, 0);  // +-30 cm and +-30 cm/s of noise
  TEST_ASSERT_EQUAL_INT_MESSAGE(5, n, "five phase changes with noise");
  for (int i = 1; i < n; i++) TEST_ASSERT_TRUE_MESSAGE(c[i].phase > c[i - 1].phase, "phases only move forward");
}

void test_phases_never_go_backward(void) {
  VxPhaseDetector d;
  vx_phase_init(&d);
  uint32_t t = 0;
  vx_phase_update(&d, 1500, 3000, t += 100);  // launch
  vx_phase_update(&d, 3000, 3000, t += 100);
  vx_phase_update(&d, 4000, 2900, t += 100);
  vx_phase_update(&d, 5000, 2800, t += 100);
  TEST_ASSERT_EQUAL_INT(COAST, vx_phase_update(&d, 6000, 2700, t += 100));
  // A climbing reading in coast must not go back to boost.
  TEST_ASSERT_EQUAL_INT(COAST, vx_phase_update(&d, 7000, 5000, t += 100));
  TEST_ASSERT_EQUAL_INT(APOGEE, vx_phase_update(&d, 7000, -10, t += 100));
  TEST_ASSERT_EQUAL_INT(APOGEE, vx_phase_update(&d, 7000, 500, t += 100));
  TEST_ASSERT_EQUAL_INT(DESCENT, vx_phase_update(&d, 6800, -650, t += 2000));
  // On the ground for 5 s.
  uint32_t ground = t + 100;
  for (t = ground; t <= ground + 5000; t += 100) vx_phase_update(&d, 0, 0, t);
  TEST_ASSERT_EQUAL_INT(LANDED, d.phase);
  TEST_ASSERT_EQUAL_INT(LANDED, vx_phase_update(&d, 5000, 3000, t + 100));
}

void test_landing_needs_5_seconds_in_a_row(void) {
  VxPhaseDetector d;
  vx_phase_init(&d);
  d.phase = DESCENT;
  uint32_t t = 0;
  for (; t < 4000; t += 100) vx_phase_update(&d, 100, 0, t);
  vx_phase_update(&d, 100, -300, t);  // a bounce breaks the streak
  t += 100;
  uint32_t restart = t;
  for (; t < restart + 4900; t += 100) TEST_ASSERT_EQUAL_INT(DESCENT, vx_phase_update(&d, 100, 0, t));
  TEST_ASSERT_EQUAL_INT(LANDED, vx_phase_update(&d, 100, 0, restart + 5000));
}

int main(int argc, char** argv) {
  (void)argc;
  (void)argv;
  UNITY_BEGIN();
  RUN_TEST(test_phase_sequence_and_times);
  RUN_TEST(test_pad_jitter_does_not_launch);
  RUN_TEST(test_fast_speed_reading_low_down_does_not_launch);
  RUN_TEST(test_noisy_flight_still_runs_in_order);
  RUN_TEST(test_phases_never_go_backward);
  RUN_TEST(test_landing_needs_5_seconds_in_a_row);
  return UNITY_END();
}
