#include "phase_detector.h"

// Phase codes match protocol/PROTOCOL.md (and VxPhase in vector_packet.h).
enum { PAD = 0, BOOST = 1, COAST = 2, APOGEE = 3, DESCENT = 4, LANDED = 5 };

static int32_t abs32(int32_t v) { return v < 0 ? -v : v; }

static void enter(VxPhaseDetector* d, uint8_t phase, uint32_t time_ms) {
  d->phase = phase;
  d->phase_since_ms = time_ms;
}

void vx_phase_init(VxPhaseDetector* d) {
  d->phase = PAD;
  d->phase_since_ms = 0;
  d->peak_vspeed_cms = 0;
  d->peak_vspeed_ms = 0;
  d->landing_candidate = false;
  d->landing_since_ms = 0;
}

uint8_t vx_phase_update(VxPhaseDetector* d, int32_t baro_alt_cm, int32_t vspeed_cms, uint32_t time_ms) {
  switch (d->phase) {
    case PAD:
      // Both conditions, so a noisy speed reading on the pad cannot start a flight.
      if (vspeed_cms > VX_LAUNCH_VSPEED_CMS && baro_alt_cm > VX_LAUNCH_ALT_CM) {
        enter(d, BOOST, time_ms);
        d->peak_vspeed_cms = vspeed_cms;
        d->peak_vspeed_ms = time_ms;
      }
      break;
    case BOOST:
      if (vspeed_cms > d->peak_vspeed_cms) {
        d->peak_vspeed_cms = vspeed_cms;
        d->peak_vspeed_ms = time_ms;
      } else if (time_ms - d->peak_vspeed_ms >= VX_BURNOUT_HOLD_MS) {
        enter(d, COAST, time_ms);
      }
      break;
    case COAST:
      if (vspeed_cms <= VX_APOGEE_VSPEED_CMS) enter(d, APOGEE, time_ms);
      break;
    case APOGEE:
      if (time_ms - d->phase_since_ms >= VX_APOGEE_TO_DESCENT_MS) enter(d, DESCENT, time_ms);
      break;
    case DESCENT: {
      const bool still = abs32(baro_alt_cm) <= VX_LANDED_ALT_CM && abs32(vspeed_cms) <= VX_LANDED_VSPEED_CMS;
      if (!still) {
        d->landing_candidate = false;
      } else if (!d->landing_candidate) {
        d->landing_candidate = true;
        d->landing_since_ms = time_ms;
      } else if (time_ms - d->landing_since_ms >= VX_LANDED_HOLD_MS) {
        enter(d, LANDED, time_ms);
      }
      break;
    }
    default:  // LANDED stays landed until the tracker is reset
      break;
  }
  return d->phase;
}
