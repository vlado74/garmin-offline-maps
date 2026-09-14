"""Contract for the physical-key raster running experience."""

from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[4]


def source(name: str) -> str:
    return (ROOT / "source" / name).read_text(encoding="utf-8")


def string_table(path: Path) -> dict[str, str]:
    root = ET.parse(path).getroot()
    return {node.attrib["id"]: node.text or "" for node in root.findall("string")}


class TestRunUi(unittest.TestCase):
    def test_delegate_handles_keys_and_touch_panning(self):
        delegate = source("RunDelegate.mc")
        self.assertIn("class RunDelegate extends WatchUi.InputDelegate", delegate)
        self.assertRegex(delegate, r"function onDrag\(event\)[\s\S]*?DRAG_TYPE_START")
        self.assertRegex(delegate, r"function onDrag\(event\)[\s\S]*?_view\.panBy")
        self.assertRegex(delegate, r"function onTap\(event\)[\s\S]*?_view\.recenterGps\(\)")
        self.assertRegex(delegate, r"KEY_ENTER[\s\S]*?_controller\.toggle\(\)")
        self.assertRegex(delegate, r"KEY_UP[\s\S]*?_view\.zoomIn\(\)")
        self.assertRegex(delegate, r"KEY_DOWN[\s\S]*?_view\.zoomOut\(\)")
        self.assertRegex(delegate, r"KEY_MENU[\s\S]*?_view\.toggleDataBand\(\)")
        self.assertNotIn("function onMenu()", delegate)
        self.assertNotIn("KEY_LIGHT", delegate)
        self.assertRegex(delegate, r"KEY_ESC[\s\S]*?_controller\.hasSession\(\)")
        self.assertIn("new WatchUi.Confirmation", delegate)

    def test_confirmation_clears_trail_only_after_success(self):
        confirmation = source("RunConfirmation.mc")
        self.assertIn("class RunConfirmation extends WatchUi.ConfirmationDelegate", confirmation)
        self.assertIn("WatchUi.CONFIRM_YES", confirmation)
        self.assertIn("_controller.save()", confirmation)
        self.assertIn("_controller.discard()", confirmation)
        self.assertIn("Rez.Strings.RetrySave", confirmation)
        self.assertRegex(confirmation, r"if \(succeeded\)[\s\S]*?_trail\.clear\(\)")

    def test_app_routes_only_usable_fixes_to_map_and_recording_trail(self):
        app = source("OfflineMapsApp.mc")
        self.assertIn("new RasterTileStore()", app)
        self.assertIn("new RunTrail()", app)
        self.assertIn("new RunController()", app)
        self.assertIn("new RunMapView", app)
        self.assertIn("new RunDelegate", app)
        self.assertIn("_tracker.hasUsableFix()", app)
        self.assertIn("_view.setPosition", app)
        self.assertRegex(app, r":recording[\s\S]*?_trail\.add")
        self.assertIn("_controller.shutdown()", app)
        self.assertIn("new Timer.Timer()", app)
        self.assertIn("WatchUi.requestUpdate()", app)
        self.assertNotIn("pollHeading", app)

    def test_location_tracker_exposes_quality(self):
        tracker = source("LocationTracker.mc")
        self.assertIn("function accuracy()", tracker)
        self.assertIn("function heading()", tracker)
        self.assertIn("function hasHeading()", tracker)
        self.assertIn("info.heading", tracker)
        self.assertIn("MIN_HEADING_SPEED", tracker)
        self.assertIn("function hasUsableFix()", tracker)
        self.assertIn("Position.QUALITY_USABLE", tracker)
        self.assertIn("Position.QUALITY_GOOD", tracker)
        null_fix = tracker.split("function onPosition", 1)[1]
        self.assertRegex(null_fix, r"position == null[\s\S]*?_hasFix = false")
        self.assertRegex(null_fix, r"position == null[\s\S]*?_onFix\.invoke\(\)")

    def test_view_draws_compact_metrics_and_statuses(self):
        view = source("RunMapView.mc")
        self.assertIn("const DATA_BAND_HEIGHT = 52", view)
        self.assertIn("const DATA_ROW_Y = 52", view)
        self.assertIn("function toggleDataBand()", view)
        self.assertIn("const DATA_BAND_VISIBLE_MS = 8000", view)
        self.assertIn("function updateDataBandVisibility()", view)
        self.assertIn("function showDataBandTemporarily()", view)
        self.assertIn("System.getTimer()", view)
        self.assertIn("function zoomIn()", view)
        self.assertIn("function zoomOut()", view)
        self.assertIn("function panBy(dx, dy)", view)
        self.assertIn("function recenterGps()", view)
        self.assertIn("_followingGps", view)
        self.assertIn("_gpsLat", view)
        self.assertIn("_gpsHeading", view)
        self.assertIn("Math.sin", view)
        self.assertIn("Math.cos", view)
        self.assertIn("StreetLabelOverlay.draw", view)
        overlay = source("StreetLabelOverlay.mc")
        self.assertIn("if (zoom != RasterPack.CLOSE)", overlay)
        self.assertIn("StreetLabelIndex.labelsAt", overlay)
        self.assertIn("MAX_DRAWN = 12", overlay)
        self.assertIn("Graphics.FONT_XTINY", overlay)
        self.assertIn("_centreLat", view)
        self.assertIn("Rez.Strings.TapToRecenter", view)
        self.assertIn("function drawHomeMarker(dc)", view)
        self.assertIn("RasterMapIndex.HOME_LAT", view)
        self.assertIn("RasterMapIndex.HOME_LON", view)
        self.assertIn("RasterPack.CLOSE", view)
        self.assertRegex(view, r"if \(_showDataBand\) \{ drawDataBand\(dc\); \}")
        self.assertIn("timerMs()", view)
        self.assertIn("distanceMetres()", view)
        self.assertIn("averagePaceSeconds()", view)
        for resource in ("Start", "Pause", "SaveFailed", "OutsideMap", "WaitingForGps"):
            self.assertIn(f"Rez.Strings.{resource}", view)
        self.assertIn('+ " km"', view)
        self.assertIn('+ "/km"', view)

    def test_english_and_italian_have_the_same_string_ids(self):
        english = string_table(ROOT / "resources/strings/strings.xml")
        italian = string_table(ROOT / "resources-ita/strings/strings.xml")
        self.assertEqual(set(english), set(italian))
        self.assertEqual("Avvia", italian["Start"])
        self.assertEqual("Pausa", italian["Pause"])
        self.assertEqual("Salva attività?", italian["SaveActivity"])
        self.assertEqual("Fuori mappa", italian["OutsideMap"])
        self.assertEqual("Ricerca GPS", italian["WaitingForGps"])
        self.assertEqual("Tocca per GPS", italian["TapToRecenter"])

    def test_manifest_targets_only_fr265s_with_both_languages(self):
        manifest = ET.parse(ROOT / "manifest.xml").getroot()
        ns = {"iq": "http://www.garmin.com/xml/connectiq"}
        products = [node.attrib["id"] for node in manifest.findall(".//iq:product", ns)]
        languages = [node.text for node in manifest.findall(".//iq:language", ns)]
        self.assertEqual(["fr265s"], products)
        self.assertEqual(["eng", "ita"], languages)

    def test_jungle_has_only_the_fr265s_icon_override(self):
        jungle = (ROOT / "monkey.jungle").read_text(encoding="utf-8")
        qualifiers = re.findall(r"^([a-z0-9]+)\.resourcePath", jungle, re.M)
        qualifiers = [name for name in qualifiers if name != "base"]
        self.assertEqual(["fr265s"], qualifiers)


if __name__ == "__main__":
    unittest.main()
