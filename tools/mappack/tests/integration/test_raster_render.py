"""Behavior tests for high-contrast raster cell rendering."""

import os
import sys
import unittest

from PIL import ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
ROOT = os.path.dirname(TESTS)
sys.path.insert(0, ROOT)

from mappack import geom  # noqa: E402
from mappack.osmread import Way  # noqa: E402
from mappack.raster import (  # noqa: E402
    RasterFonts,
    RasterStyle,
    build_scene,
    grid_for,
    render_cell,
)


class TestRasterRender(unittest.TestCase):
    def setUp(self):
        self.zoom = 15
        self.bounds = (12.49, 41.83, 12.491, 41.831)
        self.grid = grid_for(self.bounds, self.zoom)
        left = self.grid.origin_x
        top = self.grid.origin_y

        def lon_lat(x, y):
            return (
                geom.world_x_to_lon(left + x, self.zoom),
                geom.world_y_to_lat(top + y, self.zoom),
            )

        self.ways = [
            Way(
                tags={"natural": "water", "name": "Laghetto"},
                coords=[
                    lon_lat(8, 8),
                    lon_lat(55, 8),
                    lon_lat(55, 48),
                    lon_lat(8, 48),
                    lon_lat(8, 8),
                ],
                closed=True,
            ),
            Way(
                tags={"highway": "primary", "name": "Via Principale"},
                coords=[lon_lat(5, 90), lon_lat(115, 90)],
            ),
        ]
        font = ImageFont.load_default()
        self.fonts = RasterFonts(font, font)
        self.scene = build_scene(self.ways, self.zoom)

    def test_rendered_cell_is_120_square_and_palette_limited(self):
        image = render_cell(self.scene, self.grid, 0, 0, self.fonts)

        self.assertEqual(image.size, (120, 120))
        self.assertEqual(image.mode, "P")
        self.assertLessEqual(len(image.getcolors()), 32)

    def test_primary_road_and_water_change_background_pixels(self):
        image = render_cell(
            self.scene, self.grid, 0, 0, self.fonts
        ).convert("RGB")
        colors = set(image.getdata())

        self.assertIn(RasterStyle.PRIMARY, colors)
        self.assertIn(RasterStyle.WATER, colors)
        self.assertIn(RasterStyle.LABEL_HALO, colors)


if __name__ == "__main__":
    unittest.main()
