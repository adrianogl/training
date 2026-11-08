import Toybox.Lang;
import Toybox.Math;

module DewPoint {
    function fromConditions(conditions) {
        if ((conditions has :dewPoint) && conditions.dewPoint != null) {
            return conditions.dewPoint.toFloat();
        }
        return estimate(conditions.temperature, conditions.relativeHumidity);
    }

    function estimate(celsius, relativeHumidity) {
        if (celsius == null || relativeHumidity == null || relativeHumidity <= 0) {
            return null;
        }
        var t = celsius.toFloat();
        var gamma = Math.ln(relativeHumidity.toFloat() / 100.0)
            + (DewPointBands.MAGNUS_B * t) / (DewPointBands.MAGNUS_C + t);
        return DewPointBands.MAGNUS_C * gamma / (DewPointBands.MAGNUS_B - gamma);
    }

    function bandIndex(dewPointCelsius) {
        var limits = DewPointBands.UPPER_LIMITS_CELSIUS;
        for (var i = 0; i < limits.size(); i++) {
            if (dewPointCelsius < limits[i]) {
                return i;
            }
        }
        return limits.size();
    }

    function color(dewPointCelsius) {
        var index = bandIndex(dewPointCelsius);
        if (index < DewPointBands.COLORS.size()) {
            return DewPointBands.COLORS[index];
        }
        return DewPointBands.ABOVE_LAST;
    }
}
