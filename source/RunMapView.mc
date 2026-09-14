import Toybox.Graphics;
import Toybox.WatchUi;

//! North-up, GPS-centred raster map base view.
class RunMapView extends WatchUi.View {
    hidden var _store;
    hidden var _width;
    hidden var _height;
    hidden var _lat;
    hidden var _lon;
    hidden var _zoom;

    function initialize(store) {
        View.initialize();
        _store = store;
        _width = 360;
        _height = 360;
        _lat = RasterMapIndex.CENTER_LAT;
        _lon = RasterMapIndex.CENTER_LON;
        _zoom = RasterPack.OVERVIEW;
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

    function setZoom(zoom) {
        if (zoom != RasterPack.OVERVIEW && zoom != RasterPack.DETAIL) { return; }
        if (_zoom == zoom) { return; }
        _zoom = zoom;
        _store.prepare(_lat, _lon, _zoom, _width, _height);
        WatchUi.requestUpdate();
    }

    function zoom() { return _zoom; }

    function onUpdate(dc) {
        _store.draw(dc);
        drawAttribution(dc);
        drawMarker(dc);
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
}
