import argparse
import json
import re
import sys
import urllib.request
from collections import Counter
from pathlib import Path

EXERCISES_URL = "https://connect.garmin.com/web-data/exercises/Exercises.json"
ROOT = Path(__file__).resolve().parent.parent
NAMES_URL = "https://connect.garmin.com/web-translations/exercise_types/exercise_types_pt_BR.properties"

EXCLUDED_CATEGORIES = {
    "BIKE_OUTDOOR", "ELLIPTICAL", "FLOOR_CLIMB", "INDOOR_BIKE", "LADDER", "RUN", "RUN_INDOOR", "STAIR_STEPPER",
    "CARDIO", "SLED", "TIRE", "SLEDGE_HAMMER", "BATTLE_ROPE", "SANDBAG", "OLYMPIC_LIFT",
}
GENERIC_NAMES = {"CORE", "HIP_STABILITY", "SHOULDER_STABILITY"}
EXCLUDED_WORDS = ["STRETCH_NECK", "NECK_ROTATIONS", "NECK_TILTS", "STRETCH_FOREARMS", "WRIST_CURL", "PLATE_PINCH", "SNATCH", "RUCK", "SANDBAG", "SLED", "TIRE", "CALORIE_ROW", "ROPE_CLIMB", "MUSCLE_UP", "KIPPING", "INDOOR_ROW", "HANDSTAND"]

EQUIPMENT_WORDS = [
    ("barbell", ["BARBELL", "EZ_BAR", "TRAP_BAR", "BODY_BAR", "BAR_GOOD_MORNING", "BAR_HOLDS", "RACK_PULL", "ZERCHER", "LANDMINE", "SAFETY_BAR", "BURPEE_OVER_BAR"]),
    ("machine", ["AB_WHEEL", "MACHINE", "SMITH", "LEG_PRESS", "HACK_SQUAT", "BELT_SQUAT", "GHD", "PULL_UP", "PULL_UPS", "CHIN_UP", "HANGING", "DEAD_HANG", "TOES_TO_BAR", "RING_", "_DIP", "DIP_", "PREACHER", "ASSISTED"]),
    ("cable", ["CABLE", "PULLDOWN", "PULL_DOWN", "LATPULL", "PRESSDOWN", "ROPE_", "CROSSOVER_CABLE", "PULL_THROUGH", "FACE_PULL", "FACE_PULLS"]),
    ("kettlebell", ["KETTLEBELL"]),
    ("dumbbell", ["DUMBBELL", "DUMBELL", "FARMERS", "SUITCASE", "GOBLET", "PLATE", "WAITER", "WEIGHT_PLATE"]),
    ("medicineBall", ["MEDICINE_BALL", "WALL_BALL"]),
    ("suspension", ["TRX", "SUSPENDED", "SUSPENSION"]),
    ("swissBall", ["SWISS_BALL", "BOSU"]),
    ("band", ["BAND", "BANDED", "PULL_APART"]),
]
EQUIPMENT_RANK = ["barbell", "machine", "cable", "kettlebell", "dumbbell", "medicineBall", "suspension", "swissBall", "band", "bodyweight"]
CATEGORY_EQUIPMENT = {
    "BANDED_EXERCISES": "band", "SUSPENSION": "suspension", "DEADLIFT": "barbell", "BENCH_PRESS": "barbell",
    "SHOULDER_PRESS": "dumbbell", "CURL": "dumbbell", "LATERAL_RAISE": "dumbbell", "FLYE": "dumbbell", "SHRUG": "dumbbell",
    "HIP_SWING": "kettlebell", "CARRY": "dumbbell", "LEG_CURL": "machine", "TRICEPS_EXTENSION": "dumbbell",
}
BODYWEIGHT_NAMES = {"BENCH_DIP", "TABLETOP_DIP", "SINGLE_LEG_DIP", "SINGLE_LEG_BENCH_DIP_AND_KICK"}
NAME_EQUIPMENT = {
    "BACK_SQUATS": "barbell", "OVERHEAD_SQUAT": "barbell", "THRUSTERS": "barbell", "MILITARY_PRESS": "barbell", "STRICT_PRESS": "barbell",
    "T_BAR_ROW": "barbell", "ONE_ARM_BENT_OVER_ROW": "dumbbell", "RENEGADE_ROW": "dumbbell", "ROW": "dumbbell", "SEATED_CALF_RAISE": "machine",
    "DONKEY_CALF_RAISE": "machine", "STANDING_CALF_RAISE": "machine", "LEG_EXTENSION": "machine",
}
CATEGORY_EQUIPMENT_EXCEPTIONS = ["GOOD_MORNING", "SLIDING", "BENCH_DIP", "BODY_WEIGHT", "TABLETOP_DIP", "SINGLE_LEG_DIP", "FLOOR",
                                  "INVERTED_SHOULDER_PRESS", "SPLIT_STANCE_EXTENSION", "SCAPTION", "WALL_", "SIDE_LYING_LATERAL_RAISE"]
