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
        drawCentered(dc, 86, Graphics.FONT_XTINY, Format.dateLine(today), Theme.DIM);
        drawWeatherAndBattery(dc, 120);
        drawClock(dc, s(204), clock, showSeconds, Theme.TXT, 0, Graphics.FONT_NUMBER_HOT);
        drawReadiness(dc, 240);
        drawStats(dc, 288, 312);
        drawRace(dc, today);
        drawNextEvent(dc, 418);
    }

    private function drawAlwaysOn(dc, clock) {
        var shift = Layout.AOD_SHIFTS[clock.min % Layout.AOD_SHIFTS.size()];
        var dx = s(shift[0]);
        var dy = s(shift[1]);
        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        drawPx(dc, _cx + dx, s(140) + dy, Graphics.FONT_XTINY, Format.dateLine(today), Theme.AOD_DIM, Graphics.TEXT_JUSTIFY_CENTER);
        drawClock(dc, s(240) + dy, clock, false, Theme.AOD_TIME, dx, Graphics.FONT_NUMBER_MEDIUM);
        var days = raceDaysLeft(today);
        if (days != null) {
            var line = Texts.RACE_IN + " " + Format.daysCountdown(days);
            drawPx(dc, _cx + dx, s(292) + dy, Graphics.FONT_XTINY, line, Theme.AOD_ORANGE, Graphics.TEXT_JUSTIFY_CENTER);
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
        drawAt(dc, 172, baseline, Graphics.FONT_MEDIUM, temperature, Theme.TXT, Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setColor(Theme.BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(s(180), s(baseline - 5), max(2, s(4)));
        dc.fillPolygon([[s(176), s(baseline - 6)], [s(184), s(baseline - 6)], [s(180), s(baseline - 15)]]);

        var humidity = Texts.NO_VALUE;
        if (_data.humidity != null) {
            humidity = Format.percent(_data.humidity);
        }
        drawAt(dc, 190, baseline, Graphics.FONT_SMALL, humidity, Theme.DIM, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(1, s(2)));
        dc.drawLine(s(234), s(baseline - 18), s(234), s(baseline + 2));

        drawBattery(dc, 246, baseline);
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
        drawAt(dc, x + 30, baseline, Graphics.FONT_SMALL, pct + "%", Theme.TXT, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawClock(dc, baselinePx, clock, showSeconds, color, offsetPx, mainFont) {
        var secondsFont = Graphics.FONT_NUMBER_MILD;
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

    private function drawReadiness(dc, baseline) {
        if (_data.readiness != null) {
            var scoreFont = Graphics.FONT_SMALL;
            var verdictFont = Graphics.FONT_XTINY;
            var score = _data.readiness.toString();
            var verdict = "";
            if (_data.readinessVerdict != null) {
                verdict = _data.readinessVerdict.toString();
            }
            var gap = s(8);
            var scoreWidth = dc.getTextWidthInPixels(score, scoreFont);
            var verdictWidth = dc.getTextWidthInPixels(verdict, verdictFont);
            var tagWidth = aiTagWidth(dc);
            var total = scoreWidth + gap + verdictWidth + gap + tagWidth;
            var left = _cx - total / 2;
            drawPx(dc, left, s(baseline), scoreFont, score, Theme.GREEN, Graphics.TEXT_JUSTIFY_LEFT);
            drawPx(dc, left + scoreWidth + gap, s(baseline), verdictFont, verdict, Theme.LIME, Graphics.TEXT_JUSTIFY_LEFT);
            drawAiTag(dc, left + scoreWidth + gap + verdictWidth + gap, s(baseline));
            return;
        }
        if (_data.trainingStatus != null) {
            drawCentered(dc, baseline, Graphics.FONT_SMALL, _data.trainingStatus.toString(), Theme.LIME);
        }
    }

    private function drawStats(dc, valueBaseline, labelBaseline) {
        var vo2 = Texts.NO_VALUE;
        if (_data.vo2max != null) {
            vo2 = _data.vo2max.toString();
        }
        drawAt(dc, 146, valueBaseline, Graphics.FONT_MEDIUM, vo2, Theme.TXT, Graphics.TEXT_JUSTIFY_CENTER);
        drawAt(dc, 146, labelBaseline, Graphics.FONT_XTINY, Texts.VO2, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        drawWeeklyVolume(dc, valueBaseline);
        drawAt(dc, 227, labelBaseline, Graphics.FONT_XTINY, Texts.WEEK_KM, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        if (_data.hrv != null) {
            drawAt(dc, 308, valueBaseline, Graphics.FONT_MEDIUM, _data.hrv.toString(), Theme.TXT, Graphics.TEXT_JUSTIFY_CENTER);
            drawTrend(dc, 334, valueBaseline - 12, _data.hrvTrend);
            drawAt(dc, 308, labelBaseline, Graphics.FONT_XTINY, Texts.HRV, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            var bodyBattery = Texts.NO_VALUE;
            if (_data.bodyBattery != null) {
                bodyBattery = _data.bodyBattery.toString();
            }
            drawAt(dc, 308, valueBaseline, Graphics.FONT_MEDIUM, bodyBattery, Theme.BLUE, Graphics.TEXT_JUSTIFY_CENTER);
            drawAt(dc, 308, labelBaseline, Graphics.FONT_XTINY, Texts.BODY_BATTERY, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawWeeklyVolume(dc, baseline) {
        var goalKm = Settings.weeklyGoalKm();
        var meters = 0.0;
        if (_data.weeklyRunMeters != null) {
            meters = _data.weeklyRunMeters.toFloat();
        }
        var doneFont = Graphics.FONT_MEDIUM;
        var goalFont = Graphics.FONT_SMALL;
        var done = Format.kilometers(meters);
        var goal = "/" + goalKm;
        var doneWidth = dc.getTextWidthInPixels(done, doneFont);
        var total = doneWidth + dc.getTextWidthInPixels(goal, goalFont);
        var left = _cx - total / 2;
        drawPx(dc, left, s(baseline), doneFont, done, Theme.LIME, Graphics.TEXT_JUSTIFY_LEFT);
        drawPx(dc, left + doneWidth, s(baseline), goalFont, goal, Theme.DIM, Graphics.TEXT_JUSTIFY_LEFT);

        var barWidth = s(76);
        var barX = _cx - barWidth / 2;
        var barY = s(baseline + 7);
        var barHeight = max(2, s(4));
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barX, barY, barWidth, barHeight, barHeight / 2);
        var ratio = 0.0;
        if (goalKm > 0) {
            ratio = meters / (goalKm * 1000.0);
        }
        if (ratio > 1.0) {
            ratio = 1.0;
        }
        var filled = (barWidth * ratio).toNumber();
        if (filled > 0) {
            dc.setColor(Theme.LIME, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barX, barY, max(filled, barHeight), barHeight, barHeight / 2);
        }
    }

    private function drawTrend(dc, x, y, trend) {
        if (!(trend instanceof Number) || trend == 0) {
            return;
        }
        if (trend > 0) {
            dc.setColor(Theme.LIME, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[s(x - 5), s(y + 4)], [s(x + 5), s(y + 4)], [s(x), s(y - 5)]]);
        } else {
            dc.setColor(Theme.ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[s(x - 5), s(y - 4)], [s(x + 5), s(y - 4)], [s(x), s(y + 5)]]);
        }
    }

    private function drawRace(dc, today) {
        var date = CivilDate.parseIsoDate(Settings.raceDate());
        var name = Settings.raceName();
        var days = raceDaysLeft(today);
        if (days == null || date == null) {
            return;
        }
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(1, s(2)));
        dc.drawLine(s(150), s(322), s(304), s(322));

        var line = name.toUpper() + " · " + Format.shortDate(date[:day], date[:month]) + " · " + Format.daysCountdown(days);
        drawCentered(dc, 342, Graphics.FONT_XTINY, line, Theme.ORANGE);

        var goal = Settings.raceGoal();
        if (goal.length() == 0) {
            goal = Texts.NO_VALUE;
        }
        drawAt(dc, 170, 370, Graphics.FONT_SMALL, goal, Theme.TXT, Graphics.TEXT_JUSTIFY_CENTER);
        drawAt(dc, 170, 386, Graphics.FONT_XTINY, Texts.GOAL, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        var prediction = Texts.NO_VALUE;
        if (_data.racePredictionSeconds != null) {
            prediction = Format.duration(_data.racePredictionSeconds);
        }
        drawAt(dc, 286, 370, Graphics.FONT_SMALL, prediction, Theme.ORANGE, Graphics.TEXT_JUSTIFY_CENTER);
        drawAt(dc, 286, 386, Graphics.FONT_XTINY, Texts.PREDICTION, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function raceDaysLeft(today) {
        var name = Settings.raceName();
        var date = CivilDate.parseIsoDate(Settings.raceDate());
        if (name == null || name.length() == 0 || date == null) {
            return null;
        }
        var days = CivilDate.daysUntil(date, today);
        if (days < 0) {
            return null;
        }
        return days;
    }

    private function drawNextEvent(dc, baseline) {
        if (_data.nextEventTime == null) {
            return;
        }
        var font = Graphics.FONT_SMALL;
        var text = _data.nextEventTime.toString();
        var iconWidth = s(14);
        var gap = s(8);
        var total = iconWidth + gap + dc.getTextWidthInPixels(text, font);
        var left = _cx - total / 2;
        var bottom = s(baseline);
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(1, s(2)));
        dc.drawRoundedRectangle(left, bottom - s(13), iconWidth, s(13), s(2));
        dc.drawLine(left, bottom - s(9), left + iconWidth, bottom - s(9));
        drawPx(dc, left + iconWidth + gap, bottom, font, text, Theme.TXT, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function aiTagWidth(dc) {
        return dc.getTextWidthInPixels("AI", Graphics.FONT_XTINY) + s(8);
    }

    private function drawAiTag(dc, left, baselinePx) {
        var font = Graphics.FONT_XTINY;
        var width = aiTagWidth(dc);
        var height = Graphics.getFontAscent(font) + s(4);
        dc.setColor(Theme.LIME, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(1, s(2)));
        dc.drawRoundedRectangle(left, baselinePx - height + s(2), width, height, s(4));
        drawPx(dc, left + width / 2, baselinePx, font, "AI", Theme.LIME, Graphics.TEXT_JUSTIFY_CENTER);
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
