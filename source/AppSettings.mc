import Toybox.Application;

//! Typed access to native Connect IQ app settings with safe defaults.
module AppSettings {
    function value(key, fallback) {
        var stored = Application.Properties.getValue(key);
        return stored == null ? fallback : stored;
    }

    function showTouchButtons() { return value("ShowTouchButtons", true); }
    function showStreetLabels() { return value("ShowStreetLabels", true); }
    function markerMode() { return value("MarkerMode", MarkerMode.ALL); }
    function detailTextColor() { return value("DetailTextColor", 0xFFFFFF); }
    function detailBackgroundColor() { return value("DetailBackgroundColor", 0x000000); }
    function autoLapDetails() { return value("AutoLapDetails", true); }
    function lapDetailDurationMs() {
        return value("LapDetailSeconds", 8) * 1000;
    }
}
