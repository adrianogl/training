import Toybox.Application;
import Toybox.Lang;

module WorkoutStore {
    function load() {
        var plan = Application.Storage.getValue(StorageKeys.PLAN);
        if (plan instanceof Dictionary && plan[PlanKeys.BLOCKS] instanceof Array) {
            return plan;
        }
        return samplePlan();
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
