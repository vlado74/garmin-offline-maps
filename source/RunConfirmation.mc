import Toybox.Lang;
import Toybox.WatchUi;

//! Handles save/discard and keeps failed FIT sessions available for retry.
class RunConfirmation extends WatchUi.ConfirmationDelegate {
    hidden var _controller;
    hidden var _trail;

    function initialize(controller, trail) {
        ConfirmationDelegate.initialize();
        _controller = controller;
        _trail = trail;
    }

    function onResponse(value as Confirm) as Boolean {
        var succeeded;
        if (value == WatchUi.CONFIRM_YES) {
            succeeded = _controller.save();
        } else {
            // Both dialogs make this a deliberate physical-key choice.
            succeeded = _controller.discard();
        }
        if (succeeded) {
            _trail.clear();
            WatchUi.requestUpdate();
            return true;
        }

        var prompt = WatchUi.loadResource(Rez.Strings.RetrySave) as String;
        WatchUi.pushView(new WatchUi.Confirmation(prompt),
            new RunConfirmation(_controller, _trail),
            WatchUi.SLIDE_IMMEDIATE);
        WatchUi.requestUpdate();
        return true;
    }
}
