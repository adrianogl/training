#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOKEN_FILE="${WATCH_TOKEN_FILE:-$HOME/.config/training-sync/watch-token}"
[[ -r "$TOKEN_FILE" ]] || { echo "token não encontrado: $TOKEN_FILE" >&2; exit 1; }
TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"
[[ "$TOKEN" =~ ^[A-Za-z0-9_-]{43}$ ]] || { echo "token inválido em $TOKEN_FILE (esperado 43 caracteres base64url)" >&2; exit 1; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -R "$ROOT/manifest.xml" "$ROOT/monkey.jungle" "$ROOT/resources" "$ROOT/source" "$WORK/"
printf '(:background)\nmodule BuildToken {\n    const WATCH_TOKEN = "%s";\n}\n' "$TOKEN" > "$WORK/source/BuildToken.mc"
mkdir -p "$ROOT/bin"
monkeyc -f "$WORK/monkey.jungle" -d fr965 -o "$ROOT/bin/TrainingFace.prg" -y "$ROOT/developer_key.der"
