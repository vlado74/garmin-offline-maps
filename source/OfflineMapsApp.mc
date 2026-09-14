import Toybox.Application;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

//! Offline EUR running map for Forerunner 265S.
class OfflineMapsApp extends Application.AppBase {
    const REFRESH_MS = 1000;

    hidden var _store;
    hidden var _tracker;
    hidden var _trail;
    hidden var _controller;
    hidden var _view;
    hidden var _timer;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        _store = new RasterTileStore();
        _trail = new RunTrail();
        _controller = new RunController();
        _tracker = new LocationTracker(method(:onFix));
    }

    function getInitialView() {
        _view = new RunMapView(_store, _trail, _controller);
        _tracker.start();
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), REFRESH_MS, true);
        return [_view, new RunDelegate(_view, _controller, _trail)];
    }

    function onTick() as Void {
        if (_view != null) {
            _view.updateDataBandVisibility();
            WatchUi.requestUpdate();
        }
    }

    function onFix() {
        if (_tracker == null || _controller == null) { return; }
        var usable = _tracker.hasUsableFix();
        _controller.setGpsReady(usable);
        if (_view != null) { _view.setGpsReady(usable); }
        if (!usable || _view == null) { return; }

        var lat = _tracker.lat();
        var lon = _tracker.lon();
        _view.setPosition(lat, lon, _tracker.heading(), _tracker.hasHeading());
        if (_controller.state() == :recording) {
            _trail.add(lat, lon);
        }
        WatchUi.requestUpdate();
    }

    function onStop(state) {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
        if (_tracker != null) { _tracker.stop(); }
        if (_controller != null) { _controller.shutdown(); }
        if (_view != null) { _view.release(); }
        if (_store != null) { _store.clear(); }
    }
}
