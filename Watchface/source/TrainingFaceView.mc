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
        drawCentered(dc, 84, font(:date), Format.dateLine(today), Theme.DIM);
        drawWeatherAndBattery(dc, 124);
        drawClock(dc, s(212), clock, showSeconds, Theme.TXT, 0, font(:time));
        drawStats(dc, 266, 296);
        drawRace(dc, today);
        drawNextEvent(dc, 426);
    }

    private function drawAlwaysOn(dc, clock) {
        var shift = Layout.AOD_SHIFTS[clock.min % Layout.AOD_SHIFTS.size()];
        var dx = s(shift[0]);
        var dy = s(shift[1]);
        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        drawPx(dc, _cx + dx, s(140) + dy, font(:date), Format.dateLine(today), Theme.AOD_DIM, Graphics.TEXT_JUSTIFY_CENTER);
        drawClock(dc, s(240) + dy, clock, false, Theme.AOD_TIME, dx, font(:aodTime));
        var days = raceDaysLeft(today);
        if (days != null) {
            var line = Texts.RACE_IN + " " + Format.daysCountdown(days);
            drawPx(dc, _cx + dx, s(292) + dy, font(:race), line, Theme.AOD_ORANGE, Graphics.TEXT_JUSTIFY_CENTER);
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

    private function drawStats(dc, valueBaseline, labelBaseline) {
        var vo2 = Texts.NO_VALUE;
        if (_data.vo2max != null) {
            vo2 = _data.vo2max.toString();
        }
        drawAt(dc, 124, valueBaseline, font(:statValue), vo2, Theme.TXT, Graphics.TEXT_JUSTIFY_CENTER);
        drawAt(dc, 124, labelBaseline, font(:label), Texts.VO2, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        drawWeeklyVolume(dc, valueBaseline);
        drawAt(dc, 227, labelBaseline, font(:label), Texts.WEEK_KM, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        var scoreFont = font(:statValue);
        var score = Texts.NO_VALUE;
        var scoreColor = Theme.DIM;
        if (_data.readiness != null) {
            score = _data.readiness.toString();
            scoreColor = Theme.GREEN;
        }
        var scoreWidth = dc.getTextWidthInPixels(score, scoreFont);
        var tagGap = s(5);
        var scoreLeft = s(330) - (scoreWidth + tagGap + aiTagWidth(dc)) / 2;
        drawPx(dc, scoreLeft, s(valueBaseline), scoreFont, score, scoreColor, Graphics.TEXT_JUSTIFY_LEFT);
        drawAiTag(dc, scoreLeft + scoreWidth + tagGap, s(valueBaseline));
        drawAt(dc, 330, labelBaseline, font(:label), Texts.READINESS, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawWeeklyVolume(dc, baseline) {
        var goalKm = Settings.weeklyGoalKm();
        var meters = 0.0;
        if (_data.weeklyRunMeters != null) {
            meters = _data.weeklyRunMeters.toFloat();
        }
        var doneFont = font(:statValue);
        var done = Format.kilometers(meters);
        var goalFont = font(:statGoal);
        var goal = "/" + goalKm;
        var doneWidth = dc.getTextWidthInPixels(done, doneFont);
        var total = doneWidth + dc.getTextWidthInPixels(goal, goalFont);
        var left = _cx - total / 2;
        drawPx(dc, left, s(baseline), doneFont, done, Theme.LIME, Graphics.TEXT_JUSTIFY_LEFT);
        drawPx(dc, left + doneWidth, s(baseline), goalFont, goal, Theme.DIM, Graphics.TEXT_JUSTIFY_LEFT);

        var barWidth = s(92);
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

    private function drawRace(dc, today) {
        var date = CivilDate.parseIsoDate(Settings.raceDate());
        var name = Settings.raceName();
        var days = raceDaysLeft(today);
        if (days == null || date == null) {
            return;
        }
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(1, s(2)));
        dc.drawLine(s(140), s(312), s(314), s(312));

        var line = name.toUpper() + " · " + Format.shortDate(date[:day], date[:month]) + " · " + Format.daysCountdown(days);
        drawCentered(dc, 337, font(:race), line, Theme.ORANGE);

        var goal = Settings.raceGoal();
        if (goal.length() == 0) {
            goal = Texts.NO_VALUE;
        }
        drawAt(dc, 150, 374, font(:raceValue), goal, Theme.TXT, Graphics.TEXT_JUSTIFY_CENTER);
        drawAt(dc, 150, 395, font(:label), Texts.GOAL, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        var prediction = Texts.NO_VALUE;
        if (_data.racePredictionSeconds != null) {
            prediction = Format.duration(_data.racePredictionSeconds);
        }
        drawAt(dc, 304, 374, font(:raceValue), prediction, Theme.ORANGE, Graphics.TEXT_JUSTIFY_CENTER);
        drawAt(dc, 304, 395, font(:label), Texts.PREDICTION, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
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
        var eventFont = font(:meeting);
        var text = _data.nextEventTime.toString();
        var iconWidth = s(14);
        var gap = s(8);
        var total = iconWidth + gap + dc.getTextWidthInPixels(text, eventFont);
        var left = _cx - total / 2;
        var bottom = s(baseline);
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(1, s(2)));
        dc.drawRoundedRectangle(left, bottom - s(13), iconWidth, s(13), s(2));
        dc.drawLine(left, bottom - s(9), left + iconWidth, bottom - s(9));
        drawPx(dc, left + iconWidth + gap, bottom, eventFont, text, Theme.TXT, Graphics.TEXT_JUSTIFY_LEFT);
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
