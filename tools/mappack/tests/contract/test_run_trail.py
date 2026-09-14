"""Behavioral mirror and source contract for the bounded watch trail."""

import math
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


def numeric_constant(source, name):
    match = re.search(
        r"const\s+%s\s*=\s*([0-9]+(?:\.[0-9]+)?)(?:[df])?\s*;" % name,
        source,
    )
    if match is None:
        raise AssertionError("missing numeric constant %s" % name)
    return float(match.group(1))


def project(point, centre, zoom, width=360, height=360):
    lat, lon = point
    centre_lat, centre_lon = centre
    world_size = 256 * (1 << zoom)

    def world_x(value):
        return (value + 180.0) / 360.0 * world_size

    def world_y(value):
        sine = math.sin(math.radians(value))
        mercator = math.log((1.0 + sine) / (1.0 - sine))
        return (0.5 - mercator / (4.0 * math.pi)) * world_size

    return (
        width / 2.0 + world_x(lon) - world_x(centre_lon),
        height / 2.0 + world_y(lat) - world_y(centre_lat),
    )


def segment_can_intersect_viewport(start, end, width=360, height=360, margin=10):
    left = -margin
    top = -margin
    right = width + margin
    bottom = height + margin
    return not (
        (start[0] < left and end[0] < left)
        or (start[0] > right and end[0] > right)
        or (start[1] < top and end[1] < top)
        or (start[1] > bottom and end[1] > bottom)
    )


class TrailModel:
    """Python mirror of RunTrail's sampling and compaction behavior."""

    def __init__(self, source):
        self.max_points = int(numeric_constant(source, "MAX_POINTS"))
        self.sample_metres = numeric_constant(source, "INITIAL_SAMPLE_METRES")
        self.max_jump_metres = numeric_constant(source, "MAX_JUMP_METRES")
        self.earth_radius_metres = numeric_constant(source, "EARTH_RADIUS_METRES")
        self.lats = []
        self.lons = []
        self.last_fix = None

    @property
    def points(self):
        return list(zip(self.lats, self.lons))

    def distance(self, from_lat, from_lon, to_lat, to_lon):
        lat_radians = math.radians(from_lat)
        dy = math.radians(to_lat - from_lat) * self.earth_radius_metres
        dx = (
            math.radians(to_lon - from_lon)
            * self.earth_radius_metres
            * math.cos(lat_radians)
        )
        return math.sqrt(dx * dx + dy * dy)

    def add(self, lat, lon):
        if self.lats:
            jump = self.distance(*self.last_fix, lat, lon)
            if jump > self.max_jump_metres:
                return False
            self.last_fix = (lat, lon)
            distance = self.distance(self.lats[-1], self.lons[-1], lat, lon)
            if distance < self.sample_metres:
                return False
        else:
            self.last_fix = (lat, lon)
        if len(self.lats) >= self.max_points:
            indexes = [0] + list(range(2, len(self.lats) - 1, 2)) + [len(self.lats) - 1]
            compact_lats = [self.lats[index] for index in indexes]
            compact_lons = [self.lons[index] for index in indexes]
            self.lats, self.lons = compact_lats, compact_lons
            self.sample_metres *= 2.0
        self.lats.append(lat)
        self.lons.append(lon)
        return True


