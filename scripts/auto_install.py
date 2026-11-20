import argparse
import json
import plistlib
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

CONFIG_DIR = Path.home() / ".config/training-sync"
CONFIG_FILE = CONFIG_DIR / "auto-install.json"
STATE_FILE = CONFIG_DIR / "auto-install-state.json"
LOG_FILE = CONFIG_DIR / "auto-install.log"
PROFILES_DIR = Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles"
APP_PATH = "DerivedData/Build/Products/Debug-iphoneos/trAIning.app"
BUNDLE_PREFIX = "dev.aglv.training"
BUNDLE_ID = BUNDLE_PREFIX
REINSTALL_DAYS = 2
NOTIFY_DAYS = 1
NOTIFY_HOUR = 12
TITLE = "trAIning · instalação"
IMESSAGE_SCRIPT = """on run argv
  tell application "Messages"
    set target to participant (item 2 of argv) of (1st account whose service type = iMessage)
    send (item 1 of argv) to target
  end tell
end run"""
NOTIFICATION_SCRIPT = """on run argv
  display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv)
end run"""


def days_left(expiry, now):
    return (expiry.astimezone().date() - now.astimezone().date()).days


def due_devices(devices, state, now):
    due = []
    for device in devices:
        expiry = parse(state.get(device["id"], {}).get("expires"))
        if expiry is None or days_left(expiry, now) <= REINSTALL_DAYS:
            due.append(device)
    return due


def should_notify(entry, now):
    expiry = parse(entry.get("expires"))
    if expiry is None or entry.get("notified_for") == entry.get("expires"):
        return False
    return days_left(expiry, now) <= NOTIFY_DAYS and now.astimezone().hour >= NOTIFY_HOUR


def failure_text(name, expiry):
    local = expiry.astimezone()
    return f"{name} sem instalar. As tentativas de reinstalar o trAIning falharam (aparelho bloqueado ou fora da rede). Vence em {local:%d/%m} às {local:%H:%M}."


def parse(value):
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def iso(value):
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def log(message, now):
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as file:
        file.write(f"{now.astimezone():%Y-%m-%d %H:%M} {message}\n")
    print(message)


def run(command, cwd=None):
    return subprocess.run(command, cwd=cwd, capture_output=True, text=True)


def profile_expiry(profile):
    decoded = run(["security", "cms", "-D", "-i", str(profile)])
    if decoded.returncode != 0:
        return None, None
    data = plistlib.loads(decoded.stdout.encode())
    identifier = data.get("Entitlements", {}).get("application-identifier", "")
    expiry = data.get("ExpirationDate")
    if expiry is not None and expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)
    return expiry, identifier


def remove_cached_profiles(team):
    for profile in PROFILES_DIR.glob("*.mobileprovision"):
        _, identifier = profile_expiry(profile)
        if identifier.startswith(f"{team}.{BUNDLE_PREFIX}"):
            profile.unlink()


def prepare_worktree(config):
    worktree = Path(config["worktree"])
    if not worktree.exists():
        result = run(["git", "-C", config["repo"], "worktree", "add", "--detach", str(worktree), "origin/main"])
        if result.returncode != 0:
            return result.stderr.strip()
    for command in (["git", "fetch", "-q", "origin"], ["git", "checkout", "-q", "--detach", "--force", "origin/main"]):
        result = run(command, cwd=worktree)
        if result.returncode != 0:
            return result.stderr.strip()
    return None


def build(config):
    worktree = Path(config["worktree"])
    remove_cached_profiles(config["team"])
    generated = run([config.get("xcodegen", "/opt/homebrew/bin/xcodegen"), "generate", "--spec", "project.yml", "--project", ".", "--quiet"], cwd=worktree)
    if generated.returncode != 0:
        return None, generated.stderr.strip()
    run(["rm", "-rf", "DerivedData/Build/Products/Debug-iphoneos"], cwd=worktree)
    built = run([
        "xcodebuild", "-project", "trAIning.xcodeproj", "-scheme", "trAIning", "-destination", "generic/platform=iOS",
        "-derivedDataPath", "DerivedData", f"DEVELOPMENT_TEAM={config['team']}", "-allowProvisioningUpdates", "build",
    ], cwd=worktree)
    if built.returncode != 0 or "BUILD SUCCEEDED" not in built.stdout:
        errors = [line for line in built.stdout.splitlines() if "error:" in line][:3]
        return None, " | ".join(errors) or "xcodebuild falhou"
    expiry, _ = profile_expiry(worktree / APP_PATH / "embedded.mobileprovision")
    return expiry, None


def install(config, device):
    app = Path(config["worktree"]) / APP_PATH
    result = run(["xcrun", "devicectl", "device", "install", "app", "--device", device["id"], str(app)])
    return result.returncode == 0 and "App installed" in result.stdout, (result.stderr or result.stdout).strip().splitlines()[-1:]


def wake(device):
    return run(["xcrun", "devicectl", "device", "process", "launch", "--no-activate", "--device", device["id"], BUNDLE_ID]).returncode == 0


def notify(config, text, name):
    subprocess.run(["osascript", "-e", NOTIFICATION_SCRIPT, text, TITLE, name])
    if config.get("imessage"):
        subprocess.run(["osascript", "-e", IMESSAGE_SCRIPT, f"trAIning: {text}", config["imessage"]])


def load(path, default):
    return json.loads(path.read_text("utf-8")) if path.exists() else default


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--init-expiry", help="grava esta validade (ISO) para todos os aparelhos e sai")
    parser.add_argument("--test-notify", action="store_true", help="manda uma notificação e um iMessage de teste e sai")
    args = parser.parse_args()
    now = datetime.now(timezone.utc)
    config = load(CONFIG_FILE, None)
    if config is None:
        print(f"falta {CONFIG_FILE}", file=sys.stderr)
        return 1
    state = load(STATE_FILE, {})
    if args.init_expiry:
        for device in config["devices"]:
            state[device["id"]] = {"expires": args.init_expiry}
        STATE_FILE.write_text(json.dumps(state, indent=2) + "\n", "utf-8")
        log(f"validade inicial {args.init_expiry} para {len(config['devices'])} aparelhos", now)
        return 0
    if args.test_notify:
        notify(config, "teste do aviso de reinstalação. Nada a fazer.", "teste")
        return 0
    due = due_devices(config["devices"], state, now)
    if not due:
        log("nada a reinstalar", now)
        return 0
    names = ", ".join(device["name"] for device in due)
    if args.dry_run:
        print(f"reinstalaria em: {names}")
        return 0
    log(f"reinstalando em: {names}", now)
    error = prepare_worktree(config)
    expiry, build_error = (None, error) if error else build(config)
    if expiry is None:
        log(f"build falhou: {build_error}", now)
    else:
        for device in due:
            ok, detail = install(config, device)
            if ok:
                state[device["id"]] = {"expires": iso(expiry)}
                awake = "app aberto em segundo plano" if wake(device) else "app não abriu, avisa na próxima abertura"
                log(f"{device['name']}: instalado, vence em {expiry.astimezone():%d/%m %H:%M}, {awake}", now)
            else:
                log(f"{device['name']}: falhou ({' '.join(detail)})", now)
    for device in due:
        entry = state.setdefault(device["id"], {})
        if should_notify(entry, now):
            notify(config, failure_text(device["name"], parse(entry["expires"])), device["name"])
            entry["notified_for"] = entry["expires"]
            log(f"{device['name']}: aviso enviado", now)
    STATE_FILE.write_text(json.dumps(state, indent=2) + "\n", "utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
