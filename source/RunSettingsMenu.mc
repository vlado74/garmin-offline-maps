import Toybox.WatchUi;

//! Native on-watch mirror of the phone/Express app settings.
class RunSettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>WatchUi.loadResource(Rez.Strings.SettingsTitle)});
        var states = {
            :enabled=>WatchUi.loadResource(Rez.Strings.Enabled),
            :disabled=>WatchUi.loadResource(Rez.Strings.Disabled)
        };
        addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.SettingLapButton), states,
            :lapButton, AppSettings.showLapButton(), null));
        addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.SettingMarkerButton), states,
            :markerButton, AppSettings.showMarkerButton(), null));
        addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.SettingLabelButton), states,
            :labelButton, AppSettings.showLabelButton(), null));
        addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.SettingStreetLabels), states,
            :labels, AppSettings.showStreetLabels(), null));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingMarkers),
            markerLabel(AppSettings.markerMode()), :markers, null));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingTextColor),
            textColorLabel(AppSettings.detailTextColor()), :textColor, null));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingBackgroundColor),
            backgroundLabel(AppSettings.detailBackgroundColor()), :background, null));
        addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.SettingAutoLapDetails), states,
            :autoLap, AppSettings.autoLapDetails(), null));
        addItem(new WatchUi.MenuItem(
            WatchUi.loadResource(Rez.Strings.SettingDetailDuration),
            durationLabel(AppSettings.lapDetailDurationMs() / 1000), :duration, null));
    }

    function markerLabel(mode) {
        if (mode == MarkerMode.KM_ONLY) { return WatchUi.loadResource(Rez.Strings.MarkersKm); }
        if (mode == MarkerMode.HIDDEN) { return WatchUi.loadResource(Rez.Strings.MarkersHidden); }
        return WatchUi.loadResource(Rez.Strings.MarkersAll);
    }

    function textColorLabel(color) {
        if (color == 0xFFFF00) { return WatchUi.loadResource(Rez.Strings.ColorYellow); }
        if (color == 0x00D7FF) { return WatchUi.loadResource(Rez.Strings.ColorCyan); }
        if (color == 0x000000) { return WatchUi.loadResource(Rez.Strings.ColorBlack); }
        return WatchUi.loadResource(Rez.Strings.ColorWhite);
    }

    function backgroundLabel(color) {
        if (color == 0x001F4D) { return WatchUi.loadResource(Rez.Strings.ColorDarkBlue); }
        if (color == 0x555555) { return WatchUi.loadResource(Rez.Strings.ColorDarkGray); }
        return WatchUi.loadResource(Rez.Strings.ColorBlack);
    }

    function durationLabel(seconds) { return seconds.format("%d") + " s"; }
}

class RunSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _view;

    function initialize(view) {
        Menu2InputDelegate.initialize();
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :lapButton) {
            AppSettings.setValue("ShowLapButton", (item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :markerButton) {
            AppSettings.setValue("ShowMarkerButton", (item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :labelButton) {
            AppSettings.setValue("ShowLabelButton", (item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :labels) {
            AppSettings.setValue("ShowStreetLabels", (item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :autoLap) {
            AppSettings.setValue("AutoLapDetails", (item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :markers) {
            var markerMode = (AppSettings.markerMode() + 1) % 3;
            AppSettings.setValue("MarkerMode", markerMode);
            item.setSubLabel(markerLabel(markerMode));
        } else if (id == :textColor) {
            var textColor = nextTextColor(AppSettings.detailTextColor());
            AppSettings.setValue("DetailTextColor", textColor);
            item.setSubLabel(textColorLabel(textColor));
        } else if (id == :background) {
            var background = nextBackground(AppSettings.detailBackgroundColor());
            AppSettings.setValue("DetailBackgroundColor", background);
            item.setSubLabel(backgroundLabel(background));
        } else if (id == :duration) {
            var seconds = AppSettings.lapDetailDurationMs() / 1000;
            seconds = seconds == 4 ? 8 : (seconds == 8 ? 12 : 4);
            AppSettings.setValue("LapDetailSeconds", seconds);
            item.setSubLabel(seconds.format("%d") + " s");
        }
        _view.reloadSettings();
        WatchUi.requestUpdate();
    }

    hidden function nextTextColor(color) {
        if (color == 0xFFFFFF) { return 0xFFFF00; }
        if (color == 0xFFFF00) { return 0x00D7FF; }
        if (color == 0x00D7FF) { return 0x000000; }
        return 0xFFFFFF;
    }

    hidden function markerLabel(mode) {
        if (mode == MarkerMode.KM_ONLY) { return WatchUi.loadResource(Rez.Strings.MarkersKm); }
        if (mode == MarkerMode.HIDDEN) { return WatchUi.loadResource(Rez.Strings.MarkersHidden); }
        return WatchUi.loadResource(Rez.Strings.MarkersAll);
    }

    hidden function textColorLabel(color) {
        if (color == 0xFFFF00) { return WatchUi.loadResource(Rez.Strings.ColorYellow); }
        if (color == 0x00D7FF) { return WatchUi.loadResource(Rez.Strings.ColorCyan); }
        if (color == 0x000000) { return WatchUi.loadResource(Rez.Strings.ColorBlack); }
        return WatchUi.loadResource(Rez.Strings.ColorWhite);
    }

    hidden function backgroundLabel(color) {
        if (color == 0x001F4D) { return WatchUi.loadResource(Rez.Strings.ColorDarkBlue); }
        if (color == 0x555555) { return WatchUi.loadResource(Rez.Strings.ColorDarkGray); }
        return WatchUi.loadResource(Rez.Strings.ColorBlack);
    }

    hidden function nextBackground(color) {
        if (color == 0x000000) { return 0x001F4D; }
        if (color == 0x001F4D) { return 0x555555; }
        return 0x000000;
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
