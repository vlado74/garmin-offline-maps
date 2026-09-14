import Toybox.Lang;
import Toybox.WatchUi;

//! Physical-key controls for the running map.
class RunDelegate extends WatchUi.InputDelegate {
    hidden var _view;
    hidden var _controller;
    hidden var _trail;

    function initialize(view, controller, trail) {
        InputDelegate.initialize();
        _view = view;
        _controller = controller;
        _trail = trail;
    }

    function onKey(event) {
        var key = event.getKey();
        if (key == WatchUi.KEY_ENTER) {
            _controller.toggle();
            WatchUi.requestUpdate();
            return true;
        }
        if (key == WatchUi.KEY_UP) {
            _view.setZoom(RasterPack.DETAIL);
            return true;
        }
        if (key == WatchUi.KEY_DOWN) {
            _view.setZoom(RasterPack.OVERVIEW);
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

    //! The 265S maps a long press of UP/MENU to this behavior.
    function onMenu() {
        _view.toggleDataBand();
        return true;
    }
}
