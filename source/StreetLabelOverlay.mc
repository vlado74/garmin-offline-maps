import Toybox.Graphics;
import Toybox.Lang;

//! Sparse named-road labels drawn independently over every raster scale.
module StreetLabelOverlay {
    const MAX_DRAWN = 12;
    const LABEL_HEIGHT = 18;
    const PADDING_X = 4;

    function draw(dc, centreLat, centreLon, zoom, width, height) {
        var cells = RasterPack.visibleCells(centreLat, centreLon, zoom, width, height);
        var sourceZoom = RasterPack.resourceZoom(zoom);
        var scale = RasterPack.scaleFor(zoom);
        var occupied = [] as Array<Array<Number>>;
        var drawn = 0;
        for (var cellIndex = 0; cellIndex < cells.size() && drawn < MAX_DRAWN;
             cellIndex += 1) {
            var cell = cells[cellIndex];
            var rawLabels = StreetLabelIndex.labelsAt(sourceZoom, cell.col, cell.row);
            if (rawLabels == null) { continue; }
            var labels = rawLabels as Array<Array<Object>>;
            for (var labelIndex = 0; labelIndex < labels.size() && drawn < MAX_DRAWN;
                 labelIndex += 1) {
                var label = labels[labelIndex] as Array<Object>;
                var cellWorldX = RasterMapIndex.originX(sourceZoom)
                    + cell.col * RasterMapIndex.TILE_SIZE;
                var cellWorldY = RasterMapIndex.originY(sourceZoom)
                    + cell.row * RasterMapIndex.TILE_SIZE;
                var x = (cell.x + (label[0] - cellWorldX) * scale).toNumber();
                var y = (cell.y + (label[1] - cellWorldY) * scale).toNumber();
                var text = label[2] as String;
                var labelWidth = dc.getTextWidthInPixels(text, Graphics.FONT_XTINY)
                    + PADDING_X * 2;
                var left = x - labelWidth / 2;
                var top = y - LABEL_HEIGHT / 2;
                var right = left + labelWidth;
                var bottom = top + LABEL_HEIGHT;
                if (left < 3 || right > width - 3 || top < 3 || bottom > height - 3
                    || overlaps(occupied, left, top, right, bottom)) { continue; }

                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
                dc.fillRectangle(left, top, labelWidth, LABEL_HEIGHT);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x, y, Graphics.FONT_XTINY, text,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                occupied.add([left, top, right, bottom]);
                drawn += 1;
            }
        }
    }

    function overlaps(occupied as Array<Array<Number>>, left, top, right, bottom) {
        for (var index = 0; index < occupied.size(); index += 1) {
            var box = occupied[index] as Array<Number>;
            if (left < box[2] && right > box[0] && top < box[3] && bottom > box[1]) {
                return true;
            }
        }
        return false;
    }
}
