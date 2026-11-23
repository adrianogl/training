import Toybox.Graphics;

module SetScreen {
    function draw(dc, workout) {
        var exercise = workout.current;
        var block = workout.currentBlock();
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var rounds = block[PlanKeys.ROUNDS];
        var done = workout.setsOf(exercise[PlanKeys.ID]).size();
        Ring.segments(dc, rounds, done, done);
        var superset = block[PlanKeys.EXERCISES].size() > 1;
        var label = Format.upper(Format.shortName(exercise[PlanKeys.NAME])) + " · " + (superset ? "RODADA " : "SÉRIE ") + (done + 1) + "/" + rounds;
        if (superset) {
            label = letter(block, exercise) + " · " + label;
        }
        Draw.text(dc, cx, h * 0.22, Fonts.LABEL, Palette.LILAC, label);
        if (workout.isTimed(exercise)) {
            drawTimed(dc, workout, exercise, cx, h);
            return;
        }
        var reps = exercise[PlanKeys.REPS] == null ? "-" : exercise[PlanKeys.REPS].format("%d");
        Draw.text(dc, cx, h * 0.41, Fonts.BIG, Palette.LIME, reps);
        Draw.text(dc, cx, h * 0.555, Fonts.LABEL, Palette.DIM, exercise[PlanKeys.PER_SIDE] == true ? "REPS CADA LADO" : "REPS");
        var weight = workout.plannedWeight(exercise);
        if (weight == null) {
            Draw.text(dc, cx, h * 0.665, Fonts.WEIGHT, Palette.LIME, "PC");
        } else {
            Draw.unit(dc, cx, h * 0.665, Fonts.WEIGHT, Fonts.SMALL, Palette.LIME, Format.kg(weight), " kg");
        }
        var foot = superset ? after(block, exercise) : Format.lastText(exercise);
        if (foot != null) {
            Draw.text(dc, cx, h * 0.79, Fonts.LABEL, Palette.DIM, foot);
        }
    }

    function drawTimed(dc, workout, exercise, cx, h) {
        var running = workout.phase == Phase.TIMED;
        var seconds = running ? (workout.timedRemainingMs() + 999) / 1000 : exercise[PlanKeys.SECONDS];
        Draw.text(dc, cx, h * 0.45, Fonts.BIG, Palette.LIME, Format.clock(seconds));
        Draw.text(dc, cx, h * 0.62, Fonts.LABEL, Palette.DIM, "DE " + Format.clock(exercise[PlanKeys.SECONDS]));
        var last = Format.lastText(exercise);
        Draw.text(dc, cx, h * 0.74, Fonts.LABEL, Palette.DIM, running ? (last == null ? "" : last) : Hints.TIMED_READY);
    }

    function letter(block, exercise) {
        var exercises = block[PlanKeys.EXERCISES];
        var index = 0;
        for (var i = 0; i < exercises.size(); i++) {
            if (exercises[i][PlanKeys.ID].equals(exercise[PlanKeys.ID])) {
                index = i;
            }
        }
        return "A" + (index + 1);
    }

    function after(block, exercise) {
        var exercises = block[PlanKeys.EXERCISES];
        for (var i = 0; i < exercises.size(); i++) {
            if (exercises[i][PlanKeys.ID].equals(exercise[PlanKeys.ID])) {
                if (i + 1 < exercises.size()) {
                    return "depois: A" + (i + 2) + " " + Format.shortName(exercises[i + 1][PlanKeys.NAME]);
                }
                return "depois: descanso " + Format.clock(block[PlanKeys.REST]);
            }
        }
        return null;
    }
}
