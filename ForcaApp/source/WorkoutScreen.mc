import Toybox.Graphics;

module WorkoutScreen {
    const ROWS = 6;

    function draw(dc, workout) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var left = w * 0.18;
        var right = w * 0.82;
        var done = workout.setsDone();
        var planned = workout.setsPlanned();
        Draw.text(dc, cx, h * 0.14, Fonts.LABEL, Palette.LILAC, Format.upper(workout.plan[PlanKeys.TITLE]) + " · " + done + "/" + planned);
        var barLeft = w * 0.25;
        var barWidth = w * 0.5;
        dc.setColor(Palette.RING_OFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(barLeft, h * 0.2, barWidth, 6, 3);
        if (planned > 0 && done > 0) {
            dc.setColor(Palette.LILAC, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(barLeft, h * 0.2, barWidth * done / planned, 6, 3);
        }
        var order = workout.queue.order();
        var current = workout.currentBlock();
        var rowHeight = h * 0.085;
        var shown = 0;
        for (var i = 0; i < order.size() && shown < ROWS; i++) {
            var block = blockById(workout, order[i]);
            var y = h * 0.29 + shown * rowHeight;
            drawRow(dc, workout, block, current, left, right, y, rowHeight);
            shown += 1;
        }
        Draw.right(dc, cx - 8, h * 0.84, Fonts.LABEL, Palette.DIM, Format.longClock(workout.elapsedSeconds()));
        Draw.heartRate(dc, cx + 40, h * 0.84, Fonts.LABEL);
    }

    function drawRow(dc, workout, block, current, left, right, y, rowHeight) {
        var exercises = block[PlanKeys.EXERCISES];
        var name = Format.shortName(exercises[0][PlanKeys.NAME]);
        if (exercises.size() > 1) {
            name = name + " + " + Format.shortName(exercises[1][PlanKeys.NAME]);
        }
        var done = 0;
        for (var i = 0; i < exercises.size(); i++) {
            done += workout.setsOf(exercises[i][PlanKeys.ID]).size();
        }
        var total = block[PlanKeys.ROUNDS] * exercises.size();
        var complete = workout.queue.isComplete(block);
        var isCurrent = current != null && current[PlanKeys.ID].equals(block[PlanKeys.ID]);
        var pending = workout.isPending(block);
        var nameColor = Palette.DIM;
        var countColor = Palette.GRAY;
        var nameLeft = left;
        if (complete) {
            Draw.check(dc, left, y, 16, Palette.LILAC);
            nameLeft = left + 26;
            nameColor = Palette.SOFT;
            countColor = Palette.LILAC;
        } else if (isCurrent) {
            nameColor = Palette.LIME;
            countColor = Palette.LIME;
            Draw.outline(dc, left - 10, y - rowHeight / 2 + 2, right - left + 20, rowHeight - 4, Palette.LIME);
        } else if (pending) {
            name = name + " · depois";
            nameColor = Palette.YELLOW;
            countColor = Palette.YELLOW;
        }
        dc.setColor(nameColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(nameLeft, y, Fonts.regular(Fonts.LABEL), Graphics.fitTextToArea(name, Fonts.regular(Fonts.LABEL), right - nameLeft - 70, rowHeight, true), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        Draw.right(dc, right, y, Fonts.LABEL, countColor, done + "/" + total);
    }

    function blockById(workout, id) {
        var blocks = workout.plan[PlanKeys.BLOCKS];
        for (var i = 0; i < blocks.size(); i++) {
            if (blocks[i][PlanKeys.ID].equals(id)) {
                return blocks[i];
            }
        }
        return null;
    }
}
