import importlib.util
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("exercise_media", Path(__file__).with_name("exercise-media.py"))
media = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(media)


def pool_item(identifier, name, padrao, equipment="dumbbell", musculos=("quadriceps",)):
    return {"musculos": list(musculos), "origem": "freeExerciseDb", "id": identifier, "nome": name, "nome_original": name,
            "equipamento": equipment, "padrao": padrao, "quadros": [f"{identifier}/0.jpg"]}


class ExerciseMediaTests(unittest.TestCase):
    def test_norm_ignores_case_accents_spaces(self):
        self.assertEqual(media.norm("Agachamento  Goblet"), media.norm("agachamento goblet"))
        self.assertEqual(media.norm("Extensão Dorsal"), media.norm("extensao  dorsal"))

    def test_candidates_same_pattern_only(self):
        entry = {"id": "SQUAT/GOBLET_SQUAT", "exercicio": "GOBLET_SQUAT", "equipamento": "dumbbell", "padrao": "squat"}
        pool = [pool_item("a", "Dumbbell Squat", "squat"), pool_item("b", "Dumbbell Row", "horizontalPull"),
                pool_item("c", "Goblet Squat Hold", "squat")]
        result = media.equivalents(entry, pool)
        self.assertEqual({item["id"] for item in result}, {"a", "c"})
        self.assertTrue(all(item["equivalente"] and not item["revisado"] for item in result))

    def test_equivalents_empty_without_signal(self):
        entry = {"id": "BANDED_EXERCISES/AB_TWIST", "exercicio": "AB_TWIST", "equipamento": "band", "padrao": "antiRotation"}
        pool = [pool_item("a", "External Rotation with Band", "antiRotation", "bands", ("shoulders",)),
                pool_item("b", "Ab Roller", "antiRotation", "bands", ("abdominals",))]
        self.assertEqual(media.equivalents(entry, pool), [])

    def test_equivalents_require_shared_token(self):
        entry = {"id": "SQUAT/GOBLET_SQUAT", "exercicio": "GOBLET_SQUAT", "equipamento": "dumbbell", "padrao": "squat"}
        pool = [pool_item("a", "Leg Extensions", "squat"), pool_item("b", "Front Squat", "squat")]
        self.assertEqual([item["id"] for item in media.equivalents(entry, pool)], ["b"])

    def test_dumbbell_and_kettlebell_are_compatible_for_own_match(self):
        entry = {"id": "SQUAT/GOBLET_SQUAT", "exercicio": "GOBLET_SQUAT", "equipamento": "dumbbell", "padrao": "squat"}
        result = media.own_candidates(entry, [pool_item("k", "Goblet Squat", "squat", "kettlebells")])
        self.assertTrue(result[0]["revisado"])
        self.assertEqual(result[0]["confianca"], 1.0)

    def test_exact_name_with_compatible_equipment_is_auto_reviewed(self):
        entry = {"id": "SQUAT/GOBLET_SQUAT", "exercicio": "GOBLET_SQUAT", "equipamento": "dumbbell", "padrao": "squat"}
        pool = [pool_item("a", "Goblet Squat", "squat"), pool_item("b", "Goblet Squat", "squat", "barbell"),
                pool_item("c", "Goblet Squats Wide", "squat")]
        result = {item["id"]: item for item in media.own_candidates(entry, pool)}
        self.assertTrue(result["a"]["revisado"])
        self.assertFalse(result["b"]["revisado"])
        self.assertFalse(result["c"]["revisado"])

    def test_emit_keeps_only_reviewed(self):
        candidates = {"versao": 1, "ids": {
            "A/ONE": {"proprios": [{"id": "x", "revisado": True}], "equivalentes": [{"id": "y", "revisado": False}], "wger": []},
            "A/TWO": {"proprios": [{"id": "z", "revisado": False}], "equivalentes": [], "wger": []}}}
        self.assertEqual(media.reviewed_only(candidates), {"A/ONE": [{"id": "x", "revisado": True}]})


if __name__ == "__main__":
    unittest.main()
