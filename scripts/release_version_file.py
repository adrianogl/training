import argparse
import json
import re
from pathlib import Path

MAX_NOTES = 3
PREFIX = re.compile(r"^(feat|fix)(\([^)]*\))?!?:\s*")


def notes_from(subjects):
    notes = []
    for subject in subjects.splitlines():
        text = PREFIX.sub("", subject.strip())
        if text and text not in notes:
            notes.append(text[0].upper() + text[1:])
    return notes[:MAX_NOTES]


def version_file(current, version, build, app_changed, subjects):
    data = {"versao": version, "build": build, "versao_app": current.get("versao_app", version), "notas": current.get("notas", [])}
    if app_changed:
        data["versao_app"] = version
        data["notas"] = notes_from(subjects)
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
