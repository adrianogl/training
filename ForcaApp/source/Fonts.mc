import Toybox.Graphics;
import Toybox.Lang;

module Fonts {
    const LABEL = 22;
    const SMALL = 26;
    const BODY = 30;
    const ROW_CURRENT = 36;
    const TITLE = 42;
    const CLOCK = 40;
    const ADJUST = 66;
    const WEIGHT = 70;
    const REST_BIG = 104;
    const BIG = 124;
    const BOLD_FACES = ["RobotoCondensedBold", "RobotoRegular"];
    const REGULAR_FACES = ["RobotoCondensedRegular", "RobotoRegular"];

    var _cache = {};

    function font(size) {
        return load(size, true);
    }

    function regular(size) {
        return load(size, false);
    }

    function load(size, bold) {
        var key = bold ? size : -size;
        var cached = _cache[key];
        if (cached != null) {
            return cached;
        }
        var loaded = null;
        if (Graphics has :getVectorFont) {
            loaded = Graphics.getVectorFont({ :face => bold ? BOLD_FACES : REGULAR_FACES, :size => size });
        }
        if (loaded == null) {
            loaded = fallback(size);
        }
        _cache[key] = loaded;
        return loaded;
    }

    function fallback(size) {
        if (size >= BIG) {
            return Graphics.FONT_NUMBER_THAI_HOT;
        }
        if (size >= REST_BIG) {
            return Graphics.FONT_NUMBER_HOT;
        }
        if (size >= ADJUST) {
            return Graphics.FONT_NUMBER_MILD;
        }
        if (size >= TITLE) {
            return Graphics.FONT_MEDIUM;
        }
        if (size >= BODY) {
            return Graphics.FONT_SMALL;
        }
        if (size >= SMALL) {
            return Graphics.FONT_TINY;
        }
        return Graphics.FONT_XTINY;
    }
}
