import Toybox.Lang;
import Toybox.Math;

//! One visible raster cell and its screen placement.
class RasterCell {
    var col;
    var row;
    var x;
    var y;
    var resource;

    function initialize(c, r, sx, sy, rez) {
        col = c;
        row = r;
        x = sx;
        y = sy;
        resource = rez;
    }
}

//! Geographic facade over the generated raster resource index.
module RasterPack {
    const OVERVIEW = 13;
    const DETAIL = 15;
    const CLOSE = 16;
    const MAX_VISIBLE = 16;

    function resourceZoom(zoom) {
        return zoom == CLOSE ? DETAIL : zoom;
    }

    function scaleFor(zoom) {
        return zoom == CLOSE ? 2.0d : 1.0d;
    }

    function contains(lat, lon) {
        return lon >= RasterMapIndex.WEST && lon <= RasterMapIndex.EAST
            && lat >= RasterMapIndex.SOUTH && lat <= RasterMapIndex.NORTH;
    }

    function visibleCells(lat, lon, zoom, width, height) as Array<RasterCell> {
        var sourceZoom = resourceZoom(zoom);
        var scale = scaleFor(zoom);
        var cols = RasterMapIndex.cols(sourceZoom);
        var rows = RasterMapIndex.rows(sourceZoom);
        if (cols == null || rows == null) { return []; }

        var cx = Mercator.lonToWorldX(lon, sourceZoom);
        var cy = Mercator.latToWorldY(lat, sourceZoom);
        var left = cx - width / (2.0d * scale);
        var top = cy - height / (2.0d * scale);
        var right = left + width / scale;
        var bottom = top + height / scale;
        var originX = RasterMapIndex.originX(sourceZoom);
        var originY = RasterMapIndex.originY(sourceZoom);
        var size = RasterMapIndex.TILE_SIZE;

        var col0 = Math.floor((left - originX) / size).toNumber();
        var row0 = Math.floor((top - originY) / size).toNumber();
        var col1 = Math.ceil((right - originX) / size).toNumber() - 1;
        var row1 = Math.ceil((bottom - originY) / size).toNumber() - 1;
        if (col0 < 0) { col0 = 0; }
        if (row0 < 0) { row0 = 0; }
        if (col1 >= cols) { col1 = cols - 1; }
        if (row1 >= rows) { row1 = rows - 1; }

        var cells = [] as Array<RasterCell>;
        for (var row = row0; row <= row1 && cells.size() < MAX_VISIBLE; row += 1) {
            for (var col = col0; col <= col1 && cells.size() < MAX_VISIBLE; col += 1) {
                var resource = RasterMapIndex.resourceAt(sourceZoom, col, row);
                if (resource != null) {
                    cells.add(new RasterCell(
                        col,
                        row,
                        (originX + col * size - left) * scale,
                        (originY + row * size - top) * scale,
                        resource
                    ));
                }
            }
        }
        return cells;
    }
}
