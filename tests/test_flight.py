import csv
import io
import json
import unittest

import _paths  # noqa: F401
from flight_model import FlightParams, generate_flight
from flight_stats import compute_stats, haversine_m
from generate_contract_data import build_all
from vector_packet import (
    FIX_NONE, FIX_3D, PHASE_APOGEE, PHASE_BOOST, PHASE_COAST, PHASE_DESCENT, PHASE_LANDED,
    PHASE_PAD, decode_ground_frame,
)

PROTOCOL = _paths.ROOT / "protocol"


class FlightModelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.frames = generate_flight()
        cls.packets = [f.packet for f in cls.frames]

    def test_is_deterministic(self):
        again = generate_flight()
        self.assertEqual(self.frames, again)

    def test_different_seed_changes_noise_not_shape(self):
        other = generate_flight(FlightParams(seed=2))
        self.assertNotEqual(self.frames, other)
        self.assertEqual([p.packet.phase for p in other], [p.phase for p in self.packets])

    def test_sequence_and_time_are_contiguous(self):
        for i, p in enumerate(self.packets):
            self.assertEqual(p.seq, i)
            self.assertEqual(p.time_ms, 60000 + 1000 * i)

    def test_phases_run_in_order_and_all_appear(self):
        phases = [p.phase for p in self.packets]
        self.assertEqual(phases, sorted(phases))
        self.assertEqual(set(phases), {PHASE_PAD, PHASE_BOOST, PHASE_COAST,
                                       PHASE_APOGEE, PHASE_DESCENT, PHASE_LANDED})

    def test_apogee_fits_the_l1_design_envelope(self):
        apogee_m = max(p.baro_alt_cm for p in self.packets) / 100
        self.assertGreater(apogee_m, 300)
        self.assertLess(apogee_m, 1524)          # 5,000 ft AGL

    def test_gps_gap_exists_during_boost_and_ends_in_coast(self):
        gap = [p for p in self.packets if p.fix_type == FIX_NONE]
        self.assertTrue(gap)
        self.assertTrue(all(p.phase in (PHASE_BOOST, PHASE_COAST) for p in gap))
        self.assertTrue(any(p.phase == PHASE_COAST and p.fix_type == FIX_3D for p in self.packets))
        self.assertTrue(all(p.sats == 0 for p in gap))

    def test_position_is_repeated_while_there_is_no_fix(self):
        gap = [p for p in self.packets if p.fix_type == FIX_NONE]
        self.assertEqual({(p.lat_e7, p.lon_e7) for p in gap}, {(gap[0].lat_e7, gap[0].lon_e7)})

    def test_rocket_ends_on_the_ground_and_stays_there(self):
        landed = [p for p in self.packets if p.phase == PHASE_LANDED]
        self.assertGreaterEqual(len(landed), 5)
        self.assertEqual({(p.lat_e7, p.lon_e7) for p in landed[1:]}, {(landed[1].lat_e7, landed[1].lon_e7)})
        self.assertTrue(all(abs(p.baro_alt_cm) < 200 for p in landed))

    def test_battery_never_flags_low(self):
        self.assertTrue(all(not p.low_battery and p.battery_mv > 3500 for p in self.packets))

    def test_signal_gets_weaker_with_distance(self):
        self.assertGreater(self.frames[0].rssi_dbm, min(f.rssi_dbm for f in self.frames))


class StatsTests(unittest.TestCase):
    def test_haversine_known_distances(self):
        self.assertAlmostEqual(haversine_m(0, 0, 0, 0), 0.0, places=6)
        # one degree of latitude on a 6371000 m sphere
        self.assertAlmostEqual(haversine_m(0, 0, 1, 0), 111194.93, delta=0.5)
        self.assertAlmostEqual(haversine_m(10, 20, 10, 20.0001), haversine_m(10, 20.0001, 10, 20), places=9)

    def test_expected_stats_file_matches_recomputation(self):
        frames = generate_flight()
        stats = compute_stats([f.packet for f in frames])
        on_disk = json.loads((PROTOCOL / "expected_stats.json").read_text())["stats"]
        self.assertEqual(stats, on_disk)

    def test_stats_are_plausible(self):
        s = json.loads((PROTOCOL / "expected_stats.json").read_text())["stats"]
        self.assertTrue(300 < s["apogee_m"] < 1524)
        self.assertTrue(5 < s["time_to_apogee_s"] < 30)
        self.assertTrue(4 < s["descent_rate_ms"] < 9)
        self.assertTrue(s["flight_time_s"] > s["time_to_apogee_s"])
        self.assertGreater(s["landing_distance_m"], 0)


class ContractDataTests(unittest.TestCase):
    def test_files_on_disk_are_current(self):
        for name, text in build_all().items():
            with self.subTest(name):
                self.assertEqual((PROTOCOL / name).read_text(), text,
                                 "Run: python tools/generate_contract_data.py")

    def test_hex_file_decodes_and_matches_csv(self):
        lines = (PROTOCOL / "sample_flight.hex").read_text().split()
        rows = list(csv.DictReader(io.StringIO((PROTOCOL / "sample_flight.csv").read_text())))
        self.assertEqual(len(lines), len(rows))
        for line, row in zip(lines, rows):
            f = decode_ground_frame(bytes.fromhex(line))
            self.assertEqual(f.packet.seq, int(row["seq"]))
            self.assertEqual(f.packet.baro_alt_cm, round(float(row["baro_alt_m"]) * 100))
            self.assertEqual(f.rssi_dbm, int(row["rssi_dbm"]))


if __name__ == "__main__":
    unittest.main()
