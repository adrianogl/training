import Toybox.Lang;

module Format {
    function kg(weight) {
        if (weight == null) {
            return "PC";
        }
        var tenths = (weight * 10 + 0.5).toNumber();
        return (tenths / 10).format("%d") + "," + (tenths % 10).format("%d");
    }

    function kgShort(weight) {
        if (weight == null) {
            return "PC";
        }
        var tenths = (weight * 10 + 0.5).toNumber();
        if (tenths % 10 == 0) {
            return (tenths / 10).format("%d");
        }
        return kg(weight);
    }

    function clock(totalSeconds) {
        var seconds = totalSeconds < 0 ? -totalSeconds : totalSeconds;
        var text = (seconds / 60).format("%d") + ":" + (seconds % 60).format("%02d");
        return totalSeconds < 0 ? "+" + text : text;
    }

    function longClock(totalSeconds) {
        if (totalSeconds >= 3600) {
            return (totalSeconds / 3600).format("%d") + ":" + ((totalSeconds % 3600) / 60).format("%02d") + ":" + (totalSeconds % 60).format("%02d");
        }
        return clock(totalSeconds);
    }

    function setText(set) {
        if (set[PlanKeys.SECONDS] != null) {
            return clock(set[PlanKeys.SECONDS]);
        }
        var reps = set[PlanKeys.REPS] == null ? "-" : set[PlanKeys.REPS].format("%d");
        return set[PlanKeys.WEIGHT] == null ? reps + " · PC" : reps + " × " + kg(set[PlanKeys.WEIGHT]);
    }

    function lastText(exercise) {
        var last = exercise[PlanKeys.LAST];
        if (!(last instanceof Array) || last.size() == 0) {
            return null;
        }
        var set = last[0];
        if (set[PlanKeys.SECONDS] != null) {
            return "última " + last.size() + " × " + clock(set[PlanKeys.SECONDS]);
        }
        var reps = set[PlanKeys.REPS] == null ? "-" : set[PlanKeys.REPS].format("%d");
        return set[PlanKeys.WEIGHT] == null ? "última " + reps + " · PC" : "última " + reps + " × " + kgShort(set[PlanKeys.WEIGHT]);
    }

    function target(exercise, weight) {
        if (PlanKeys.TIMED.equals(exercise[PlanKeys.KIND])) {
            return clock(exercise[PlanKeys.SECONDS]);
        }
        var reps = exercise[PlanKeys.REPS] == null ? "-" : exercise[PlanKeys.REPS].format("%d");
        return weight == null ? reps + " · PC" : reps + " · " + kgShort(weight) + " kg";
    }

    function plan(exercise, rounds, weight) {
        return rounds.format("%d") + " × " + target(exercise, weight).toString();
    }

    function shortName(name) {
        if (name.length() <= NameRules.SHORT_MAX) {
            return name;
        }
        var words = [] as Array<String>;
        var rest = name;
        while (words.size() < NameRules.SHORT_WORDS) {
            var space = rest.find(" ");
            if (space == null) {
                words.add(rest);
                break;
            }
            words.add(rest.substring(0, space));
            rest = rest.substring(space + 1, rest.length());
        }
        if (words.size() > 1 && NameRules.CONNECTORS.indexOf(words[words.size() - 1].toLower()) >= 0) {
            words = words.slice(0, words.size() - 1);
        }
        var text = words[0];
        for (var i = 1; i < words.size(); i++) {
            text += " " + words[i];
        }
        return text;
    }

    function upper(text) {
        return text.toUpper();
    }
}