TOOL_CATEGORIES = {"BANDED_EXERCISES": ("com elástico", ["elástic", "faixa"]), "SUSPENSION": ("na suspensão", ["suspens", "TRX"])}
GOOD_MORNING_EQUIPMENT = {"GOOD_MORNING": "barbell", "STAGGERED_STANCE_GOOD_MORNING": "barbell", "BAND_GOOD_MORNING": "band"}

MOBILITY_ANKLE = ["ANKLE", "CALF"]
MOBILITY_HIP = ["LEG_SWINGS", "HIP", "GLUTES", "HAMSTRING", "QUAD", "PIRIFORMIS", "PIGEON", "90_90", "BUTTERFLY", "GROINERS", "SIDE_LUNGE",
                "IT_BAND", "ABDUCTION", "SCORPION", "STRADDLE", "FRONT_SPLIT", "SIDE_SPLIT", "KNEE_TO_CHEST"]
MOBILITY_THORACIC = ["CAT_CAMEL", "CAT_COW", "THORACIC", "SPINAL", "LAT", "PECTORAL", "SHOULDER", "CHEST", "NECK", "TRICEPS", "BICEPS",
                     "FOREARM", "FOREARMS", "ARM_CIRCLES", "COBRA", "CHILDS", "OBLIQUES", "SIDE", "REACH", "LEVATOR", "SLEEPER", "ABS", "WALKOUT", "DUCK_UNDER", "WINDSHIELD"]

