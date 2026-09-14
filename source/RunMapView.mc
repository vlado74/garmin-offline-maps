import Toybox.Graphics;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

//! North-up raster map with GPS following and touch exploration.
class RunMapView extends WatchUi.View {
    const LABEL_BUTTON_OFFSET = 68;
    const LABEL_BUTTON_RADIUS = 22;
    const LABEL_BUTTON_HIT_RADIUS = 28;
    const MARKER_BUTTON_X = 68;
    const MARKER_BUTTON_Y = 68;

    hidden var _store;
    hidden var _trail;
    hidden var _controller;
    hidden var _laps;
    hidden var _width;
    hidden var _height;
    hidden var _centreLat;
    hidden var _centreLon;
    hidden var _gpsLat;
    hidden var _gpsLon;
    hidden var _gpsHeading;
    hidden var _hasGpsHeading;
    hidden var _zoom;
    hidden var _gpsReady;
    hidden var _followingGps;
    hidden var _hasGpsPosition;
    hidden var _showStreetLabels;
    hidden var _showLapDetails;
    hidden var _lapDetailsHideAt;
    hidden var _markerMode;
    hidden var _showTouchButtons;
    hidden var _detailTextColor;
    hidden var _detailBackgroundColor;
    hidden var _autoLapDetails;
    hidden var _lapDetailDurationMs;

    function initialize(store, trail, controller, laps) {
        View.initialize();
        _store = store;
        _trail = trail;
        _controller = controller;
        _laps = laps;
        _width = 360;
        _height = 360;
        _centreLat = RasterMapIndex.CENTER_LAT;
        _centreLon = RasterMapIndex.CENTER_LON;
        _gpsLat = RasterMapIndex.CENTER_LAT;
        _gpsLon = RasterMapIndex.CENTER_LON;
        _gpsHeading = 0.0d;
        _hasGpsHeading = false;
        _zoom = RasterPack.OVERVIEW;
        _gpsReady = false;
        _followingGps = true;
        _hasGpsPosition = false;
        _showStreetLabels = true;
        _showLapDetails = false;
        _lapDetailsHideAt = null;
        reloadSettings();
    }

    function reloadSettings() {
        _showTouchButtons = AppSettings.showTouchButtons();
        _showStreetLabels = AppSettings.showStreetLabels();
        _markerMode = AppSettings.markerMode();
        _detailTextColor = AppSettings.detailTextColor();
        _detailBackgroundColor = AppSettings.detailBackgroundColor();
        _autoLapDetails = AppSettings.autoLapDetails();
        _lapDetailDurationMs = AppSettings.lapDetailDurationMs();
        WatchUi.requestUpdate();
    }

    function onLayout(dc) {
        _width = dc.getWidth();
        _height = dc.getHeight();
        prepareMap();
    }

    function onHide() {
        _store.clear();
    }

    function onShow() {
        prepareMap();
        WatchUi.requestUpdate();
    }

    function setPosition(lat, lon, heading, hasHeading) {
        _gpsLat = lat;
        _gpsLon = lon;
        _gpsHeading = heading;
        _hasGpsHeading = hasHeading;
        if (_followingGps || !_hasGpsPosition) {
            _centreLat = lat;
            _centreLon = lon;
        }
        _hasGpsPosition = true;
        prepareMap();
        WatchUi.requestUpdate();
    }

    function setGpsReady(ready) {
        _gpsReady = ready;
        WatchUi.requestUpdate();
    }

    function setZoom(zoom) {
        if (zoom != RasterPack.OVERVIEW && zoom != RasterPack.DETAIL
                && zoom != RasterPack.CLOSE) { return; }
        if (_zoom == zoom) { return; }
        _zoom = zoom;
        prepareMap();
        WatchUi.requestUpdate();
    }

    function zoom() { return _zoom; }

