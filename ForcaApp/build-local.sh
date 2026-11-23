#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY="${DEVELOPER_KEY:-$ROOT/../Watchface/developer_key.der}"
[[ -r "$KEY" ]] || { echo "chave não encontrada: $KEY (defina DEVELOPER_KEY)" >&2; exit 1; }
mkdir -p "$ROOT/bin"
monkeyc -f "$ROOT/monkey.jungle" -d fr965 -o "$ROOT/bin/TrainingForca.prg" -y "$KEY"