PATTERN_WORDS = [
    ("plyo", ["JUMP", "HOP", "BOUND", "BURPEE", "SKATER", "PLYO", "THROW", "THROWS", "SLAM", "CHEST_PASS", "CLAPPING", "EXPLOSIVE", "SCISSOR", "STAR_JUMP", "LEAP", "JUMPING"]),
    ("calf", ["CALF", "TOE_RAISE"]),
    ("horizontalPush", ["TRICEP", "TRICEPS", "SKULL", "DIP"]),
    ("hinge", ["BRIDGE", "REAR_LEG_EXTENSION", "HAMSTRING_CURL", "HAMSTRING_CURLS", "LEG_CURL", "GOOD_MORNING"]),
    ("hipStability", ["LATERAL_BAND_WALKS"]),
    ("singleLeg", ["LUNGE", "SPLIT_SQUAT", "STEP_UP", "STEPOVER", "STEP_OVER", "PISTOL", "SINGLE_LEG_SQUAT", "ONE_LEGGED_SQUAT",
                   "SINGLE_LEG_DEADLIFT", "SINGLE_LEG_RDL", "SINGLE_LEG_ROMANIAN", "SINGLE_LEG_BARBELL_DEADLIFT", "SINGLE_LEG_BARBELL_STRAIGHT",
                   "ONE_LEG_DEADLIFT", "ONE_ARM_ONE_LEG_DEADLIFT", "SINGLE_LEG_BENCH_SQUAT", "SINGLE_LEG_BENCH_GET_UP", "ELEVATED_SINGLE_LEG_SQUAT", "STEP_UP_AND_PRESS"]),
    ("squat", ["SQUAT", "LEG_PRESS", "THRUSTER", "WALL_SIT", "LEG_EXTENSION", "WALL_BALL"]),
    ("hinge", ["DEADLIFT", "RDL", "GOOD_MORNING", "HIP_THRUST", "HIP_RAISE", "BRIDGE", "SWING", "HYPEREXTENSION", "BACK_EXTENSION",
               "SUPERMAN", "LEG_CURL", "HAMSTRING_CURL", "PULL_THROUGH", "RACK_PULL", "NORDIC", "SPINE_EXTENSION", "REVERSE_HIP", "HIP_EXTENSION",
               "DONKEY_KICK", "REAR_LEG_EXTENSION", "FLOOR_TO_SHELF", "SPLIT_STANCE_EXTENSION"]),
    ("hipStability", ["CLAM", "ABDUCTION", "ADDUCTION", "FIRE_HYDRANT", "LATERAL_BAND_WALK", "LATERAL_WALK", "MONSTER", "HIP_CIRCLES",
                      "REAR_LEG_RAISE", "SIDE_LYING_LEG_RAISE", "INNER_THIGH", "PRETZEL", "HIP_DROP", "QUADRUPED_HIP", "QUADRUPED_WITH_LEG_LIFT",
                      "HIP_INTERNAL_ROTATION", "EXTERNAL_HIP_RAISE", "SIDE_STEP", "LATERAL_STEPOVER"]),
    ("horizontalPull", ["EXTERNAL_ROTATION", "INTERNAL_ROTATION", "I_RAISE", "T_RAISE", "Y_RAISE", "W_RAISE", "L_RAISE", "Y_FLY",
                        "PULL_APART", "FACE_PULL", "FACE_PULLS", "REAR_FLYE", "REVERSE_FLYE", "REAR_LATERAL", "BENT_OVER_LATERAL", "SCAPULAR", "SHOULDER_EXTENSION", "POWER_PULL", "ROW"]),
    ("verticalPull", ["PULL_UP", "PULL_UPS", "CHIN_UP", "PULLDOWN", "PULL_DOWN", "LATPULL", "PULLOVER", "CURL", "CURLS", "SHRUG", "UPRIGHT_ROW"]),
    ("verticalPush", ["SHOULDER_PRESS", "OVERHEAD_PRESS", "OVERHEAD_BARBELL_PRESS", "OVERHEAD_DUMBBELL_PRESS", "MILITARY", "ARNOLD", "PUSH_PRESS",
                      "STRICT_PRESS", "LANDMINE", "PIKE_PUSH_UP", "SHOULDER_PUSH_UP", "LATERAL_RAISE", "FRONT_RAISE", "DIAGONAL_RAISE", "V_RAISE",
                      "PLATE_RAISE", "SHOULDER_RAISE", "SCAPTION", "WALL_SLIDE", "SHOULDER_ABDUCTION", "SHOULDER_FLEXION", "LYING_DUMBBELL_RAISE", "INVERTED_SHOULDER_PRESS"]),
    ("horizontalPush", ["BENCH_PRESS", "CHEST_PRESS", "FLOOR_PRESS", "PUSH_UP", "PUSH_UPS", "PUSHUP", "FLY", "FLYE", "CABLE_CROSSOVER", "PARTIAL_LOCKOUT"]),
    ("lateralCore", ["SIDE_PLANK", "CARRY", "FARMERS", "SUITCASE", "SIDE_BEND", "COPENHAGEN", "WAITER", "HOLDS", "HEX_DUMBBELL_HOLD", "SIDE_ABS", "LATERAL_ROLL", "OVERHEAD_WALK"]),
    ("antiRotation", ["PALLOF", "HIP_CROSSOVER", "CHOP", "WOODCHOP", "WOOD_CHOP", "RUSSIAN_TWIST", "TWIST", "ROTATION", "ROTATIONAL", "WINDMILL", "BIRD_DOG",
                      "OPPOSITE_ARM", "TURKISH_GET_UP", "CORE_PRESS", "AB_TWIST", "T_STABILIZATION", "BASE_ROTATIONS", "STANDING_T_ROTATION"]),
    ("antiExtension", ["PLANK", "DEAD_BUG", "DEADBUG", "ROLLOUT", "AB_WHEEL", "CRUNCH", "SIT_UP", "SIT_UPS", "LEG_RAISE", "KNEE_RAISE", "HOLLOW",
                       "L_SIT", "V_UP", "MOUNTAIN_CLIMBER", "JACKKNIFE", "TUCK", "PIKE", "FLUTTER", "TEASER", "ROLL_UP", "ROLL_DOWN", "LEG_LOWERING",
                       "SLIDE_OUT", "BEAR_CRAWL", "INCHWORM", "KNEES_TO_ELBOW", "TOES_TO", "CURL_UP", "LEG_LEVERS", "X_ABS", "U_BOAT", "JABS", "LEG_DROPS", "KNEE_RAISES", "FROG_PRESS"]),
]
CATEGORY_PATTERN = {
    "SQUAT": "squat", "DEADLIFT": "hinge", "HIP_RAISE": "hinge", "LEG_CURL": "hinge", "LUNGE": "singleLeg", "CALF_RAISE": "calf",
    "HIP_STABILITY": "hipStability", "PLYO": "plyo", "BENCH_PRESS": "horizontalPush", "PUSH_UP": "horizontalPush", "FLYE": "horizontalPush",
    "TRICEPS_EXTENSION": "horizontalPush", "ROW": "horizontalPull", "SHOULDER_STABILITY": "horizontalPull", "CURL": "verticalPull",
    "PULL_UP": "verticalPull", "SHRUG": "verticalPull", "SHOULDER_PRESS": "verticalPush", "LATERAL_RAISE": "verticalPush",
    "PLANK": "antiExtension", "CORE": "antiExtension", "CRUNCH": "antiExtension", "SIT_UP": "antiExtension", "LEG_RAISE": "antiExtension",
    "CHOP": "antiRotation", "CARRY": "lateralCore", "HYPEREXTENSION": "hinge", "HIP_SWING": "hinge", "TOTAL_BODY": "plyo",
}
UPPER_PLYO = ["THROW", "THROWS", "SLAM", "CHEST_PASS", "CLAPPING", "PUSH_UP"]
LOWER_PATTERNS = {"squat", "hinge", "singleLeg", "calf", "hipStability"}
UPPER_PATTERNS = {"horizontalPush", "horizontalPull", "verticalPush", "verticalPull"}
CORE_PATTERNS = {"antiExtension", "antiRotation", "lateralCore"}
MOBILITY_PATTERNS = {"mobilityHip", "mobilityAnkle", "mobilityThoracic"}
LOWER_MUSCLES = {"QUADS", "HAMSTRINGS", "GLUTES", "CALVES", "HIPS", "ADDUCTORS", "ABDUCTORS"}
ISOLATION_WORDS = ["CURL", "CURLS", "TRICEP", "TRICEPS", "KICKBACK", "LATERAL_RAISE", "FRONT_RAISE", "FLYE", "FLY", "SHRUG", "WRIST", "LEG_EXTENSION", "LEG_CURL",
                   "PRESSDOWN", "CROSSOVER", "DIAGONAL_RAISE", "V_RAISE", "PLATE_RAISE", "SKULL"]
