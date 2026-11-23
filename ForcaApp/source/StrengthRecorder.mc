import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Attention;
import Toybox.Sensor;
import Toybox.WatchUi;

class StrengthRecorder {
    private var _session = null;
    private var _state = RecorderState.IDLE;
    private var _sets = 0;

    function initialize() {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
    }

    function state() {
        return _state;
    }

    function sets() {
        return _sets;
    }

    function start() {
        if (_session == null) {
            _session = ActivityRecording.createSession({
                :name => WatchUi.loadResource(Rez.Strings.ActivityName),
                :sport => Activity.SPORT_TRAINING,
                :subSport => Activity.SUB_SPORT_STRENGTH_TRAINING
            });
        }
        _session.start();
        _state = RecorderState.RECORDING;
        vibrate(200);
    }

    function pause() {
        if (_state != RecorderState.RECORDING) {
            return;
        }
        _session.stop();
        _state = RecorderState.PAUSED;
        vibrate(200);
    }

    function markSet() {
        if (_state != RecorderState.RECORDING) {
            return;
        }
        _session.addLap();
        _sets += 1;
        vibrate(100);
    }

    function save() {
        if (_session == null) {
            return;
        }
        _session.save();
        _session = null;
        _state = RecorderState.SAVED;
        vibrate(400);
    }

    function discard() {
        if (_session == null) {
            return;
        }
        _session.discard();
        _session = null;
        _state = RecorderState.DISCARDED;
    }

    function hasSession() {
        return _session != null;
    }

    private function vibrate(durationMs) {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, durationMs)]);
        }
    }
}
