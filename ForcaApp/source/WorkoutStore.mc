import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

module WorkoutStore {
    function load() {
        var plan = planFor(today());
        if (plan != null) {
            return plan;
        }
        return samplePlan();
    }

    function savePlans(plans) {
        if (!(plans instanceof Array)) {
            return false;
        }
        return store(StorageKeys.PLANS, plans);
    }

    function planFor(day) {
        var plans = Application.Storage.getValue(StorageKeys.PLANS);
        if (!(plans instanceof Array)) {
            return null;
        }
        for (var i = 0; i < plans.size(); i++) {
            var plan = plans[i];
            if (plan instanceof Dictionary && plan[PlanKeys.BLOCKS] instanceof Array && day.equals(plan[PlanKeys.DAY])) {
                return plan;
            }
        }
        return null;
    }

    function today() {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return Lang.format("$1$-$2$-$3$", [info.year.format("%04d"), info.month.format("%02d"), info.day.format("%02d")]);
    }

    function saveResults(results) {
        store(StorageKeys.RESULTS, results);
    }

    function store(key, value) {
        try {
            Application.Storage.setValue(key, value);
            return true;
        } catch (e) {
            return false;
        }
    }

    function clearSession() {
        Application.Storage.deleteValue(StorageKeys.RESULTS);
        Application.Storage.deleteValue(StorageKeys.EVENTS);
    }

    (:debug)
    function samplePlan() {
        return SamplePlan.superiores();
    }

    (:release)
    function samplePlan() {
        return null;
    }
}