SHOULDER_CARE_WORDS = ["EXTERNAL_ROTATION", "INTERNAL_ROTATION", "I_RAISE", "T_RAISE", "Y_RAISE", "W_RAISE", "L_RAISE", "PULL_APART",
                       "FACE_PULL", "SCAPULAR", "Y_FLY", "SHOULDER_EXTENSION", "WALL_SLIDE", "SCAPTION"]
CRUNCH_WORDS = ["REVERSE_CURL_AND_LIFT", "CRUNCH", "CRUNCHES", "SIT_UP", "SIT_UPS", "V_UP", "CURL_UP", "TEASER", "ROLL_UP", "ROLL_DOWN", "X_ABS", "JABS", "FLUTTER", "LEG_LEVERS"]
LOWER_BACK_WORDS = ["OVERHEAD_BARBELL_PRESS", "MILITARY_PRESS", "BARBELL_PUSH_PRESS", "STRICT_PRESS", "DEADLIFT", "RDL", "GOOD_MORNING", "SWING", "HYPEREXTENSION", "BACK_EXTENSION", "SUPERMAN", "ROLLOUT", "AB_WHEEL",
                    "LEG_RAISE", "KNEE_RAISE", "REVERSE_CRUNCH", "BENT_OVER_ROW", "BARBELL_ROW", "PULL_THROUGH", "RACK_PULL", "SPINE_EXTENSION",
                    "TOES_TO_BAR", "LEG_LOWERING", "FLOOR_TO_SHELF", "T_BAR_ROW", "REVERSE_GRIP_BARBELL_ROW", "SLIDE_OUT", "GHD", "STRAIGHT_LEG_CRUNCH"]
