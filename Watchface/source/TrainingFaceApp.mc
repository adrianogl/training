import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

(:background)
class TrainingFaceApp extends Application.AppBase {
    private var _view = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        scheduleReadinessFetch();
        _view = new TrainingFaceView();
        return [_view];
    }

    function getServiceDelegate() {
        return [new ReadinessServiceDelegate()];
    }

    function onSettingsChanged() {
        scheduleReadinessFetch();
        refreshView();
    }

    function onBackgroundData(data) {
        if (data instanceof Dictionary) {
            storeReadiness(data);
        } else if (data == ReadinessBridge.UNAUTHORIZED || data == ReadinessBridge.NOT_FOUND) {
            clearReadiness();
        }
        refreshView();
    }

    private function scheduleReadinessFetch() {
        if (Settings.watchToken() == null) {
            Background.deleteTemporalEvent();
            clearReadiness();
            return;
        }
        if (Background.getTemporalEventRegisteredTime() == null) {
            Background.registerForTemporalEvent(new Time.Duration(ReadinessBridge.INTERVAL_SECONDS));
        }
    }

    private function storeReadiness(data) {
        var day = data[ReadinessBridge.DAY];
        var score = data[ReadinessBridge.SCORE];
        if (!(day instanceof String) || !(score instanceof Number)) {
            return;
        }
        Application.Storage.setValue(StorageKeys.READINESS, score);
        Application.Storage.setValue(StorageKeys.READINESS_DAY, day);
        Application.Storage.setValue(StorageKeys.READINESS_VERDICT, data[ReadinessBridge.VERDICT]);
    }

    private function clearReadiness() {
        Application.Storage.deleteValue(StorageKeys.READINESS);
        Application.Storage.deleteValue(StorageKeys.READINESS_DAY);
        Application.Storage.deleteValue(StorageKeys.READINESS_VERDICT);
    }

    private function refreshView() {
        if (_view != null) {
            _view.invalidateData();
        }
        WatchUi.requestUpdate();
    }
}
