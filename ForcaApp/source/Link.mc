import Toybox.Communications;
import Toybox.Lang;
import Toybox.Timer;

class Link extends Communications.ConnectionListener {
    private var _log;
    private var _sent = 0;
    private var _inFlight = 0;
    private var _retry;

    function initialize(log) {
        ConnectionListener.initialize();
        _log = log;
        _retry = new Timer.Timer();
    }

    function start() {
        _log.listener = self;
        if (Communications has :registerForPhoneAppMessages) {
            Communications.registerForPhoneAppMessages(method(:onPhoneMessage));
        }
        flush();
    }

    function flush() {
        if (_inFlight > 0 || _sent >= _log.events.size()) {
            return;
        }
        var end = _log.events.size();
        if (end - _sent > LinkKeys.BATCH) {
            end = _sent + LinkKeys.BATCH;
        }
        _inFlight = end - _sent;
        Communications.transmit({ LinkKeys.EVENTS => _log.events.slice(_sent, end) }, null, self);
    }

    function onComplete() {
        _sent += _inFlight;
        _inFlight = 0;
        flush();
    }

    function onError() {
        _inFlight = 0;
        _retry.start(method(:flush), Timing.LINK_RETRY_MS, false);
    }

    function onPhoneMessage(message as Communications.PhoneAppMessage) as Void {
        var data = message.data;
        if (data instanceof Dictionary && data[LinkKeys.PING] != null) {
            Communications.transmit({ LinkKeys.PONG => data[LinkKeys.PING] }, null, new Communications.ConnectionListener());
        }
    }
}
