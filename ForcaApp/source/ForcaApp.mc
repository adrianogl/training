import Toybox.Application;
import Toybox.WatchUi;

class ForcaApp extends Application.AppBase {
    private var _workout;

    function initialize() {
        AppBase.initialize();
        _workout = new Workout(WorkoutStore.load(), new Services(new StrengthRecorder()));
    }

    function getInitialView() {
        return [new WorkoutView(_workout), new WorkoutDelegate(_workout)];
    }
}