SHOULDER_WORDS = ["PRESS", "PUSH_UP", "PUSH_UPS", "PULL_UP", "PULL_UPS", "CHIN_UP", "DIP", "HANGING", "DEAD_HANG", "OVERHEAD", "PULLDOWN",
                  "PULL_DOWN", "LATPULL", "PULLOVER", "LATERAL_RAISE", "FRONT_RAISE", "FLYE", "FLY", "UPRIGHT_ROW", "PIKE", "TOES_TO_BAR", "L_SIT"]
UNILATERAL_WORDS = ["SINGLE_", "ONE_ARM", "ONE_LEG", "ONE_LEGGED", "OFFSET", "SUITCASE", "SIDE_PLANK", "SIDE_LYING", "LUNGE", "SPLIT_SQUAT",
                    "STEP_UP", "PISTOL", "COPENHAGEN", "BIRD_DOG", "WINDMILL", "SIDE_BEND", "CLAM", "FIRE_HYDRANT", "DONKEY_KICK", "STEPOVER", "WAITER"]
SYMMETRIC_STRETCHES = ["CAT", "COBRA", "CHILDS", "BUTTERFLY", "STRADDLE", "ABS", "NECK", "LATERAL_DUCK", "WALKOUT", "INCHWORM", "ARM_CIRCLES",
                       "SHOULDER_CIRCLES", "BENT_OVER_REACH", "QUADRUPED_ROCKING", "WALKING_HIGH", "WALKING_KNEE", "INVERTED_HAMSTRING", "GLUTES_STRETCH",
                       "STANDING_HAMSTRING", "SLIDE_OUT", "SIDE_TO_SIDE", "SWISS_BALL_WINDSHIELD", "WALL_CHEST", "OVER_UNDER", "FOREARMS", "FRONT_SPLIT", "SIDE_SPLIT"]
TIMED_WORDS = ["PLANK", "HOLD", "L_SIT", "WALL_SIT", "WALL_SQUAT", "DEAD_HANG", "CARRY", "FARMERS", "HOLLOW_HOLD", "ISOMETRIC", "STATIC",
               "COPENHAGEN", "OVERHEAD_WALK", "BEAR_CRAWL", "STRETCH_"]
