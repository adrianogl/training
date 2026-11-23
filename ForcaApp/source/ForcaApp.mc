import Toybox.Application;
import Toybox.WatchUi;

class ForcaApp extends Application.AppBase {
    private var _workout;
    private var _link;

    function initialize() {
        AppBase.initialize();
        _workout = new Workout(WorkoutStore.load(), new Services(new StrengthRecorder()));
        _link = new Link(_workout.log);
    }

    function onStart(state) {
        _link.start();
    }

    function getInitialView() {
        return [new WorkoutView(_workout), new WorkoutDelegate(_workout)];
    }
}