    //! Move the map with the finger; geographic content follows the gesture.
    function panBy(dx, dy) {
        if (dx == 0 && dy == 0) { return; }
        var worldX = Mercator.lonToWorldX(_centreLon, _zoom) - dx;
        var worldY = Mercator.latToWorldY(_centreLat, _zoom) - dy;
        _centreLon = Mercator.worldXToLon(worldX, _zoom);
        _centreLat = Mercator.worldYToLat(worldY, _zoom);
        if (_centreLon < RasterMapIndex.WEST) { _centreLon = RasterMapIndex.WEST; }
        if (_centreLon > RasterMapIndex.EAST) { _centreLon = RasterMapIndex.EAST; }
        if (_centreLat < RasterMapIndex.SOUTH) { _centreLat = RasterMapIndex.SOUTH; }
        if (_centreLat > RasterMapIndex.NORTH) { _centreLat = RasterMapIndex.NORTH; }
        _followingGps = false;
        prepareMap();
        WatchUi.requestUpdate();
    }

    //! A tap returns to live GPS following after manual exploration.
    function recenterGps() {
        if (!_gpsReady || !_hasGpsPosition) { return false; }
        _followingGps = true;
        _centreLat = _gpsLat;
        _centreLon = _gpsLon;
        prepareMap();
        WatchUi.requestUpdate();
        return true;
    }

    function zoomIn() {
        if (_zoom == RasterPack.OVERVIEW) {
            setZoom(RasterPack.DETAIL);
        } else if (_zoom == RasterPack.DETAIL) {
            setZoom(RasterPack.CLOSE);
        }
    }

    function zoomOut() {
        if (_zoom == RasterPack.CLOSE) {
            setZoom(RasterPack.DETAIL);
        } else if (_zoom == RasterPack.DETAIL) {
            setZoom(RasterPack.OVERVIEW);
        }
    }

    function toggleLapDetails() {
        _showLapDetails = !_showLapDetails;
        _lapDetailsHideAt = null;
        WatchUi.requestUpdate();
    }

    function updateOverlayVisibility() {
        if (_showLapDetails && _lapDetailsHideAt != null
            && System.getTimer() >= _lapDetailsHideAt) {
            _showLapDetails = false;
            _lapDetailsHideAt = null;
        }
    }

    function showCompletedLap() {
        if (!_autoLapDetails) { return; }
        _showLapDetails = true;
        _lapDetailsHideAt = System.getTimer() + _lapDetailDurationMs;
        WatchUi.requestUpdate();
    }

    //! Consume taps on the label control; all other taps keep
    //! their existing GPS-recentre behavior in RunDelegate.
    function handleTap(x, y) {
        if (!_showTouchButtons) { return false; }
        var lapButtonX = LABEL_BUTTON_OFFSET;
        var buttonY = _height - LABEL_BUTTON_OFFSET;
        var lapDx = x - lapButtonX;
        var lapDy = y - buttonY;
        if (lapDx >= -LABEL_BUTTON_HIT_RADIUS && lapDx <= LABEL_BUTTON_HIT_RADIUS
            && lapDy >= -LABEL_BUTTON_HIT_RADIUS && lapDy <= LABEL_BUTTON_HIT_RADIUS) {
            toggleLapDetails();
            return true;
        }
        var markerDx = x - MARKER_BUTTON_X;
        var markerDy = y - MARKER_BUTTON_Y;
        if (markerDx >= -LABEL_BUTTON_HIT_RADIUS && markerDx <= LABEL_BUTTON_HIT_RADIUS
            && markerDy >= -LABEL_BUTTON_HIT_RADIUS && markerDy <= LABEL_BUTTON_HIT_RADIUS) {
            _markerMode = (_markerMode + 1) % 3;
            WatchUi.requestUpdate();
            return true;
        }
        var buttonX = _width - LABEL_BUTTON_OFFSET;
        var dx = x - buttonX;
        var dy = y - buttonY;
        if (dx < -LABEL_BUTTON_HIT_RADIUS || dx > LABEL_BUTTON_HIT_RADIUS
            || dy < -LABEL_BUTTON_HIT_RADIUS || dy > LABEL_BUTTON_HIT_RADIUS) {
            return false;
        }
        _showStreetLabels = !_showStreetLabels;
        WatchUi.requestUpdate();
        return true;
    }