class TestRunTrail(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = read_repo("source/RunTrail.mc")
        cls.view_source = read_repo("source/RunMapView.mc")

    def test_jitter_and_jump_are_rejected(self):
        trail = TrailModel(self.source)
        self.assertTrue(trail.add(52.5133994, 13.3632))
        self.assertFalse(trail.add(52.5134094, 13.3632))  # about 1.1 m
        self.assertFalse(trail.add(52.5160994, 13.3632))  # about 300 m

    def test_compaction_is_bounded_and_keeps_ends(self):
        trail = TrailModel(self.source)
        first = (52.5133994, 13.3632)
        trail.add(*first)
        largest = 0
        for index in range(1, 700):
            trail.add(first[0] + index * 0.00018, first[1])
            largest = max(largest, len(trail.points))
        self.assertLessEqual(largest, 512)
        self.assertEqual(trail.points[0], first)
        self.assertEqual(trail.points[-1][0], first[0] + 699 * 0.00018)
        self.assertEqual(len(trail.lats), len(trail.lons))
        self.assertEqual(trail.sample_metres, 10.0)

    def test_repeated_compaction_keeps_accepting_small_raw_steps(self):
        trail = TrailModel(self.source)
        first = (41.0, 12.0)
        trail.add(*first)
        latest_stored = trail.points[-1]
        reached_large_threshold = False
        stored_after_large_threshold = False

        for index in range(1, 30000):
            trail.add(first[0] + index * 0.00018, first[1])
            if trail.sample_metres > trail.max_jump_metres:
                if not reached_large_threshold:
                    reached_large_threshold = True
                    latest_stored = trail.points[-1]
                elif trail.points[-1] != latest_stored:
                    stored_after_large_threshold = True
                    break

        self.assertTrue(reached_large_threshold)
        self.assertTrue(stored_after_large_threshold)
        self.assertLessEqual(len(trail.points), trail.max_points)
        self.assertIn("_lastFixLat", function_body(self.source, "add"))

    def test_scale_changes_projection_not_stored_coordinates(self):
        trail = TrailModel(self.source)
        point = (41.8320, 12.4950)
        centre = (52.5133994, 13.3632)
        trail.add(*point)
        stored = trail.points[:]
        self.assertNotEqual(project(point, centre, 13), project(point, centre, 15))
        self.assertEqual(trail.points, stored)
        self.assertNotIn("Mercator.", function_body(self.source, "add"))
        self.assertIn("Mercator.lonToWorldX", function_body(self.source, "draw"))
        self.assertIn("Mercator.latToWorldY", function_body(self.source, "draw"))

    def test_culling_keeps_segments_that_cross_the_margin(self):
        self.assertTrue(segment_can_intersect_viewport((-20, 180), (380, 180)))
        self.assertTrue(segment_can_intersect_viewport((180, -20), (180, 380)))
        self.assertFalse(segment_can_intersect_viewport((-30, 20), (-20, 340)))
        self.assertFalse(segment_can_intersect_viewport((20, 390), (340, 400)))

        visible = function_body(self.source, "segmentVisible")
        for rejection in (
            "x1 < left && x2 < left",
            "x1 > right && x2 > right",
            "y1 < top && y2 < top",
            "y1 > bottom && y2 > bottom",
        ):
            self.assertIn(rejection, visible)

    def test_draw_order_is_raster_attribution_trail_then_marker(self):
        update = function_body(self.view_source, "onUpdate")
        draw_order = [
            update.index("_store.draw(dc)"),
            update.index("drawAttribution(dc)"),
            update.index("_trail.draw(dc"),
            update.index("drawMarker(dc)"),
        ]
        self.assertEqual(draw_order, sorted(draw_order))

        draw = function_body(self.source, "draw")
        outline = draw.index("drawPass(dc, 4, Graphics.COLOR_DK_GRAY")
        cyan = draw.index("drawPass(dc, 2, 0x00D7FF")
        self.assertLess(outline, cyan)

    def test_storage_is_parallel_typed_arrays_replaced_after_compaction(self):
        self.assertIn("hidden var _lats as Array<Number>;", self.source)
        self.assertIn("hidden var _lons as Array<Number>;", self.source)
        compact = function_body(self.source, "compact")
        self.assertLess(compact.index("var compactLats"), compact.index("_lats = compactLats"))
        self.assertLess(compact.index("var compactLons"), compact.index("_lons = compactLons"))
        self.assertLess(compact.index("_lats = compactLats"), compact.index("_lons = compactLons"))

    def test_draw_streams_segments_without_per_frame_coordinate_arrays(self):
        draw = function_body(self.source, "draw")
        draw_pass = function_body(self.source, "drawPass")

        self.assertNotIn("[] as Array<Number>", draw)
        self.assertNotIn("[] as Array<Number>", draw_pass)
        self.assertEqual(draw.count("drawPass(dc"), 2)


if __name__ == "__main__":
    unittest.main()
