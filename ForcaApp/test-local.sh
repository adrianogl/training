#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY="${DEVELOPER_KEY:-$ROOT/../Watchface/developer_key.der}"
[[ -r "$KEY" ]] || { echo "chave não encontrada: $KEY (defina DEVELOPER_KEY)" >&2; exit 1; }
DEVICE="${DEVICE:-fr965}"
mkdir -p "$ROOT/bin"
monkeyc -f "$ROOT/monkey.jungle" -d "$DEVICE" -o "$ROOT/bin/ForcaTests.prg" -y "$KEY" --unit-test
monkeydo "$ROOT/bin/ForcaTests.prg" "$DEVICE" -t
