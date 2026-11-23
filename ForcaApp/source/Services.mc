import Toybox.Activity;
import Toybox.Attention;
import Toybox.System;
import Toybox.Time;

class Services {
    var recorder;

    function initialize(aRecorder) {
        recorder = aRecorder;
    }

    function persists() {
        return true;
    }

    function now() {
        return System.getTimer();
    }

    function epoch() {
        return Time.now().value();
    }

    function vibrate(kind) {
        if (!(Attention has :vibrate)) {
            return;
        }
        var profile;
        if (kind == Vibe.GO || kind == Vibe.DONE) {
            profile = [new Attention.VibeProfile(100, 600)];
        } else if (kind == Vibe.WARN) {
            profile = [new Attention.VibeProfile(70, 150)];
        } else {
            profile = [new Attention.VibeProfile(80, 120)];
        }
        Attention.vibrate(profile);
    }

    static function heartRate() {
        var info = Activity.getActivityInfo();
        return info == null ? null : info.currentHeartRate;
    }

    static function averageHeartRate() {
        var info = Activity.getActivityInfo();
        return info == null ? null : info.averageHeartRate;
    }
}
