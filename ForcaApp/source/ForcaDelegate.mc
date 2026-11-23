import Toybox.WatchUi;

class ForcaDelegate extends WatchUi.BehaviorDelegate {
    private var _recorder;

    function initialize(recorder) {
        BehaviorDelegate.initialize();
        _recorder = recorder;
    }

    function onSelect() {
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

    function onBack() {
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
}
