"""Cross-language contract for the watch-side raster cell selection."""

import json
import math
import os
import re
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
ROOT = os.path.dirname(TESTS)
REPO = os.path.dirname(os.path.dirname(ROOT))
sys.path.insert(0, ROOT)

from mappack import geom  # noqa: E402
from mappack.raster import RasterGrid, visible_cells  # noqa: E402


def read_repo(path):
    with open(os.path.join(REPO, path), encoding="utf-8") as handle:
        return handle.read()


def function_body(source, name):
    start = source.index("function %s(" % name)
    brace = source.index("{", start)
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    raise AssertionError("unterminated function %s" % name)


class TestRasterRuntime(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pack_source = read_repo("source/RasterPack.mc")
        cls.store_source = read_repo("source/RasterTileStore.mc")
        cls.view_source = read_repo("source/RunMapView.mc")
        cls.index_source = read_repo("source/generated/RasterMapIndex.mc")
        cls.manifest = json.loads(read_repo("mapdata/raster-demo/pack.json"))

    def grid_from_index(self, zoom):
        def lookup(name):
            body = function_body(self.index_source, name)
            match = re.search(
                r"if \(zoom == %d\) \{ return (-?\d+); \}" % zoom,
                body,
            )
            self.assertIsNotNone(match)
            return int(match.group(1))

        tile_size = int(
            re.search(r"const TILE_SIZE = (\d+);", self.index_source).group(1)
        )
        return RasterGrid(
            zoom,
            tile_size,
            lookup("originX"),
            lookup("originY"),
            lookup("cols"),
            lookup("rows"),
        )

    def watch_mirror(self, grid, lon, lat, width=360, height=360):
        cx = geom.lon_to_world_x(lon, grid.zoom)
        cy = geom.lat_to_world_y(lat, grid.zoom)
        left = cx - width / 2.0
        top = cy - height / 2.0
        right = left + width
        bottom = top + height
        col0 = max(0, math.floor((left - grid.origin_x) / grid.tile_size))
        row0 = max(0, math.floor((top - grid.origin_y) / grid.tile_size))
        col1 = min(
            grid.cols - 1,
            math.ceil((right - grid.origin_x) / grid.tile_size) - 1,
        )
        row1 = min(
            grid.rows - 1,
            math.ceil((bottom - grid.origin_y) / grid.tile_size) - 1,
        )
        return [
            (
                col,
                row,
                grid.origin_x + col * grid.tile_size - left,
                grid.origin_y + row * grid.tile_size - top,
            )
            for row in range(row0, row1 + 1)
            for col in range(col0, col1 + 1)
        ][:16]

    def test_watch_selection_matches_host_at_centre_edges_and_outside(self):
        west, south, east, north = self.manifest["bounds"]
        center_lon, center_lat = self.manifest["center"]
        for zoom in (13, 15):
            grid = self.grid_from_index(zoom)
            grid_west = geom.world_x_to_lon(grid.origin_x, zoom)
            grid_east = geom.world_x_to_lon(
                grid.origin_x + grid.cols * grid.tile_size, zoom
            )
            grid_north = geom.world_y_to_lat(grid.origin_y, zoom)
            grid_south = geom.world_y_to_lat(
                grid.origin_y + grid.rows * grid.tile_size, zoom
            )
            positions = [
                (center_lon, center_lat),
                (grid_west, center_lat),
                (grid_east, center_lat),
                (center_lon, grid_north),
                (center_lon, grid_south),
                (grid_west - 10.0, center_lat),
                (grid_east + 10.0, center_lat),
                (center_lon, grid_north + 10.0),
                (center_lon, grid_south - 10.0),
            ]
            for lon, lat in positions:
                with self.subTest(zoom=zoom, lon=lon, lat=lat):
                    expected = visible_cells(grid, lon, lat, 360, 360)
                    actual = self.watch_mirror(grid, lon, lat)
                    self.assertEqual(len(actual), len(expected))
                    self.assertLessEqual(len(actual), 16)
                    for got, want in zip(actual, expected):
                        self.assertEqual(got[:2], want[:2])
                        self.assertAlmostEqual(got[2], want[2])
                        self.assertAlmostEqual(got[3], want[3])

    def test_runtime_bounds_residency_and_draw_contracts_are_explicit(self):
        self.assertIn("const MAX_VISIBLE = 16;", self.pack_source)
        self.assertIn("const CLOSE = 16;", self.pack_source)
        self.assertIn("function resourceZoom", self.pack_source)
        prepare = function_body(self.store_source, "prepare")
        load_missing = function_body(self.store_source, "loadMissing")
        self.assertIn("loadMissing", prepare)
        self.assertIn("Application.loadResource", load_missing)
        self.assertNotIn("Application.loadResource", function_body(self.store_source, "draw"))
        self.assertNotIn("Application.loadResource", function_body(self.view_source, "onUpdate"))
        self.assertIn("dc.drawBitmap", function_body(self.store_source, "draw"))
        self.assertIn("dc.drawBitmap2", function_body(self.store_source, "draw"))
        self.assertIn("AffineTransform", self.store_source)
        self.assertIn("RasterMapIndex.WEST", function_body(self.pack_source, "contains"))

    def test_store_releases_old_selection_before_loading_and_retries_failures(self):
        prepare = function_body(self.store_source, "prepare")

        changed_load = prepare.rindex("loadMissing")
        self.assertLess(prepare.index("_cells = nextCells"), changed_load)
        self.assertLess(prepare.index("_bitmaps = nextBitmaps"), changed_load)
        self.assertIn("if (_loadFailed) { loadMissing(); }", prepare)

    def test_view_releases_bitmaps_when_hidden_and_restores_them_when_shown(self):
        self.assertIn("_store.clear()", function_body(self.view_source, "onHide"))
        self.assertIn("prepareMap", function_body(self.view_source, "onShow"))
        self.assertIn("_store.prepare", function_body(self.view_source, "prepareMap"))


if __name__ == "__main__":
    unittest.main()
