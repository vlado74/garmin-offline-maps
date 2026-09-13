"""Command line entry point for deterministic raster map resources."""

from __future__ import annotations

import argparse
import math
from typing import List

from PIL import ImageFont

from . import osmread
from .geom import BBox, MAX_LAT
from .raster import RasterFonts, resolve_fonts
from .raster_emit import write_raster_pack


def parse_bbox(text: str) -> BBox:
    try:
        values = tuple(float(part.strip()) for part in text.split(","))
    except ValueError as error:
        raise argparse.ArgumentTypeError("bbox values must be numbers") from error
    if len(values) != 4:
        raise argparse.ArgumentTypeError("bbox needs west,south,east,north")
    west, south, east, north = values
    if not all(math.isfinite(value) for value in values):
        raise argparse.ArgumentTypeError("bbox values must be finite")
    if west < -180.0 or east > 180.0:
        raise argparse.ArgumentTypeError("bbox longitude must be within -180..180")
    if south < -MAX_LAT or north > MAX_LAT:
        raise argparse.ArgumentTypeError(
            "bbox latitude must be within %.8f..%.8f" % (-MAX_LAT, MAX_LAT)
        )
    if west >= east or south >= north:
        raise argparse.ArgumentTypeError("bbox must satisfy west<east and south<north")
    return west, south, east, north


def parse_zooms(text: str) -> List[int]:
    try:
        zooms = sorted(
            int(part.strip()) for part in text.split(",") if part.strip()
        )
    except ValueError as error:
        raise argparse.ArgumentTypeError("zooms must be integers") from error
    if zooms != [13, 15]:
        raise argparse.ArgumentTypeError("--zooms must be exactly 13,15")
    return zooms


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="mappack-raster",
        description="Build offline raster bitmap resources for Connect IQ.",
    )
    parser.add_argument("--input", help="read a local OSM extract instead of Overpass")
    parser.add_argument("--bbox", type=parse_bbox, required=True)
    parser.add_argument("--zooms", type=parse_zooms, required=True)
    parser.add_argument("--font", help="regular TrueType font path")
    parser.add_argument("--bold-font", help="bold TrueType font path")
    parser.add_argument(
        "--pillow-default-font",
        action="store_true",
        help="use Pillow's bundled default font for reproducible test/demo output",
    )
    parser.add_argument("--cache", help="reuse/cache the Overpass OSM response")
    parser.add_argument("--out", required=True, help="raster resource directory")
    parser.add_argument("--index", required=True, help="generated Monkey C index path")
    parser.add_argument("--name", default="raster", help="pack name")
    return parser


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.pillow_default_font:
        if args.font or args.bold_font:
            parser.error("--pillow-default-font cannot be combined with font paths")
        default_font = ImageFont.load_default()
        fonts = RasterFonts(default_font, default_font)
    else:
        if not args.font or not args.bold_font:
            parser.error("pass --font and --bold-font, or --pillow-default-font")
        fonts = resolve_fonts(args.font, args.bold_font)
    ways = osmread.load(args.input, bbox=args.bbox, cache_path=args.cache)
    manifest = write_raster_pack(
        ways,
        args.bbox,
        args.zooms,
        args.out,
        args.index,
        fonts,
        name=args.name,
    )
    print(
        "wrote %d raster resources to %s"
        % (manifest["resourceCount"], args.out)
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
