import importlib.util
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("release_version_file", Path(__file__).with_name("release_version_file.py"))
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class ReleaseVersionFileTests(unittest.TestCase):
    def test_app_change_moves_app_version_and_notes(self):
        data = release.version_file({"versao_app": "1.9.0", "notas": ["Antiga"]}, "1.11.0", 16, True,
                                    "feat(app): avisa quando há versão nova\nfix: corrige o total da semana\nfeat!: muda tudo\nfeat: quarta nota")
        self.assertEqual(data["versao_app"], "1.11.0")
        self.assertEqual(data["notas"], ["Avisa quando há versão nova", "Corrige o total da semana", "Muda tudo"])
        self.assertEqual(data["historico"], [{"versao": "1.11.0", "notas": data["notas"]}, {"versao": "1.9.0", "notas": ["Antiga"]}])

    def test_notes_fix_proper_nouns_and_capitalize(self):
        notes = release.notes_from(
            "feat(x): envia o nome do exercício do mfit ao garmin connect\n"
            "feat: renomeia o app para training e mantém trAIning\n"
            "fix: mostra vo2 e fc no iphone, ipad e apple watch via mcp\n"
            "fix: lê strava e claude; garmin, connect iq, apple saúde. mfits fica")
        self.assertEqual(notes[0], "Envia o nome do exercício do MFIT ao Garmin Connect")
        self.assertEqual(notes[1], "Renomeia o app para Training e mantém trAIning")
        self.assertEqual(notes[2], "Mostra VO2 e FC no iPhone, iPad e Apple Watch via MCP")

    def test_format_note_covers_remaining_names(self):
        self.assertEqual(release.format_note("lê strava e claude; garmin, connect iq, apple saúde. mfits fica"),
                         "Lê Strava e Claude; Garmin, Connect IQ, Apple Saúde. mfits fica")
        self.assertEqual(release.format_note("trAIning abre"), "trAIning abre")

    def test_release_without_app_change_keeps_the_last_app_version(self):
        data = release.version_file({"versao_app": "1.9.0", "notas": ["Usa o catálogo"]}, "1.10.0", 15, False, "")
        self.assertEqual(data, {"versao": "1.10.0", "build": 15, "versao_app": "1.9.0", "notas": ["Usa o catálogo"],
                                "historico": [{"versao": "1.9.0", "notas": ["Usa o catálogo"]}]})

    def test_history_keeps_the_last_app_versions(self):
        history = [{"versao": f"1.{minor}.0", "notas": [f"Nota {minor}"]} for minor in range(20, 10, -1)]
        data = release.version_file({"versao_app": "1.20.0", "notas": ["Nota 20"], "historico": history}, "1.21.0", 30, True, "fix: nova")
        self.assertEqual(len(data["historico"]), release.MAX_HISTORY)
        self.assertEqual(data["historico"][0], {"versao": "1.21.0", "notas": ["Nova"]})
        self.assertEqual(data["historico"][-1]["versao"], "1.12.0")


if __name__ == "__main__":
    unittest.main()
