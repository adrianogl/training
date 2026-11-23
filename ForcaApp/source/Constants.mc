import Toybox.Graphics;

module Palette {
    const BG = Graphics.COLOR_BLACK;
    const TXT = 0xE8ECEF;
    const SOFT = 0xC9CDD1;
    const DIM = 0x8A949F;
    const GRAY = 0x5C6168;
    const FAINT = 0x3A4048;
    const LINE = 0x262E38;
    const LILAC = 0xB59CFF;
    const LILAC_DIM = 0x4B4470;
    const RING_OFF = 0x22262D;
    const LIME = 0xC8F05A;
    const LIME_BG = 0x1A2210;
    const REST = 0x7FB2FF;
    const REST_DIM = 0x1C2A3D;
    const YELLOW = 0xFFC24C;
    const HR = 0xE5534B;
}

module Phase {
    const START = 0;
    const SET = 1;
    const TIMED = 2;
    const REST = 3;
    const ADJUST = 4;
    const EXERCISE_DONE = 5;
    const PENDING = 6;
    const FINISHED = 7;
    const SAVED = 8;
    const DISCARDED = 9;
    const EMPTY = 10;
}

module SetView {
    const MAIN = 0;
    const EXERCISE = 1;
    const WORKOUT = 2;
    const COUNT = 3;
}

module AdjustField {
    const WEIGHT = 0;
    const REPS = 1;
    const SECONDS = 2;
}

module Vibe {
    const SET = 0;
    const WARN = 1;
    const GO = 2;
    const DONE = 3;
    const INTENSITY = 100;
    const SET_MS = 400;
    const WARN_MS = 300;
    const WARN_PULSES = 2;
    const GO_MS = 500;
    const GO_PULSES = 3;
    const GAP_MS = 200;
}

module Timing {
    const REFRESH_MS = 1000;
    const REST_WARN_S = 10;
    const VIEW_RETURN_MS = 8000;
    const EXERCISE_DONE_MS = 3000;
    const MENU_RELEASE_MS = 700;
    const LINK_RETRY_MS = 5000;
    const STATUS_CHECK_MS = 1000;
    const STATUS_EVERY_MS = 15000;
}

module Steps {
    const WEIGHT = 2.5;
    const REPS = 1;
    const SECONDS = 5;
}

module PauseAction {
    const RESUME = :resume;
    const SAVE = :save;
    const DISCARD = :discard;
}

module QueueAction {
    const SKIP = :skip;
    const BACK = :back;
    const LEAVE_OUT = :leaveOut;
    const DO_NOW = :doNow;
}

module StorageKeys {
    const PLANS = "plans";
    const RESULTS = "results";
    const EVENTS = "events";
}

module EventKeys {
    const ID = "id";
    const SEQUENCE = "sequence";
    const ACTION = "action";
    const SET_DONE = "setDone";
    const ADJUST = "adjust";
    const SKIP = "skip";
    const DO_NOW = "doNow";
    const LEAVE_OUT = "leaveOut";
    const EXERCISE_ID = "exerciseId";
    const SET_INDEX = "setIndex";
    const RESULT = "result";
}

module LinkKeys {
    const EVENTS = "events";
    const PING = "ping";
    const PONG = "pong";
    const STARTED = "started";
    const TITLE = "title";
    const ACK = "ack";
    const ACK_STARTED = "ackStarted";
    const FINISHED = "finished";
    const SAVED = "saved";
    const DURATION = "durationSeconds";
    const AVERAGE_HEART_RATE = "averageHeartRate";
    const ACK_FINISHED = "ackFinished";
    const PLANS = "plans";
    const STATUS = "status";
    const BATCH = 10;
}

module StatusKeys {
    const PHASE = "phase";
    const HEART_RATE = "heartRate";
    const REST_ENDS_AT = "restEndsAt";
    const SET = "set";
    const TIMED = "timed";
    const REST = "rest";
    const REST_OVER = "restOver";
    const ADJUST = "adjust";
    const EXERCISE_DONE = "exerciseDone";
    const PENDING = "pending";
    const PAUSED = "paused";
    const FINISHED = "finished";
}

module PlanKeys {
    const ID = "id";
    const DAY = "day";
    const TITLE = "title";
    const BLOCKS = "blocks";
    const ROUNDS = "rounds";
    const REST = "restSeconds";
    const EXERCISES = "exercises";
    const NAME = "name";
    const KIND = "kind";
    const TIMED = "timed";
    const REPS = "reps";
    const SECONDS = "seconds";
    const WEIGHT = "weight";
    const BODYWEIGHT = "bodyweight";
    const PER_SIDE = "perSide";
    const LAST = "last";
    const START = "start";
    const DURATION = "durationSeconds";
    const EXERCISE_ID = "exerciseId";
}

module NameRules {
    const SHORT_MAX = 16;
    const CONNECTORS = ["de", "do", "da", "dos", "das", "com", "no", "na", "em", "e"];
    const SHORT_WORDS = 2;
}
