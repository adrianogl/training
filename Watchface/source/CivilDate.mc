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

    function daysBetween(fromInfo, toInfo) {
        return daysFromCivil(toInfo.year, toInfo.month, toInfo.day)
            - daysFromCivil(fromInfo.year, fromInfo.month, fromInfo.day);
    }
}
