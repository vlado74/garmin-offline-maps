import Toybox.Graphics;
import Toybox.WatchUi;

//! North-up raster map with GPS following and touch exploration.
class RunMapView extends WatchUi.View {
    const DATA_BAND_HEIGHT = 52;
    const DATA_ROW_Y = 52;

    hidden var _store;
    hidden var _trail;
    hidden var _controller;
    hidden var _width;
    hidden var _height;
    hidden var _centreLat;
    hidden var _centreLon;
    hidden var _gpsLat;
    hidden var _gpsLon;
    hidden var _zoom;
    hidden var _gpsReady;
    hidden var _showDataBand;
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
        _zoom = RasterPack.OVERVIEW;
        _gpsReady = false;
        _showDataBand = true;
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

    function setPosition(lat, lon) {
        _gpsLat = lat;
        _gpsLon = lon;
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
        _showDataBand = !_showDataBand;
        WatchUi.requestUpdate();
    }

    function release() { _store.clear(); }

    hidden function prepareMap() {
        _store.prepare(_centreLat, _centreLon, _zoom, _width, _height);
    }

    function onUpdate(dc) {
        _store.draw(dc);
        drawAttribution(dc);
        _trail.draw(dc, _centreLat, _centreLon, _zoom, _width, _height);
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
        dc.setColor(RunStyle.MARKER_OUTLINE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x.toNumber(), y.toNumber(), 8);
        dc.setColor(RunStyle.MARKER, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x.toNumber(), y.toNumber(), 5);
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
