import Toybox.Lang;
import Toybox.Position;
import Toybox.System;

//! Supplies only position fixes whose Garmin quality is usable for a run.
class LocationTracker {
    const MIN_HEADING_SPEED = 0.8d;

    hidden var _lat;
    hidden var _lon;
    hidden var _hasFix;
    hidden var _accuracy;
    hidden var _heading;
    hidden var _speed;
    hidden var _hasHeading;
    hidden var _onFix;
    hidden var _running;

    function initialize(onFix) {
        _lat = 0.0d;
        _lon = 0.0d;
        _hasFix = false;
        _accuracy = Position.QUALITY_NOT_AVAILABLE;
        _heading = 0.0d;
        _speed = 0.0d;
        _hasHeading = false;
        _onFix = onFix;
        _running = false;
    }

    function lat() { return _lat; }
    function lon() { return _lon; }
    function hasFix() { return _hasFix; }
    function accuracy() { return _accuracy; }
    function heading() { return _heading; }
    function speed() { return _speed; }
    function hasHeading() { return _hasHeading; }
    function hasUsableFix() {
        return _hasFix && (_accuracy == Position.QUALITY_USABLE
            || _accuracy == Position.QUALITY_GOOD);
    }

    function start() {
        if (_running) { return; }
        try {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
            _running = true;
        } catch (ex) {
            System.println("LocationTracker: positioning unavailable");
        }
        seedFromLastKnown();
    }

    hidden function seedFromLastKnown() {
        try {
            var info = Position.getInfo();
            if (info != null && info.position != null
                && info.accuracy != Position.QUALITY_NOT_AVAILABLE) {
                var degrees = info.position.toDegrees();
                if (degrees[0] <= Mercator.MAX_LAT && degrees[0] >= -Mercator.MAX_LAT) {
                    onPosition(info);
                }
            }
        } catch (ex) {
            // A live location event remains the normal path.
        }
    }

    function stop() {
        if (!_running) { return; }
        try {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
        } catch (ex) {
            // Receiver is already unavailable; local state can still be reset.
        }
        _running = false;
    }

    function onPosition(info as Position.Info) as Void {
        if (info == null || info.position == null) {
            _hasFix = false;
            _accuracy = Position.QUALITY_NOT_AVAILABLE;
            _hasHeading = false;
            _speed = 0.0d;
            if (_onFix != null) { _onFix.invoke(); }
            return;
        }
        var degrees = info.position.toDegrees();
        _lat = degrees[0];
        _lon = degrees[1];
        _hasFix = true;
        _accuracy = info.accuracy;
        _speed = info.speed == null ? 0.0d : info.speed;
        _hasHeading = info.heading != null && info.speed != null
            && info.speed >= MIN_HEADING_SPEED;
        if (_hasHeading) { _heading = info.heading; }
        if (_onFix != null) { _onFix.invoke(); }
    }
}
