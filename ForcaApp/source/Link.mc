import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

class Link extends Communications.ConnectionListener {
    private var _workout;
    private var _log;
    private var _acked = 0;
    private var _busy = false;
    private var _start = null;
    private var _finish = null;
    private var _timer;
    private var _statusTimer;
    private var _statusBusy = false;
    private var _statusPhase = null;
    private var _statusAtMs = 0;

    function initialize(workout) {
        ConnectionListener.initialize();
        _workout = workout;
        _log = workout.log;
        _timer = new Timer.Timer();
        _statusTimer = new Timer.Timer();
    }

    function start() {
        _log.listener = self;
        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
        }
        _statusTimer.start(method(:onStatusCheck), Timing.STATUS_CHECK_MS, true);
        flush();
    }

    function onStatusCheck() as Void {
        if (_statusBusy || !_workout.hasStarted()) {
            return;
        }
        var status = _workout.status();
        var phase = status[StatusKeys.PHASE];
        var now = System.getTimer();
        if (phase.equals(_statusPhase) && now - _statusAtMs < Timing.STATUS_EVERY_MS) {
            return;
        }
        _statusBusy = true;
        _statusPhase = phase;
        _statusAtMs = now;
        Communications.transmit({ LinkKeys.STATUS => status }, null, new LinkStatusListener(self));
    }

    function statusSent() {
        _statusBusy = false;
    }

    function started(title) {
        _start = { LinkKeys.STARTED => Time.now().value(), LinkKeys.TITLE => title };
        flush();
    }

    function finished(saved, seconds, heartRate) {
        _finish = {
            LinkKeys.FINISHED => Time.now().value(),
            LinkKeys.SAVED => saved,
            LinkKeys.DURATION => seconds,
            LinkKeys.AVERAGE_HEART_RATE => heartRate
        };
        flush();
    }

    function flush() {
        if (_busy) {
            return;
        }
        var message = pending();
        if (message == null) {
            return;
        }
        _busy = true;
        _timer.start(method(:onTimeout), Timing.LINK_RETRY_MS, false);
        Communications.transmit(message, null, self);
    }

    function onComplete() {
    }

    function onError() {
    }

    function onTimeout() as Void {
        _busy = false;
        flush();
    }

    function onPhoneMessage(message as Communications.PhoneAppMessage) as Void {
        var data = message.data;
        if (!(data instanceof Dictionary)) {
            return;
        }
        if (data[LinkKeys.PING] != null) {
            Communications.transmit({ LinkKeys.PONG => data[LinkKeys.PING] }, null, new Communications.ConnectionListener());
            return;
        }
        var command = data[LinkKeys.COMMAND];
        if (command instanceof Dictionary) {
            var keys = command.keys();
            if (keys.size() > 0 && _workout.command(keys[0], command[keys[0]])) {
                WatchUi.requestUpdate();
            }
            return;
        }
        if (data[LinkKeys.PLANS] != null) {
            if (WorkoutStore.savePlans(data[LinkKeys.PLANS]) && _workout.usePlan(WorkoutStore.planFor(WorkoutStore.today()))) {
                WatchUi.requestUpdate();
            }
            return;
        }
        if (data[LinkKeys.ACK_STARTED] != null) {
            _start = null;
        }
        if (data[LinkKeys.ACK_FINISHED] != null) {
            _finish = null;
        }
        var ack = data[LinkKeys.ACK];
        if (ack != null && ack > _acked) {
            _acked = ack;
        }
        _timer.stop();
        _busy = false;
        flush();
    }

    private function pending() {
        if (_start != null) {
            return _start;
        }
        var size = _log.events.size();
        if (_acked >= size) {
            return _finish;
        }
        var end = size;
        if (end - _acked > LinkKeys.BATCH) {
            end = _acked + LinkKeys.BATCH;
        }
        return { LinkKeys.EVENTS => _log.events.slice(_acked, end) };
    }
}

class LinkStatusListener extends Communications.ConnectionListener {
    private var _link;

    function initialize(link) {
        ConnectionListener.initialize();
        _link = link;
    }

    function onComplete() {
        _link.statusSent();
    }

    function onError() {
        _link.statusSent();
    }
}
