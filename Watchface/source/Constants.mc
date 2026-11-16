import Toybox.Graphics;
import Toybox.Lang;

module Theme {
    const BG = 0x000000;
    const TXT = 0xE8ECEF;
    const TXT_SOFT = 0xC9CDD1;
    const DIM = 0x8A949F;
    const LINE = 0x262E38;
    const LIME = 0xC8F05A;
    const LIME_LANE = 0x50601F;
    const RUNNER = 0xEDEFF2;
    const BLUE = 0x7FB2FF;
    const YELLOW = 0xFFC24C;
    const RED_LIGHT = 0xFF8080;
    const RED = 0xE5534B;
    const AOD_TIME = 0x8A949F;
    const AOD_DIM = 0x5C6168;
    const AOD_LOGO = 0x5E7A2A;
    const REST = 0xE5534B;
    const MODERATE = 0xFFC24C;
    const HARD = 0xC8F05A;
    const REST_TRACK = 0x501D1A;
    const MODERATE_TRACK = 0x59441A;
    const HARD_TRACK = 0x2F3A16;
    const PLAN = 0x7FB2FF;
}

module Texts {
    const WEEKDAYS = ["DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SÁB"];
    const MONTHS = ["JAN", "FEV", "MAR", "ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OUT", "NOV", "DEZ"];
    const VO2 = "VO2 MÁX.";
    const THREE_MONTHS = "3M";
    const VERDICT_REST = "DESCANSO";
    const VERDICT_MODERATE = "MODERADO";
    const VERDICT_HARD = "FORTE";
    const WEEK_KM = "KM SEMANA";
    const READINESS = "PRONTIDÃO";
    const NO_VALUE = "--";
    const TODAY = "HOJE";
    const TOMORROW = "AMANHÃ";
    const IN = "EM";
    const MINUTES = "MIN";
    const HOURS = "H";
    const SEPARATOR = " · ";
    const ELLIPSIS = "…";
    const AI = "AI";
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
    const EVENTS = "events";
    const EVENT_START = "start";
    const EVENT_TITLE = "title";
    const UNAUTHORIZED = 401;
    const NOT_FOUND = 404;
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
    const KM_SCALE_MARGIN = 1.1;
}

module FontSpecs {
    const BOLD = "RobotoCondensedBold";
    const REGULAR = "RobotoCondensedRegular";
    const ALL = {
        :date => [BOLD, 23, Graphics.FONT_XTINY],
        :temperature => [BOLD, 37, Graphics.FONT_SMALL],
        :humidity => [REGULAR, 29, Graphics.FONT_XTINY],
        :battery => [BOLD, 29, Graphics.FONT_XTINY],
        :statValue => [BOLD, 42, Graphics.FONT_SMALL],
        :statGoal => [REGULAR, 24, Graphics.FONT_XTINY],
        :label => [BOLD, 17, Graphics.FONT_XTINY],
        :delta => [BOLD, 17, Graphics.FONT_XTINY],
        :tag => [BOLD, 15, Graphics.FONT_XTINY],
        :eventLabel => [BOLD, 19, Graphics.FONT_XTINY],
        :eventTitle => [BOLD, 26, Graphics.FONT_TINY],
        :eventTitleSmall => [BOLD, 22, Graphics.FONT_XTINY],
        :aodDate => [BOLD, 22, Graphics.FONT_XTINY],
        :aodEventTitle => [BOLD, 22, Graphics.FONT_XTINY]
    };
}

module Layout {
    const REFERENCE_SIZE = 454.0;
    const AOD_SHIFTS = [[0, 0], [18, 10], [0, 20], [-18, 10]];
    const LOGO_TOP = 35;
    const LOGO_WIDTH = 26;
    const LOGO_HEIGHT = 18;
    const LOGO_GAP = 9;
    const DATE_BASELINE = 51;
    const WEATHER_BASELINE = 101;
    const CLOCK_BASELINE = 221;
    const SECONDS_GAP = 7;
    const LEFT_COLUMN = 112;
    const RIGHT_COLUMN = 343;
    const LEFT_DIVIDER = 171;
    const RIGHT_DIVIDER = 285;
    const DIVIDER_TOP = 261;
    const DIVIDER_BOTTOM = 341;
    const STAT_BASELINE = 288;
    const LABEL_BASELINE = 316;
    const DELTA_BASELINE = 338;
    const BAR_TOP = 328;
    const BAR_HEIGHT = 6;
    const READINESS_BAR_LEFT = 77;
    const READINESS_BAR_WIDTH = 73.0;
    const KM_BAR_LEFT = 304;
    const KM_BAR_WIDTH = 77;
    const EVENT_LABEL_BASELINE = 389;
    const EVENT_TITLE_BASELINE = 418;
    const EVENT_TITLE_MAX = 233;
    const AOD_LOGO_TOP = 58;
    const AOD_LOGO_WIDTH = 22;
    const AOD_LOGO_HEIGHT = 15;
    const AOD_DATE_BASELINE = 72;
    const AOD_CLOCK_BASELINE = 222;
    const AOD_EVENT_LABEL_BASELINE = 388;
    const AOD_EVENT_TITLE_BASELINE = 413;
    const AOD_EVENT_TITLE_MAX = 190;
}
