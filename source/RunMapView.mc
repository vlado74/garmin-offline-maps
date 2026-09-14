import Toybox.Graphics;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

//! North-up raster map with GPS following and touch exploration.
class RunMapView extends WatchUi.View {
    const DATA_BAND_HEIGHT = 52;
    const DATA_ROW_Y = 52;
    const DATA_BAND_VISIBLE_MS = 8000;

    hidden var _store;
    hidden var _trail;
    hidden var _controller;
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
    hidden var _showDataBand;
    hidden var _dataBandHideAt;
    hidden var _followingGps;
    hidden var _hasGpsPosition;

    function initialize(store, trail, controller) {
        View.initialize();
        _store = store;
        _trail = trail;
        _controller = controller;
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
        _showDataBand = true;
        _dataBandHideAt = System.getTimer() + DATA_BAND_VISIBLE_MS;
        _followingGps = true;
        _hasGpsPosition = false;
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

    //! Give the map the full screen on demand while keeping recording active.
    function toggleDataBand() {
        if (_showDataBand) {
            _showDataBand = false;
        } else {
            showDataBandTemporarily();
        }
        WatchUi.requestUpdate();
    }

    //! Reveal metrics briefly after launch, START/STOP, or a manual request.
    function showDataBandTemporarily() {
        _showDataBand = true;
        _dataBandHideAt = System.getTimer() + DATA_BAND_VISIBLE_MS;
        WatchUi.requestUpdate();
    }

    function updateDataBandVisibility() {
        if (_showDataBand && System.getTimer() >= _dataBandHideAt) {
            _showDataBand = false;
        }
    }

    function release() { _store.clear(); }

    hidden function prepareMap() {
        _store.prepare(_centreLat, _centreLon, _zoom, _width, _height);
    }

    function onUpdate(dc) {
        _store.draw(dc);
        drawAttribution(dc);
        StreetLabelOverlay.draw(dc, _centreLat, _centreLon, _zoom, _width, _height);
        _trail.draw(dc, _centreLat, _centreLon, _zoom, _width, _height);
        drawHomeMarker(dc);
        if (_gpsReady) { drawMarker(dc); }
        drawStatus(dc);
        if (!_followingGps && _gpsReady) { drawRecenterHint(dc); }
        if (_showDataBand) { drawDataBand(dc); }
    }

    hidden function drawAttribution(dc) {
        dc.setColor(RunStyle.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            _width / 2,
            _height - 18,
            Graphics.FONT_XTINY,
            "(c) OSM",
            Graphics.TEXT_JUSTIFY_CENTER
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

    hidden function drawDataBand(dc) {
        dc.setColor(RunStyle.BAND, RunStyle.BAND);
        dc.fillRectangle(0, 26, _width, DATA_BAND_HEIGHT);
        dc.setColor(RunStyle.BAND_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(90, DATA_ROW_Y, Graphics.FONT_XTINY,
                    formatTimer(_controller.timerMs()),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(_width / 2, DATA_ROW_Y, Graphics.FONT_XTINY,
                    formatDistance(_controller.distanceMetres()),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(_width - 90, DATA_ROW_Y, Graphics.FONT_XTINY,
                    formatPace(_controller.averagePaceSeconds()),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
        dc.drawText(_width / 2, 80, Graphics.FONT_XTINY,
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

    hidden function formatPace(secondsPerKm) {
        if (secondsPerKm == null) { return "--:--"; }
        var seconds = secondsPerKm.toNumber();
        return (seconds / 60).format("%d") + ":"
            + (seconds % 60).format("%02d") + "/km";
    }
}
