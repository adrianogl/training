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
    private var _fonts = {};
    private var _timeActive = null;
    private var _timeAlwaysOn = null;
    private var _timeSeconds = null;

    function initialize() {
        WatchFace.initialize();
        _data = new FaceData();
    }

    function onLayout(dc) {
        _scale = dc.getWidth() / Layout.REFERENCE_SIZE;
        _cx = dc.getWidth() / 2;
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
        _timeActive = WatchUi.loadResource(Rez.Fonts.TimeActive);
        _timeAlwaysOn = WatchUi.loadResource(Rez.Fonts.TimeAlwaysOn);
        _timeSeconds = WatchUi.loadResource(Rez.Fonts.TimeSeconds);
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
        drawLogoAndDate(dc, 0, 0, today, Layout.LOGO_TOP, Layout.LOGO_WIDTH, Layout.LOGO_HEIGHT, Layout.DATE_BASELINE, font(:date), Theme.DIM, false);
        drawWeatherAndBattery(dc, s(Layout.WEATHER_BASELINE));
        drawClock(dc, s(Layout.CLOCK_BASELINE), clock, showSeconds, Theme.TXT, 0, _timeActive);
        drawDividers(dc);
        drawReadiness(dc);
        drawVo2(dc);
        drawWeeklyVolume(dc);
        drawEvent(dc, 0, 0, today, Layout.EVENT_LABEL_BASELINE, Layout.EVENT_TITLE_BASELINE, Layout.EVENT_TITLE_MAX, false);
    }

    private function drawAlwaysOn(dc, clock) {
        var shift = Layout.AOD_SHIFTS[clock.min % Layout.AOD_SHIFTS.size()];
        var dx = s(shift[0]);
        var dy = s(shift[1]);
        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        drawLogoAndDate(dc, dx, dy, today, Layout.AOD_LOGO_TOP, Layout.AOD_LOGO_WIDTH, Layout.AOD_LOGO_HEIGHT, Layout.AOD_DATE_BASELINE, font(:aodDate), Theme.AOD_DIM, true);
        drawClock(dc, s(Layout.AOD_CLOCK_BASELINE) + dy, clock, false, Theme.AOD_TIME, dx, _timeAlwaysOn);
        drawEvent(dc, dx, dy, today, Layout.AOD_EVENT_LABEL_BASELINE, Layout.AOD_EVENT_TITLE_BASELINE, Layout.AOD_EVENT_TITLE_MAX, true);
    }

    private function drawLogoAndDate(dc, dx, dy, today, logoTop, logoWidth, logoHeight, dateBaseline, dateFont, dateColor, alwaysOn) {
        var text = Format.dateLine(today);
        var width = s(logoWidth);
        var gap = s(Layout.LOGO_GAP);
        var total = width + gap + dc.getTextWidthInPixels(text, dateFont);
        var left = _cx + dx - total / 2;
        drawLogo(dc, left, s(logoTop) + dy, width, s(logoHeight), alwaysOn);
        drawPx(dc, left + width + gap, s(dateBaseline) + dy, dateFont, text, dateColor, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawLogo(dc, left, top, width, height, alwaysOn) {
        var outer = Theme.LIME;
        if (alwaysOn) {
            outer = Theme.AOD_LOGO;
        }
        dc.setColor(outer, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(2, s(3)));
        dc.drawRoundedRectangle(left, top, width, height, height / 2);
        if (alwaysOn) {
            return;
        }
        var inset = width / 6;
        var innerHeight = height / 2;
        dc.setColor(Theme.LIME_LANE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(left + inset, top + (height - innerHeight) / 2, width - inset * 2, innerHeight, innerHeight / 2);
        dc.setColor(Theme.RUNNER, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(left + width * 5 / 6, top + 1, max(2, s(3)));
    }

    private function drawWeatherAndBattery(dc, baseline) {
        var temperature = Texts.NO_VALUE;
        if (_data.temperature != null) {
            temperature = Format.temperature(_data.temperature);
        }
        var humidity = Texts.NO_VALUE;
        if (_data.humidity != null) {
            humidity = Format.percent(_data.humidity);
        }
        var pct = 0;
        if (_data.battery != null) {
            pct = _data.battery.toNumber();
        }
        var batteryText = pct + "%";
        var temperatureFont = font(:temperature);
        var humidityFont = font(:humidity);
        var batteryFont = font(:battery);
        var temperatureWidth = dc.getTextWidthInPixels(temperature, temperatureFont);
        var humidityWidth = dc.getTextWidthInPixels(humidity, humidityFont);
        var drop = s(14);
        var icon = s(27);
        var total = temperatureWidth + s(6) + drop + s(4) + humidityWidth + s(13) + s(13) + icon + s(6)
            + dc.getTextWidthInPixels(batteryText, batteryFont);
        var x = _cx - total / 2;

        drawPx(dc, x, baseline, temperatureFont, temperature, Theme.TXT, Graphics.TEXT_JUSTIFY_LEFT);
        x += temperatureWidth + s(6);

        var dropColor = Theme.BLUE;
        var humidityColor = Theme.TXT_SOFT;
        if (_data.dewPoint != null && DewPoint.bandIndex(_data.dewPoint) > 0) {
            dropColor = DewPoint.color(_data.dewPoint);
            humidityColor = dropColor;
        }
        var dropCenter = x + drop / 2;
        dc.setColor(dropColor, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dropCenter, baseline - s(7), max(2, s(6)));
        dc.fillPolygon([[dropCenter - s(6), baseline - s(8)], [dropCenter + s(6), baseline - s(8)], [dropCenter, baseline - s(21)]]);
        x += drop + s(4);

        drawPx(dc, x, baseline, humidityFont, humidity, humidityColor, Graphics.TEXT_JUSTIFY_LEFT);
        x += humidityWidth + s(13);

        dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(1, s(2)));
        dc.drawLine(x, baseline - s(26), x, baseline + s(4));
        x += s(13);

        drawBattery(dc, x, baseline, pct);
        drawPx(dc, x + icon + s(6), baseline, batteryFont, batteryText, Theme.TXT, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawBattery(dc, x, baseline, pct) {
        var top = baseline - s(19);
        var width = s(24);
        var height = s(14);
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(1, s(2)));
        dc.drawRoundedRectangle(x, top, width, height, s(3));
        dc.fillRectangle(x + width, top + s(4), max(2, s(3)), s(6));
        var fill = ((width - s(6)) * pct / 100).toNumber();
        if (fill > 0) {
            dc.fillRectangle(x + s(3), top + s(3), fill, height - s(6));
        }
    }

    private function drawClock(dc, baselinePx, clock, showSeconds, color, offsetPx, mainFont) {
        var main = Format.hoursMinutes(clock);
        var mainWidth = dc.getTextWidthInPixels(main, mainFont);
        var left = _cx + offsetPx - mainWidth / 2;
        drawPx(dc, left, baselinePx, mainFont, main, color, Graphics.TEXT_JUSTIFY_LEFT);
        if (showSeconds) {
            drawPx(dc, left + mainWidth + s(Layout.SECONDS_GAP), baselinePx, _timeSeconds, Format.seconds(clock), Theme.LIME, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    private function drawDividers(dc) {
        dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(max(1, s(2)));
        dc.drawLine(s(Layout.LEFT_DIVIDER), s(Layout.DIVIDER_TOP), s(Layout.LEFT_DIVIDER), s(Layout.DIVIDER_BOTTOM));
        dc.drawLine(s(Layout.RIGHT_DIVIDER), s(Layout.DIVIDER_TOP), s(Layout.RIGHT_DIVIDER), s(Layout.DIVIDER_BOTTOM));
    }

    private function drawReadiness(dc) {
        var score = _data.readiness;
        var color = Theme.TXT;
        var verdict = Texts.READINESS;
        var text = Texts.NO_VALUE;
        if (score != null) {
            color = bandColor(score);
            verdict = bandVerdict(score);
            text = score.toString();
        } else if (_data.missingNight) {
            verdict = Texts.NO_NIGHT;
        }
        var valueFont = font(:statValue);
        var tagFont = font(:tag);
        var tagGap = s(5);
        var width = dc.getTextWidthInPixels(text, valueFont);
        var left = s(Layout.LEFT_COLUMN) - (width + tagGap + dc.getTextWidthInPixels(Texts.AI, tagFont)) / 2;
        drawPx(dc, left, s(Layout.STAT_BASELINE), valueFont, text, color, Graphics.TEXT_JUSTIFY_LEFT);
        drawPx(dc, left + width + tagGap, s(Layout.STAT_BASELINE - 2), tagFont, Texts.AI, Theme.LIME, Graphics.TEXT_JUSTIFY_LEFT);
        drawAt(dc, Layout.LEFT_COLUMN, Layout.LABEL_BASELINE, font(:label), verdict, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
        drawReadinessRuler(dc, score);
    }

    private function drawReadinessRuler(dc, score) {
        var left = Layout.READINESS_BAR_LEFT;
        var width = Layout.READINESS_BAR_WIDTH;
        var y = s(Layout.BAR_TOP);
        var height = max(2, s(Layout.BAR_HEIGHT));
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
        dc.fillCircle(markerX, y + height / 2, max(3, s(8)));
        dc.setColor(Theme.TXT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(markerX, y + height / 2, max(2, s(6)));
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
        drawAt(dc, 227, Layout.STAT_BASELINE, font(:statValue), vo2, Theme.TXT, Graphics.TEXT_JUSTIFY_CENTER);
        drawAt(dc, 227, Layout.LABEL_BASELINE, font(:label), Texts.VO2, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
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
        var text = Format.decimalComma(delta.toFloat(), "%.1f") + Texts.SEPARATOR + Texts.THREE_MONTHS;
        var deltaFont = font(:delta);
        var arrow = s(10);
        var gap = s(4);
        var total = arrow + gap + dc.getTextWidthInPixels(text, deltaFont);
        var left = _cx - total / 2;
        var baseline = s(Layout.DELTA_BASELINE);
        var top = baseline - s(11);
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
        var left = s(Layout.RIGHT_COLUMN) - total / 2;
        drawPx(dc, left, s(Layout.STAT_BASELINE), doneFont, done, Theme.HARD, Graphics.TEXT_JUSTIFY_LEFT);
        drawPx(dc, left + doneWidth, s(Layout.STAT_BASELINE), refFont, ref, Theme.DIM, Graphics.TEXT_JUSTIFY_LEFT);
        drawAt(dc, Layout.RIGHT_COLUMN, Layout.LABEL_BASELINE, font(:label), Texts.WEEK_KM, Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

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
        var barLeft = s(Layout.KM_BAR_LEFT);
        var barWidth = s(Layout.KM_BAR_WIDTH);
        var y = s(Layout.BAR_TOP);
        var height = max(2, s(Layout.BAR_HEIGHT));
        dc.setColor(Theme.LINE, Graphics.COLOR_TRANSPARENT);
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
            dc.drawLine(goalX, y - s(5), goalX, y + height + s(5));
        }
    }

    private function drawEvent(dc, dx, dy, today, labelBaseline, titleBaseline, titleMax, alwaysOn) {
        var start = _data.eventStart;
        var title = _data.eventTitle;
        if (start == null || title == null) {
            return;
        }
        var nowSeconds = Time.now().value();
        if (start <= nowSeconds) {
            return;
        }
        var info = Gregorian.info(new Time.Moment(start), Time.FORMAT_SHORT);
        var day = Format.eventDay(info, today);
        var time = Format.eventTime(info);
        var relative = "";
        if (day.equals(Texts.TODAY)) {
            relative = Texts.SEPARATOR + Format.timeUntil(start - nowSeconds);
        }
        var labelFont = font(:eventLabel);
        var dayColor = Theme.DIM;
        var timeColor = Theme.LIME;
        if (alwaysOn) {
            dayColor = Theme.AOD_DIM;
            timeColor = Theme.AOD_DIM;
        }
        var dayText = day + " ";
        var dayWidth = dc.getTextWidthInPixels(dayText, labelFont);
        var timeWidth = dc.getTextWidthInPixels(time, labelFont);
        var total = dayWidth + timeWidth + dc.getTextWidthInPixels(relative, labelFont);
        var left = _cx + dx - total / 2;
        var baseline = s(labelBaseline) + dy;
        drawPx(dc, left, baseline, labelFont, dayText, dayColor, Graphics.TEXT_JUSTIFY_LEFT);
        drawPx(dc, left + dayWidth, baseline, labelFont, time, timeColor, Graphics.TEXT_JUSTIFY_LEFT);
        if (relative.length() > 0) {
            drawPx(dc, left + dayWidth + timeWidth, baseline, labelFont, relative, dayColor, Graphics.TEXT_JUSTIFY_LEFT);
        }

        var titleFonts = [font(:eventTitle), font(:eventTitleSmall)];
        var titleColor = Theme.TXT;
        if (alwaysOn) {
            titleFonts = [font(:aodEventTitle)];
            titleColor = Theme.DIM;
        }
        var fitted = fitLine(dc, title, titleFonts, s(titleMax));
        drawPx(dc, _cx + dx, s(titleBaseline) + dy, fitted[1], fitted[0], titleColor, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function fitLine(dc, text, fonts, maxWidth) {
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxWidth) {
                return [text, fonts[i]];
            }
        }
        var smallest = fonts[fonts.size() - 1];
        var cut = text;
        while (cut.length() > 1) {
            var space = lastSpace(cut);
            if (space > 0) {
                cut = trimEnd(cut.substring(0, space));
            } else {
                cut = cut.substring(0, cut.length() - 1);
            }
            var candidate = cut + Texts.ELLIPSIS;
            if (dc.getTextWidthInPixels(candidate, smallest) <= maxWidth) {
                return [candidate, smallest];
            }
        }
        return [cut + Texts.ELLIPSIS, smallest];
    }

    private function lastSpace(text) {
        var chars = text.toCharArray();
        for (var i = chars.size() - 1; i > 0; i--) {
            if (chars[i] == ' ') {
                return i;
            }
        }
        return -1;
    }

    private function trimEnd(text) {
        var chars = text.toCharArray();
        var end = chars.size();
        while (end > 0 && (chars[end - 1] == ' ' || chars[end - 1] == ':' || chars[end - 1] == ',' || chars[end - 1] == '-' || chars[end - 1] == ';')) {
            end--;
        }
        return text.substring(0, end);
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
