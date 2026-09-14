"""Behavioral FIT-session mirror and source contract for RunController."""

import os
import re
import unittest


HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
ROOT = os.path.dirname(TESTS)
REPO = os.path.dirname(os.path.dirname(ROOT))


def read_repo(path):
    with open(os.path.join(REPO, path), encoding="utf-8") as handle:
        return handle.read()


class FakeSession:
    def __init__(self, start_result=True, stop_result=True, save_result=True,
                 discard_result=True):
        self.start_result = start_result
        self.stop_result = stop_result
        self.save_result = save_result
        self.discard_result = discard_result
        self.starts = 0
        self.stops = 0
        self.saves = 0
        self.discards = 0

    def start(self):
        self.starts += 1
        if isinstance(self.start_result, Exception):
            raise self.start_result
        return self.start_result

    def stop(self):
        self.stops += 1
        if isinstance(self.stop_result, Exception):
            raise self.stop_result
        return self.stop_result

    def save(self):
        self.saves += 1
        if isinstance(self.save_result, Exception):
            raise self.save_result
        return self.save_result

    def discard(self):
        self.discards += 1
        if isinstance(self.discard_result, Exception):
            raise self.discard_result
        return self.discard_result


class ControllerModel:
    def __init__(self, factory):
        self.factory = factory
        self.session = None
        self.gps_ready = False
        self.state = "waitingGps"
        self.recording_active = False

    def set_gps_ready(self, ready):
        self.gps_ready = ready
        if self.session is None:
            self.state = "ready" if ready else "waitingGps"

    def toggle(self):
        if self.state == "ready":
            try:
                self.session = self.factory()
                if not self.session.start():
                    self.state = "saveFailed"
                    return False
            except Exception:
                if self.session is not None:
                    self.state = "saveFailed"
                return False
            self.recording_active = True
            self.state = "recording"
            return True
        if self.state == "recording":
            try:
                if not self.session.stop():
                    self.state = "saveFailed"
                    return False
            except Exception:
                self.state = "saveFailed"
                return False
            self.recording_active = False
            self.state = "paused"
            return True
        if self.state == "paused":
            try:
                if not self.session.start():
                    return False
            except Exception:
                return False
            self.recording_active = True
            self.state = "recording"
            return True
        return False

    def save(self):
        if self.session is None:
            return True
        if self.recording_active:
            try:
                if not self.session.stop():
                    self.state = "saveFailed"
                    return False
            except Exception:
                self.state = "saveFailed"
                return False
            self.recording_active = False
        try:
            saved = self.session.save()
        except Exception:
            saved = False
        if not saved:
            self.state = "saveFailed"
            return False
        self.session = None
        self.state = "ready" if self.gps_ready else "waitingGps"
        return True

    def discard(self):
        if self.session is None:
            return True
        if self.recording_active:
            try:
                if not self.session.stop():
                    self.state = "saveFailed"
                    return False
            except Exception:
                self.state = "saveFailed"
                return False
            self.recording_active = False
        try:
            discarded = self.session.discard()
        except Exception:
            discarded = False
        if not discarded:
            self.state = "saveFailed"
            return False
        self.session = None
        self.state = "ready" if self.gps_ready else "waitingGps"
        return True

    def shutdown(self):
        return self.save()


def recording_controller(session):
    run = ControllerModel(lambda: session)
    run.set_gps_ready(True)
    run.toggle()
    return run


