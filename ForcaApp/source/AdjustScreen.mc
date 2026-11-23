import Toybox.Graphics;

module AdjustScreen {
    function draw(dc, workout) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var adjust = workout.adjust;
        var set = workout.results[workout.lastDone[:exercise]][workout.lastDone[:index]];
        var exercise = adjust[:exercise];
        var remaining = workout.restRemainingMs();
        var seconds = remaining <= 0 ? remaining / 1000 : (remaining + 999) / 1000;
        Draw.text(dc, cx, h * 0.2, Fonts.LABEL, Palette.REST, "DESCANSO " + Format.clock(seconds) + " · SÉRIE " + (workout.lastDone[:index] + 1));
        var fields = workout.adjustFields();
        var active = adjust[:field];
        var columns = fields.size();
        for (var i = 0; i < columns; i++) {
            var x = columns == 1 ? cx : (i == 0 ? w * 0.35 : w * 0.65);
            drawField(dc, x, h, fields[i], adjust, fields[i] == active, plannedValue(fields[i], exercise, workout));
        }
        var diff = difference(adjust, exercise, workout);
        if (diff != null) {
            Draw.text(dc, cx, h * 0.75, Fonts.LABEL, Palette.YELLOW, diff);
        }
        var last = fields.indexOf(active) == fields.size() - 1;
        Draw.text(dc, cx, h * 0.84, Fonts.LABEL, Palette.DIM, last ? Hints.ADJUST : Hints.ADJUST_NEXT);
    }

    function drawField(dc, x, h, field, adjust, active, planned) {
        var value = adjust[field];
        var label = field == AdjustField.WEIGHT ? "KG" : (field == AdjustField.REPS ? "REPS" : "TEMPO");
        Draw.text(dc, x, h * 0.32, Fonts.LABEL, active ? Palette.LIME : Palette.DIM, label);
        if (active) {
            Draw.text(dc, x, h * 0.4, Fonts.SMALL, Palette.FAINT, show(field, step(field, value, 1)));
            dc.setColor(Palette.LIME_BG, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x - 70, h * 0.455, 140, h * 0.12, 14);
            Draw.text(dc, x, h * 0.515, Fonts.ADJUST, Palette.LIME, show(field, value));
            Draw.text(dc, x, h * 0.63, Fonts.SMALL, Palette.FAINT, show(field, step(field, value, -1)));
        } else {
            var changed = !same(value, planned);
            Draw.text(dc, x, h * 0.515, Fonts.ADJUST, changed ? Palette.YELLOW : Palette.SOFT, show(field, value));
        }
    }

    function show(field, value) {
        if (field == AdjustField.WEIGHT) {
            return value == null ? "PC" : Format.kg(value);
        }
        if (field == AdjustField.SECONDS) {
            return Format.clock(value == null ? 0 : value);
        }
        return value == null ? "-" : value.format("%d");
    }

    function step(field, value, direction) {
        if (field == AdjustField.WEIGHT) {
            var next = (value == null ? 0.0 : value) + direction * Steps.WEIGHT;
            return next <= 0 ? null : next;
        }
        var amount = field == AdjustField.REPS ? Steps.REPS : Steps.SECONDS;
        var result = (value == null ? 0 : value) + direction * amount;
        return result < 0 ? 0 : result;
    }

    function plannedValue(field, exercise, workout) {
        if (field == AdjustField.WEIGHT) {
            return exercise[PlanKeys.WEIGHT];
        }
        return field == AdjustField.REPS ? exercise[PlanKeys.REPS] : exercise[PlanKeys.SECONDS];
    }

    function same(a, b) {
        if (a == null || b == null) {
            return a == null && b == null;
        }
        return (a - b).abs() < 0.01;
    }

    function difference(adjust, exercise, workout) {
        var parts = [];
        var reps = adjust[AdjustField.REPS];
        var planned = exercise[PlanKeys.REPS];
        if (reps != null && planned != null && reps != planned) {
            parts.add((reps > planned ? "+" : "−") + (reps - planned).abs() + " reps");
        }
        var weight = adjust[AdjustField.WEIGHT];
        var plannedWeight = exercise[PlanKeys.WEIGHT];
        if (weight != null && plannedWeight != null && !same(weight, plannedWeight)) {
            parts.add((weight > plannedWeight ? "+" : "−") + Format.kgShort((weight - plannedWeight).abs()) + " kg");
        }
        if (parts.size() == 0) {
            return null;
        }
        var text = parts[0];
        for (var i = 1; i < parts.size(); i++) {
            text += " · " + parts[i];
        }
        return parts.size() == 1 && reps == planned ? text + " vs plano" : text;
    }
}
