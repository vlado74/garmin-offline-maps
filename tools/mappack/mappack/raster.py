"""Web Mercator grid metadata for offline raster map cells."""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import List, Tuple

from . import geom
from .geom import BBox


@dataclass(frozen=True)
class RasterGrid:
    zoom: int
    tile_size: int
    origin_x: int
    origin_y: int
    cols: int
    rows: int


VisibleCell = Tuple[int, int, float, float]


def grid_for(bounds: BBox, zoom: int, tile_size: int = 120) -> RasterGrid:
    """Return the world-pixel-aligned grid enclosing geographic *bounds*."""
    west, south, east, north = bounds
    left = math.floor(geom.lon_to_world_x(west, zoom) / tile_size) * tile_size
    top = math.floor(geom.lat_to_world_y(north, zoom) / tile_size) * tile_size
    right = math.ceil(geom.lon_to_world_x(east, zoom) / tile_size) * tile_size
    bottom = math.ceil(geom.lat_to_world_y(south, zoom) / tile_size) * tile_size
    return RasterGrid(
        zoom,
        tile_size,
        left,
        top,
        (right - left) // tile_size,
        (bottom - top) // tile_size,
    )


def cell_bounds(grid: RasterGrid, col: int, row: int) -> BBox:
    """Return a cell's geographic bounds as west, south, east, north."""
    left = grid.origin_x + col * grid.tile_size
    top = grid.origin_y + row * grid.tile_size
    right = left + grid.tile_size
    bottom = top + grid.tile_size
    return (
        geom.world_x_to_lon(left, grid.zoom),
        geom.world_y_to_lat(bottom, grid.zoom),
        geom.world_x_to_lon(right, grid.zoom),
        geom.world_y_to_lat(top, grid.zoom),
    )


def visible_cells(
    grid: RasterGrid,
    lon: float,
    lat: float,
    width: int,
    height: int,
) -> List[VisibleCell]:
    """Return cells intersecting a centred viewport, in row-major order."""
    center_x = geom.lon_to_world_x(lon, grid.zoom)
    center_y = geom.lat_to_world_y(lat, grid.zoom)
    left = center_x - width / 2.0
    top = center_y - height / 2.0
    right = left + width
    bottom = top + height

    first_col = max(0, math.floor((left - grid.origin_x) / grid.tile_size))
    last_col = min(
        grid.cols - 1,
        math.ceil((right - grid.origin_x) / grid.tile_size) - 1,
    )
    first_row = max(0, math.floor((top - grid.origin_y) / grid.tile_size))
    last_row = min(
        grid.rows - 1,
        math.ceil((bottom - grid.origin_y) / grid.tile_size) - 1,
    )

    return [
        (
            col,
            row,
            grid.origin_x + col * grid.tile_size - left,
            grid.origin_y + row * grid.tile_size - top,
        )
        for row in range(first_row, last_row + 1)
        for col in range(first_col, last_col + 1)
    ]
