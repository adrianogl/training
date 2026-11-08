#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_NAME="trAIning iPhone 18 Pro"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"
RUNTIMES=("com.apple.CoreSimulator.SimRuntime.iOS-27-1" "com.apple.CoreSimulator.SimRuntime.iOS-27-0")
BUNDLE_ID="dev.aglv.training"
SCHEME="trAIning"
PROJECT="$ROOT/trAIning.xcodeproj"
DERIVED="$ROOT/DerivedData"
KEY_FILE="$HOME/.config/garmin/connect-personal-api-key"
MAIN_ROOT="$(git -C "$ROOT" worktree list --porcelain | sed -n 's/^worktree //p' | head -n 1)"
SNAPSHOT="${MAIN_ROOT:-$ROOT}/garmin-data/snapshot"

MODE="run"
RESET_DATA=0

usage() {
  echo "uso: scripts/dev-run.sh [--test] [--reset-data] [--snapshot <dir>]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test) MODE="test"; shift ;;
    --reset-data) RESET_DATA=1; shift ;;
    --snapshot) [[ $# -ge 2 ]] || usage; SNAPSHOT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "opção desconhecida: $1" >&2; usage ;;
  esac
done

phase() { printf '==> %s\n' "$1"; }

fail_with_log() {
  local log="$1"
  echo "xcodebuild falhou. Erros:" >&2
  grep -E "error:|✘|failed|Failing tests|\*\* (BUILD|TEST) FAILED" "$log" | grep -v "^note:" | head -n 60 >&2 || tail -n 40 "$log" >&2
  echo "log completo: $log" >&2
  exit 1
}

show_simulator() {
  open -a Simulator --args -CurrentDeviceUDID "$UDID" 2>/dev/null \
    || open "$(xcode-select -p)/../Applications/DeviceHub.app" 2>/dev/null \
    || echo "aviso: não achei Simulator.app nem DeviceHub.app para mostrar o simulador" >&2
}

find_device() {
  xcrun simctl list devices | grep -F "    $DEVICE_NAME (" | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -n 1 || true
}

phase "gerando projeto"
/opt/homebrew/bin/xcodegen generate --spec "$ROOT/project.yml" --project "$ROOT" --quiet

phase "preparando simulador \"$DEVICE_NAME\""
UDID="$(find_device)"
if [[ -z "$UDID" ]]; then
  for runtime in "${RUNTIMES[@]}"; do
    if UDID="$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$runtime" 2>/dev/null)"; then break; fi
    UDID=""
  done
  [[ -n "$UDID" ]] || { echo "não foi possível criar o simulador $DEVICE_TYPE em ${RUNTIMES[*]}" >&2; exit 1; }
fi
xcrun simctl bootstatus "$UDID" -b >/dev/null
show_simulator

mkdir -p "$DERIVED"

if [[ "$MODE" == "test" ]]; then
  phase "rodando testes"
  LOG="$DERIVED/dev-run-test.log"
  xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "id=$UDID" \
    -derivedDataPath "$DERIVED" >"$LOG" 2>&1 || fail_with_log "$LOG"
  grep -E "Test run with" "$LOG" | tail -n 1 || true
  exit 0
fi

phase "compilando"
LOG="$DERIVED/dev-run-build.log"
xcodebuild build -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -destination "id=$UDID" \
  -derivedDataPath "$DERIVED" >"$LOG" 2>&1 || fail_with_log "$LOG"

phase "instalando"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$DERIVED/Build/Products/Debug-iphonesimulator/trAIning.app"

DATA="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
SUPPORT="$DATA/Library/Application Support"
if [[ "$RESET_DATA" -eq 1 || ! -f "$SUPPORT/store.sqlite" ]]; then
  phase "copiando dados de $SNAPSHOT"
  [[ -f "$SNAPSHOT/store.sqlite" ]] || { echo "snapshot não encontrado: $SNAPSHOT/store.sqlite" >&2; exit 1; }
  mkdir -p "$SUPPORT"
  rm -rf "$SUPPORT/store.sqlite" "$SUPPORT/store.sqlite-wal" "$SUPPORT/store.sqlite-shm" "$SUPPORT/.store_SUPPORT"
  cp "$SNAPSHOT/store.sqlite" "$SUPPORT/store.sqlite"
  for suffix in -wal -shm; do
    if [[ -f "$SNAPSHOT/store.sqlite$suffix" ]]; then cp "$SNAPSHOT/store.sqlite$suffix" "$SUPPORT/store.sqlite$suffix"; fi
  done
  if [[ -d "$SNAPSHOT/.store_SUPPORT" ]]; then cp -R "$SNAPSHOT/.store_SUPPORT" "$SUPPORT/.store_SUPPORT"; fi
fi

phase "abrindo o app"
if [[ -r "$KEY_FILE" ]]; then
  SIMCTL_CHILD_TRAINING_API_KEY="$(tr -d '[:space:]' <"$KEY_FILE")" \
    xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" >/dev/null
else
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" >/dev/null
fi
show_simulator
