import Toybox.Lang;

module Format {
    function dateLine(info) {
        return Texts.WEEKDAYS[info.day_of_week - 1] + " " + info.day + " " + Texts.MONTHS[info.month - 1];
    }

    function hoursMinutes(clock) {
        return clock.hour.format("%02d") + ":" + clock.min.format("%02d");
    }

    function seconds(clock) {
        return clock.sec.format("%02d");
    }

    function decimalComma(value, pattern) {
        var text = value.format(pattern);
        var dot = text.find(".");
        if (dot == null) {
            return text;
        }
        return text.substring(0, dot) + "," + text.substring(dot + 1, text.length());
    }

    function temperature(celsius) {
        return celsius.toNumber() + "°";
    }

    function percent(value) {
        return value.toNumber() + "%";
    }

    function isoDate(info) {
        return info.year.format("%04d") + "-" + info.month.format("%02d") + "-" + info.day.format("%02d");
    }

    function eventDay(eventInfo, todayInfo) {
        var days = CivilDate.daysBetween(todayInfo, eventInfo);
        if (days <= 0) {
            return Texts.TODAY;
        }
        if (days == 1) {
            return Texts.TOMORROW;
        }
        return Texts.WEEKDAYS[eventInfo.day_of_week - 1];
    }

    function eventTime(eventInfo) {
        return eventInfo.hour.format("%02d") + ":" + eventInfo.min.format("%02d");
    }

    function timeUntil(seconds) {
        var minutes = (seconds + 59) / 60;
        if (minutes < 60) {
            return Texts.IN + " " + minutes + " " + Texts.MINUTES;
        }
        var hours = minutes / 60;
        var rest = minutes % 60;
        if (rest == 0) {
            return Texts.IN + " " + hours + " " + Texts.HOURS;
        }
        return Texts.IN + " " + hours + " " + Texts.HOURS + " " + rest.format("%02d");
    }
}
