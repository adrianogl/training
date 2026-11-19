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

    def test_release_without_app_change_keeps_the_last_app_version(self):
        data = release.version_file({"versao_app": "1.9.0", "notas": ["Usa o catálogo"]}, "1.10.0", 15, False, "")
        self.assertEqual(data, {"versao": "1.10.0", "build": 15, "versao_app": "1.9.0", "notas": ["Usa o catálogo"]})


if __name__ == "__main__":
    unittest.main()
