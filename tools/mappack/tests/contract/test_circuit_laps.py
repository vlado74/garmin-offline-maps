"""Behavior and source contracts for automatic short-circuit laps."""

from pathlib import Path
import math
import re
import unittest


ROOT = Path(__file__).resolve().parents[4]
SOURCE = (ROOT / "source" / "CircuitLapTracker.mc").read_text(encoding="utf-8")


def constant(name):
    match = re.search(rf"const {name} = ([0-9.]+)d?;", SOURCE)
    if not match:
        raise AssertionError(f"missing {name}")
    return float(match.group(1))


class LapModel:
    def __init__(self):
        self.exit_radius = constant("EXIT_RADIUS_METRES")
        self.entry_radius = constant("ENTRY_RADIUS_METRES")
        self.min_distance = constant("MIN_LAP_DISTANCE_METRES")
        self.min_time = constant("MIN_LAP_TIME_MS")
        self.start = None
        self.armed = False
        self.lap_distance = 0
        self.lap_time = 0
        self.count = 0

    def update(self, distance_from_start, total_distance, timer_ms):
        if self.start is None:
            self.start = True
            self.lap_distance = total_distance
            self.lap_time = timer_ms
            return False
        if not self.armed and distance_from_start >= self.exit_radius:
            self.armed = True
        if (self.armed and distance_from_start <= self.entry_radius
                and total_distance - self.lap_distance >= self.min_distance
                and timer_ms - self.lap_time >= self.min_time):
            self.count += 1
            self.armed = False
            self.lap_distance = total_distance
            self.lap_time = timer_ms
            return True
        return False


class TestCircuitLaps(unittest.TestCase):
    def test_arms_after_leaving_and_counts_only_on_valid_return(self):
        laps = LapModel()
        self.assertFalse(laps.update(0, 0, 0))
        self.assertFalse(laps.update(160, 180, 50_000))
        self.assertTrue(laps.update(20, 560, 150_000))
        self.assertEqual(1, laps.count)
        self.assertFalse(laps.update(10, 580, 155_000))

    def test_short_out_and_back_is_not_a_lap(self):
        laps = LapModel()
        laps.update(0, 0, 0)
        laps.update(160, 170, 30_000)
        self.assertFalse(laps.update(20, 280, 55_000))

    def test_watch_wires_fit_trail_and_detail_panel(self):
        controller = (ROOT / "source" / "RunController.mc").read_text(encoding="utf-8")
        app = (ROOT / "source" / "OfflineMapsApp.mc").read_text(encoding="utf-8")
        trail = (ROOT / "source" / "RunTrail.mc").read_text(encoding="utf-8")
        view = (ROOT / "source" / "RunMapView.mc").read_text(encoding="utf-8")
        self.assertRegex(controller, r"function addLap\(\)[\s\S]*?_session\.addLap\(\)")
        self.assertRegex(app, r"_laps\.update[\s\S]*?_controller\.addLap[\s\S]*?_trail\.markLap")
        self.assertIn("function markLap()", trail)
        self.assertIn("function drawLapDetails(dc)", view)
        self.assertIn("function drawLapButton(dc)", view)
        self.assertIn("function showCompletedLap()", view)


if __name__ == "__main__":
    unittest.main()
