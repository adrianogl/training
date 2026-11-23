import Toybox.Graphics;

module RestScreen {
    function draw(dc, workout) {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var remainingMs = workout.restRemainingMs();
        var over = remainingMs <= 0;
        var fraction = workout.restTotalMs > 0 ? remainingMs.toFloat() / workout.restTotalMs : 0;
        Ring.progress(dc, over ? 0 : fraction, Palette.REST, over ? Palette.LIME : Palette.REST_DIM);
        var seconds = over ? remainingMs / 1000 : (remainingMs + 999) / 1000;
        Draw.text(dc, cx, h * 0.21, Fonts.CLOCK, over ? Palette.YELLOW : Palette.REST, Format.clock(seconds));
        var next = workout.current;
        if (next == null) {
            Draw.text(dc, cx, h * 0.5, Fonts.BODY, Palette.TXT, "Último exercício feito");
            return;
        }
        var block = workout.currentBlock();
        var done = workout.setsOf(next[PlanKeys.ID]).size();
        var title = done == 0 ? "PRÓXIMO · " + Format.upper(Format.shortName(next[PlanKeys.NAME])) : "PRÓXIMA · SÉRIE " + (done + 1) + "/" + block[PlanKeys.ROUNDS];
        var warn = remainingMs <= Timing.REST_WARN_S * 1000;
        var color = warn ? Palette.LIME : Palette.TXT;
        Draw.text(dc, cx, h * 0.32, Fonts.LABEL, Palette.DIM, title);
        if (workout.isTimed(next)) {
            Draw.text(dc, cx, h * 0.48, Fonts.REST_BIG, color, Format.clock(next[PlanKeys.SECONDS]));
        } else {
            var reps = next[PlanKeys.REPS] == null ? "-" : next[PlanKeys.REPS].format("%d");
            Draw.text(dc, cx, h * 0.46, Fonts.REST_BIG, color, reps);
            var weight = workout.plannedWeight(next);
            if (weight == null) {
                Draw.text(dc, cx, h * 0.61, Fonts.ADJUST, color, "PC");
            } else {
                Draw.unit(dc, cx, h * 0.61, Fonts.ADJUST, Fonts.LABEL, color, Format.kg(weight), " kg");
            }
        }
        Draw.heartRate(dc, cx, h * 0.72, Fonts.LABEL);
        Draw.text(dc, cx, h * 0.81, Fonts.LABEL, Palette.DIM, over ? Hints.REST_OVER : Hints.REST);
    }
}
