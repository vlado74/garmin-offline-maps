"""Integration tests for composing the exact raster cells used on-watch."""

import os
import tempfile
import unittest

from PIL import Image

from mappack.raster_preview import compose_preview


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
PACK = os.path.join(ROOT, "mapdata", "raster-demo")


class TestRasterPreview(unittest.TestCase):
    def test_composes_both_watch_scales_with_a_centered_marker(self):
        with tempfile.TemporaryDirectory() as directory:
            for zoom in (13, 15):
                output = os.path.join(directory, "preview-%d.png" % zoom)
                compose_preview(PACK, output, zoom=zoom, width=360, height=360)
                image = Image.open(output).convert("RGB")
                self.assertEqual((360, 360), image.size)
                background = (242, 239, 231)
                changed = sum(pixel != background for pixel in image.getdata())
                self.assertGreater(changed / (360 * 360), 0.03)
                self.assertEqual((0, 215, 255), image.getpixel((180, 180)))


if __name__ == "__main__":
    unittest.main()
