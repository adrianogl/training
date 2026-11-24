import argparse
import json
import re
from pathlib import Path

MAX_NOTES = 3
MAX_HISTORY = 10
PREFIX = re.compile(r"^(feat|fix)(\([^)]*\))?!?:\s*")


PROPER_NOUNS = [
    ("garmin connect", "Garmin Connect"),
    ("connect iq", "Connect IQ"),
    ("apple watch", "Apple Watch"),
    ("apple saúde", "Apple Saúde"),
    ("mfit", "MFIT"),
    ("garmin", "Garmin"),
    ("strava", "Strava"),
    ("training", "Training"),
    ("claude", "Claude"),
    ("iphone", "iPhone"),
    ("ipad", "iPad"),
    ("vo2", "VO2"),
    ("fc", "FC"),
    ("mcp", "MCP"),
]
PROPER_NOUN_PATTERN = re.compile(
    r"(?<!\w)(" + "|".join(re.escape(raw) for raw, _ in PROPER_NOUNS) + r")(?!\w)", re.IGNORECASE)
PROPER_NOUN_BY_KEY = {raw.lower(): fixed for raw, fixed in PROPER_NOUNS}


BRAND = "trAIning"


def format_note(text):
    fixed = PROPER_NOUN_PATTERN.sub(lambda match: match.group(1) if match.group(1) == BRAND else PROPER_NOUN_BY_KEY[match.group(1).lower()], text)
    if not fixed or fixed.startswith(BRAND):
        return fixed
    return fixed[0].upper() + fixed[1:]


def notes_from(subjects):
    notes = []
    for subject in subjects.splitlines():
        text = PREFIX.sub("", subject.strip())
        if text and text not in notes:
            notes.append(format_note(text))
    return notes[:MAX_NOTES]


def history_from(current):
    if "historico" in current:
        return current["historico"]
    if "versao_app" in current:
        return [{"versao": current["versao_app"], "notas": current.get("notas", [])}]
    return []


def version_file(current, version, build, app_changed, subjects):
    data = {"versao": version, "build": build, "versao_app": current.get("versao_app", version), "notas": current.get("notas", []),
            "historico": history_from(current)}
    if app_changed:
        data["versao_app"] = version
        data["notas"] = notes_from(subjects)
        data["historico"] = ([{"versao": version, "notas": data["notas"]}] + data["historico"])[:MAX_HISTORY]
    return data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", type=int, required=True)
    parser.add_argument("--app-changed", choices=["true", "false"], required=True)
    parser.add_argument("--notes", default="")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    current = json.loads(args.out.read_text("utf-8")) if args.out.exists() else {}
    data = version_file(current, args.version, args.build, args.app_changed == "true", args.notes)
    args.out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", "utf-8")


if __name__ == "__main__":
    main()
