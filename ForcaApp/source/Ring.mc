import Toybox.Graphics;

module Ring {
    const WIDTH = 12;
    const INSET = 8;
    const GAP_DEGREES = 6;

    function segments(dc, total, done, currentIndex) {
        if (total <= 0) {
            return;
        }
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var radius = cx - INSET - WIDTH / 2;
        var span = 360.0 / total;
        dc.setPenWidth(WIDTH);
        for (var i = 0; i < total; i++) {
            var color = Palette.RING_OFF;
            if (i < done) {
                color = Palette.LILAC;
            } else if (i == currentIndex) {
                color = Palette.LILAC_DIM;
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            var from = i * span + GAP_DEGREES / 2;
            var to = (i + 1) * span - GAP_DEGREES / 2;
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90 - from, 90 - to);
        }
        dc.setPenWidth(1);
    }

    function progress(dc, fraction, color, background) {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var radius = cx - INSET - WIDTH / 2;
        dc.setPenWidth(WIDTH);
        dc.setColor(background, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);
        if (fraction > 0) {
            var clamped = fraction > 1 ? 1.0 : fraction;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            if (clamped >= 1) {
                dc.drawCircle(cx, cy, radius);
            } else {
                dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, 90 - clamped * 360);
            }
        }
        dc.setPenWidth(1);
    }
}
