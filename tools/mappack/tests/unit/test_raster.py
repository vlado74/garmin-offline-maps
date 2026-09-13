"""Unit tests for the raster grid and viewport selection contract."""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
ROOT = os.path.dirname(TESTS)
sys.path.insert(0, ROOT)

from mappack import geom  # noqa: E402
from PIL import ImageFont  # noqa: E402

from mappack.raster import (  # noqa: E402
    LabelCandidate,
    RasterFonts,
    RasterGrid,
    cell_bounds,
    grid_for,
    place_labels,
    visible_cells,
)


ROME = (12.4644720888, 41.8094001206, 12.5247529112, 41.8543156794)


class TestRasterGrid(unittest.TestCase):
    def test_grid_is_anchored_to_120_pixel_world_cells(self):
        grid = grid_for(ROME, 15)

        self.assertIsInstance(grid, RasterGrid)
        self.assertEqual(grid.tile_size, 120)
        self.assertEqual(grid.origin_x % 120, 0)
        self.assertEqual(grid.origin_y % 120, 0)

    def test_grid_covers_the_requested_bounds_at_both_scales(self):
        west, south, east, north = ROME

        for zoom in (13, 15):
            with self.subTest(zoom=zoom):
                grid = grid_for(ROME, zoom)
                grid_west, grid_south, grid_east, grid_north = cell_bounds(
                    grid, grid.cols - 1, grid.rows - 1
                )
                first_west, _, _, first_north = cell_bounds(grid, 0, 0)

                self.assertLessEqual(first_west, west)
                self.assertGreaterEqual(first_north, north)
                self.assertGreaterEqual(grid_east, east)
                self.assertLessEqual(grid_south, south)

    def test_grid_cell_bounds_round_trip(self):
        grid = grid_for(ROME, 13)
        west, south, east, north = cell_bounds(grid, 0, 0)

        self.assertLess(west, east)
        self.assertLess(south, north)
        self.assertAlmostEqual(geom.lon_to_world_x(west, 13), grid.origin_x)
        self.assertAlmostEqual(geom.lat_to_world_y(north, 13), grid.origin_y)
        self.assertAlmostEqual(
            geom.lon_to_world_x(east, 13), grid.origin_x + grid.tile_size
        )
        self.assertAlmostEqual(
            geom.lat_to_world_y(south, 13), grid.origin_y + grid.tile_size
        )


class TestVisibleCells(unittest.TestCase):
    def test_360_pixel_view_never_selects_more_than_sixteen_cells(self):
        grid = grid_for(ROME, 15)

        cells = visible_cells(grid, 12.4946125, 41.8318579, 360, 360)

        self.assertLessEqual(len(cells), 16)

    def test_cells_are_clamped_and_returned_in_row_major_order(self):
        grid = RasterGrid(zoom=0, tile_size=120, origin_x=0, origin_y=0,
                          cols=3, rows=3)
        lon = geom.world_x_to_lon(60, 0)
        lat = geom.world_y_to_lat(60, 0)

        cells = visible_cells(grid, lon, lat, 240, 240)

        self.assertEqual([(col, row) for col, row, _, _ in cells],
                         [(0, 0), (1, 0), (0, 1), (1, 1)])
        expected_offsets = [
            (60.0, 60.0),
            (180.0, 60.0),
            (60.0, 180.0),
            (180.0, 180.0),
        ]
        for (_, _, screen_x, screen_y), (expected_x, expected_y) in zip(
            cells, expected_offsets
        ):
            self.assertAlmostEqual(screen_x, expected_x)
            self.assertAlmostEqual(screen_y, expected_y)


class TestLabelPlacement(unittest.TestCase):
    def test_collision_keeps_the_higher_priority_name(self):
        font = ImageFont.load_default()
        fonts = RasterFonts(font, font)
        low_priority = LabelCandidate("Parco", 10, (60.0, 60.0), False)
        high_priority = LabelCandidate("Via Principale", 100, (60.0, 60.0), True)

        placed = place_labels(
            [low_priority, high_priority], (120, 120), fonts
        )

        self.assertEqual([label.text for label in placed], ["Via Principale"])


if __name__ == "__main__":
    unittest.main()
