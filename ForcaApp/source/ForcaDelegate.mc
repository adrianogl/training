import Toybox.WatchUi;

class ForcaDelegate extends WatchUi.BehaviorDelegate {
    private var _recorder;

    function initialize(recorder) {
        BehaviorDelegate.initialize();
        _recorder = recorder;
    }

    function onKey(keyEvent) {
        if (keyEvent.getType() != WatchUi.PRESS_TYPE_ACTION) {
            return false;
        }
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER) {
            return onStartKey();
        }
        if (key == WatchUi.KEY_ESC) {
            return onLapKey();
        }
        return false;
    }

    function onSelect() {
        return isActive();
    }

    function onBack() {
        return isActive();
    }

    function onTap(clickEvent) {
        return true;
    }

    function onSwipe(swipeEvent) {
        return isActive();
    }

    private function onStartKey() {
        var state = _recorder.state();
        if (state == RecorderState.IDLE) {
            _recorder.start();
        } else if (state == RecorderState.RECORDING) {
            _recorder.pause();
            PauseMenu.push(_recorder);
        } else if (state == RecorderState.PAUSED) {
            PauseMenu.push(_recorder);
        }
        WatchUi.requestUpdate();
        return true;
    }

    private function onLapKey() {
        var state = _recorder.state();
        if (state == RecorderState.RECORDING) {
            _recorder.markSet();
            WatchUi.requestUpdate();
            return true;
        }
        if (state == RecorderState.PAUSED) {
            PauseMenu.push(_recorder);
            return true;
        }
        return false;
    }

    private function isActive() {
        return _recorder.hasSession();
    }
}
