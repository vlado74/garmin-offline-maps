"""Web Mercator grid metadata for offline raster map cells."""

from __future__ import annotations

import math
import os
import sys
from dataclasses import dataclass
from typing import Dict, Iterable, List, NamedTuple, Optional, Sequence, Tuple

from PIL import Image, ImageDraw, ImageFont

from . import classify, geom
from .geom import BBox
from .osmread import Way


@dataclass(frozen=True)
class RasterGrid:
    zoom: int
    tile_size: int
    origin_x: int
    origin_y: int
    cols: int
    rows: int


VisibleCell = Tuple[int, int, float, float]


class RasterStyle:
    BACKGROUND = (242, 239, 231)
    WATER = (159, 198, 232)
    GREEN = (191, 224, 168)
    RAIL = (105, 105, 105)
    PATH = (150, 112, 72)
    MINOR = (255, 255, 255)
    TERTIARY = (245, 205, 92)
    PRIMARY = (240, 140, 40)
    MOTORWAY = (224, 74, 24)
    LABEL = (30, 30, 30)
    LABEL_HALO = (255, 255, 255)


class RasterFonts(NamedTuple):
    regular: ImageFont.ImageFont
    bold: ImageFont.ImageFont


@dataclass(frozen=True)
class SceneFeature:
    name: Optional[str]
    geom: int
    layer: int
    importance: int
    points: Tuple[geom.Point, ...]
    tags: Dict[str, str]


@dataclass(frozen=True)
class RasterScene:
    zoom: int
    tile_size: int
    cells: Dict[Tuple[int, int], Tuple[SceneFeature, ...]]


@dataclass(frozen=True)
class LabelCandidate:
    text: str
    priority: int
    anchor: geom.Point
    bold: bool


@dataclass(frozen=True)
class PlacedLabel:
    text: str
    priority: int
    anchor: geom.Point
    bold: bool
    position: geom.Point
    bounds: BBox


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


def build_scene(
    ways: Iterable[Way], zoom: int, tile_size: int = 120
) -> RasterScene:
    """Project retained OSM ways once and index them by world-pixel cell."""
    indexed: Dict[Tuple[int, int], List[SceneFeature]] = {}
    for way in ways:
        kind = classify.classify(way.tags)
        if kind is None or kind.minzoom > zoom:
            continue
        points = tuple(geom.project(way.coords, zoom))
        if len(points) < 2:
            continue
        feature = SceneFeature(
            way.tags.get("name"),
            kind.geom,
            kind.layer,
            kind.importance,
            points,
            dict(way.tags),
        )
        min_x, min_y, max_x, max_y = geom.bbox(points)
        if kind.geom == classify.GEOM_LINE:
            stroke_width = _line_width(kind.layer)
            if kind.layer == classify.L_MINOR:
                stroke_width += 2
            padding = stroke_width / 2.0
            min_x -= padding
            min_y -= padding
            max_x += padding
            max_y += padding
        first_col = math.floor(min_x / tile_size)
        last_col = math.floor(max_x / tile_size)
        first_row = math.floor(min_y / tile_size)
        last_row = math.floor(max_y / tile_size)
        for row in range(first_row, last_row + 1):
            for col in range(first_col, last_col + 1):
                indexed.setdefault((col, row), []).append(feature)

    cells = {
        key: tuple(sorted(features, key=lambda feature: feature.layer))
        for key, features in indexed.items()
    }
    return RasterScene(zoom, tile_size, cells)


def resolve_fonts(
    regular_path: Optional[str] = None,
    bold_path: Optional[str] = None,
) -> RasterFonts:
    """Load deterministic map fonts, preferring explicit caller paths."""
    if regular_path or bold_path:
        regular = regular_path or bold_path
        bold = bold_path or regular_path
        if not regular or not bold or not os.path.isfile(regular) or not os.path.isfile(bold):
            raise RuntimeError("Raster font paths must point to readable font files")
        return RasterFonts(
            ImageFont.truetype(regular, 13), ImageFont.truetype(bold, 13)
        )

    if sys.platform == "darwin":
        regular = "/System/Library/Fonts/Supplemental/Arial.ttf"
        bold = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
        if os.path.isfile(regular) and os.path.isfile(bold):
            return RasterFonts(
                ImageFont.truetype(regular, 13), ImageFont.truetype(bold, 13)
            )
    raise RuntimeError(
        "No raster fonts found; pass explicit regular_path and bold_path"
    )


def _boxes_intersect(a: BBox, b: BBox) -> bool:
    return not (a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1])


