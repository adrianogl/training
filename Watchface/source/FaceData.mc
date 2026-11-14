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
    var workout = null;
    var workoutShape = null;
    var workoutTip = null;
    var raceName = null;
    var raceDate = null;
    var raceGoal = null;
    var racePredictionSeconds = null;

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
        workout = null;
        workoutShape = null;
        workoutTip = null;
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
            var name = face[ReadinessBridge.WORKOUT];
            var shape = face[ReadinessBridge.WORKOUT_SHAPE];
            if (name instanceof String) {
                workout = name;
            }
            if (shape instanceof Array) {
                workoutShape = shape;
            }
            var tip = face[ReadinessBridge.WORKOUT_TIP];
            if (tip instanceof String) {
                workoutTip = tip;
            }
        }
        readRace(face);
    }

    private function readRace(face) {
        var name = face[ReadinessBridge.RACE_NAME];
        var date = null;
        if (face[ReadinessBridge.RACE_DAY] instanceof String) {
            date = CivilDate.parseIsoDate(face[ReadinessBridge.RACE_DAY]);
        }
        if (name instanceof String && date != null) {
            raceName = name;
            raceDate = date;
            var goal = number(face[ReadinessBridge.RACE_GOAL]);
            raceGoal = goal == null ? null : Format.duration(goal);
            racePredictionSeconds = number(face[ReadinessBridge.RACE_PREDICTION]);
            return;
        }
        raceName = Settings.raceName();
        raceDate = CivilDate.parseIsoDate(Settings.raceDate());
        raceGoal = Settings.raceGoal();
        if (raceGoal.length() == 0) {
            raceGoal = null;
        }
        racePredictionSeconds = readRacePrediction();
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
