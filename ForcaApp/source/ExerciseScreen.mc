import Toybox.Graphics;

module ExerciseScreen {
    function draw(dc, workout) {
        var exercise = workout.current;
        var block = workout.currentBlock();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var left = w * 0.2;
        var right = w * 0.8;
        dc.setColor(Palette.TXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.13, Fonts.font(Fonts.SMALL), Graphics.fitTextToArea(exercise[PlanKeys.NAME], Fonts.font(Fonts.SMALL), w * 0.62, h * 0.16, true), Graphics.TEXT_JUSTIFY_CENTER);
        Draw.text(dc, cx, h * 0.33, Fonts.LABEL, Palette.LILAC, "EXERCÍCIO " + position(workout, block) + " · DESC. " + Format.clock(block[PlanKeys.REST]));
        Draw.line(dc, left, right, h * 0.38);
        var sets = workout.setsOf(exercise[PlanKeys.ID]);
        var weight = workout.plannedWeight(exercise);
        var rounds = block[PlanKeys.ROUNDS];
        var rows = rounds > 5 ? 5 : rounds;
        var rowHeight = h * 0.095;
        for (var i = 0; i < rows; i++) {
            var y = h * 0.45 + i * rowHeight;
            var text;
            var color;
            var mark = (i + 1).format("%d");
            if (i < sets.size()) {
                text = Format.setText(sets[i]);
                color = Palette.SOFT;
                Draw.check(dc, left, y, 14, Palette.LILAC);
                Draw.left(dc, left + 22, y, Fonts.LABEL, Palette.LILAC, mark);
            } else {
                text = Format.setText({ PlanKeys.REPS => exercise[PlanKeys.REPS], PlanKeys.SECONDS => workout.isTimed(exercise) ? exercise[PlanKeys.SECONDS] : null, PlanKeys.WEIGHT => weight });
                color = i == sets.size() ? Palette.LIME : Palette.GRAY;
                if (i == sets.size()) {
                    Draw.outline(dc, left - 10, y - rowHeight / 2 + 2, right - left + 20, rowHeight - 4, Palette.LIME);
                }
                Draw.left(dc, left, y, Fonts.LABEL, color, mark);
            }
            Draw.right(dc, right, y, i == sets.size() ? Fonts.ROW_CURRENT : Fonts.BODY, color, text);
        }
    }

    function position(workout, block) {
        var blocks = workout.plan[PlanKeys.BLOCKS];
        for (var i = 0; i < blocks.size(); i++) {
            if (blocks[i][PlanKeys.ID].equals(block[PlanKeys.ID])) {
                return (i + 1) + " DE " + blocks.size();
            }
        }
        return "";
    }
}
