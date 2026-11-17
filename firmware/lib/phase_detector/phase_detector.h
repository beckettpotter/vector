// Flight phase detector for the tracker. Pure logic: no hardware, no Arduino.
// Input each sample: barometric altitude above the pad (cm), vertical speed
// (cm/s, up positive) and time (ms). Output: the VxPhase code to transmit.
//
// The phase is telemetry only. Vector never uses it to fire, eject or deploy
// anything, and it must never be wired to anything that does.
#pragma once

#include <stdint.h>

// Thresholds, named so the club can tune them. Units are in the names.
#define VX_LAUNCH_VSPEED_CMS 1000      // pad -> boost: climbing faster than 10 m/s ...
#define VX_LAUNCH_ALT_CM 1000          // ... and more than 10 m above the pad
#define VX_BURNOUT_HOLD_MS 300         // boost -> coast: upward speed stopped increasing for 0.3 s
#define VX_APOGEE_VSPEED_CMS 0         // coast -> apogee: vertical speed at or below 0
#define VX_APOGEE_TO_DESCENT_MS 2000   // apogee -> descent: 2 s after apogee
#define VX_LANDED_ALT_CM 500           // descent -> landed: within 5 m of the pad ...
#define VX_LANDED_VSPEED_CMS 100       // ... and vertical speed within 1 m/s ...
#define VX_LANDED_HOLD_MS 5000         // ... for 5 s in a row

struct VxPhaseDetector {
  uint8_t phase;              // VxPhase code (0 pad ... 5 landed)
  uint32_t phase_since_ms;    // time of the last phase change
  int32_t peak_vspeed_cms;    // fastest climb seen during boost
  uint32_t peak_vspeed_ms;    // when that peak was set
  bool landing_candidate;     // landed conditions currently hold
  uint32_t landing_since_ms;  // since when they have held
};

void vx_phase_init(VxPhaseDetector* d);

// Feed one sample; returns the phase after it. Phases only ever move forward.
uint8_t vx_phase_update(VxPhaseDetector* d, int32_t baro_alt_cm, int32_t vspeed_cms, uint32_t time_ms);
