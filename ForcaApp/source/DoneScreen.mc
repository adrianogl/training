import Toybox.Graphics;

module DoneScreen {
    function drawExercise(dc, workout) {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var block = workout.finishedBlock();
        var rounds = block[PlanKeys.ROUNDS];
        Ring.segments(dc, rounds, rounds, rounds);
        var name = Format.shortName(block[PlanKeys.EXERCISES][0][PlanKeys.NAME]);
        Draw.text(dc, cx, h * 0.25, Fonts.LABEL, Palette.LILAC, Format.upper(name) + " CONCLUÍDO");
        Draw.text(dc, cx, h * 0.36, Fonts.TITLE, Palette.TXT, rounds + " de " + rounds + " séries");
        Draw.line(dc, cx - 110, cx + 110, h * 0.46);
        var next = workout.queue.current();
        if (next == null) {
            Draw.text(dc, cx, h * 0.58, Fonts.BODY, Palette.LIME, "Último exercício");
            return;
        }
        var exercise = next[PlanKeys.EXERCISES][0];
        Draw.text(dc, cx, h * 0.54, Fonts.LABEL, Palette.DIM, "PRÓXIMO · " + ExerciseScreen.position(workout, next));
        Draw.text(dc, cx, h * 0.63, Fonts.BODY, Palette.LIME, Format.shortName(exercise[PlanKeys.NAME]));
        Draw.text(dc, cx, h * 0.72, Fonts.LABEL, Palette.SOFT, Format.plan(exercise, next[PlanKeys.ROUNDS], workout.plannedWeight(exercise)));
    }

    function drawPending(dc, workout) {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var pending = workout.queue.pending();
        var block = pending.size() > 0 ? pending[0] : workout.currentBlock();
        var exercise = block[PlanKeys.EXERCISES][0];
        var label = pending.size() == 1 ? "FALTA 1 EXERCÍCIO" : "FALTAM " + pending.size() + " EXERCÍCIOS";
        Draw.text(dc, cx, h * 0.28, Fonts.LABEL, Palette.YELLOW, label);
        Draw.text(dc, cx, h * 0.42, Fonts.TITLE, Palette.TXT, Format.shortName(exercise[PlanKeys.NAME]));
        Draw.text(dc, cx, h * 0.53, Fonts.LABEL, Palette.SOFT, Format.plan(exercise, block[PlanKeys.ROUNDS], workout.plannedWeight(exercise)));
        Draw.text(dc, cx, h * 0.72, Fonts.BODY, Palette.LIME, Hints.PENDING);
    }

    function drawFinished(dc, workout) {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        Ring.progress(dc, 1.0, Palette.LILAC, Palette.RING_OFF);
        Draw.text(dc, cx, h * 0.3, Fonts.LABEL, Palette.LILAC, "TREINO CONCLUÍDO");
        Draw.text(dc, cx, h * 0.43, Fonts.TITLE, Palette.TXT, workout.setsDone() + " de " + workout.setsPlanned() + " séries");
        Draw.text(dc, cx, h * 0.55, Fonts.LABEL, Palette.DIM, Format.longClock(workout.elapsedSeconds()));
        Draw.text(dc, cx, h * 0.72, Fonts.BODY, Palette.LIME, Hints.FINISHED);
    }

    function drawSaved(dc, workout) {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var discarded = workout.phase == Phase.DISCARDED;
        Draw.text(dc, cx, h * 0.3, Fonts.LABEL, discarded ? Palette.DIM : Palette.LILAC, discarded ? "DESCARTADO" : "SALVO");
        Draw.text(dc, cx, h * 0.42, Fonts.TITLE, Palette.TXT, workout.plan[PlanKeys.TITLE]);
        if (!discarded) {
            var hr = workout.savedHeartRate;
            var line = workout.setsDone() + " séries · " + Format.longClock(workout.savedSeconds) + (hr == null ? "" : " · FC " + hr.format("%d"));
            Draw.text(dc, cx, h * 0.53, Fonts.LABEL, Palette.SOFT, line);
            Draw.text(dc, cx, h * 0.63, Fonts.LABEL, Palette.DIM, "sincronize para ir ao Garmin Connect");
        }
        Draw.text(dc, cx, h * 0.78, Fonts.LABEL, Palette.DIM, Hints.SAVED);
    }
}
