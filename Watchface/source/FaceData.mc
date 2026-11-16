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
    var vo2Delta = null;
    var weeklyRunMeters = null;
    var weekPlannedKm = null;
    var weekGoalKm = null;
    var readiness = null;
    var eventStart = null;
    var eventTitle = null;

    function initialize() {
    }

    function refresh() {
        readWeather();
        battery = System.getSystemStats().battery;
        vo2max = complicationValue(Complications.COMPLICATION_TYPE_VO2MAX_RUN);
        weeklyRunMeters = complicationValue(Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE);
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

    private function readBridge() {
        readiness = null;
        vo2Delta = null;
        weekPlannedKm = null;
        var today = Format.isoDate(Gregorian.info(Time.now(), Time.FORMAT_SHORT));
        var day = Application.Storage.getValue(StorageKeys.READINESS_DAY);
        var isToday = day instanceof String && day.equals(today);
        if (isToday) {
            readiness = Application.Storage.getValue(StorageKeys.READINESS);
        }
        var face = Application.Storage.getValue(StorageKeys.FACE);
        if (!(face instanceof Dictionary)) {
            face = {};
        }
        vo2Delta = number(face[ReadinessBridge.VO2_DELTA]);
        weekGoalKm = number(face[ReadinessBridge.WEEK_GOAL_KM]);
        if (weekGoalKm == null) {
            weekGoalKm = Settings.weeklyGoalKm();
        }
        if (isToday) {
            weekPlannedKm = number(face[ReadinessBridge.WEEK_PLANNED_KM]);
        }
        readNextEvent(face[ReadinessBridge.EVENTS]);
    }

    private function readNextEvent(events) {
        eventStart = null;
        eventTitle = null;
        if (!(events instanceof Array)) {
            return;
        }
        var now = Time.now().value();
        for (var i = 0; i < events.size(); i++) {
            var event = events[i];
            if (!(event instanceof Dictionary)) {
                continue;
            }
            var start = number(event[ReadinessBridge.EVENT_START]);
            var title = event[ReadinessBridge.EVENT_TITLE];
            if (start != null && start > now && title instanceof String && title.length() > 0) {
                eventStart = start.toNumber();
                eventTitle = title;
                return;
            }
        }
    }

    private function number(value) {
        if (value instanceof Number || value instanceof Float || value instanceof Double || value instanceof Long) {
            return value;
        }
        return null;
    }

    private function complicationValue(type) {
        try {
            return Complications.getComplication(new Complications.Id(type)).value;
        } catch (e) {
            return null;
        }
    }
}
