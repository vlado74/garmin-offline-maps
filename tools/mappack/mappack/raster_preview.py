"""Compose packed raster cells exactly as the north-up watch view does."""

from __future__ import annotations

import argparse
import json
import math
import os
from typing import Optional

from PIL import Image, ImageDraw

from .raster import RasterGrid, RasterStyle, visible_cells


MARKER = (0, 215, 255)
MARKER_OUTLINE = (0, 0, 0)


def compose_preview(pack_dir: str, output: str, zoom: int, width: int = 360,
                    height: int = 360, lon: Optional[float] = None,
                    lat: Optional[float] = None) -> Image.Image:
    """Compose one GPS-centred viewport from a raster resource pack."""
    with open(os.path.join(pack_dir, "pack.json"), encoding="utf-8") as handle:
        manifest = json.load(handle)
    if zoom not in manifest["zooms"]:
        raise ValueError("zoom %s is not present in the pack" % zoom)
    if lon is None or lat is None:
        lon, lat = manifest["center"]
    raw_grid = next(item for item in manifest["grids"] if item["zoom"] == zoom)
    grid = RasterGrid(
        zoom=zoom,
        tile_size=manifest["tileSize"],
        origin_x=raw_grid["originX"],
        origin_y=raw_grid["originY"],
        cols=raw_grid["cols"],
        rows=raw_grid["rows"],
    )
    image = Image.new("RGB", (width, height), RasterStyle.BACKGROUND)
    for col, row, x, y in visible_cells(grid, lon, lat, width, height):
        path = os.path.join(pack_dir, "tiles", "r%d_%d_%d.png" % (zoom, col, row))
        if os.path.isfile(path):
            with Image.open(path) as tile:
                image.paste(tile.convert("RGB"), (math.floor(x), math.floor(y)))
    draw = ImageDraw.Draw(image)
    cx, cy = width // 2, height // 2
    draw.ellipse((cx - 8, cy - 8, cx + 8, cy + 8), fill=MARKER_OUTLINE)
    draw.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=MARKER)
    image.save(output)
    return image


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Compose a Garmin raster map preview")
    parser.add_argument("--pack", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--zoom", type=int, required=True)
    parser.add_argument("--lon", type=float)
    parser.add_argument("--lat", type=float)
    args = parser.parse_args(argv)
    if (args.lon is None) != (args.lat is None):
        parser.error("pass both --lon and --lat, or neither")
    compose_preview(args.pack, args.out, args.zoom, lon=args.lon, lat=args.lat)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
