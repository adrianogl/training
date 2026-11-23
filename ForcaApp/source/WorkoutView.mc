import Toybox.Graphics;
import Toybox.Timer;
import Toybox.WatchUi;

class WorkoutView extends WatchUi.View {
    private var _workout;
    private var _timer;

    function initialize(workout) {
        View.initialize();
        _workout = workout;
        _timer = new Timer.Timer();
    }

    function onShow() {
        _timer.start(method(:onTick), Timing.REFRESH_MS, true);
    }

    function onHide() {
        _timer.stop();
    }

    function onTick() {
        _workout.tick();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        var phase = _workout.phase;
        if (phase == Phase.EMPTY) {
            StartScreen.drawEmpty(dc);
        } else if (phase == Phase.START) {
            StartScreen.draw(dc, _workout);
        } else if (phase == Phase.SET || phase == Phase.TIMED) {
            drawSet(dc);
        } else if (phase == Phase.REST) {
            RestScreen.draw(dc, _workout);
        } else if (phase == Phase.ADJUST) {
            AdjustScreen.draw(dc, _workout);
        } else if (phase == Phase.EXERCISE_DONE) {
            DoneScreen.drawExercise(dc, _workout);
        } else if (phase == Phase.PENDING) {
            DoneScreen.drawPending(dc, _workout);
        } else if (phase == Phase.FINISHED) {
            DoneScreen.drawFinished(dc, _workout);
        } else {
            DoneScreen.drawSaved(dc, _workout);
        }
        if (_workout.paused) {
            Draw.text(dc, dc.getWidth() / 2, dc.getHeight() * 0.92, Fonts.LABEL, Palette.YELLOW, "PAUSADO");
        }
    }

    private function drawSet(dc) {
        if (_workout.view == SetView.EXERCISE) {
            ExerciseScreen.draw(dc, _workout);
        } else if (_workout.view == SetView.WORKOUT) {
            WorkoutScreen.draw(dc, _workout);
        } else {
            SetScreen.draw(dc, _workout);
        }
    }
}
