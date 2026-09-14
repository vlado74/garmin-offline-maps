"""The shipping watch app contains only the raster running runtime."""

from pathlib import Path
import re
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[4]
LEGACY = {
    "Camera.mc", "DevTools.mc", "Diag.mc", "MapDelegate.mc", "MapMenu.mc",
    "MapRenderer.mc", "MapView.mc", "Num.mc", "Onboarding.mc", "Pack.mc",
    "Palette.mc", "Settings.mc", "TileReader.mc", "TileStore.mc", "Ui.mc",
    "Waypoints.mc",
}


class TestRasterOnlyRuntime(unittest.TestCase):
    def test_vector_watch_runtime_is_absent(self):
        present = {path.name for path in (ROOT / "source").glob("*.mc")}
        self.assertFalse(LEGACY & present)
        self.assertFalse((ROOT / "source/generated/MapIndex.mc").exists())
        self.assertFalse((ROOT / "mapdata/active").exists())

    def test_build_path_selects_only_the_synthetic_raster_pack(self):
        jungle = (ROOT / "monkey.jungle").read_text(encoding="utf-8")
        resource_path = re.search(r"^base\.resourcePath\s*=\s*(.+)$", jungle, re.M).group(1)
        self.assertEqual("resources;mapdata/raster-demo", resource_path.strip())

    def test_manifest_keeps_only_required_permissions(self):
        ns = {"iq": "http://www.garmin.com/xml/connectiq"}
        root = ET.parse(ROOT / "manifest.xml").getroot()
        permissions = {
            node.attrib["id"] for node in root.findall(".//iq:uses-permission", ns)
        }
        self.assertEqual({"Positioning", "Fit"}, permissions)
        self.assertFalse((ROOT / "resources/settings").exists())

    def test_makefile_defaults_to_fr265s_and_raster_commands(self):
        makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
        self.assertRegex(makefile, r"(?m)^DEVICE\s*\?=\s*fr265s$")
        self.assertIn("raster-pack:", makefile)
        self.assertIn("raster-preview:", makefile)

    def test_release_helpers_match_the_raster_app(self):
        regression = (ROOT / "tools/regression.sh").read_text(encoding="utf-8")
        push_watch = (ROOT / "tools/push-watch.sh").read_text(encoding="utf-8")
        guidance = (ROOT / "CLAUDE.md").read_text(encoding="utf-8")
        self.assertIn("if make raster-demo", regression)
        self.assertIn('${1:-fr265s}', push_watch)
        self.assertNotIn("venu3", push_watch.lower())
        self.assertIn("offline raster", guidance.lower())
        self.assertNotIn("offline vector", guidance.lower())
        self.assertFalse((ROOT / ".claude").exists())

    def test_personal_map_coordinates_are_not_in_versioned_inputs(self):
        forbidden = ("Bald" + "ovinetti", "41." + "8318579", "12." + "4946125")
        roots = [ROOT / "source", ROOT / "docs", ROOT / "tools/mappack/tests"]
        candidates = [ROOT / "Makefile", ROOT / "README.md"]
        for directory in roots:
            candidates.extend(directory.rglob("*"))
        for path in candidates:
            if not path.is_file() or path == Path(__file__):
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            self.assertFalse(any(value in text for value in forbidden), str(path))


if __name__ == "__main__":
    unittest.main()
