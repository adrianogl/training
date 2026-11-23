#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY="${DEVELOPER_KEY:-$ROOT/../Watchface/developer_key.der}"
[[ -r "$KEY" ]] || { echo "chave não encontrada: $KEY (defina DEVELOPER_KEY)" >&2; exit 1; }
DEVICES="${DEVICES:-fr965 venu3 venu3s}"
mkdir -p "$ROOT/bin"
for device in $DEVICES; do
    monkeyc -f "$ROOT/monkey.jungle" -d "$device" -o "$ROOT/bin/TrainingForca-$device.prg" -y "$KEY"
done
