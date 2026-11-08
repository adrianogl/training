import Toybox.Complications;
import Toybox.Graphics;
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
    const YELLOW = 0xFFC93B;
    const RED_LIGHT = 0xFF8080;
    const RED = 0xFF4A4A;
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

module DewPointBands {
    const UPPER_LIMITS_CELSIUS = [15.5, 18.5, 21.5];
    const COLORS = [Theme.BLUE, Theme.YELLOW, Theme.RED_LIGHT];
    const ABOVE_LAST = Theme.RED;
    const MAGNUS_B = 17.62;
    const MAGNUS_C = 243.12;
}

module Defaults {
    const WEEKLY_GOAL_KM = 45;
    const RACE_DISTANCE_KM = 21;
}

module FontSpecs {
    const BOLD = "RobotoCondensedBold";
    const REGULAR = "RobotoCondensedRegular";
    const ALL = {
        :time => [BOLD, 104, Graphics.FONT_NUMBER_HOT],
        :seconds => [BOLD, 40, Graphics.FONT_NUMBER_MILD],
        :aodTime => [REGULAR, 96, Graphics.FONT_NUMBER_MEDIUM],
        :date => [BOLD, 19, Graphics.FONT_XTINY],
        :temperature => [BOLD, 30, Graphics.FONT_SMALL],
        :humidity => [REGULAR, 24, Graphics.FONT_XTINY],
        :battery => [BOLD, 24, Graphics.FONT_XTINY],
        :status => [BOLD, 24, Graphics.FONT_XTINY],
        :statValue => [BOLD, 32, Graphics.FONT_SMALL],
        :statGoal => [REGULAR, 22, Graphics.FONT_XTINY],
        :label => [BOLD, 16, Graphics.FONT_XTINY],
        :race => [BOLD, 18, Graphics.FONT_XTINY],
        :raceValue => [BOLD, 28, Graphics.FONT_SMALL],
        :meeting => [BOLD, 24, Graphics.FONT_XTINY],
        :tag => [BOLD, 13, Graphics.FONT_XTINY]
    };
}

module Layout {
    const REFERENCE_SIZE = 454.0;
    const AOD_SHIFTS = [[0, 0], [18, 10], [0, 20], [-18, 10]];
}
