import Toybox.Application;
import Toybox.WatchUi;

class ForcaApp extends Application.AppBase {
    private var _recorder;

    function initialize() {
        AppBase.initialize();
        _recorder = new StrengthRecorder();
    }

    function getInitialView() {
        return [new ForcaView(_recorder), new ForcaDelegate(_recorder)];
    }
}
