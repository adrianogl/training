import Toybox.Graphics;

module StartScreen {
    function draw(dc, workout) {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var plan = workout.plan;
        Draw.text(dc, cx, h * 0.20, Fonts.LABEL, Palette.LILAC, "FORÇA · HOJE");
        Draw.text(dc, cx, h * 0.33, Fonts.TITLE, Palette.TXT, plan[PlanKeys.TITLE]);
        var exercises = 0;
        var blocks = plan[PlanKeys.BLOCKS];
        for (var i = 0; i < blocks.size(); i++) {
            exercises += blocks[i][PlanKeys.EXERCISES].size();
        }
        Draw.text(dc, cx, h * 0.47, Fonts.BODY, Palette.SOFT, exercises + " exercícios · " + workout.setsPlanned() + " séries");
        Draw.text(dc, cx, h * 0.60, Fonts.LABEL, Palette.DIM, "salvo no relógio · iPhone opcional");
        Draw.text(dc, cx, h * 0.78, Fonts.BODY, Palette.LIME, Hints.START);
    }

    function drawEmpty(dc) {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        Draw.text(dc, cx, h * 0.40, Fonts.BODY, Palette.TXT, "Sem treino salvo");
        Draw.text(dc, cx, h * 0.55, Fonts.LABEL, Palette.DIM, "abra o trAIning no iPhone");
    }
}
