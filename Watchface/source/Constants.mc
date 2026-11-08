import Toybox.Complications;
import Toybox.Lang;

module Theme {
    const BG = 0x000000;
    const TXT = 0xEDEFF2;
    const DIM = 0x8A9099;
    const FAINT = 0x2A2D31;
    const LIME = 0xC8F05A;
    const ORANGE = 0xFF8A4C;
    const BLUE = 0x7FB2FF;
    const GREEN = 0x6EE07A;
    const AOD_TIME = 0x9AA0A8;
    const AOD_DIM = 0x5C6168;
    const AOD_ORANGE = 0xA35A33;
}

module Texts {
    const WEEKDAYS = ["DOMINGO", "SEGUNDA", "TERÇA", "QUARTA", "QUINTA", "SEXTA", "SÁBADO"];
    const MONTHS = ["JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"];
    const DAYS = "DIAS";
    const DAY = "DIA";
    const RACE_TODAY = "É HOJE";
    const VO2 = "VO2";
    const WEEK_KM = "KM SEMANA";
    const HRV = "HRV";
    const BODY_BATTERY = "BB";
    const GOAL = "META";
    const PREDICTION = "PREVISÃO";
    const RACE_IN = "PROVA EM";
    const NO_VALUE = "--";
}

module StorageKeys {
    const READINESS = "readiness";
    const READINESS_VERDICT = "readinessVerdict";
    const HRV = "hrv";
    const HRV_TREND = "hrvTrend";
}

module RacePredictors {
    const BY_DISTANCE_KM = {
        5 => Complications.COMPLICATION_TYPE_RACE_PREDICTOR_5K,
        10 => Complications.COMPLICATION_TYPE_RACE_PREDICTOR_10K,
        21 => Complications.COMPLICATION_TYPE_RACE_PREDICTOR_HALF_MARATHON,
        42 => Complications.COMPLICATION_TYPE_RACE_PREDICTOR_MARATHON
    };
}

module Defaults {
    const WEEKLY_GOAL_KM = 45;
    const RACE_DISTANCE_KM = 21;
}

module Layout {
    const REFERENCE_SIZE = 454.0;
    const AOD_SHIFTS = [[0, 0], [18, 10], [0, 20], [-18, 10]];
}
