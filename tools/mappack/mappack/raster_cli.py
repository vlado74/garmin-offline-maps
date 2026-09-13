"""Command line entry point for deterministic raster map resources."""

from __future__ import annotations

import argparse
from typing import List

from . import osmread
from .geom import BBox
from .raster import resolve_fonts
from .raster_emit import write_raster_pack


def parse_bbox(text: str) -> BBox:
    try:
        values = tuple(float(part.strip()) for part in text.split(","))
    except ValueError as error:
        raise argparse.ArgumentTypeError("bbox values must be numbers") from error
    if len(values) != 4:
        raise argparse.ArgumentTypeError("bbox needs west,south,east,north")
    west, south, east, north = values
    if west >= east or south >= north:
        raise argparse.ArgumentTypeError("bbox must satisfy west<east and south<north")
    return west, south, east, north


def parse_zooms(text: str) -> List[int]:
    try:
        zooms = sorted(
            set(int(part.strip()) for part in text.split(",") if part.strip())
        )
    except ValueError as error:
        raise argparse.ArgumentTypeError("zooms must be integers") from error
    if len(zooms) != 2:
        raise argparse.ArgumentTypeError("--zooms needs exactly two distinct levels")
    return zooms


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="mappack-raster",
        description="Build offline raster bitmap resources for Connect IQ.",
    )
    parser.add_argument("--bbox", type=parse_bbox, required=True)
    parser.add_argument("--zooms", type=parse_zooms, required=True)
    parser.add_argument("--font", required=True, help="regular TrueType font path")
    parser.add_argument("--bold-font", required=True, help="bold TrueType font path")
    parser.add_argument("--cache", help="reuse/cache the Overpass OSM response")
    parser.add_argument("--out", required=True, help="raster resource directory")
    parser.add_argument("--index", required=True, help="generated Monkey C index path")
    parser.add_argument("--name", default="raster", help="pack name")
    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    fonts = resolve_fonts(args.font, args.bold_font)
    ways = osmread.load(None, bbox=args.bbox, cache_path=args.cache)
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
