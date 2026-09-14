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
