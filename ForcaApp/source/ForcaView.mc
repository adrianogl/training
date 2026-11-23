import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Timer;
import Toybox.WatchUi;

class ForcaView extends WatchUi.View {
    private var _recorder;
    private var _timer;

    function initialize(recorder) {
        View.initialize();
        _recorder = recorder;
        _timer = new Timer.Timer();
    }

    function onShow() {
        _timer.start(method(:onTick), ViewTiming.REFRESH_MS, true);
    }

    function onHide() {
        _timer.stop();
    }

    function onTick() {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.setColor(Palette.BG, Palette.BG);
        dc.clear();
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var info = Activity.getActivityInfo();
        var state = _recorder.state();

        dc.setColor(stateColor(state), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.16, Graphics.FONT_SMALL, stateLabel(state), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Palette.TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.30, Graphics.FONT_NUMBER_HOT, elapsed(info), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Palette.LIME, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.56, Graphics.FONT_MEDIUM, "Séries " + _recorder.sets(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Palette.HR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.70, Graphics.FONT_SMALL, "FC " + heartRate(info), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Palette.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.83, Graphics.FONT_XTINY, hint(state), Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function elapsed(info) {
        var ms = (info != null && info.timerTime != null) ? info.timerTime : 0;
        var total = ms / 1000;
        return (total / 60).format("%d") + ":" + (total % 60).format("%02d");
    }

    private function heartRate(info) {
        if (info == null || info.currentHeartRate == null) {
            return "--";
        }
        return info.currentHeartRate.format("%d");
    }

    private function stateLabel(state) {
        if (state == RecorderState.RECORDING) {
            return "Gravando";
        }
        if (state == RecorderState.PAUSED) {
            return "Pausado";
        }
        if (state == RecorderState.SAVED) {
            return "Salvo";
        }
        if (state == RecorderState.DISCARDED) {
            return "Descartado";
        }
        return "Força · S1";
    }

    private function stateColor(state) {
        if (state == RecorderState.RECORDING) {
            return Palette.LIME;
        }
        if (state == RecorderState.PAUSED) {
            return Palette.REST;
        }
        return Palette.DIM;
    }

    private function hint(state) {
        if (state == RecorderState.RECORDING) {
            return "baixo: série · cima: pausa";
        }
        if (state == RecorderState.IDLE) {
            return "cima: começa";
        }
        if (state == RecorderState.PAUSED) {
            return "cima: menu";
        }
        return "baixo: sai";
    }
}
