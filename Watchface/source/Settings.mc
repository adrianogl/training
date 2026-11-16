import Toybox.Application;
import Toybox.Lang;

(:background)
module Settings {
    function read(key, fallback) {
        var value = Application.Properties.getValue(key);
        if (value == null) {
            return fallback;
        }
        return value;
    }

    function weeklyGoalKm() {
        return read("WeeklyGoalKm", Defaults.WEEKLY_GOAL_KM);
    }

    function watchToken() {
        var token = read("watchToken", "");
        if (token.length() == 0) {
            token = BuildToken.WATCH_TOKEN;
        }
        if (token.length() == 0) {
            return null;
        }
        return token;
    }
}
