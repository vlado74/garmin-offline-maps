import Toybox.Graphics;
import Toybox.WatchUi;

//! North-up, GPS-centred raster map base view.
class RunMapView extends WatchUi.View {
    const DATA_BAND_HEIGHT = 52;

    hidden var _store;
    hidden var _trail;
    hidden var _controller;
    hidden var _width;
    hidden var _height;
    hidden var _lat;
    hidden var _lon;
    hidden var _zoom;
    hidden var _gpsReady;

    function initialize(store, trail, controller) {
        View.initialize();
        _store = store;
        _trail = trail;
        _controller = controller;
        _width = 360;
        _height = 360;
        _lat = RasterMapIndex.CENTER_LAT;
        _lon = RasterMapIndex.CENTER_LON;
        _zoom = RasterPack.OVERVIEW;
        _gpsReady = false;
    }

    function onLayout(dc) {
        _width = dc.getWidth();
        _height = dc.getHeight();
        _store.prepare(_lat, _lon, _zoom, _width, _height);
    }

    function onHide() {
        _store.clear();
    }

    function onShow() {
        _store.prepare(_lat, _lon, _zoom, _width, _height);
        WatchUi.requestUpdate();
    }

    function setPosition(lat, lon) {
        _lat = lat;
        _lon = lon;
        _store.prepare(_lat, _lon, _zoom, _width, _height);
        WatchUi.requestUpdate();
    }

    function setGpsReady(ready) {
        _gpsReady = ready;
        WatchUi.requestUpdate();
    }

    function setZoom(zoom) {
        if (zoom != RasterPack.OVERVIEW && zoom != RasterPack.DETAIL) { return; }
        if (_zoom == zoom) { return; }
        _zoom = zoom;
        _store.prepare(_lat, _lon, _zoom, _width, _height);
        WatchUi.requestUpdate();
    }

    function zoom() { return _zoom; }

    function release() { _store.clear(); }

    function onUpdate(dc) {
        _store.draw(dc);
        drawAttribution(dc);
        _trail.draw(dc, _lat, _lon, _zoom, _width, _height);
        if (_gpsReady) { drawMarker(dc); }
        drawStatus(dc);
        drawDataBand(dc);
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
        var x = _width / 2;
        var y = _height / 2;
        dc.setColor(RunStyle.MARKER_OUTLINE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 8);
        dc.setColor(RunStyle.MARKER, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 5);
    }

    hidden function drawDataBand(dc) {
        dc.setColor(RunStyle.BAND, RunStyle.BAND);
        dc.fillRectangle(0, 0, _width, DATA_BAND_HEIGHT);
        dc.setColor(RunStyle.BAND_TEXT, Graphics.COLOR_TRANSPARENT);
        var y = 26;
        dc.drawText(84, y, Graphics.FONT_XTINY, formatTimer(_controller.timerMs()),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(_width / 2, y, Graphics.FONT_XTINY,
                    formatDistance(_controller.distanceMetres()),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(_width - 84, y, Graphics.FONT_XTINY,
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
        } else if (!RasterPack.contains(_lat, _lon)) {
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
        dc.drawText(_width / 2, DATA_BAND_HEIGHT + 3, Graphics.FONT_XTINY,
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
        return (metres / 1000.0d).format("%.2f") + "k";
    }

    hidden function formatPace(secondsPerKm) {
        if (secondsPerKm == null) { return "--:--"; }
        var seconds = secondsPerKm.toNumber();
        return (seconds / 60).format("%d") + ":" + (seconds % 60).format("%02d");
    }
}
