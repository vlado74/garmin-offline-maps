"""Contract checks for the committed synthetic raster demo pack."""

import json
import math
import os
import re
import unittest
import xml.etree.ElementTree as ET


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
PACK = os.path.join(ROOT, "mapdata", "raster-demo")
INDEX = os.path.join(ROOT, "source", "generated", "RasterMapIndex.mc")
JUNGLE = os.path.join(ROOT, "monkey.jungle")


def world_x(lon, zoom):
    return (lon + 180.0) / 360.0 * 256 * (1 << zoom)


def world_y(lat, zoom):
    radians = math.radians(lat)
    return (
        1.0
        - math.log(math.tan(radians) + 1.0 / math.cos(radians)) / math.pi
    ) / 2.0 * 256 * (1 << zoom)


class TestCommittedRasterMap(unittest.TestCase):
    def setUp(self):
        self.assertTrue(os.path.isfile(os.path.join(PACK, "mapdata.xml")))
        self.assertTrue(os.path.isfile(os.path.join(PACK, "pack.json")))
        self.assertTrue(os.path.isfile(INDEX))
        with open(os.path.join(PACK, "mapdata.xml"), encoding="utf-8") as handle:
            self.xml = handle.read()
        with open(os.path.join(PACK, "pack.json"), encoding="utf-8") as handle:
            self.pack = json.load(handle)
        with open(INDEX, encoding="utf-8") as handle:
            self.index = handle.read()

    def test_every_index_resource_exists_in_xml(self):
        ids = set(re.findall(r'<bitmap id="([^"]+)"', self.xml))
        refs = set(re.findall(r"Rez\.Drawables\.(r\d+_\d+_\d+)", self.index))
        self.assertEqual(ids, refs)
        self.assertEqual(len(ids), self.pack["resourceCount"])
        for resource_id in ids:
            self.assertTrue(os.path.isfile(os.path.join(PACK, "tiles", resource_id + ".png")))

    def test_generated_indexes_only_reference_resources_on_the_build_path(self):
        with open(JUNGLE, encoding="utf-8") as handle:
            match = re.search(r"^base\.resourcePath\s*=\s*(.+)$", handle.read(), re.M)
        self.assertIsNotNone(match)

        declared = set()
        for relative_dir in match.group(1).strip().split(";"):
            resource_dir = os.path.join(ROOT, relative_dir)
            for directory, _subdirs, filenames in os.walk(resource_dir):
                for filename in filenames:
                    if filename.endswith(".xml"):
                        for element in ET.parse(os.path.join(directory, filename)).iter():
                            resource_id = element.attrib.get("id")
                            if resource_id:
                                declared.add(resource_id)

        referenced = set()
        generated_dir = os.path.join(ROOT, "source", "generated")
        for filename in os.listdir(generated_dir):
            if filename.endswith(".mc"):
                with open(os.path.join(generated_dir, filename), encoding="utf-8") as handle:
                    referenced.update(
                        re.findall(r"Rez\.(?:JsonData|Drawables)\.(\w+)", handle.read())
                    )

        self.assertFalse(
            referenced - declared,
            "generated indexes reference resources absent from base.resourcePath: %s"
            % sorted(referenced - declared),
        )

    def test_watch_and_host_agree_on_tile_size_and_zooms(self):
        self.assertEqual(self.pack["tileSize"], 120)
        self.assertEqual(self.pack["zooms"], [13, 15])
        self.assertIn("const TILE_SIZE = 120;", self.index)
        self.assertIn("const ZOOMS = [13, 15];", self.index)

    def test_each_zoom_covers_a_centered_360_pixel_viewport(self):
        center_lon, center_lat = self.pack["center"]
        grids = {grid["zoom"]: grid for grid in self.pack["grids"]}
        self.assertEqual(set(grids), {13, 15})
        for zoom in (13, 15):
            with self.subTest(zoom=zoom):
                grid = grids[zoom]
                center_x = world_x(center_lon, zoom)
                center_y = world_y(center_lat, zoom)
                self.assertLessEqual(grid["originX"], center_x - 180)
                self.assertGreaterEqual(
                    grid["originX"] + grid["cols"] * 120, center_x + 180
                )
                self.assertLessEqual(grid["originY"], center_y - 180)
                self.assertGreaterEqual(
                    grid["originY"] + grid["rows"] * 120, center_y + 180
                )

    def test_metadata_identifies_the_synthetic_berlin_fixture(self):
        self.assertEqual(self.pack["name"], "Synthetic Raster Demo")
        self.assertAlmostEqual(self.pack["center"][0], 13.3632, places=7)
        self.assertAlmostEqual(self.pack["center"][1], 52.5133994, places=7)


if __name__ == "__main__":
    unittest.main()