REP_PLANKS = ["PUSH_UP", "LEG_LIFTS", "PLANK_PIKES", "MOUNTAIN_CLIMBER", "PLANK_JACKS", "PLANK_PIKE", "PLANK_KNEE", "PLANK_WITH_KNEE", "PLANK_TO_STAND", "PLANK_WITH_ARM", "PLANK_WITH_LEG",
              "INCHWORM", "SIDE_PLANK_AND_ROW", "SIDE_PLANK_LIFT", "SIDE_PLANK_WITH_LEG", "SIDE_PLANK_WITH_KNEE", "SIDE_PLANK_WITH_REACH",
              "SIDE_PLANK_TO_PLANK", "ROLLING_SIDE_PLANK", "PLYOMETRIC_SIDE_PLANK", "SIDE_KICK_PLANK", "SPIDERMAN_PLANK", "SHOULDER_TOUCH",
              "SWISS_BALL_PLANK_LEG_LIFT", "WIDE_STANCE_PLANK", "THREE_WAY_PLANK", "TOWEL_PLANK", "RING_PLANK", "PLANK_KNEE_TUCKS", "ELBOW_PLANK_PIKE",
              "INCHING_ELBOW", "FULL_PLANK_PASSE", "KNEELING_SIDE_PLANK_WITH_LEG", "TURKISH_GET_UP_TO_SIDE_PLANK", "STATIC_LYING_TRICEPS", "STATIC_CURL"]


def has(name, words):
    padded = f"_{name}_"
    return any(f"_{word.strip('_')}_" in padded for word in words)


def equipment_of(category, name):
    if category in TOOL_CATEGORIES:
        return CATEGORY_EQUIPMENT[category]
    if name in BODYWEIGHT_NAMES:
        return "bodyweight"
    if category != "BANDED_EXERCISES" and name in NAME_EQUIPMENT:
        return NAME_EQUIPMENT[name]
    found = [kind for kind, words in EQUIPMENT_WORDS if has(name, words)]
    if found:
        return min(found, key=EQUIPMENT_RANK.index)
    if name in GOOD_MORNING_EQUIPMENT:
        return GOOD_MORNING_EQUIPMENT[name]
    if category in CATEGORY_EQUIPMENT and not has(name, CATEGORY_EQUIPMENT_EXCEPTIONS):
        return CATEGORY_EQUIPMENT[category]
    if has(name, ["WEIGHTED"]):
        return "dumbbell"
    return "bodyweight"


def pattern_of(category, name, primary):
    if category == "WARM_UP" or name.startswith("STRETCH_"):
        if has(name, MOBILITY_ANKLE):
            return "mobilityAnkle"
        if has(name, MOBILITY_HIP):
            return "mobilityHip"
        if has(name, MOBILITY_THORACIC):
            return "mobilityThoracic"
        return "mobilityHip"
    base = name.removeprefix("WEIGHTED_")
    if has(base, CRUNCH_WORDS):
        return "antiExtension"
    if has(base, ["SHOULDER_ABDUCTION", "SHOULDER_FLEXION_TO_90_DEGREES"]):
        return "verticalPush"
    for pattern, words in PATTERN_WORDS:
        if has(base, words):
            if pattern == "plyo" and has(base, ["SHRUG", "PULL_UP", "PULL_UPS", "CRUNCH"]):
                continue
            return pattern
    if category in CATEGORY_PATTERN:
        return CATEGORY_PATTERN[category]
    if set(primary) & LOWER_MUSCLES:
        return "squat"
    return "antiExtension"


def focus_of(pattern, name, primary):
    if pattern in MOBILITY_PATTERNS:
        return ["core"]
    if pattern == "plyo":
        return ["fullBody", "lower"] if set(primary) & LOWER_MUSCLES or not primary else ["upper"]
    if pattern == "hipStability":
        return ["core", "lower"]
    if pattern in LOWER_PATTERNS:
        return ["lower"] if has(name, ISOLATION_WORDS) else ["fullBody", "lower"]
    if pattern in UPPER_PATTERNS:
        if has(name, SHOULDER_CARE_WORDS):
            return ["core", "upper"]
        return ["upper"] if has(name, ISOLATION_WORDS) else ["fullBody", "upper"]
    if has(name, CRUNCH_WORDS):
        return ["core"]
    return ["core", "fullBody"]


