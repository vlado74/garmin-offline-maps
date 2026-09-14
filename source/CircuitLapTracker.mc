import Toybox.Math;

//! Detects a completed short circuit by leaving and returning to the start.
class CircuitLapTracker {
    const EXIT_RADIUS_METRES = 150.0d;
    const ENTRY_RADIUS_METRES = 25.0d;
    const MIN_LAP_DISTANCE_METRES = 300.0d;
    const MIN_LAP_TIME_MS = 60000.0d;
    const EARTH_RADIUS_METRES = 6371000.0d;

    hidden var _startLat;
    hidden var _startLon;
    hidden var _armed;
    hidden var _lapStartDistance;
    hidden var _lapStartTime;
    hidden var _count;
    hidden var _lastDistance;
    hidden var _lastTime;

    function initialize() { clear(); }

    function clear() {
        _startLat = null;
        _startLon = null;
        _armed = false;
        _lapStartDistance = 0.0d;
        _lapStartTime = 0;
        _count = 0;
        _lastDistance = 0.0d;
        _lastTime = 0;
    }

    function update(lat, lon, totalDistance, timerMs) {
        if (_startLat == null) {
            _startLat = lat;
            _startLon = lon;
            _lapStartDistance = totalDistance;
            _lapStartTime = timerMs;
            return false;
        }
        var fromStart = distance(_startLat, _startLon, lat, lon);
        if (!_armed && fromStart >= EXIT_RADIUS_METRES) { _armed = true; }
        var lapDistance = totalDistance - _lapStartDistance;
        var lapTime = timerMs - _lapStartTime;
        if (!_armed || fromStart > ENTRY_RADIUS_METRES
            || lapDistance < MIN_LAP_DISTANCE_METRES || lapTime < MIN_LAP_TIME_MS) {
            return false;
        }
        _count += 1;
        _lastDistance = lapDistance;
        _lastTime = lapTime;
        _lapStartDistance = totalDistance;
        _lapStartTime = timerMs;
        _armed = false;
        return true;
    }

    function hasStart() { return _startLat != null; }
    function startLat() { return _startLat; }
    function startLon() { return _startLon; }
    function count() { return _count; }
    function lastDistanceMetres() { return _lastDistance; }
    function lastTimeMs() { return _lastTime; }
    function lastPaceSeconds() {
        return _lastDistance <= 0 ? null : _lastTime / _lastDistance;
    }

    hidden function distance(fromLat, fromLon, toLat, toLon) {
        var latRadians = fromLat * Math.PI / 180.0d;
        var dy = (toLat - fromLat) * Math.PI / 180.0d * EARTH_RADIUS_METRES;
        var dx = (toLon - fromLon) * Math.PI / 180.0d * EARTH_RADIUS_METRES
            * Math.cos(latRadians);
        return Math.sqrt(dx * dx + dy * dy);
    }
}
