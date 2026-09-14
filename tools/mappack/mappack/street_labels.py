"""Select compact named-road labels for the watch's close zoom overlay."""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Dict, Iterable, List, Tuple

from . import geom
from .osmread import Way
from .raster import RasterGrid


MAX_LABELS_PER_CELL = 4
ROAD_PRIORITY = {
    "motorway": 0,
    "trunk": 0,
    "primary": 1,
    "secondary": 2,
    "tertiary": 3,
    "unclassified": 4,
    "residential": 4,
    "living_street": 4,
    "service": 5,
}
PARTICLES = {"da", "dal", "dalla", "de", "dei", "del", "della", "delle", "di"}


@dataclass(frozen=True)
class StreetLabel:
    world_x: int
    world_y: int
    text: str
    priority: int
    length: float


def abbreviate_street_name(name: str) -> str:
    """Shorten a likely given name while retaining road type and surname."""
    words = name.split()
    if len(words) >= 3 and words[0].lower() in {
        "via", "viale", "piazza", "largo", "vicolo", "corso",
    } and words[1].lower() not in PARTICLES:
        words[1] = words[1][0] + "."
    replacements = {"Viale": "V.le", "Piazza": "P.za", "Vicolo": "V.lo"}
    if words:
        words[0] = replacements.get(words[0], words[0])
    return " ".join(words)


def _midpoint(points: List[Tuple[float, float]]) -> Tuple[float, float, float]:
    lengths = [math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(points, points[1:])]
    total = sum(lengths)
    target = total / 2.0
    travelled = 0.0
    for index, length in enumerate(lengths):
        if travelled + length >= target and length > 0:
            ratio = (target - travelled) / length
            a, b = points[index], points[index + 1]
            return a[0] + (b[0] - a[0]) * ratio, a[1] + (b[1] - a[1]) * ratio, total
        travelled += length
    return points[0][0], points[0][1], total


def street_label_cells(
    ways: Iterable[Way], grid: RasterGrid
) -> Dict[Tuple[int, int], Tuple[StreetLabel, ...]]:
    """Keep at most four useful, unique road names in each z15 raster cell."""
    candidates: Dict[Tuple[int, int], Dict[str, StreetLabel]] = {}
    for way in ways:
        highway = way.tags.get("highway")
        name = way.tags.get("name")
        if highway not in ROAD_PRIORITY or not name or len(way.coords) < 2:
            continue
        points = list(geom.project(way.coords, grid.zoom))
        world_x, world_y, length = _midpoint(points)
        col = math.floor((world_x - grid.origin_x) / grid.tile_size)
        row = math.floor((world_y - grid.origin_y) / grid.tile_size)
        if col < 0 or row < 0 or col >= grid.cols or row >= grid.rows:
            continue
        label = StreetLabel(
            int(round(world_x)), int(round(world_y)),
            abbreviate_street_name(name), ROAD_PRIORITY[highway], length,
        )
        cell = candidates.setdefault((col, row), {})
        previous = cell.get(name)
        if previous is None or label.length > previous.length:
            cell[name] = label

    result = {}
    for key, by_name in candidates.items():
        ranked = sorted(by_name.values(), key=lambda label: (label.priority, -label.length, label.text))
        result[key] = tuple(ranked[:MAX_LABELS_PER_CELL])
    return result