    function release() { _store.clear(); }

    hidden function prepareMap() {
        _store.prepare(_centreLat, _centreLon, _zoom, _width, _height);
    }

    function onUpdate(dc) {
        _store.draw(dc);
        drawAttribution(dc);
        if (_showStreetLabels) {
            StreetLabelOverlay.draw(dc, _centreLat, _centreLon, _zoom, _width, _height);
        }
        _trail.draw(dc, _centreLat, _centreLon, _zoom, _width, _height,
                    _markerMode);
        drawLapMarker(dc);
        drawHomeMarker(dc);
        if (_gpsReady) { drawMarker(dc); }
        drawNorthIndicator(dc);
        drawScaleBar(dc);
        if (!_followingGps && _gpsReady) { drawRecenterHint(dc); }
        drawStatus(dc);
        if (_showLapDetails) { drawLapDetails(dc); }
        if (_showTouchButtons) {
            drawLapButton(dc);
            drawMarkerModeButton(dc);
            drawStreetLabelButton(dc);
        }
    }

    hidden function drawMarkerModeButton(dc) {
        var x = MARKER_BUTTON_X;
        var y = MARKER_BUTTON_Y;
        dc.setColor(RunStyle.MARKER_OUTLINE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, LABEL_BUTTON_RADIUS);
        dc.setColor(_markerMode == MarkerMode.HIDDEN
                    ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_WHITE,
                    Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, LABEL_BUTTON_RADIUS - 3);
        dc.setColor(_markerMode == MarkerMode.HIDDEN
                    ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK,
                    Graphics.COLOR_TRANSPARENT);
        var text = _markerMode == MarkerMode.ALL ? ".5"
                   : (_markerMode == MarkerMode.KM_ONLY ? "KM" : "--");
        dc.drawText(x, y, Graphics.FONT_XTINY, text,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawNorthIndicator(dc) {
        var x = _width / 2;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x, 12], [x - 6, 25], [x + 6, 25]]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x, 15], [x - 3, 23], [x + 3, 23]]);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, 0, Graphics.FONT_XTINY, "N", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawScaleBar(dc) {
        var metres = _zoom == RasterPack.OVERVIEW ? 1000
                     : (_zoom == RasterPack.DETAIL ? 200 : 100);
        var pixels = (metres / Mercator.metresPerPixel(_centreLat, _zoom)).toNumber();
        var left = (_width - pixels) / 2;
        var right = left + pixels;
        var y = _height - 24;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawLine(left, y, right, y);
        dc.drawLine(left, y - 5, left, y + 5);
        dc.drawLine(right, y - 5, right, y + 5);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(left, y, right, y);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_width / 2, y - 22, Graphics.FONT_XTINY,
                    metres >= 1000 ? "1 km" : metres.format("%d") + " m",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawLapButton(dc) {
        var x = LABEL_BUTTON_OFFSET;
        var y = _height - LABEL_BUTTON_OFFSET;
        dc.setColor(RunStyle.MARKER_OUTLINE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, LABEL_BUTTON_RADIUS);
        dc.setColor(_showLapDetails ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY,
                    Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, LABEL_BUTTON_RADIUS - 3);
        dc.setColor(_showLapDetails ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE,
                    Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY,
                    WatchUi.loadResource(Rez.Strings.LapButton),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawLapDetails(dc) {
        var panelX = 30;
        var panelY = 44;
        var panelWidth = _width - 60;
        dc.setColor(_detailBackgroundColor, _detailBackgroundColor);
        dc.fillRectangle(panelX, panelY, panelWidth, 230);
        dc.setColor(_detailTextColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_width / 2, panelY + 18, Graphics.FONT_XTINY,
                    WatchUi.loadResource(Rez.Strings.TotalTime) + "  "
                    + formatTimer(_controller.timerMs()), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_width / 2, panelY + 50, Graphics.FONT_XTINY,
                    WatchUi.loadResource(Rez.Strings.TotalDistance) + "  "
                    + formatDistance(_controller.distanceMetres()), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_width / 2, panelY + 82, Graphics.FONT_XTINY,
                    WatchUi.loadResource(Rez.Strings.AveragePace) + "  "
                    + formatPace(_controller.averagePaceSeconds()), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawLine(panelX + 24, panelY + 116, panelX + panelWidth - 24, panelY + 116);
        dc.drawText(_width / 2, panelY + 128, Graphics.FONT_XTINY,
                    WatchUi.loadResource(Rez.Strings.Laps) + "  "
                    + _laps.count().format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_width / 2, panelY + 160, Graphics.FONT_XTINY,
                    WatchUi.loadResource(Rez.Strings.LastLap) + "  "
                    + formatLapTime(_laps.lastTimeMs()), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(_width / 2, panelY + 192, Graphics.FONT_XTINY,
                    WatchUi.loadResource(Rez.Strings.LapDistance) + "  "
                    + formatDistance(_laps.lastDistanceMetres()) + "   "
                    + formatPace(_laps.lastPaceSeconds()), Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawLapMarker(dc) {
        if (!_laps.hasStart() || _laps.count() <= 0) { return; }
        var x = _width / 2.0d + Mercator.lonToWorldX(_laps.startLon(), _zoom)
                - Mercator.lonToWorldX(_centreLon, _zoom);
        var y = _height / 2.0d + Mercator.latToWorldY(_laps.startLat(), _zoom)
                - Mercator.latToWorldY(_centreLat, _zoom);
        if (x < -14 || x > _width + 14 || y < -14 || y > _height + 14) { return; }
        var px = x.toNumber();
        var py = y.toNumber();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px, py, 13);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px, py, 10);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(px, py, Graphics.FONT_XTINY, _laps.count().format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawStreetLabelButton(dc) {
        var x = _width - LABEL_BUTTON_OFFSET;
        var y = _height - LABEL_BUTTON_OFFSET;
        dc.setColor(RunStyle.MARKER_OUTLINE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, LABEL_BUTTON_RADIUS);
        dc.setColor(_showStreetLabels ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY,
                    Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, LABEL_BUTTON_RADIUS - 3);
        dc.setColor(_showStreetLabels ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE,
                    Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, "Aa",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (!_showStreetLabels) {
            dc.setColor(RunStyle.ERROR, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(3);
            dc.drawLine(x - 11, y + 10, x + 11, y - 10);
        }
    }

    hidden function drawAttribution(dc) {
        dc.setColor(RunStyle.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            8,
            _height / 2,
            Graphics.FONT_XTINY,
            "(c) OSM",
            Graphics.TEXT_JUSTIFY_LEFT
        );
    }

    hidden function drawMarker(dc) {
        var x = _width / 2.0d + Mercator.lonToWorldX(_gpsLon, _zoom)
                - Mercator.lonToWorldX(_centreLon, _zoom);
        var y = _height / 2.0d + Mercator.latToWorldY(_gpsLat, _zoom)
                - Mercator.latToWorldY(_centreLat, _zoom);
        if (x < -8 || x > _width + 8 || y < -8 || y > _height + 8) { return; }
        var px = x.toNumber();
        var py = y.toNumber();
        if (!_hasGpsHeading) {
            dc.setColor(RunStyle.MARKER_OUTLINE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, 8);
            dc.setColor(RunStyle.MARKER, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, 5);
            return;
        }

        var forwardX = Math.sin(_gpsHeading);
        var forwardY = -Math.cos(_gpsHeading);
        var sideX = -forwardY;
        var sideY = forwardX;
        dc.setColor(RunStyle.MARKER_OUTLINE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(markerTriangle(px, py, forwardX, forwardY, sideX, sideY, 13, 7, 9));
        dc.setColor(RunStyle.MARKER, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(markerTriangle(px, py, forwardX, forwardY, sideX, sideY, 10, 4, 6));
    }

    hidden function markerTriangle(px, py, forwardX, forwardY, sideX, sideY,
                                   nose, back, halfWidth) {
        return [
            [(px + forwardX * nose).toNumber(), (py + forwardY * nose).toNumber()],
            [(px - forwardX * back + sideX * halfWidth).toNumber(),
             (py - forwardY * back + sideY * halfWidth).toNumber()],
            [(px - forwardX * back - sideX * halfWidth).toNumber(),
             (py - forwardY * back - sideY * halfWidth).toNumber()]
        ];
    }

    //! Fixed home landmark; private coordinates never enter version control.
    hidden function drawHomeMarker(dc) {
        var x = _width / 2.0d + Mercator.lonToWorldX(RasterMapIndex.HOME_LON, _zoom)
                - Mercator.lonToWorldX(_centreLon, _zoom);
        var y = _height / 2.0d + Mercator.latToWorldY(RasterMapIndex.HOME_LAT, _zoom)
                - Mercator.latToWorldY(_centreLat, _zoom);
        if (x < -12 || x > _width + 12 || y < -12 || y > _height + 12) { return; }
        var px = x.toNumber();
        var py = y.toNumber();

        dc.setColor(RunStyle.MARKER_OUTLINE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawLine(px - 9, py, px, py - 9);
        dc.drawLine(px, py - 9, px + 9, py);
        dc.fillRectangle(px - 8, py - 1, 17, 11);

        dc.setColor(RunStyle.HOME, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(px - 7, py, px, py - 7);
        dc.drawLine(px, py - 7, px + 7, py);
        dc.fillRectangle(px - 6, py, 13, 8);
        dc.setColor(RunStyle.MARKER_OUTLINE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 2, py + 3, 4, 5);
    }

    hidden function drawRecenterHint(dc) {
        dc.setColor(RunStyle.MARKER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_width / 2, _height - 42, Graphics.FONT_XTINY,
                    WatchUi.loadResource(Rez.Strings.TapToRecenter),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function drawStatus(dc) {
        var text;
        var colour;
        if (_controller.state() == :saveFailed) {
            text = WatchUi.loadResource(Rez.Strings.SaveFailed);
            colour = RunStyle.ERROR;
        } else if (!_gpsReady) {
            text = WatchUi.loadResource(Rez.Strings.WaitingForGps);
            colour = RunStyle.ERROR;
        } else if (!RasterPack.contains(_gpsLat, _gpsLon)) {
            text = WatchUi.loadResource(Rez.Strings.OutsideMap);
            colour = RunStyle.ERROR;
        } else if (_store.hadLoadFailure()) {
            text = WatchUi.loadResource(Rez.Strings.MapFailed);
            colour = RunStyle.ERROR;
        } else if (_controller.state() == :recording) {
            text = WatchUi.loadResource(Rez.Strings.Pause);
            colour = RunStyle.RECORDING;
        } else if (_controller.state() == :paused) {
            text = WatchUi.loadResource(Rez.Strings.Resume);
            colour = RunStyle.PAUSED;
        } else {
            text = WatchUi.loadResource(Rez.Strings.Start);
            colour = RunStyle.READY;
        }
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_width / 2, 86, Graphics.FONT_XTINY,
                    text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function formatTimer(milliseconds) {
        var seconds = (milliseconds / 1000).toNumber();
        var hours = seconds / 3600;
        var minutes = (seconds % 3600) / 60;
        var remainder = seconds % 60;
        return hours.format("%d") + ":" + minutes.format("%02d")
            + ":" + remainder.format("%02d");
    }

    hidden function formatDistance(metres) {
        return (metres / 1000.0d).format("%.2f") + " km";
    }

    hidden function formatLapTime(milliseconds) {
        if (milliseconds <= 0) { return "--:--"; }
        var seconds = (milliseconds / 1000).toNumber();
        return (seconds / 60).format("%d") + ":" + (seconds % 60).format("%02d");
    }

    hidden function formatPace(secondsPerKm) {
        if (secondsPerKm == null) { return "--:--"; }
        var seconds = secondsPerKm.toNumber();
        return (seconds / 60).format("%d") + ":"
            + (seconds % 60).format("%02d") + "/km";
    }
}
