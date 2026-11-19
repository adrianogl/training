#!/bin/bash
set -euo pipefail

CONFIG="$HOME/.config/training-sync/auto-install.json"
LABEL="dev.aglv.training.autoinstall"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/.config/training-sync/auto-install.log"

if [[ ! -f "$CONFIG" ]]; then
  cat >&2 <<HELP
Falta $CONFIG. Exemplo:
{
  "repo": "$HOME/Code/pessoal/training",
  "worktree": "$HOME/Code/pessoal/training-autoinstall",
  "team": "SEU_TEAM_ID",
  "imessage": "+55...",
  "devices": [{"id": "UDID", "name": "iPhone"}]
}
HELP
  exit 1
fi

REPO=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["repo"])' "$CONFIG")
WORKTREE=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["worktree"])' "$CONFIG")

git -C "$REPO" fetch -q origin
if [[ ! -d "$WORKTREE" ]]; then
  git -C "$REPO" worktree add --detach "$WORKTREE" origin/main
else
  git -C "$WORKTREE" checkout -q --detach --force origin/main
fi

mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>-I</string>
    <string>$WORKTREE/scripts/auto_install.py</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>PYTHONDONTWRITEBYTECODE</key><string>1</string>
  </dict>
  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Hour</key><integer>12</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Hour</key><integer>21</integer><key>Minute</key><integer>0</integer></dict>
  </array>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLISTEOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Agendado: $LABEL (12h e 21h). Log em $LOG"
