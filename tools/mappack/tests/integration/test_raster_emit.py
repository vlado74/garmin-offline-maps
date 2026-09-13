"""Integration tests for emitted raster resources and their Monkey C index."""

import argparse
import glob
import json
import os
import re
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

from PIL import Image, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.dirname(HERE)
ROOT = os.path.dirname(TESTS)
sys.path.insert(0, ROOT)

from mappack.osmread import Way  # noqa: E402
from mappack.raster import RasterFonts  # noqa: E402
from mappack.raster_cli import main as raster_main, parse_bbox, parse_zooms  # noqa: E402
from mappack.raster_emit import write_raster_pack  # noqa: E402


class TestRasterEmit(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.out = os.path.join(self.temp_dir.name, "raster")
        self.index = os.path.join(self.temp_dir.name, "generated", "RasterMapIndex.mc")
        self.bounds = (-0.003, -0.003, 0.003, 0.003)
        self.ways = [
            Way(
                tags={"highway": "primary", "name": "Synthetic Road"},
                coords=[(-0.0029, 0.0), (0.0029, 0.0)],
            )
        ]
        font = ImageFont.load_default()
        self.fonts = RasterFonts(font, font)

    def tearDown(self):
        self.temp_dir.cleanup()

    def read(self, path):
        with open(path, encoding="utf-8") as handle:
            return handle.read()

    def test_emit_writes_png_resources_metadata_and_index(self):
        os.makedirs(os.path.join(self.out, "tiles"))
        stale_tile = os.path.join(self.out, "tiles", "stale.png")
        sibling = os.path.join(self.out, "keep.txt")
        open(stale_tile, "wb").close()
        with open(sibling, "w", encoding="utf-8") as handle:
            handle.write("keep")

        manifest = write_raster_pack(
            self.ways,
            self.bounds,
            (13, 15),
            self.out,
            self.index,
            fonts=self.fonts,
        )

        self.assertEqual(manifest["tileSize"], 120)
        self.assertEqual(manifest["zooms"], [13, 15])
        self.assertEqual(manifest["bounds"], [-0.003, -0.003, 0.003, 0.003])
        self.assertEqual(manifest["center"], [0.0, 0.0])
        self.assertTrue(os.path.exists(os.path.join(self.out, "mapdata.xml")))
        self.assertIn('packingFormat="png"', self.read(os.path.join(self.out, "mapdata.xml")))
        self.assertIn("module RasterMapIndex", self.read(self.index))
        pngs = glob.glob(os.path.join(self.out, "tiles", "*.png"))
        self.assertEqual(len(pngs), manifest["resourceCount"])
        self.assertEqual(len(pngs), 13)
        self.assertFalse(os.path.exists(stale_tile))
        self.assertEqual(self.read(sibling), "keep")
        self.assertEqual(
            json.loads(self.read(os.path.join(self.out, "pack.json"))),
            manifest,
        )
        for path in pngs:
            with Image.open(path) as image:
                self.assertEqual(image.size, (120, 120))
                self.assertEqual(image.mode, "P")
                self.assertLessEqual(len(image.getcolors()), 32)

    def test_every_bitmap_has_exactly_one_matching_index_case(self):
        write_raster_pack(
            self.ways,
            self.bounds,
            (13, 15),
            self.out,
            self.index,
            fonts=self.fonts,
        )

        root = ET.parse(os.path.join(self.out, "mapdata.xml")).getroot()
        bitmaps = root.findall("bitmap")
        bitmap_ids = [bitmap.attrib["id"] for bitmap in bitmaps]
        index = self.read(self.index)

        expected_cases = {
            "r13_0_0": 0,
            "r13_0_1": 1,
            "r13_1_0": 2,
            "r13_1_1": 3,
            "r15_0_0": 0,
            "r15_0_1": 1,
            "r15_0_2": 2,
            "r15_1_0": 3,
            "r15_1_1": 4,
            "r15_1_2": 5,
            "r15_2_0": 6,
            "r15_2_1": 7,
            "r15_2_2": 8,
        }
        self.assertEqual(bitmap_ids, list(expected_cases))
        for bitmap in bitmaps:
            resource_id = bitmap.attrib["id"]
            zoom, col, row = (int(value) for value in resource_id[1:].split("_"))
            case = (
                r"case %d: return Rez\.Drawables\.%s;"
                % (expected_cases[resource_id], re.escape(resource_id))
            )
            self.assertEqual(len(re.findall(case, index)), 1)
            self.assertIn(
                "function resourceAt%d(col, row)" % zoom,
                index,
            )
            self.assertEqual(
                bitmap.attrib,
                {
                    "id": resource_id,
                    "filename": "tiles/%s.png" % resource_id,
                    "scope": "foreground",
                    "packingFormat": "png",
                },
            )
            self.assertIn(col, (0, 1, 2))
            self.assertIn(row, (0, 1, 2))

        self.assertIn("const TILE_SIZE = 120;", index)
        self.assertIn("const ZOOMS = [13, 15];", index)
        self.assertIn("function originX(zoom)", index)
        self.assertIn("function originY(zoom)", index)
        self.assertIn("function cols(zoom)", index)
        self.assertIn("function rows(zoom)", index)
        self.assertIn("function resourceAt(zoom, col, row)", index)
        self.assertEqual(index.count("if (col < 0 || row < 0"), 2)
        self.assertIn("if (zoom == 15) { return resourceAt15(col, row); }", index)

    def test_cli_accepts_only_the_zoom_13_and_15_pair(self):
        self.assertEqual(parse_zooms("15,13"), [13, 15])
        for text in ("12,14", "13,16", "13,13", "13,15,15"):
            with self.subTest(text=text):
                with self.assertRaises(argparse.ArgumentTypeError):
                    parse_zooms(text)

    def test_cli_builds_from_local_osm_with_pillow_default_font(self):
        fixture = os.path.join(TESTS, "demo-city.osm")

        result = raster_main(
            [
                "--input", fixture,
                "--bbox", "13.359,52.509,13.367,52.517",
                "--zooms", "13,15",
                "--pillow-default-font",
                "--out", self.out,
                "--index", self.index,
                "--name", "Synthetic Raster Demo",
            ]
        )

        self.assertEqual(result, 0)
        self.assertTrue(os.path.isfile(os.path.join(self.out, "mapdata.xml")))
        self.assertTrue(os.path.isfile(self.index))

    def test_emitter_rejects_other_zoom_pairs_before_writing(self):
        for zooms in ((13, 16), (13, 15, 15)):
            with self.subTest(zooms=zooms):
                with self.assertRaises(ValueError):
                    write_raster_pack(
                        self.ways,
                        self.bounds,
                        zooms,
                        self.out,
                        self.index,
                        fonts=self.fonts,
                    )

        self.assertFalse(os.path.exists(self.out))

    def test_pack_name_is_preserved_and_escaped_for_monkey_c(self):
        name = 'Runner "A" \\ East – Roma'

        manifest = write_raster_pack(
            self.ways,
            self.bounds,
            (13, 15),
            self.out,
            self.index,
            fonts=self.fonts,
            name=name,
        )

        self.assertEqual(manifest["name"], name)
        self.assertIn(
            'const PACK_NAME = "Runner \\"A\\" \\\\ East – Roma";',
            self.read(self.index),
        )

    def test_pack_name_rejects_control_characters_before_writing(self):
        for position, name in enumerate(
            ("Line\nBreak", "Tab\tBreak", "Nul\0Break", "Delete\x7fBreak")
        ):
            with self.subTest(name=repr(name)):
                out = os.path.join(self.temp_dir.name, "raster-%d" % position)
                index = os.path.join(self.temp_dir.name, "index-%d.mc" % position)
                with self.assertRaisesRegex(ValueError, "control character"):
                    write_raster_pack(
                        self.ways,
                        self.bounds,
                        (13, 15),
                        out,
                        index,
                        fonts=self.fonts,
                        name=name,
                    )
                self.assertFalse(os.path.exists(out))

    def test_bbox_rejects_non_finite_or_out_of_mercator_range_values(self):
        self.assertEqual(
            parse_bbox("-180,-85.05112878,180,85.05112878"),
            (-180.0, -85.05112878, 180.0, 85.05112878),
        )
        invalid = (
            "nan,-1,1,1",
            "-1,-1,inf,1",
            "-181,-1,1,1",
            "-1,-1,181,1",
            "-1,-85.05112879,1,1",
            "-1,-1,1,85.05112879",
        )
        for text in invalid:
            with self.subTest(text=text):
                with self.assertRaises(argparse.ArgumentTypeError):
                    parse_bbox(text)


if __name__ == "__main__":
    unittest.main()
