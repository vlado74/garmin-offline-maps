import Toybox.Activity;
import Toybox.ActivityRecording;

//! Owns the single FIT recording session for one run.
class RunController {
    const WAITING_GPS = :waitingGps;
    const READY = :ready;
    const RECORDING = :recording;
    const PAUSED = :paused;
    const SAVE_FAILED = :saveFailed;

    // @transition waitingGps + gpsReady -> ready
    // @transition ready + toggle -> recording
    // @transition recording + toggle -> paused
    // @transition paused + toggle -> recording
    // @transition recording + saveFailure -> saveFailed

    hidden var _session;
    hidden var _state;
    hidden var _gpsReady;
    hidden var _recordingActive;

    function initialize() {
        _session = null;
        _state = WAITING_GPS;
        _gpsReady = false;
        _recordingActive = false;
    }

    function setGpsReady(ready) {
        _gpsReady = ready;
        if (_session == null) {
            _state = ready ? READY : WAITING_GPS;
        }
    }

    function toggle() {
        if (_state == READY) {
            try {
                _session = ActivityRecording.createSession({
                    :name => "EUR Run",
                    :sport => Activity.SPORT_RUNNING,
                    :subSport => Activity.SUB_SPORT_STREET
                });
                if (!_session.start()) {
                    _state = SAVE_FAILED;
                    return false;
                }
                _recordingActive = true;
                _state = RECORDING;
                return true;
            } catch (ex) {
                if (_session != null) { _state = SAVE_FAILED; }
                return false;
            }
        }
        if (_state == RECORDING) {
            if (!stopRecording()) { return false; }
            _state = PAUSED;
            return true;
        }
        if (_state == PAUSED) {
            try {
                if (!_session.start()) { return false; }
                _recordingActive = true;
                _state = RECORDING;
                return true;
            } catch (ex) {
                return false;
            }
        }
        return false;
    }

    function save() {
        if (_session == null) { return true; }
        if (!stopRecording()) { return false; }
        try {
            if (_session.save()) {
                _session = null;
                settleIdleState();
                return true;
            }
        } catch (ex) { }
        _state = SAVE_FAILED;
        return false;
    }

    //! Called only after an explicit user choice.
    function discard() {
        if (_session == null) { return true; }
        if (!stopRecording()) { return false; }
        try {
            if (!_session.discard()) {
                _state = SAVE_FAILED;
                return false;
            }
            _session = null;
            settleIdleState();
            return true;
        } catch (ex) {
            _state = SAVE_FAILED;
            return false;
        }
    }

    //! Best-effort lifecycle save. It never discards the session.
    function shutdown() {
        return save();
    }

    //! Stop whenever Garmin may still be recording, including a save retry.
    hidden function stopRecording() {
        if (!_recordingActive) { return true; }
        try {
            if (!_session.stop()) {
                _state = SAVE_FAILED;
                return false;
            }
        } catch (ex) {
            _state = SAVE_FAILED;
            return false;
        }
        _recordingActive = false;
        return true;
    }

    function state() { return _state; }
    function hasSession() { return _session != null; }

    function addLap() {
        if (_session == null || _state != RECORDING) { return false; }
        try {
            return _session.addLap();
        } catch (ex) {
            return false;
        }
    }

    function timerMs() {
        var info = Activity.getActivityInfo();
        return info == null || info.timerTime == null ? 0 : info.timerTime;
    }

    function distanceMetres() {
        var info = Activity.getActivityInfo();
        return info == null || info.elapsedDistance == null ? 0 : info.elapsedDistance;
    }

    function averagePaceSeconds() {
        var info = Activity.getActivityInfo();
        if (info == null || info.averageSpeed == null || info.averageSpeed <= 0) {
            return null;
        }
        return 1000.0d / info.averageSpeed;
    }

    hidden function settleIdleState() {
        _state = _gpsReady ? READY : WAITING_GPS;
    }
}
