import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

//! Holds only the bitmap references needed by the current viewport.
class RasterTileStore {
    hidden var _zoom;
    hidden var _cells as Array<RasterCell>;
    hidden var _bitmaps as Array<Object?>;
    hidden var _loadFailed;

    function initialize() {
        _zoom = null;
        _cells = [];
        _bitmaps = [];
        _loadFailed = false;
    }

    function prepare(lat, lon, zoom, width, height) {
        var requested = RasterPack.visibleCells(lat, lon, zoom, width, height);
        if (sameSelection(requested, zoom)) {
            for (var i = 0; i < requested.size(); i += 1) {
                _cells[i].x = requested[i].x;
                _cells[i].y = requested[i].y;
            }
            if (_loadFailed) { loadMissing(); }
            return;
        }

        _loadFailed = false;
        var nextCells = [] as Array<RasterCell>;
        var nextBitmaps = [] as Array<Object?>;
        for (var i = 0; i < requested.size(); i += 1) {
            var cell = requested[i];
            var oldIndex = indexOf(cell, zoom);
            var bitmap = oldIndex >= 0 ? _bitmaps[oldIndex] : null;
            if (oldIndex >= 0) { _bitmaps[oldIndex] = null; }
            nextCells.add(cell);
            nextBitmaps.add(bitmap);
        }

        // Publish the new selection before loading. This drops every outgoing
        // bitmap reference first, so a zoom switch cannot retain one full
        // viewport while allocating the next one.
        _zoom = zoom;
        _cells = nextCells;
        _bitmaps = nextBitmaps;
        loadMissing();
    }

    function draw(dc) {
        dc.setColor(RunStyle.MAP_BACKGROUND, RunStyle.MAP_BACKGROUND);
        dc.clear();
        for (var i = 0; i < _cells.size(); i += 1) {
            if (_bitmaps[i] != null) {
                dc.drawBitmap(
                    Math.floor(_cells[i].x).toNumber(),
                    Math.floor(_cells[i].y).toNumber(),
                    _bitmaps[i]
                );
            }
        }
    }

    function hadLoadFailure() { return _loadFailed; }

    function clear() {
        _zoom = null;
        _cells = [];
        _bitmaps = [];
        _loadFailed = false;
    }

    hidden function sameSelection(requested as Array<RasterCell>, zoom) {
        if (_zoom != zoom || requested.size() != _cells.size()) { return false; }
        for (var i = 0; i < requested.size(); i += 1) {
            if (requested[i].col != _cells[i].col || requested[i].row != _cells[i].row) {
                return false;
            }
        }
        return true;
    }

    hidden function indexOf(cell as RasterCell, zoom) {
        if (_zoom != zoom) { return -1; }
        for (var i = 0; i < _cells.size(); i += 1) {
            if (_cells[i].col == cell.col && _cells[i].row == cell.row) { return i; }
        }
        return -1;
    }

    hidden function loadMissing() {
        _loadFailed = false;
        for (var i = 0; i < _cells.size(); i += 1) {
            if (_bitmaps[i] != null) { continue; }
            try {
                _bitmaps[i] = Application.loadResource(_cells[i].resource);
            } catch (ex) {
                System.println("RasterTileStore: bitmap load failed");
                _bitmaps[i] = null;
            }
            if (_bitmaps[i] == null) { _loadFailed = true; }
        }
    }
}
