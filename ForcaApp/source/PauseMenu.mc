import Toybox.WatchUi;

module PauseMenu {
    function push(recorder) {
        var menu = new WatchUi.Menu2({ :title => WatchUi.loadResource(Rez.Strings.PauseTitle) });
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.Resume), null, PauseAction.RESUME, null));
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.Save), null, PauseAction.SAVE, null));
        menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.Discard), null, PauseAction.DISCARD, null));
        WatchUi.pushView(menu, new PauseMenuDelegate(recorder), WatchUi.SLIDE_UP);
    }
}

class PauseMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _recorder;

    function initialize(recorder) {
        Menu2InputDelegate.initialize();
        _recorder = recorder;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == PauseAction.RESUME) {
            _recorder.start();
        } else if (id == PauseAction.SAVE) {
            _recorder.save();
        } else if (id == PauseAction.DISCARD) {
            _recorder.discard();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }
}
