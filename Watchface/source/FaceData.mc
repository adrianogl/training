import Toybox.Application;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

class FaceData {
    var temperature = null;
    var humidity = null;
    var dewPoint = null;
    var battery = null;
    var vo2max = null;
    var weeklyRunMeters = null;
    var nextEventTime = null;
    var racePredictionSeconds = null;
    var readiness = null;

    function initialize() {
    }

    function refresh() {
        readWeather();
        battery = System.getSystemStats().battery;
        vo2max = complicationValue(Complications.COMPLICATION_TYPE_VO2MAX_RUN);
        weeklyRunMeters = complicationValue(Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE);
        nextEventTime = complicationValue(Complications.COMPLICATION_TYPE_CALENDAR_EVENTS);
        racePredictionSeconds = readRacePrediction();
        readBridge();
    }

    private function readWeather() {
        temperature = null;
        humidity = null;
        dewPoint = null;
        var conditions = Weather.getCurrentConditions();
        if (conditions != null) {
            temperature = conditions.temperature;
            humidity = conditions.relativeHumidity;
            dewPoint = DewPoint.fromConditions(conditions);
        }
    }

    private function readRacePrediction() {
        var type = RacePredictors.BY_DISTANCE_KM[Settings.raceDistanceKm()];
        if (type == null) {
            return null;
        }
        var seconds = complicationValue(type);
        if (seconds == null || seconds <= 0) {
            return null;
        }
        return seconds;
    }

    private function readBridge() {
        readiness = null;
        var day = Application.Storage.getValue(StorageKeys.READINESS_DAY);
        var today = Format.isoDate(Gregorian.info(Time.now(), Time.FORMAT_SHORT));
        if (day instanceof String && day.equals(today)) {
            readiness = Application.Storage.getValue(StorageKeys.READINESS);
        }
    }

    private function complicationValue(type) {
        try {
            return Complications.getComplication(new Complications.Id(type)).value;
        } catch (e) {
            return null;
        }
    }
}
