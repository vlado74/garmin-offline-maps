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
        self.bounds = (-0.001, -0.001, 0.001, 0.001)
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

    def test_road_stroke_is_rendered_across_a_neighboring_cell_edge(self):
        grid = grid_for((-0.01, -0.01, 0.01, 0.01), self.zoom)
        boundary = grid.origin_x + grid.tile_size
        top = grid.origin_y

        def lon_lat(x, y):
            return (
                geom.world_x_to_lon(x, self.zoom),
                geom.world_y_to_lat(y, self.zoom),
            )

        road = Way(
            tags={"highway": "primary"},
            coords=[
                lon_lat(boundary + 1, top + 10),
                lon_lat(boundary + 1, top + 110),
            ],
        )

        image = render_cell(
            build_scene([road], self.zoom), grid, 0, 0, self.fonts
        ).convert("RGB")

        self.assertIn(RasterStyle.PRIMARY, set(image.getdata()))

    def test_named_paths_are_labelled_but_named_forests_are_not(self):
        left = self.grid.origin_x
        top = self.grid.origin_y

        def lon_lat(x, y):
            return (
                geom.world_x_to_lon(left + x, self.zoom),
                geom.world_y_to_lat(top + y, self.zoom),
            )

        path = Way(
            tags={"highway": "footway", "name": "Sentiero"},
            coords=[lon_lat(10, 90), lon_lat(110, 90)],
        )
        forest = Way(
            tags={"landuse": "forest", "name": "Bosco"},
            coords=[
                lon_lat(5, 5), lon_lat(115, 5), lon_lat(115, 55),
                lon_lat(5, 55), lon_lat(5, 5),
            ],
            closed=True,
        )

        with_path = render_cell(
            build_scene([path], self.zoom), self.grid, 0, 0, self.fonts
        ).convert("RGB")
        forest_only = render_cell(
            build_scene([forest], self.zoom), self.grid, 0, 0, self.fonts
        ).convert("RGB")

        self.assertIn(RasterStyle.LABEL, set(with_path.getdata()))
        self.assertNotIn(RasterStyle.LABEL, set(forest_only.getdata()))


if __name__ == "__main__":
    unittest.main()