def place_labels(
    candidates: Iterable[LabelCandidate],
    size: Tuple[int, int],
    fonts: RasterFonts,
) -> List[PlacedLabel]:
    """Place higher-priority labels first and reject collisions or overflow."""
    width, height = size
    placed: List[PlacedLabel] = []
    ordered = sorted(
        candidates,
        key=lambda candidate: (
            -candidate.priority,
            candidate.text,
            candidate.anchor[1],
            candidate.anchor[0],
        ),
    )
    for candidate in ordered:
        font = fonts.bold if candidate.bold else fonts.regular
        left, top, right, bottom = font.getbbox(candidate.text, stroke_width=2)
        x = candidate.anchor[0] - (left + right) / 2.0
        y = candidate.anchor[1] - (top + bottom) / 2.0
        bounds = (x + left, y + top, x + right, y + bottom)
        if bounds[0] < 0 or bounds[1] < 0 or bounds[2] > width or bounds[3] > height:
            continue
        if any(_boxes_intersect(bounds, item.bounds) for item in placed):
            continue
        placed.append(
            PlacedLabel(
                candidate.text,
                candidate.priority,
                candidate.anchor,
                candidate.bold,
                (x, y),
                bounds,
            )
        )
    return placed


def _feature_color(layer: int) -> Tuple[int, int, int]:
    return {
        classify.L_WATER_AREA: RasterStyle.WATER,
        classify.L_GREEN_AREA: RasterStyle.GREEN,
        classify.L_BUILDING: RasterStyle.BACKGROUND,
        classify.L_WATERWAY: RasterStyle.WATER,
        classify.L_RAIL: RasterStyle.RAIL,
        classify.L_PATH: RasterStyle.PATH,
        classify.L_MINOR: RasterStyle.MINOR,
        classify.L_TERTIARY: RasterStyle.TERTIARY,
        classify.L_PRIMARY: RasterStyle.PRIMARY,
        classify.L_MOTORWAY: RasterStyle.MOTORWAY,
    }[layer]


def _line_width(layer: int) -> int:
    return {
        classify.L_WATERWAY: 2,
        classify.L_RAIL: 2,
        classify.L_PATH: 1,
        classify.L_MINOR: 3,
        classify.L_TERTIARY: 4,
        classify.L_PRIMARY: 5,
        classify.L_MOTORWAY: 6,
    }.get(layer, 1)


def _local_points(
    feature: SceneFeature, left: float, top: float, scale: int = 1
) -> List[geom.Point]:
    return [
        ((x - left) * scale, (y - top) * scale)
        for x, y in feature.points
    ]


def _label_priority(feature: SceneFeature) -> Optional[Tuple[int, bool]]:
    highway = feature.tags.get("highway")
    if highway in ("motorway", "motorway_link", "trunk", "trunk_link"):
        return 400, True
    if highway in ("primary", "primary_link"):
        return 350, True
    if highway in ("secondary", "secondary_link", "tertiary", "tertiary_link"):
        return 300, True
    if highway in ("residential", "living_street", "unclassified"):
        return 250, False
    if highway is not None:
        return 225, False
    if feature.tags.get("leisure") in ("park", "garden", "nature_reserve"):
        return 200, False
    if feature.layer in (classify.L_WATER_AREA, classify.L_WATERWAY):
        return 150, False
    if feature.layer == classify.L_RAIL:
        return 100, False
    return None


def _line_anchor(
    points: Sequence[geom.Point], bounds: BBox
) -> Optional[geom.Point]:
    longest = -1.0
    anchor: Optional[geom.Point] = None
    for clipped in geom.clip_polyline(points, *bounds):
        for start, end in zip(clipped, clipped[1:]):
            length = math.hypot(end[0] - start[0], end[1] - start[1])
            if length > longest:
                longest = length
                anchor = ((start[0] + end[0]) / 2.0, (start[1] + end[1]) / 2.0)
    return anchor


def _point_on_segment(point: geom.Point, start: geom.Point, end: geom.Point) -> bool:
    px, py = point
    ax, ay = start
    bx, by = end
    cross = (px - ax) * (by - ay) - (py - ay) * (bx - ax)
    if abs(cross) > 1e-7:
        return False
    return (
        min(ax, bx) - 1e-7 <= px <= max(ax, bx) + 1e-7
        and min(ay, by) - 1e-7 <= py <= max(ay, by) + 1e-7
    )


def _point_in_polygon(point: geom.Point, polygon: Sequence[geom.Point]) -> bool:
    """Return whether a point lies inside or on the boundary of a polygon."""
    inside = False
    px, py = point
    for start, end in zip(polygon, polygon[1:] + polygon[:1]):
        if _point_on_segment(point, start, end):
            return True
        ax, ay = start
        bx, by = end
        if (ay > py) != (by > py):
            crossing_x = (bx - ax) * (py - ay) / (by - ay) + ax
            if px < crossing_x:
                inside = not inside
    return inside


