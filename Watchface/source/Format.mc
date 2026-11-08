import Toybox.Lang;

module Format {
    function dateLine(info) {
        return Texts.WEEKDAYS[info.day_of_week - 1] + " " + info.day + " " + Texts.MONTHS[info.month - 1];
    }

    function shortDate(day, month) {
        return day + " " + Texts.MONTHS[month - 1];
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

    function kilometers(meters) {
        return decimalComma(meters / 1000.0, "%.1f");
    }

    function duration(totalSeconds) {
        var total = totalSeconds.toNumber();
        var hours = total / 3600;
        var minutes = (total % 3600) / 60;
        var secs = total % 60;
        return hours + ":" + minutes.format("%02d") + ":" + secs.format("%02d");
    }

    function temperature(celsius) {
        return celsius.toNumber() + "°";
    }

    function percent(value) {
        return value.toNumber() + "%";
    }

    function daysCountdown(days) {
        if (days == 0) {
            return Texts.RACE_TODAY;
        }
        if (days == 1) {
            return "1 " + Texts.DAY;
        }
        return days + " " + Texts.DAYS;
    }
}
