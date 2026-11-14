import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;

module Theme {
    const BG = 0x000000;
    const TXT = 0xFFFFFF;
    const DIM = 0xB3BAC4;
    const FAINT = 0x3A3F46;
    const LIME = 0xE4FF1A;
    const ORANGE = 0xFF8A1A;
    const BLUE = 0x5CB0FF;
    const GREEN = 0x3DFF6E;
    const YELLOW = 0xFFC93B;
    const RED_LIGHT = 0xFF8080;
    const RED = 0xFF4A4A;
    const AOD_TIME = 0x9AA0A8;
    const AOD_DIM = 0x5C6168;
    const AOD_ORANGE = 0xA35A33;
    const AOD_READINESS = 0x8A6A2A;
    const REST = 0xE5534B;
    const MODERATE = 0xFFC24C;
    const HARD = 0xC8F05A;
    const REST_TRACK = 0x501D1A;
    const MODERATE_TRACK = 0x59441A;
    const HARD_TRACK = 0x46541F;
    const PLAN = 0x7FB2FF;
    const ZONES = [0x7FB2FF, 0xC8F05A, 0xE8C547, 0xFF8A4C, 0xE5534B];
}

module Texts {
    const WEEKDAYS = ["DOMINGO", "SEGUNDA", "TERÇA", "QUARTA", "QUINTA", "SEXTA", "SÁBADO"];
    const MONTHS = ["JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"];
    const DAYS = "DIAS";
    const DAY = "DIA";
    const RACE_TODAY = "É HOJE";
    const VO2 = "VO2 MÁX.";
    const THREE_MONTHS = "3M";
    const VERDICT_REST = "DESCANSO";
    const VERDICT_MODERATE = "MODERADO";
    const VERDICT_HARD = "FORTE";
    const WEEK_KM = "KM SEMANA";
    const READINESS = "PRONTIDÃO";
    const GOAL = "META";
    const RACE_IN = "PROVA EM";
    const NO_VALUE = "--";
}

(:background)
module StorageKeys {
    const READINESS = "readiness";
    const READINESS_DAY = "readinessDay";
    const READINESS_VERDICT = "readinessVerdict";
    const FACE = "face";
}

(:background)
module ReadinessBridge {
    const URL = "https://training-sync-ashy.vercel.app/api/v1/watch/readiness";
    const INTERVAL_SECONDS = 15 * 60;
    const DAY = "day";
    const SCORE = "score";
    const VERDICT = "verdict";
    const VO2_DELTA = "vo2Delta";
    const WEEK_PLANNED_KM = "weekPlannedKm";
    const WEEK_GOAL_KM = "weekGoalKm";
    const WORKOUT = "workout";
    const WORKOUT_SHAPE = "workoutShape";
    const RACE_NAME = "raceName";
    const RACE_DAY = "raceDay";
    const RACE_GOAL = "raceGoal";
    const RACE_PREDICTION = "racePrediction";
    const UNAUTHORIZED = 401;
    const NOT_FOUND = 404;
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

module ReadinessBands {
    const MODERATE_FROM = 40;
    const HARD_FROM = 70;
}

module Defaults {
    const WEEKLY_GOAL_KM = 45;
    const RACE_DISTANCE_KM = 21;
    const RACE_NAME_MAX = 14;
    const KM_SCALE_MARGIN = 1.1;
}

module FontSpecs {
    const BOLD = "RobotoCondensedBold";
    const REGULAR = "RobotoCondensedRegular";
    const ALL = {
        :time => [BOLD, 100, Graphics.FONT_NUMBER_HOT],
        :seconds => [BOLD, 34, Graphics.FONT_NUMBER_MILD],
        :aodTime => [REGULAR, 96, Graphics.FONT_NUMBER_MEDIUM],
        :date => [BOLD, 22, Graphics.FONT_XTINY],
        :temperature => [BOLD, 36, Graphics.FONT_SMALL],
        :humidity => [REGULAR, 28, Graphics.FONT_XTINY],
        :battery => [BOLD, 28, Graphics.FONT_XTINY],
        :statValue => [BOLD, 38, Graphics.FONT_SMALL],
        :statGoal => [REGULAR, 22, Graphics.FONT_XTINY],
        :label => [BOLD, 15, Graphics.FONT_XTINY],
        :delta => [BOLD, 14, Graphics.FONT_XTINY],
        :race => [BOLD, 21, Graphics.FONT_XTINY],
        :raceValue => [BOLD, 24, Graphics.FONT_XTINY],
        :raceGoal => [BOLD, 16, Graphics.FONT_XTINY],
        :tag => [BOLD, 16, Graphics.FONT_XTINY]
    };
}

module Layout {
    const REFERENCE_SIZE = 454.0;
    const AOD_SHIFTS = [[0, 0], [18, 10], [0, 20], [-18, 10]];
}
