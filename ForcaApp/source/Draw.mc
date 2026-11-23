import Toybox.Graphics;

module Draw {
    function text(dc, x, y, font, color, value) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Fonts.font(font), value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function left(dc, x, y, font, color, value) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Fonts.font(font), value, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function right(dc, x, y, font, color, value) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Fonts.font(font), value, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function line(dc, x1, x2, y) {
        dc.setColor(Palette.LINE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x1, y, x2, y);
    }

    function outline(dc, x, y, w, h, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawRoundedRectangle(x, y, w, h, h / 3);
        dc.setPenWidth(1);
    }

    function heartRate(dc, x, y, size) {
        var hr = Services.heartRate();
        var value = hr == null ? "--" : hr.format("%d");
        var font = Fonts.font(size);
        var width = dc.getTextWidthInPixels(value, font);
        var icon = size * 0.55;
        var gap = size * 0.25;
        var start = x - (width + icon + gap) / 2;
        heart(dc, start + icon / 2, y, icon);
        dc.setColor(Palette.HR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(start + icon + gap, y, font, value, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function heart(dc, cx, cy, size) {
        var r = size / 4;
        dc.setColor(Palette.HR, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - r, cy - r / 2, r);
        dc.fillCircle(cx + r, cy - r / 2, r);
        dc.fillPolygon([[cx - 2 * r, cy - r / 3], [cx + 2 * r, cy - r / 3], [cx, cy + 2 * r]]);
    }

    function check(dc, x, y, size, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(x, y, x + size * 0.35, y + size * 0.35);
        dc.drawLine(x + size * 0.35, y + size * 0.35, x + size, y - size * 0.4);
        dc.setPenWidth(1);
    }

    function unit(dc, x, y, size, unitSize, color, value, suffix) {
        var main = Fonts.font(size);
        var small = Fonts.font(unitSize);
        var mainWidth = dc.getTextWidthInPixels(value, main);
        var unitWidth = dc.getTextWidthInPixels(suffix, small);
        var start = x - (mainWidth + unitWidth) / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(start, y, main, value, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var offset = (dc.getFontHeight(main) - dc.getFontHeight(small)) / 4;
        dc.setColor(Palette.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(start + mainWidth, y + offset, small, suffix, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
