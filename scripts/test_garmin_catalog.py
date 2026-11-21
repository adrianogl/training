import importlib.util
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("garmin_catalog", Path(__file__).with_name("garmin-catalog.py"))
catalog = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(catalog)

EXERCISES = {
    "categories": {
        "SQUAT": {"exercises": {
            "BARBELL_BACK_SQUAT": {"primaryMuscles": ["QUADS"]},
            "GOBLET_SQUAT": {"primaryMuscles": ["QUADS"]},
            "STEP_UP": {"primaryMuscles": ["QUADS"]},
            "BARBELL_HANG_SQUAT_SNATCH": {"primaryMuscles": ["QUADS"]},
        }},
        "DEADLIFT": {"exercises": {"ROMANIAN_DEADLIFT": {"primaryMuscles": ["HAMSTRINGS"]}, "DEADLIFT": {"primaryMuscles": ["HAMSTRINGS"]}}},
        "BANDED_EXERCISES": {"exercises": {"ROW": {"primaryMuscles": ["LATS"]}, "DEADLIFT": {"primaryMuscles": ["HAMSTRINGS"]}}},
        "PLANK": {"exercises": {"SIDE_PLANK": {"primaryMuscles": ["OBLIQUES"]}, "MOUNTAIN_CLIMBER": {"primaryMuscles": ["ABS"]}}},
        "PLYO": {"exercises": {"BOX_JUMP": {"primaryMuscles": ["QUADS"]}, "MEDICINE_BALL_SLAM": {"primaryMuscles": ["LATS"]}}},
        "CURL": {"exercises": {"DUMBBELL_BICEPS_CURL": {"primaryMuscles": ["BICEPS"]}}},
        "CRUNCH": {"exercises": {"MCGILL_CURL_UP": {"primaryMuscles": ["ABS"]}}},
        "WARM_UP": {"exercises": {"STRETCH_CALF": {"primaryMuscles": ["CALVES"]}, "CAT_CAMEL": {"primaryMuscles": ["LOWER_BACK"]}, "STRETCH_NECK": {"primaryMuscles": []}}},
        "CORE": {"exercises": {"CORE": {"primaryMuscles": ["ABS"]}}},
        "RUN": {"exercises": {"RUN": {"primaryMuscles": ["QUADS"]}}},
    }
}
NAMES = catalog.load_names("""
exercise_type_GOBLET_SQUAT=Agachamento Goblet
exercise_type_DEADLIFT=Levantamento com faixa elástica
category_type_DEADLIFT=Levantamento terra
exercise_type_ROW=Remo
exercise_type_SIDE_PLANK=Prancha lateral
""")


GENERATED = Path(__file__).resolve().parent.parent / "Packages/TrainingKit/Sources/Insights/GarminStrengthCatalogData.swift"


class GeneratedCatalogNamesTests(unittest.TestCase):
    def setUp(self):
        self.names = {row["id"]: row["nome"] for row in catalog.read_rows(GENERATED)}

    def test_bulgarian_variations_have_distinct_names(self):
        bulgarians = {key: name for key, name in self.names.items() if "BULGARIAN" in key}
        self.assertEqual(len(set(bulgarians.values())), len(bulgarians))
        self.assertIn("acima da cabeça", self.names["LUNGE/DUMBBELL_OVERHEAD_BULGARIAN_SPLIT_SQUAT"])
        self.assertIn("halter", self.names["LUNGE/DUMBBELL_OVERHEAD_BULGARIAN_SPLIT_SQUAT"])

    def test_names_are_unique_except_known_garmin_twins(self):
        from collections import Counter
        twins = {"Flexão de braços com as mãos afastadas"}
        repeated = {name for name, count in Counter(self.names.values()).items() if count > 1}
        self.assertEqual(repeated, twins)

    def test_decline_dumbbell_bench_press_is_decline(self):
        name = self.names["BENCH_PRESS/DECLINE_DUMBBELL_BENCH_PRESS"]
        self.assertIn("declinado", name)
        self.assertNotIn("inclinado", name.replace("declinado", ""))
        self.assertNotEqual(name, self.names["BENCH_PRESS/INCLINE_DUMBBELL_BENCH_PRESS"])


