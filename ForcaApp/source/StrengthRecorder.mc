import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Sensor;
import Toybox.WatchUi;

class StrengthRecorder {
    private var _session = null;

    function initialize() {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
    }

    function start(title) {
        if (_session == null) {
            _session = ActivityRecording.createSession({
                :name => title != null ? title : WatchUi.loadResource(Rez.Strings.ActivityName),
                :sport => Activity.SPORT_TRAINING,
                :subSport => Activity.SUB_SPORT_STRENGTH_TRAINING
            });
        }
        _session.start();
    }

    function pause() {
        if (_session != null && _session.isRecording()) {
            _session.stop();
        }
    }

    function save() {
        if (_session != null) {
            _session.stop();
            _session.save();
            _session = null;
        }
    }

    function discard() {
        if (_session != null) {
            _session.stop();
            _session.discard();
            _session = null;
        }
    }

    function elapsedMs() {
        var info = Activity.getActivityInfo();
        return (info != null && info.timerTime != null) ? info.timerTime : 0;
    }

    function heartRate() {
        var info = Activity.getActivityInfo();
        return info == null ? null : info.currentHeartRate;
    }
}
