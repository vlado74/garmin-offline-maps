import Toybox.Lang;
import Toybox.WatchUi;

//! Physical-key controls for the running map.
class RunDelegate extends WatchUi.InputDelegate {
    hidden var _view;
    hidden var _controller;
    hidden var _trail;
    hidden var _laps;
    hidden var _lastDragX;
    hidden var _lastDragY;

    function initialize(view, controller, trail, laps) {
        InputDelegate.initialize();
        _view = view;
        _controller = controller;
        _trail = trail;
        _laps = laps;
        _lastDragX = 0;
        _lastDragY = 0;
    }

    function onDrag(event) {
        var coordinates = event.getCoordinates();
        if (event.getType() == WatchUi.DRAG_TYPE_START) {
            _lastDragX = coordinates[0];
            _lastDragY = coordinates[1];
            return true;
        }

        var dx = coordinates[0] - _lastDragX;
        var dy = coordinates[1] - _lastDragY;
        _lastDragX = coordinates[0];
        _lastDragY = coordinates[1];
        _view.panBy(dx, dy);
        return true;
    }

    function onTap(event) {
        var coordinates = event.getCoordinates();
        if (_view.handleTap(coordinates[0], coordinates[1])) { return true; }
        _view.recenterGps();
        return true;
    }

    function onKey(event) {
        var key = event.getKey();
        if (key == WatchUi.KEY_ENTER) {
            var starting = _controller.state() == :ready;
            if (_controller.toggle() && starting) { _laps.clear(); }
            _view.showDataBandTemporarily();
            WatchUi.requestUpdate();
            return true;
        }
        if (key == WatchUi.KEY_UP) {
            _view.zoomIn();
            return true;
        }
        if (key == WatchUi.KEY_DOWN) {
            _view.zoomOut();
            return true;
        }
        if (key == WatchUi.KEY_MENU) {
            _view.toggleDataBand();
            return true;
        }
        if (key == WatchUi.KEY_ESC && _controller.hasSession()) {
            var prompt = WatchUi.loadResource(Rez.Strings.SaveActivity) as String;
            WatchUi.pushView(new WatchUi.Confirmation(prompt),
                new RunConfirmation(_controller, _trail),
                WatchUi.SLIDE_IMMEDIATE);
            return true;
        }
        return false;
    }

}