class GarminCatalogTests(unittest.TestCase):
    def setUp(self):
        rows, self.report = catalog.build(EXERCISES, NAMES, {"BANDED_EXERCISES/ROW": {"nome": "Remada com elástico"}})
        self.rows = {row["id"]: row for row in rows}

    def test_excludes_cardio_generic_and_olympic(self):
        self.assertNotIn("RUN/RUN", self.rows)
        self.assertNotIn("CORE/CORE", self.rows)
        self.assertNotIn("SQUAT/BARBELL_HANG_SQUAT_SNATCH", self.rows)
        self.assertNotIn("WARM_UP/STRETCH_NECK", self.rows)

    def test_equipment_comes_from_name_then_category(self):
        self.assertEqual(self.rows["SQUAT/BARBELL_BACK_SQUAT"]["equipamento"], "barbell")
        self.assertEqual(self.rows["SQUAT/GOBLET_SQUAT"]["equipamento"], "dumbbell")
        self.assertEqual(self.rows["DEADLIFT/ROMANIAN_DEADLIFT"]["equipamento"], "barbell")
        self.assertEqual(self.rows["BANDED_EXERCISES/DEADLIFT"]["equipamento"], "band")
        self.assertEqual(self.rows["PLANK/SIDE_PLANK"]["equipamento"], "bodyweight")

    def test_pattern_and_pain_regions(self):
        self.assertEqual(self.rows["SQUAT/STEP_UP"]["padrao"], "singleLeg")
        self.assertEqual(self.rows["PLANK/SIDE_PLANK"]["padrao"], "lateralCore")
        self.assertEqual(self.rows["CRUNCH/MCGILL_CURL_UP"]["padrao"], "antiExtension")
        self.assertEqual(self.rows["CURL/DUMBBELL_BICEPS_CURL"]["focos"], ["upper"])
        self.assertEqual(self.rows["SQUAT/BARBELL_BACK_SQUAT"]["regioes"], ["hip", "knee", "lowerBack"])
        self.assertEqual(self.rows["PLYO/BOX_JUMP"]["regioes"], ["calfAchilles", "knee"])
        self.assertEqual(self.rows["PLYO/MEDICINE_BALL_SLAM"]["regioes"], [])

    def test_mobility_by_region(self):
        self.assertEqual(self.rows["WARM_UP/STRETCH_CALF"]["padrao"], "mobilityAnkle")
        self.assertEqual(self.rows["WARM_UP/CAT_CAMEL"]["padrao"], "mobilityThoracic")
        self.assertTrue(self.rows["WARM_UP/STRETCH_CALF"]["isometria"])

    def test_timed_and_unilateral(self):
        self.assertTrue(self.rows["PLANK/SIDE_PLANK"]["isometria"])
        self.assertTrue(self.rows["PLANK/SIDE_PLANK"]["unilateral"])
        self.assertFalse(self.rows["PLANK/MOUNTAIN_CLIMBER"]["isometria"])

    def test_names(self):
        self.assertEqual(self.rows["SQUAT/GOBLET_SQUAT"]["nome"], "Agachamento Goblet")
        self.assertEqual(self.rows["DEADLIFT/DEADLIFT"]["nome"], "Levantamento terra")
        self.assertEqual(self.rows["BANDED_EXERCISES/ROW"]["nome"], "Remada com elástico")
        self.assertEqual(self.rows["SQUAT/STEP_UP"]["nome"], "Step up")

    def test_swift_source_holds_valid_json(self):
        source = catalog.swift_source(list(self.rows.values()))
        self.assertTrue(source.startswith("enum GarminStrengthCatalogData {"))

    def test_reports_added_removed_and_changed(self):
        old = [dict(self.rows["SQUAT/GOBLET_SQUAT"], nome="Goblet"), self.rows["PLANK/SIDE_PLANK"], {**self.rows["PLYO/BOX_JUMP"], "id": "PLYO/OLD_JUMP"}]
        new = [self.rows["SQUAT/GOBLET_SQUAT"], self.rows["PLANK/SIDE_PLANK"], self.rows["SQUAT/STEP_UP"]]
        diff = catalog.changes(old, new, '"PLYO/OLD_JUMP": "x"')
        self.assertEqual([row["id"] for row in diff["added"]], ["SQUAT/STEP_UP"])
        self.assertEqual([row["id"] for row in diff["removed"]], ["PLYO/OLD_JUMP"])
        self.assertEqual(diff["changed"][0][1], {"nome": ("Goblet", "Agachamento Goblet")})
        self.assertEqual(diff["referenced"], ["PLYO/OLD_JUMP"])
        text = catalog.markdown(diff)
        self.assertIn("1 novos, 1 removidos, 1 alterados", text)
        self.assertIn("**Atenção:**", text)

    def test_reports_nothing_when_equal(self):
        rows = list(self.rows.values())
        self.assertEqual(catalog.markdown(catalog.changes(rows, rows)), "Sem mudanças no catálogo de exercícios da Garmin.")

    def test_snapshot_keeps_the_raw_garmin_list(self):
        raw = catalog.raw_names(EXERCISES, NAMES)
        self.assertEqual(raw["SQUAT/GOBLET_SQUAT"], "Agachamento Goblet")
        self.assertIsNone(raw["SQUAT/STEP_UP"])
        self.assertIn("RUN/RUN", raw)
        referenced = catalog.referenced_ids('"agachamento-livre": "SQUAT/BARBELL_BACK_SQUAT",\n"SQUAT/BARBELL_BACK_SQUAT": "Agachamento livre"')
        self.assertEqual(referenced, ["SQUAT/BARBELL_BACK_SQUAT"])
        source = catalog.snapshot_source({"SQUAT/STEP_UP": None, "SQUAT/GOBLET_SQUAT": "Agachamento Goblet"}, referenced)
        self.assertIn('"SQUAT/STEP_UP": null', source)
        self.assertIn("GARMIN_CATALOG_REFERENCED", source)

    def test_reads_rows_back_from_swift_source(self):
        import tempfile
        rows = list(self.rows.values())
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "out.swift"
            path.write_text(catalog.swift_source(rows), "utf-8")
            self.assertEqual(catalog.read_rows(path), rows)


if __name__ == "__main__":
    unittest.main()