def _distance_to_edges(point: geom.Point, polygon: Sequence[geom.Point]) -> float:
    px, py = point
    shortest = float("inf")
    for start, end in zip(polygon, polygon[1:] + polygon[:1]):
        ax, ay = start
        bx, by = end
        dx = bx - ax
        dy = by - ay
        if dx == 0 and dy == 0:
            distance = math.hypot(px - ax, py - ay)
        else:
            t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
            distance = math.hypot(px - (ax + t * dx), py - (ay + t * dy))
        shortest = min(shortest, distance)
    return shortest


def _visual_center(polygon: Sequence[geom.Point]) -> geom.Point:
    """Approximate a pole of inaccessibility that remains inside the area."""
    min_x, min_y, max_x, max_y = geom.bbox(polygon)
    candidates = [polygon[0], ((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)]
    steps = 16
    for row in range(steps):
        y = min_y + (row + 0.5) * (max_y - min_y) / steps
        for col in range(steps):
            x = min_x + (col + 0.5) * (max_x - min_x) / steps
            candidates.append((x, y))
    inside = [point for point in candidates if _point_in_polygon(point, polygon)]
    return max(inside, key=lambda point: _distance_to_edges(point, polygon))


def _label_candidates(
    features: Sequence[SceneFeature], left: float, top: float, size: int
) -> List[LabelCandidate]:
    candidates: List[LabelCandidate] = []
    bounds = (left, top, left + size, top + size)
    for feature in features:
        if not feature.name:
            continue
        ranked = _label_priority(feature)
        if ranked is None:
            continue
        if feature.geom == classify.GEOM_POLYGON:
            visible = geom.clip_polygon(feature.points, *bounds)
            if len(visible) < 3:
                continue
            anchor = _visual_center(visible)
        else:
            anchor = _line_anchor(feature.points, bounds)
            if anchor is None:
                continue
        priority, bold = ranked
        candidates.append(
            LabelCandidate(
                feature.name,
                priority,
                (anchor[0] - left, anchor[1] - top),
                bold,
            )
        )
    return candidates


def _palette_image() -> Image.Image:
    colors = [
        RasterStyle.BACKGROUND,
        RasterStyle.WATER,
        RasterStyle.GREEN,
        RasterStyle.RAIL,
        RasterStyle.PATH,
        RasterStyle.MINOR,
        RasterStyle.TERTIARY,
        RasterStyle.PRIMARY,
        RasterStyle.MOTORWAY,
        RasterStyle.LABEL,
        RasterStyle.LABEL_HALO,
    ]
    palette = [component for color in colors for component in color]
    palette.extend([0] * (768 - len(palette)))
    image = Image.new("P", (1, 1))
    image.putpalette(palette)
    return image


def _scaled_font(font: ImageFont.ImageFont, scale: int) -> ImageFont.ImageFont:
    if hasattr(font, "font_variant") and hasattr(font, "size"):
        return font.font_variant(size=max(1, int(round(font.size * scale))))
    return font


def render_cell(
    scene: RasterScene,
    grid: RasterGrid,
    col: int,
    row: int,
    fonts: RasterFonts,
) -> Image.Image:
    """Render one high-contrast, indexed-color offline map cell."""
    if scene.zoom != grid.zoom or scene.tile_size != grid.tile_size:
        raise ValueError("Raster scene and grid use different zoom or tile size")
    size = grid.tile_size
    left = grid.origin_x + col * size
    top = grid.origin_y + row * size
    world_col = left // size
    world_row = top // size
    features = scene.cells.get((world_col, world_row), ())

    scale = 2
    canvas = Image.new("RGB", (size * scale, size * scale), RasterStyle.BACKGROUND)
    draw = ImageDraw.Draw(canvas)

    for feature in features:
        if feature.geom != classify.GEOM_POLYGON:
            continue
        points = _local_points(feature, left, top, scale)
        if len(points) >= 3:
            draw.polygon(points, fill=_feature_color(feature.layer))

    for feature in features:
        if feature.geom == classify.GEOM_POLYGON:
            continue
        points = _local_points(feature, left, top, scale)
        if len(points) < 2:
            continue
        width = _line_width(feature.layer) * scale
        if feature.layer == classify.L_MINOR:
            draw.line(points, fill=RasterStyle.RAIL, width=width + 2 * scale, joint="curve")
        draw.line(points, fill=_feature_color(feature.layer), width=width, joint="curve")

    placed = place_labels(_label_candidates(features, left, top, size), (size, size), fonts)
    for label in placed:
        base_font = fonts.bold if label.bold else fonts.regular
        font = _scaled_font(base_font, scale)
        position = (label.position[0] * scale, label.position[1] * scale)
        draw.text(
            position,
            label.text,
            font=font,
            fill=RasterStyle.LABEL,
            stroke_width=2 * scale,
            stroke_fill=RasterStyle.LABEL_HALO,
        )

    canvas = canvas.resize((size, size), Image.Resampling.LANCZOS)
    return canvas.quantize(
        palette=_palette_image(), dither=Image.Dither.NONE
    )
