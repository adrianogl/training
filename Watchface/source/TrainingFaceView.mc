import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class TrainingFaceView extends WatchUi.WatchFace {
    private var _data;
    private var _awake = true;
    private var _burnInProtection = false;
    private var _refreshedMinute = -1;
    private var _scale = 1.0;
    private var _cx = 227;
    private var _cy = 227;
    private var _fonts = {};

    function initialize() {
        WatchFace.initialize();
        _data = new FaceData();
    }

    function onLayout(dc) {
        _scale = dc.getWidth() / Layout.REFERENCE_SIZE;
        _cx = dc.getWidth() / 2;
        _cy = dc.getHeight() / 2;
        var settings = System.getDeviceSettings();
        _burnInProtection = (settings has :requiresBurnInProtection) && settings.requiresBurnInProtection;
        loadFonts();
    }

    private function loadFonts() {
        var specs = FontSpecs.ALL;
        var keys = specs.keys();
        for (var i = 0; i < keys.size(); i++) {
            var spec = specs[keys[i]];
            _fonts[keys[i]] = vectorFont(spec[0], s(spec[1]), spec[2]);
        }
    }

    private function vectorFont(face, size, fallback) {
        if (Graphics has :getVectorFont) {
            var font = Graphics.getVectorFont({ :face => face, :size => size });
            if (font != null) {
                return font;
            }
        }
        return fallback;
    }

    private function font(key) {
        return _fonts[key];
    }

    function onShow() {
        invalidateData();
    }

    function invalidateData() {
        _refreshedMinute = -1;
    }

    function onEnterSleep() {
        _awake = false;
        WatchUi.requestUpdate();
    }

    function onExitSleep() {
        _awake = true;
        invalidateData();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        var clock = System.getClockTime();
        if (clock.min != _refreshedMinute) {
            _data.refresh();
            _refreshedMinute = clock.min;
        }
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(Theme.BG, Theme.BG);
        dc.clear();
        if (!_awake && _burnInProtection) {
            drawAlwaysOn(dc, clock);
        } else {
            drawActive(dc, clock, _awake);
        }
    }

    private function drawActive(dc, clock, showSeconds) {
        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        if (showSeconds) {
            drawSecondsRing(dc, clock.sec);
        }
        drawCentered(dc, 76, font(:date), Format.dateLine(today), Theme.DIM);
        drawWeatherAndBattery(dc, 114);
        drawClock(dc, s(214), clock, showSeconds, Theme.TXT, 0, font(:time));
        drawDividers(dc);
        drawReadiness(dc);
        drawVo2(dc);
        drawWeeklyVolume(dc);
        drawWorkout(dc);
        drawRace(dc, today);
    }

    private function drawAlwaysOn(dc, clock) {
        var shift = Layout.AOD_SHIFTS[clock.min % Layout.AOD_SHIFTS.size()];
        var dx = s(shift[0]);
        var dy = s(shift[1]);
        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        drawPx(dc, _cx + dx, s(150) + dy, font(:date), Format.dateLine(today), Theme.AOD_DIM, Graphics.TEXT_JUSTIFY_CENTER);
        drawClock(dc, s(250) + dy, clock, false, Theme.AOD_TIME, dx, font(:aodTime));
        if (_data.readiness != null) {
            var readiness = Texts.READINESS + " " + _data.readiness;
            drawPx(dc, _cx + dx, s(300) + dy, font(:race), readiness, Theme.AOD_READINESS, Graphics.TEXT_JUSTIFY_CENTER);
        }
        var days = raceDaysLeft(today);
        if (days != null) {
            var line = Texts.RACE_IN + " " + Format.daysCountdown(days);
            drawPx(dc, _cx + dx, s(334) + dy, font(:race), line, Theme.AOD_ORANGE, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawSecondsRing(dc, second) {
        for (var i = 0; i < 60; i++) {
            var major = i % 5 == 0;
            var inner = 210;
            var width = 2;
            if (major) {
                inner = 205;
                width = 3;
            }
            var color = Theme.FAINT;
            if (i <= second) {
                color = Theme.LIME;
            }
            var angle = Math.toRadians(i * 6 - 90);
            var cos = Math.cos(angle);
            var sin = Math.sin(angle);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(max(1, s(width)));
            dc.drawLine(
                _cx + inner * _scale * cos, _cy + inner * _scale * sin,
                _cx + 219 * _scale * cos, _cy + 219 * _scale * sin
            );
        }
    }

    private function drawWeatherAndBattery(dc, baseline) {
        var temperature = Texts.NO_VALUE;
        if (_data.temperature != null) {
            temperature = Format.temperature(_data.temperature);
        }
        drawAt(dc, 160, baseline, font(:temperature), temperature, Theme.TXT, Graphics.TEXT_JUSTIFY_RIGHT);

        var dropColor = Theme.BLUE;
        var humidityColor = Theme.DIM;
        if (_data.dewPoint != null && DewPoint.bandIndex(_data.dewPoint) > 0) {
            dropColor = DewPoint.color(_data.dewPoint);
            humidityColor = dropColor;
        }
        dc.setColor(dropColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(s(170), s(baseline - 6), max(2, s(5)));
        dc.fillPolygon([[s(165), s(baseline - 7)], [s(175), s(baseline - 7)], [s(170), s(baseline - 18)]]);

        var humidity = Texts.NO_VALUE;
        if (_data.humidity != null) {
            humidity = Format.percent(_data.humidity);
        }
        drawAt(dc, 180, baseline, font(:humidity), humidity, humidityColor, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(1, s(2)));
        dc.drawLine(s(238), s(baseline - 22), s(238), s(baseline + 2));

        drawBattery(dc, 250, baseline);
    }

    private function drawBattery(dc, x, baseline) {
        var pct = 0;
        if (_data.battery != null) {
            pct = _data.battery.toNumber();
        }
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(1, s(2)));
        dc.drawRoundedRectangle(s(x), s(baseline - 11), s(22), s(12), s(3));
        dc.fillRectangle(s(x + 22), s(baseline - 8), max(2, s(3)), s(6));
        var fill = (s(18) * pct / 100).toNumber();
        if (fill > 0) {
            dc.fillRectangle(s(x + 2), s(baseline - 9), fill, s(8));
        }
        drawAt(dc, x + 30, baseline, font(:battery), pct + "%", Theme.TXT, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawClock(dc, baselinePx, clock, showSeconds, color, offsetPx, mainFont) {
        var secondsFont = font(:seconds);
        var main = Format.hoursMinutes(clock);
        var mainWidth = dc.getTextWidthInPixels(main, mainFont);
        var gap = s(5);
        var total = mainWidth;
        var secs = Format.seconds(clock);
        if (showSeconds) {
            total = total + gap + dc.getTextWidthInPixels(secs, secondsFont);
        }
        var left = _cx + offsetPx - total / 2;
        drawPx(dc, left, baselinePx, mainFont, main, color, Graphics.TEXT_JUSTIFY_LEFT);
        if (showSeconds) {
            drawPx(dc, left + mainWidth + gap, baselinePx, secondsFont, secs, Theme.LIME, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    private function drawDividers(dc) {
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(1, s(2)));
        dc.drawLine(s(174), s(234), s(174), s(302));
        dc.drawLine(s(280), s(234), s(280), s(302));
    }

    private function drawReadiness(dc) {
        var score = _data.readiness;
        var color = Theme.DIM;
        var verdict = Texts.READINESS;
        if (score != null) {
            color = bandColor(score);
            verdict = bandVerdict(score);
        }
        var text = Texts.NO_VALUE;
        if (score != null) {
            text = score.toString();
        }
        var valueFont = font(:statValue);
        var tagGap = s(4);
        var width = dc.getTextWidthInPixels(text, valueFont);
        var left = s(121) - (width + tagGap + aiTagWidth(dc)) / 2;
        drawPx(dc, left, s(258), valueFont, text, color, Graphics.TEXT_JUSTIFY_LEFT);
        drawAiTag(dc, left + width + tagGap, s(258));
        drawAt(dc, 121, 282, font(:label), verdict, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
        drawReadinessRuler(dc, score);
    }

    private function drawReadinessRuler(dc, score) {
        var left = 86;
        var width = 70.0;
        var y = s(294);
        var height = max(2, s(5));
        var bands = [
            [0, ReadinessBands.MODERATE_FROM, Theme.REST_TRACK],
            [ReadinessBands.MODERATE_FROM, ReadinessBands.HARD_FROM, Theme.MODERATE_TRACK],
            [ReadinessBands.HARD_FROM, 100, Theme.HARD_TRACK]
        ];
        for (var i = 0; i < bands.size(); i++) {
            var band = bands[i];
            var x0 = s(left + width * band[0] / 100.0) + 1;
            var x1 = s(left + width * band[1] / 100.0) - 1;
            dc.setColor(band[2], Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x0, y, max(2, x1 - x0), height, height / 2);
        }
        if (score == null) {
            return;
        }
        var markerX = s(left + width * score / 100.0);
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(markerX, y + height / 2, max(3, s(7)));
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(markerX, y + height / 2, max(2, s(5)));
    }

    private function bandColor(score) {
        if (score >= ReadinessBands.HARD_FROM) {
            return Theme.HARD;
        }
        if (score >= ReadinessBands.MODERATE_FROM) {
            return Theme.MODERATE;
        }
        return Theme.REST;
    }

    private function bandVerdict(score) {
        if (score >= ReadinessBands.HARD_FROM) {
            return Texts.VERDICT_HARD;
        }
        if (score >= ReadinessBands.MODERATE_FROM) {
            return Texts.VERDICT_MODERATE;
        }
        return Texts.VERDICT_REST;
    }

    private function drawVo2(dc) {
        var vo2 = Texts.NO_VALUE;
        if (_data.vo2max != null) {
            vo2 = Format.decimalComma(_data.vo2max.toFloat(), "%.1f");
        }
        drawCentered(dc, 258, font(:statValue), vo2, Theme.TXT);
        drawCentered(dc, 282, font(:label), Texts.VO2, Theme.DIM);
        var delta = _data.vo2Delta;
        if (delta == null) {
            return;
        }
        var color = Theme.HARD;
        var up = delta >= 0;
        if (!up) {
            color = Theme.REST;
            delta = -delta;
        }
        var text = Format.decimalComma(delta.toFloat(), "%.1f") + " · " + Texts.THREE_MONTHS;
        var deltaFont = font(:delta);
        var arrow = s(9);
        var gap = s(4);
        var total = arrow + gap + dc.getTextWidthInPixels(text, deltaFont);
        var left = _cx - total / 2;
        var baseline = s(300);
        var top = baseline - s(10);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (up) {
            dc.fillPolygon([[left, baseline - s(1)], [left + arrow, baseline - s(1)], [left + arrow / 2, top]]);
        } else {
            dc.fillPolygon([[left, top], [left + arrow, top], [left + arrow / 2, baseline - s(1)]]);
        }
        drawPx(dc, left + arrow + gap, baseline, deltaFont, text, color, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawWeeklyVolume(dc) {
        var doneKm = 0.0;
        if (_data.weeklyRunMeters != null) {
            doneKm = _data.weeklyRunMeters.toFloat() / 1000.0;
        }
        var goalKm = _data.weekGoalKm.toFloat();
        var planKm = _data.weekPlannedKm;
        var reference = goalKm;
        if (planKm != null) {
            planKm = planKm.toFloat();
            reference = planKm;
        }
        var doneFont = font(:statValue);
        var done = Format.decimalComma(doneKm, "%.1f");
        var refFont = font(:statGoal);
        var ref = "/" + Math.round(reference).toNumber();
        var doneWidth = dc.getTextWidthInPixels(done, doneFont);
        var total = doneWidth + dc.getTextWidthInPixels(ref, refFont);
        var left = s(333) - total / 2;
        drawPx(dc, left, s(258), doneFont, done, Theme.HARD, Graphics.TEXT_JUSTIFY_LEFT);
        drawPx(dc, left + doneWidth, s(258), refFont, ref, Theme.DIM, Graphics.TEXT_JUSTIFY_LEFT);
        drawAt(dc, 333, 282, font(:label), Texts.WEEK_KM, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        var scale = goalKm;
        if (planKm != null && planKm > scale) {
            scale = planKm;
        }
        if (doneKm > scale) {
            scale = doneKm;
        }
        scale = scale * Defaults.KM_SCALE_MARGIN;
        if (scale <= 0) {
            return;
        }
        var barLeft = s(298);
        var barWidth = s(70);
        var y = s(294);
        var height = max(2, s(5));
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barLeft, y, barWidth, height, height / 2);
        if (planKm != null && planKm > 0) {
            dc.setColor(Theme.PLAN, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            dc.drawRoundedRectangle(barLeft, y, max(height, (barWidth * planKm / scale).toNumber()), height, height / 2);
        }
        var filled = (barWidth * doneKm / scale).toNumber();
        if (filled > 0) {
            dc.setColor(Theme.HARD, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barLeft, y, max(filled, height), height, height / 2);
        }
        if (goalKm > 0) {
            var goalX = barLeft + (barWidth * goalKm / scale).toNumber();
            dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(max(1, s(2)));
            dc.drawLine(goalX, s(290), goalX, s(303));
        }
    }

    private function drawWorkout(dc) {
        if (_data.workout == null) {
            return;
        }
        drawCentered(dc, 330, font(:race), _data.workout.toUpper(), Theme.LIME);
        var shape = _data.workoutShape;
        if (shape == null || shape.size() == 0) {
            return;
        }
        var total = 0;
        for (var i = 0; i < shape.size(); i++) {
            total += shape[i][0];
        }
        if (total <= 0) {
            return;
        }
        var x = 132.0;
        var width = 190.0;
        for (var i = 0; i < shape.size(); i++) {
            var step = shape[i];
            var zone = step[1];
            if (zone < 1) {
                zone = 1;
            }
            if (zone > Theme.ZONES.size()) {
                zone = Theme.ZONES.size();
            }
            var stepWidth = width * step[0] / total;
            var height = s(zone * 3.4);
            dc.setColor(Theme.ZONES[zone - 1], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(s(x), s(352) - height, max(1, s(stepWidth - 1.5)), height);
            x += stepWidth;
        }
        if (_data.workoutTip != null) {
            drawCentered(dc, 368, font(:delta), _data.workoutTip, Theme.MODERATE);
        }
    }

    private function drawRace(dc, today) {
        var days = raceDaysLeft(today);
        if (days == null) {
            return;
        }
        var date = _data.raceDate;
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(1, s(2)));
        dc.drawLine(s(150), s(376), s(304), s(376));

        var name = _data.raceName.toUpper();
        if (name.length() > Defaults.RACE_NAME_MAX) {
            name = name.substring(0, Defaults.RACE_NAME_MAX);
        }
        var line = name + " · " + Format.shortDate(date[:day], date[:month]) + " · " + Format.daysCountdown(days);
        drawCentered(dc, 392, font(:race), line, Theme.ORANGE);

        var prediction = Texts.NO_VALUE;
        if (_data.racePredictionSeconds != null) {
            prediction = Format.duration(_data.racePredictionSeconds);
        }
        var goal = "";
        if (_data.raceGoal != null) {
            goal = " / " + Texts.GOAL + " " + _data.raceGoal;
        }
        var predictionFont = font(:raceValue);
        var goalFont = font(:raceGoal);
        var predictionWidth = dc.getTextWidthInPixels(prediction, predictionFont);
        var total = predictionWidth + dc.getTextWidthInPixels(goal, goalFont);
        var left = _cx - total / 2;
        drawPx(dc, left, s(418), predictionFont, prediction, Theme.ORANGE, Graphics.TEXT_JUSTIFY_LEFT);
        drawPx(dc, left + predictionWidth, s(418), goalFont, goal, Theme.DIM, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function raceDaysLeft(today) {
        var name = _data.raceName;
        var date = _data.raceDate;
        if (name == null || name.length() == 0 || date == null) {
            return null;
        }
        var days = CivilDate.daysUntil(date, today);
        if (days < 0) {
            return null;
        }
        return days;
    }

    private function aiTagWidth(dc) {
        return dc.getTextWidthInPixels("AI", font(:tag));
    }

    private function drawAiTag(dc, left, baselinePx) {
        drawPx(dc, left, baselinePx, font(:tag), "AI", Theme.LIME, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawCentered(dc, baseline, font, text, color) {
        drawAt(dc, 227, baseline, font, text, color, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawAt(dc, x, baseline, font, text, color, justify) {
        drawPx(dc, s(x), s(baseline), font, text, color, justify);
    }

    private function drawPx(dc, x, baselinePx, font, text, color, justify) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, baselinePx - Graphics.getFontAscent(font), font, text, justify);
    }

    private function s(value) {
        return (value * _scale).toNumber();
    }

    private function max(a, b) {
        if (a > b) {
            return a;
        }
        return b;
    }
}
