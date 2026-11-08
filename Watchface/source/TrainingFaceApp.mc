import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class TrainingFaceApp extends Application.AppBase {
    private var _view = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        _view = new TrainingFaceView();
        return [_view];
    }

    function onSettingsChanged() {
        if (_view != null) {
            _view.invalidateData();
        }
        WatchUi.requestUpdate();
    }
}
