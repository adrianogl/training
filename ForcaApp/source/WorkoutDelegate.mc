import Toybox.System;
import Toybox.WatchUi;

class WorkoutDelegate extends WatchUi.InputDelegate {
    private var _workout;
    private var _menuAtMs = -Timing.MENU_RELEASE_MS;

    function initialize(workout) {
        InputDelegate.initialize();
        _workout = workout;
    }

    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER) {
            return onStartKey();
        }
        if (key == WatchUi.KEY_ESC) {
            if (System.getTimer() - _menuAtMs < Timing.MENU_RELEASE_MS) {
                return true;
            }
            return onLapKey();
        }
        if (key == WatchUi.KEY_UP) {
            return step(-1);
        }
        if (key == WatchUi.KEY_DOWN) {
            return step(1);
        }
        if (key == WatchUi.KEY_MENU) {
            _menuAtMs = System.getTimer();
            return openMenu();
        }
        return isActive();
    }

    function onSwipe(swipeEvent) {
        var direction = swipeEvent.getDirection();
        if (direction == WatchUi.SWIPE_UP) {
            return step(1);
        }
        if (direction == WatchUi.SWIPE_DOWN) {
            return step(-1);
        }
        return isActive();
    }

    function onTap(clickEvent) {
        return true;
    }

    function onHold(clickEvent) {
        return true;
    }

    private function onStartKey() {
        var phase = _workout.phase;
        if (phase == Phase.START) {
            _workout.start();
        } else if (phase == Phase.ADJUST) {
            _workout.confirmAdjust();
        } else if (phase == Phase.PENDING && !_workout.paused) {
            WorkoutMenus.pushPending(_workout);
        } else if (_workout.isRunning()) {
            _workout.pause();
            WorkoutMenus.pushPause(_workout);
        }
        WatchUi.requestUpdate();
        return true;
    }

    private function onLapKey() {
        if (!isActive()) {
            return false;
        }
        if (_workout.paused) {
            WorkoutMenus.pushPause(_workout);
            return true;
        }
        _workout.onLap();
        WatchUi.requestUpdate();
        return true;
    }

    private function step(direction) {
        if (!isActive()) {
            return false;
        }
        _workout.onStep(direction);
        WatchUi.requestUpdate();
        return true;
    }

    private function openMenu() {
        if (_workout.canOpenMenu()) {
            WorkoutMenus.pushActions(_workout);
        }
        return isActive();
    }

    private function isActive() {
        return _workout.isRunning();
    }
}
