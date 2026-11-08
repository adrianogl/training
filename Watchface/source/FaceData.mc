import Toybox.Application;
import Toybox.Complications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Weather;

class FaceData {
    var temperature = null;
    var humidity = null;
    var dewPoint = null;
    var battery = null;
    var vo2max = null;
    var weeklyRunMeters = null;
    var nextEventTime = null;
    var trainingStatus = null;
    var bodyBattery = null;
    var racePredictionSeconds = null;
    var readiness = null;
    var readinessVerdict = null;
    var hrv = null;
    var hrvTrend = null;

    function initialize() {
    }

    function refresh() {
        readWeather();
        battery = System.getSystemStats().battery;
        vo2max = complicationValue(Complications.COMPLICATION_TYPE_VO2MAX_RUN);
        weeklyRunMeters = complicationValue(Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE);
        nextEventTime = complicationValue(Complications.COMPLICATION_TYPE_CALENDAR_EVENTS);
        trainingStatus = complicationValue(Complications.COMPLICATION_TYPE_TRAINING_STATUS);
        bodyBattery = complicationValue(Complications.COMPLICATION_TYPE_BODY_BATTERY);
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
        readiness = Application.Storage.getValue(StorageKeys.READINESS);
        readinessVerdict = Application.Storage.getValue(StorageKeys.READINESS_VERDICT);
        hrv = Application.Storage.getValue(StorageKeys.HRV);
        hrvTrend = Application.Storage.getValue(StorageKeys.HRV_TREND);
    }

    private function complicationValue(type) {
        try {
            return Complications.getComplication(new Complications.Id(type)).value;
        } catch (e) {
            return null;
        }
    }
}
