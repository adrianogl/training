import importlib.util
import os
import unittest
from datetime import datetime, timezone
from pathlib import Path

os.environ["TZ"] = "America/Sao_Paulo"
import time
time.tzset()

SPEC = importlib.util.spec_from_file_location("auto_install", Path(__file__).with_name("auto_install.py"))
auto = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(auto)

EXPIRY = "2026-11-26T16:21:07Z"
DEVICES = [{"id": "a", "name": "iPhone do Adriano"}, {"id": "b", "name": "iPhone da Thaís"}]


def at(text):
    return datetime.fromisoformat(text).astimezone(timezone.utc)


class AutoInstallTests(unittest.TestCase):
    def test_reinstalls_from_the_fifth_day(self):
        state = {"a": {"expires": EXPIRY}, "b": {"expires": EXPIRY}}
        self.assertEqual(auto.due_devices(DEVICES, state, at("2026-11-23T12:00:00-03:00")), [])
        self.assertEqual(auto.due_devices(DEVICES, state, at("2026-11-24T12:00:00-03:00")), DEVICES)

    def test_device_without_state_is_due(self):
        self.assertEqual(auto.due_devices(DEVICES, {"a": {"expires": "2026-12-03T16:00:00Z"}}, at("2026-11-24T12:00:00-03:00")), [DEVICES[1]])

    def test_notifies_once_from_noon_of_the_sixth_day(self):
        entry = {"expires": EXPIRY}
        self.assertFalse(auto.should_notify(entry, at("2026-11-24T21:00:00-03:00")))
        self.assertFalse(auto.should_notify(entry, at("2026-11-25T11:59:00-03:00")))
        self.assertTrue(auto.should_notify(entry, at("2026-11-25T12:00:00-03:00")))
        self.assertFalse(auto.should_notify({"expires": EXPIRY, "notified_for": EXPIRY}, at("2026-11-25T21:00:00-03:00")))

    def test_failure_text_uses_local_time(self):
        self.assertEqual(
            auto.failure_text("iPhone da Thaís", auto.parse(EXPIRY)),
            "iPhone da Thaís sem instalar. As tentativas de reinstalar o trAIning falharam (aparelho bloqueado ou fora da rede). Vence em 26/11 às 13:21.",
        )


if __name__ == "__main__":
    unittest.main()