def loads_of(pattern, name, equipment):
    loads = set()
    if pattern in {"squat", "singleLeg"} or (pattern == "plyo" and not has(name, UPPER_PLYO)):
        loads.add("knee")
    if pattern in {"calf", "plyo"} and not has(name, UPPER_PLYO):
        loads.add("calfAchilles")
    if pattern in {"hinge", "singleLeg", "hipStability"} or (pattern == "squat" and equipment in {"barbell", "machine"}):
        loads.add("hip")
    if pattern in {"hinge", "squat"} and equipment == "barbell" or has(name, LOWER_BACK_WORDS) and pattern != "hipStability":
        loads.add("lowerBack")
    if has(name, ["LEG_CURL", "HAMSTRING_CURL", "NORDIC"]):
        loads.add("knee")
    if pattern in {"horizontalPush", "verticalPush"} and not has(name, SHOULDER_CARE_WORDS) or has(name, SHOULDER_WORDS) and not has(name, ["LEG_PRESS", "FROG_PRESS", "CORE_PRESS", "HIP_PRESS"]):
        loads.add("shoulder")
    if pattern == "verticalPull" and not has(name, ["CURL", "SHRUG"]):
        loads.add("shoulder")
    if pattern in MOBILITY_PATTERNS:
        return []
    return sorted(loads)


def unilateral_of(pattern, name):
    if pattern in MOBILITY_PATTERNS:
        return name.startswith("STRETCH_") and not has(name, SYMMETRIC_STRETCHES) or has(name, ["LEG_SWINGS", "90_90", "HIP_FLEXOR", "PIGEON", "THORACIC_ROTATION", "DORSIFLEXION"])
    return has(name, UNILATERAL_WORDS) and not has(name, ["ALTERNATING", "WALKING"])


def timed_of(name):
    return has(name, TIMED_WORDS) and not has(name, REP_PLANKS)


def english_name(key):
    return key.strip("_").replace("_", " ").capitalize()


def load_names(text):
    names = {}
    for line in text.splitlines():
        if "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            names[key.strip()] = value.strip()
    return names


def build(exercises, names, overrides):
    rows, report = [], Counter()
    for category, body in sorted(exercises["categories"].items()):
        if category in EXCLUDED_CATEGORIES:
            report["categoria excluída"] += len(body["exercises"])
            continue
        for name, muscles in sorted(body["exercises"].items()):
            exercise_id = f"{category}/{name}"
            override = overrides.get(exercise_id, {})
            if override.get("excluir") or name in GENERIC_NAMES or any(word in name for word in EXCLUDED_WORDS):
                report["excluído por nome"] += 1
                continue
            primary = muscles.get("primaryMuscles", [])
            equipment = equipment_of(category, name)
            pattern = pattern_of(category, name, primary)
            translated = (names.get(f"category_type_{name}") if name == category else None) or names.get(f"exercise_type_{name}")
            if not translated:
                report["sem tradução"] += 1
            if translated and category in TOOL_CATEGORIES:
                suffix, markers = TOOL_CATEGORIES[category]
                if not any(marker.lower() in translated.lower() for marker in markers):
                    translated = f"{translated} {suffix}"
            row = {
                "id": exercise_id, "nome": translated or english_name(name), "categoria": category, "exercicio": name,
                "padrao": pattern, "equipamento": equipment, "focos": focus_of(pattern, name, primary),
                "regioes": loads_of(pattern, name, equipment), "unilateral": unilateral_of(pattern, name), "isometria": timed_of(name),
            }
            row.update({key: value for key, value in override.items() if key in row})
            report[f"equipamento {row['equipamento']}"] += 1
            report[f"padrão {row['padrao']}"] += 1
            rows.append(row)
    return rows, report


