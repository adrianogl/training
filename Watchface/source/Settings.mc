import Toybox.Application;
import Toybox.Lang;

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

    function raceName() {
        return read("RaceName", "");
    }

    function raceDate() {
        return read("RaceDate", "");
    }

    function raceGoal() {
        return read("RaceGoal", "");
    }

    function raceDistanceKm() {
        return read("RaceDistance", Defaults.RACE_DISTANCE_KM);
    }
}
