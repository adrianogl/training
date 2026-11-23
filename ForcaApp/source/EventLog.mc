import Toybox.Lang;

class EventLog {
    var events = [];
    var listener = null;
    private var _prefix;
    private var _sequence = 0;
    private var _persist;

    function initialize(sessionId, persist) {
        _prefix = sessionId.toString();
        _persist = persist;
    }

    function started(title) {
        if (listener != null) {
            listener.started(title);
        }
    }

    function finished(saved, seconds, heartRate) {
        if (listener != null) {
            listener.finished(saved, seconds, heartRate);
        }
    }

    function setDone(exerciseId, set) {
        append(EventKeys.SET_DONE, { EventKeys.EXERCISE_ID => exerciseId, EventKeys.RESULT => copy(set) });
    }

    function adjust(exerciseId, setIndex, set) {
        append(EventKeys.ADJUST, { EventKeys.EXERCISE_ID => exerciseId, EventKeys.SET_INDEX => setIndex, EventKeys.RESULT => copy(set) });
    }

    function skip(exerciseId) {
        append(EventKeys.SKIP, { EventKeys.EXERCISE_ID => exerciseId });
    }

    function doNow(exerciseId) {
        append(EventKeys.DO_NOW, { EventKeys.EXERCISE_ID => exerciseId });
    }

    function leaveOut(exerciseId) {
        append(EventKeys.LEAVE_OUT, { EventKeys.EXERCISE_ID => exerciseId });
    }

    private function copy(set) {
        var result = {};
        var keys = set.keys();
        for (var i = 0; i < keys.size(); i++) {
            result[keys[i]] = set[keys[i]];
        }
        return result;
    }

    private function append(kind, payload) {
        _sequence += 1;
        events.add({
            EventKeys.ID => _prefix + "-" + _sequence,
            EventKeys.SEQUENCE => _sequence,
            EventKeys.ACTION => { kind => payload }
        });
        if (_persist) {
            WorkoutStore.store(StorageKeys.EVENTS, events);
        }
        if (listener != null) {
            listener.flush();
        }
    }
}
