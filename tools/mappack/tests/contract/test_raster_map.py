"""Contract checks for the committed synthetic raster demo pack."""

import json
import math
import os
import re
import unittest


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
PACK = os.path.join(ROOT, "mapdata", "raster-demo")
INDEX = os.path.join(ROOT, "source", "generated", "RasterMapIndex.mc")


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
