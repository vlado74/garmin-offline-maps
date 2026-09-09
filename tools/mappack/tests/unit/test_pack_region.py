"""Unit tests for clipping fetched geometry to the requested pack region.

Overpass returns a way's *whole* geometry once any one of its nodes falls
inside the query box: a river or a coastline that runs the length of a
country arrives with the rest of its length attached. Left unclipped, that
pollutes `clamp_bbox` and the tile grid with tiles far from the requested
area -- a 10 km pack request spending its resource budget on tiles 30 km
away. See `PackOptions.region`.
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
ROOT = os.path.dirname(TESTS)
sys.path.insert(0, ROOT)
from mappack import geom  # noqa: E402
from mappack.osmread import Way  # noqa: E402
from mappack.pack import PackOptions, build_features, pack  # noqa: E402

# west, south, east, north -- a small box the way below only clips a corner of.
REGION = (12.95, 41.95, 13.05, 42.05)


def crossing_river():
    # A long diagonal way, most of it nowhere near REGION, that happens to
    # pass through it around the midpoint -- the Tiber-through-a-small-pack
    # shape that motivated this.
    coords = [(12.0 + i * 0.05, 41.0 + i * 0.05) for i in range(41)]
    return Way(tags={"waterway": "river"}, coords=coords)


class TestRegionClip(unittest.TestCase):
    def test_feature_coords_stay_within_the_region(self):
        options = PackOptions(data_zooms=(14,), region=REGION)
        features = build_features([crossing_river()], options, 14)
        self.assertTrue(features, "the piece crossing the region was dropped entirely")

        margin = geom.TILE_SIZE + 1
        xmin = geom.lon_to_world_x(REGION[0], 14) - margin
        xmax = geom.lon_to_world_x(REGION[2], 14) + margin
        ymin = geom.lat_to_world_y(REGION[3], 14) - margin
        ymax = geom.lat_to_world_y(REGION[1], 14) + margin
        for feature in features:
            for x, y in feature.coords:
                self.assertGreaterEqual(x, xmin)
                self.assertLessEqual(x, xmax)
                self.assertGreaterEqual(y, ymin)
                self.assertLessEqual(y, ymax)

    def test_bounds_do_not_balloon_to_the_ways_full_extent(self):
        options = PackOptions(data_zooms=(12, 14, 16), region=REGION)
        result = pack([crossing_river()], options)
        west, south, east, north = result.bounds
        # A couple of tiles' slack either side of the request, not the ~300 km
        # the unclipped way would otherwise span end to end.
        self.assertGreater(west, REGION[0] - 1.0)
        self.assertLess(east, REGION[2] + 1.0)
        self.assertGreater(south, REGION[1] - 1.0)
        self.assertLess(north, REGION[3] + 1.0)

    def test_without_a_region_the_full_way_is_kept(self):
        options = PackOptions(data_zooms=(14,), region=None)
        features = build_features([crossing_river()], options, 14)
        self.assertEqual(1, len(features))
        self.assertEqual(41, len(features[0].coords))


if __name__ == "__main__":
    unittest.main()
