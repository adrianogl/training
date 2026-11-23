(:debug)
module SamplePlan {
    function superiores() {
        return {
            PlanKeys.DAY => "2026-11-23",
            PlanKeys.TITLE => "Superiores",
            PlanKeys.BLOCKS => [
                block("b1", 4, 90, [exercise("b1e1", "Remada curvada", 10, null, 30.0, [10, 30.0])]),
                block("b2", 4, 90, [
                    exercise("b2e1", "Supino reto com halteres no banco plano", 10, null, 22.5, [10, 20.0]),
                    exercise("b2e2", "Desenvolvimento com halteres", 12, null, 14.0, [12, 14.0])
                ]),
                block("b3", 3, 60, [sided("b3e1", "Remada unilateral", 10, 14.0)]),
                block("b4", 3, 60, [exercise("b4e1", "Flexão de braço", 12, null, null, null)]),
                block("b5", 3, 45, [exercise("b5e1", "Prancha", null, 45, null, null)])
            ]
        };
    }

    function block(id, rounds, rest, exercises) {
        return { PlanKeys.ID => id, PlanKeys.ROUNDS => rounds, PlanKeys.REST => rest, PlanKeys.EXERCISES => exercises };
    }

    function exercise(id, name, reps, seconds, weight, last) {
        return {
            PlanKeys.ID => id,
            PlanKeys.NAME => name,
            PlanKeys.KIND => seconds != null ? PlanKeys.TIMED : PlanKeys.REPS,
            PlanKeys.REPS => reps,
            PlanKeys.SECONDS => seconds,
            PlanKeys.WEIGHT => weight,
            PlanKeys.BODYWEIGHT => weight == null && seconds == null,
            PlanKeys.PER_SIDE => false,
            PlanKeys.LAST => last == null ? [] : [{ PlanKeys.REPS => last[0], PlanKeys.WEIGHT => last[1] }]
        };
    }

    function sided(id, name, reps, weight) {
        var item = exercise(id, name, reps, null, weight, null);
        item[PlanKeys.PER_SIDE] = true;
        return item;
    }
}
