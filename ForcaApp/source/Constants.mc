import Toybox.Graphics;

module Palette {
    const BG = Graphics.COLOR_BLACK;
    const TXT = 0xE8ECEF;
    const DIM = 0x8A949F;
    const LIME = 0xC8F05A;
    const REST = 0x7FB2FF;
    const HR = 0xE5534B;
}

module RecorderState {
    const IDLE = 0;
    const RECORDING = 1;
    const PAUSED = 2;
    const SAVED = 3;
    const DISCARDED = 4;
}

module PauseAction {
    const RESUME = :resume;
    const SAVE = :save;
    const DISCARD = :discard;
}

module ViewTiming {
    const REFRESH_MS = 1000;
}