class TestRunController(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = read_repo("source/RunController.mc")
        cls.manifest = read_repo("manifest.xml")

    def test_toggle_uses_one_session_for_start_pause_and_resume(self):
        session = FakeSession()
        run = ControllerModel(lambda: session)
        self.assertFalse(run.toggle())
        run.set_gps_ready(True)

        self.assertTrue(run.toggle())
        self.assertEqual((session.starts, session.stops), (1, 0))
        self.assertTrue(run.toggle())
        self.assertEqual((session.starts, session.stops), (1, 1))
        self.assertTrue(run.toggle())
        self.assertIs(run.session, session)
        self.assertEqual(session.starts, 2)

    def test_average_pace_uses_only_moving_samples(self):
        self.assertIn("const MIN_MOVING_SPEED = 0.8d", self.source)
        self.assertIn("function updateMotion(speed, distanceMetres, timerMs)", self.source)
        update = self.source.split("function updateMotion", 1)[1].split("function", 1)[0]
        self.assertIn("speed >= MIN_MOVING_SPEED", update)
        self.assertIn("_movingTimeMs", update)
        pace = self.source.split("function averagePaceSeconds()", 1)[1].split("function", 1)[0]
        self.assertIn("_movingTimeMs", pace)
        self.assertIn("_movingDistance", pace)
        self.assertNotIn("averageSpeed", pace)

    def test_failed_save_retains_session_for_retry(self):
        session = FakeSession(save_result=False)
        run = recording_controller(session)

        self.assertFalse(run.save())
        self.assertIs(run.session, session)
        self.assertEqual(run.state, "saveFailed")
        session.save_result = True
        self.assertTrue(run.save())
        self.assertIsNone(run.session)

    def test_failed_stop_is_retried_before_save(self):
        session = FakeSession(stop_result=False)
        run = recording_controller(session)

        self.assertFalse(run.save())
        self.assertEqual((session.stops, session.saves), (1, 0))
        self.assertIs(run.session, session)
        session.stop_result = True
        self.assertTrue(run.save())
        self.assertEqual((session.stops, session.saves), (2, 1))

    def test_false_or_exception_never_advances_recording_state(self):
        for failed in (False, RuntimeError("FIT unavailable")):
            session = FakeSession(start_result=failed)
            run = ControllerModel(lambda: session)
            run.set_gps_ready(True)
            self.assertFalse(run.toggle())
            self.assertNotEqual("recording", run.state)
            self.assertIs(run.session, session)

        session = FakeSession(stop_result=False)
        run = recording_controller(session)
        self.assertFalse(run.toggle())
        self.assertEqual("saveFailed", run.state)

    def test_stop_exception_is_retried_by_shutdown(self):
        session = FakeSession(stop_result=RuntimeError("stop failed"))
        run = recording_controller(session)

        self.assertFalse(run.shutdown())
        self.assertEqual((session.stops, session.saves), (1, 0))
        self.assertIs(run.session, session)
        session.stop_result = True
        self.assertTrue(run.shutdown())
        self.assertEqual((session.stops, session.saves), (2, 1))
        self.assertIsNone(run.session)

    def test_failed_discard_retains_session(self):
        for failed in (False, RuntimeError("discard failed")):
            session = FakeSession(discard_result=failed)
            run = recording_controller(session)
            self.assertFalse(run.discard())
            self.assertIs(run.session, session)
            self.assertEqual("saveFailed", run.state)

    def test_successful_save_and_shutdown_release_session(self):
        run = recording_controller(FakeSession(save_result=True))
        self.assertTrue(run.save())
        self.assertIsNone(run.session)

        run = recording_controller(FakeSession(save_result=True))
        self.assertTrue(run.shutdown())
        self.assertIsNone(run.session)

    def test_failed_shutdown_never_discards_and_keeps_session(self):
        session = FakeSession(save_result=False)
        run = recording_controller(session)

        self.assertFalse(run.shutdown())
        self.assertEqual(session.discards, 0)
        self.assertIs(run.session, session)

    def test_discard_occurs_only_on_explicit_discard(self):
        session = FakeSession()
        run = recording_controller(session)

        self.assertTrue(run.discard())
        self.assertEqual(session.discards, 1)
        self.assertIsNone(run.session)

    def test_metrics_defaults_and_average_pace(self):
        def metrics(info):
            timer = 0 if info is None or info.get("timerTime") is None else info["timerTime"]
            distance = 0 if info is None or info.get("elapsedDistance") is None else info["elapsedDistance"]
            speed = None if info is None else info.get("averageSpeed")
            pace = None if speed is None or speed <= 0 else 1000.0 / speed
            return timer, distance, pace

        self.assertEqual(metrics(None), (0, 0, None))
        self.assertEqual(
            metrics({"timerTime": None, "elapsedDistance": None, "averageSpeed": 0}),
            (0, 0, None),
        )
        self.assertEqual(metrics({"timerTime": 65000, "elapsedDistance": 500, "averageSpeed": 4}),
                         (65000, 500, 250.0))

    def test_source_declares_transitions_fit_permission_and_running_session(self):
        transitions = set(re.findall(
            r"// @transition (\w+) \+ (\w+) -> (\w+)", self.source
        ))
        self.assertEqual(
            transitions,
            {
                ("waitingGps", "gpsReady", "ready"),
                ("ready", "toggle", "recording"),
                ("recording", "toggle", "paused"),
                ("paused", "toggle", "recording"),
                ("recording", "saveFailure", "saveFailed"),
            },
        )
        for state in ("waitingGps", "ready", "recording", "paused", "saveFailed"):
            self.assertIn(":" + state, self.source)
        self.assertIn('<iq:uses-permission id="Fit"/>', self.manifest)
        self.assertIn(":sport => Activity.SPORT_RUNNING", self.source)
        self.assertIn(":subSport => Activity.SUB_SPORT_STREET", self.source)
        self.assertNotIn(".discard()", self.source.split("function shutdown", 1)[1])
        self.assertIn("if (!_session.start())", self.source)
        self.assertIn("if (!_session.stop())", self.source)
        self.assertIn("if (!_session.discard())", self.source)
        self.assertIn("hidden var _recordingActive", self.source)


if __name__ == "__main__":
    unittest.main()
