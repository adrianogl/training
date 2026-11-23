import Toybox.Communications;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Timer;

class Link extends Communications.ConnectionListener {
    private var _log;
    private var _acked = 0;
    private var _busy = false;
    private var _start = null;
    private var _timer;

    function initialize(log) {
        ConnectionListener.initialize();
        _log = log;
        _timer = new Timer.Timer();
    }

    function start() {
        _log.listener = self;
        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
        }
        flush();
    }

    function started(title) {
        _start = { LinkKeys.STARTED => Time.now().value(), LinkKeys.TITLE => title };
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
        if (data[LinkKeys.ACK_STARTED] != null) {
            _start = null;
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
            return null;
        }
        var end = size;
        if (end - _acked > LinkKeys.BATCH) {
            end = _acked + LinkKeys.BATCH;
        }
        return { LinkKeys.EVENTS => _log.events.slice(_acked, end) };
    }
}
