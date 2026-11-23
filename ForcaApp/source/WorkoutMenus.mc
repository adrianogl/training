import Toybox.WatchUi;

module WorkoutMenus {
    function pushPause(workout) {
        var menu = new WatchUi.Menu2({ :title => "Pausado · " + workout.setsDone() + "/" + workout.setsPlanned() });
        menu.addItem(new WatchUi.MenuItem("Retomar", null, PauseAction.RESUME, null));
        menu.addItem(new WatchUi.MenuItem("Salvar", null, PauseAction.SAVE, null));
        menu.addItem(new WatchUi.MenuItem("Descartar", null, PauseAction.DISCARD, null));
        WatchUi.pushView(menu, new PauseMenuDelegate(workout), WatchUi.SLIDE_UP);
    }

    function pushActions(workout) {
        var menu = new WatchUi.Menu2({ :title => Format.shortName(workout.current[PlanKeys.NAME]) });
        var pending = workout.queue.pending();
        for (var i = 0; i < pending.size(); i++) {
            var exercise = pending[i][PlanKeys.EXERCISES][0];
            menu.addItem(new WatchUi.MenuItem("Fazer agora", Format.shortName(exercise[PlanKeys.NAME]), exercise[PlanKeys.ID], null));
        }
        menu.addItem(new WatchUi.MenuItem("Pular · fazer depois", null, QueueAction.SKIP, null));
        menu.addItem(new WatchUi.MenuItem("Voltar", null, QueueAction.BACK, null));
        WatchUi.pushView(menu, new ActionMenuDelegate(workout), WatchUi.SLIDE_UP);
    }

    function pushPending(workout) {
        var exercise = workout.current;
        var menu = new WatchUi.Menu2({ :title => Format.shortName(exercise[PlanKeys.NAME]) });
        menu.addItem(new WatchUi.MenuItem("Fazer agora", null, QueueAction.DO_NOW, null));
        menu.addItem(new WatchUi.MenuItem("Deixar de fora", null, QueueAction.LEAVE_OUT, null));
        WatchUi.pushView(menu, new PendingMenuDelegate(workout), WatchUi.SLIDE_UP);
    }
}

class PauseMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _workout;

    function initialize(workout) {
        Menu2InputDelegate.initialize();
        _workout = workout;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == PauseAction.RESUME) {
            _workout.resume();
        } else if (id == PauseAction.SAVE) {
            _workout.save();
        } else if (id == PauseAction.DISCARD) {
            _workout.discard();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }

    function onBack() {
        _workout.resume();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        WatchUi.requestUpdate();
    }
}

class ActionMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _workout;

    function initialize(workout) {
        Menu2InputDelegate.initialize();
        _workout = workout;
    }

    function onSelect(item) {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (id == QueueAction.SKIP) {
            _workout.skip();
        } else if (id instanceof String) {
            _workout.doNow(id);
        }
        WatchUi.requestUpdate();
    }
}

class PendingMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _workout;

    function initialize(workout) {
        Menu2InputDelegate.initialize();
        _workout = workout;
    }

    function onSelect(item) {
        var exerciseId = _workout.current[PlanKeys.ID];
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (item.getId() == QueueAction.DO_NOW) {
            _workout.doNow(exerciseId);
        } else {
            _workout.leaveOut(exerciseId);
        }
        WatchUi.requestUpdate();
    }
}