def swift_source(rows):
    payload = json.dumps(rows, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    lines = ",\n".join(json.dumps(row, ensure_ascii=False, separators=(",", ":"), sort_keys=True) for row in rows)
    assert json.loads(f"[{lines}]") == json.loads(payload)
    return f'enum GarminStrengthCatalogData {{\n    static let json = #"""\n[\n{lines}\n]\n"""#\n}}\n'


def read_rows(path):
    if not path.exists():
        return []
    source = path.read_text("utf-8")
    return json.loads(source.split('#"""', 1)[1].rsplit('"""#', 1)[0])


def describe(row):
    return f"`{row['id']}` {row['nome']} ({row['padrao']}, {row['equipamento']}, regiões: {', '.join(row['regioes']) or 'nenhuma'})"


def changes(old_rows, new_rows, referenced_text=""):
    old = {row["id"]: row for row in old_rows}
    new = {row["id"]: row for row in new_rows}
    added = [new[key] for key in sorted(new.keys() - old.keys())]
    removed = [old[key] for key in sorted(old.keys() - new.keys())]
    changed = []
    for key in sorted(old.keys() & new.keys()):
        fields = [field for field in new[key] if new[key][field] != old[key].get(field)]
        if fields:
            changed.append((new[key], {field: (old[key].get(field), new[key][field]) for field in fields}))
    return {
        "added": added, "removed": removed, "changed": changed,
        "referenced": [row["id"] for row in removed if f'"{row["id"]}"' in referenced_text],
    }


def markdown(diff):
    if not (diff["added"] or diff["removed"] or diff["changed"]):
        return "Sem mudanças no catálogo de exercícios da Garmin."
    lines = [f"Catálogo da Garmin: {len(diff['added'])} novos, {len(diff['removed'])} removidos, {len(diff['changed'])} alterados."]
    if diff["referenced"]:
        lines += ["", "**Atenção:** removidos que estão em `StrengthCatalogConstants` (ids antigos ou nomes antigos) e precisam de um novo destino:"]
        lines += [f"- `{key}`" for key in diff["referenced"]]
    if diff["added"]:
        lines += ["", "**Novos** (conferir padrão, equipamento e regiões):"] + [f"- {describe(row)}" for row in diff["added"]]
    if diff["removed"]:
        lines += ["", "**Removidos:**"] + [f"- {describe(row)}" for row in diff["removed"]]
    if diff["changed"]:
        lines += ["", "**Alterados:**"]
        for row, fields in diff["changed"]:
            detail = "; ".join(f"{field}: {before} → {after}" for field, (before, after) in fields.items())
            lines.append(f"- `{row['id']}`: {detail}")
    return "\n".join(lines)


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "training-catalog"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--exercises", type=Path)
    parser.add_argument("--names", type=Path)
    parser.add_argument("--overrides", type=Path, default=Path(__file__).with_name("garmin-catalog-overrides.json"))
    parser.add_argument("--out", type=Path, default=ROOT / "Packages/TrainingKit/Sources/Insights/GarminStrengthCatalogData.swift")
    parser.add_argument("--constants", type=Path, default=ROOT / "Packages/TrainingKit/Sources/Insights/StrengthCatalogConstants.swift")
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    exercises = json.loads(args.exercises.read_text("utf-8") if args.exercises else fetch(EXERCISES_URL))
    names = load_names(args.names.read_text("utf-8") if args.names else fetch(NAMES_URL))
    overrides = json.loads(args.overrides.read_text("utf-8")) if args.overrides.exists() else {}
    rows, report = build(exercises, names, overrides)
    referenced = args.constants.read_text("utf-8") if args.constants.exists() else ""
    summary = markdown(changes(read_rows(args.out), rows, referenced))
    args.out.write_text(swift_source(rows), "utf-8")
    print(summary)
    if args.report:
        args.report.write_text(summary + "\n", "utf-8")
    print(f"{len(rows)} exercícios gravados em {args.out}", file=sys.stderr)
    for key, count in sorted(report.items()):
        print(f"  {key}: {count}", file=sys.stderr)


if __name__ == "__main__":
    main()
