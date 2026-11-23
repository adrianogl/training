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
            profile = pulses(Vibe.GO_PULSES, Vibe.GO_MS);
        } else if (kind == Vibe.WARN) {
            profile = pulses(Vibe.WARN_PULSES, Vibe.WARN_MS);
        } else {
            profile = pulses(1, Vibe.SET_MS);
        }
        Attention.vibrate(profile);
    }

    private function pulses(count, durationMs) {
        var profile = [];
        for (var i = 0; i < count; i++) {
            if (i > 0) {
                profile.add(new Attention.VibeProfile(0, Vibe.GAP_MS));
            }
            profile.add(new Attention.VibeProfile(Vibe.INTENSITY, durationMs));
        }
        return profile;
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
