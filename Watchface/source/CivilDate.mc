import Toybox.Lang;

module CivilDate {
    function daysFromCivil(year, month, day) {
        var y = year;
        if (month <= 2) {
            y = y - 1;
        }
        var era = y / 400;
        if (y < 0) {
            era = (y - 399) / 400;
        }
        var yearOfEra = y - era * 400;
        var shiftedMonth = month - 3;
        if (month <= 2) {
            shiftedMonth = month + 9;
        }
        var dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1;
        var dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear;
        return era * 146097 + dayOfEra - 719468;
    }

    function parseIsoDate(text) {
        if (text == null || text.length() != 10) {
            return null;
        }
        var year = text.substring(0, 4).toNumberWithBase(10);
        var month = text.substring(5, 7).toNumberWithBase(10);
        var day = text.substring(8, 10).toNumberWithBase(10);
        if (year == null || month == null || day == null || month < 1 || month > 12 || day < 1 || day > 31) {
            return null;
        }
        return { :year => year, :month => month, :day => day };
    }

    function daysUntil(target, todayInfo) {
        return daysFromCivil(target[:year], target[:month], target[:day])
            - daysFromCivil(todayInfo.year, todayInfo.month, todayInfo.day);
    }
}
