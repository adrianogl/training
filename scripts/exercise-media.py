#!/usr/bin/env python3
import json
import re
import shutil
import subprocess
import sys
import unicodedata
import urllib.request
from difflib import SequenceMatcher
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Packages/TrainingKit/Sources/Insights/GarminStrengthCatalogData.swift"
CANDIDATES = ROOT / "tasks/exercise-media-candidatos.json"
REVIEW = ROOT / "scripts/exercise-media-revisao.json"
STEPS_PT = ROOT / "scripts/exercise-media-passos-pt.json"
MEDIA_DIR = ROOT / "App/Strength/Media"
CACHE = Path.home() / ".cache/training/exercise-media"
FED_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"
FED_IMAGE_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"
WGER_URL = "https://wger.de/api/v2/exerciseinfo/?language=2&limit=1000"
WGER_ENGLISH = 2
MAX_PER_KIND = 3
MIN_OWN_SCORE = 0.5
MAX_SIDE = 640
JPG_QUALITY = 70
SIZE_LIMIT_MB = 40
FUZZY_SHORTLIST = 12

STOP_WORDS = {"the", "a", "an", "with", "on", "of", "to", "and"}
EQUIPMENT_WORDS = {"dumbbell", "barbell", "kettlebell", "cable", "machine", "band", "bands", "swiss", "ball", "bosu",
                   "medicine", "suspension", "trx", "bodyweight", "weighted", "resistance", "ez", "bar", "plate"}
GENERIC_WORDS = {"ab", "abs", "exercise", "alternating", "standing", "seated", "lying", "single", "one", "arm", "leg", "wide", "close", "grip", "and"}
MIN_EQUIVALENT_SCORE = 0.3
WGER_DEFAULT_AUTHOR = "Colaboradores do wger.de"
LICENSE_NAMES = {"CC-BY-SA 4": "CC-BY-SA 4.0", "CC-BY-SA 3": "CC-BY-SA 3.0"}

PADRAO_MUSCLES = {
    "squat": {"quadriceps", "glutes"},
    "hinge": {"hamstrings", "glutes", "lower back"},
    "singleLeg": {"quadriceps", "glutes", "hamstrings"},
    "horizontalPush": {"chest", "triceps", "shoulders"},
    "verticalPush": {"shoulders", "triceps"},
    "horizontalPull": {"middle back", "lats", "traps", "shoulders"},
    "verticalPull": {"lats", "biceps", "traps"},
    "antiExtension": {"abdominals"},
    "antiRotation": {"abdominals"},
    "lateralCore": {"abdominals"},
    "hipStability": {"abductors", "adductors", "glutes"},
    "calf": {"calves"},
    "plyo": {"quadriceps", "glutes", "calves", "chest", "hamstrings"},
    "mobilityHip": {"hamstrings", "quadriceps", "glutes", "abductors", "adductors"},
    "mobilityAnkle": {"calves"},
    "mobilityThoracic": {"lower back", "chest", "shoulders", "middle back", "lats", "abdominals", "traps", "neck"},
}

FED_EQUIPMENT = {
    "bodyweight": {"body only", "other", None},
    "dumbbell": {"dumbbell", "kettlebells"},
    "barbell": {"barbell", "e-z curl bar"},
    "machine": {"machine"},
    "band": {"bands"},
    "cable": {"cable"},
    "kettlebell": {"kettlebells", "dumbbell"},
    "medicineBall": {"medicine ball"},
    "swissBall": {"exercise ball"},
    "suspension": {"other"},
}

WGER_EQUIPMENT = {
    "bodyweight": {"none (bodyweight exercise)", "Gym mat", "Pull-up bar"},
    "dumbbell": {"Dumbbell", "Kettlebell"},
    "barbell": {"Barbell", "SZ-Bar"},
    "machine": {"Cable machine"},
    "band": {"Resistance band"},
    "cable": {"Cable machine"},
    "kettlebell": {"Kettlebell", "Dumbbell"},
    "medicineBall": set(),
    "swissBall": {"Swiss Ball"},
    "suspension": set(),
}

NAME_PATTERNS = [
    ("plyo", r"jump|burpee|plyo|clap|explosive|\bhop\b|bound|box jump"),
    ("calf", r"calf|calves|donkey"),
    ("singleLeg", r"lunge|step.?up|split squat|single.leg|one.leg|pistol|bulgarian"),
    ("hipStability", r"abduct|adduct|clamshell|fire hydrant|side.?step|rear leg raise|kickback|donkey kick"),
    ("hinge", r"deadlift|good morning|hip thrust|glute bridge|bridge|back extension|hyperextension|leg curl|swing|pull.?through|romanian|superman"),
    ("squat", r"squat|leg press|hack|thruster|wall sit"),
    ("lateralCore", r"side plank|side bend|oblique|suitcase"),
    ("antiRotation", r"russian twist|chop|rotation|twist|pallof"),
    ("antiExtension", r"crunch|sit.?up|plank|leg raise|ab roller|rollout|mountain climber|dead bug|flutter|v.up|knee raise|hanging|abs\b"),
    ("verticalPull", r"pull.?up|chin.?up|pull.?down|curl|shrug"),
    ("horizontalPull", r"\brow\b|face pull|reverse fl|rear delt|upright row|bent.over"),
    ("verticalPush", r"shoulder press|overhead press|military|arnold|push press|lateral raise|front raise|handstand|pike|raise"),
    ("horizontalPush", r"bench press|push.?up|press|\bfly\b|flye|dip|tricep|extension|pushdown|pressdown|skull"),
]

MUSCLE_PATTERNS = {
    "abdominals": "antiExtension",
    "calves": "calf",
    "chest": "horizontalPush",
    "triceps": "horizontalPush",
    "shoulders": "verticalPush",
    "lats": "verticalPull",
    "biceps": "verticalPull",
    "middle back": "horizontalPull",
    "traps": "horizontalPull",
    "lower back": "hinge",
    "hamstrings": "hinge",
    "glutes": "hinge",
    "quadriceps": "squat",
    "abductors": "hipStability",
    "adductors": "hipStability",
}

STRETCH_PATTERNS = {
    "hamstrings": "mobilityHip",
    "quadriceps": "mobilityHip",
    "glutes": "mobilityHip",
    "abductors": "mobilityHip",
    "adductors": "mobilityHip",
    "calves": "mobilityAnkle",
}


def norm(text):
    decomposed = unicodedata.normalize("NFKD", text)
    plain = "".join(char for char in decomposed if not unicodedata.combining(char))
    return " ".join(re.sub(r"[^a-z0-9]+", " ", plain.lower()).split())


def tokens(text):
    result = set()
    for word in norm(text).split():
        if word in STOP_WORDS or word == "weighted":
            continue
        result.add(word[:-1] if len(word) > 3 and word.endswith("s") else word)
    return result


def core_tokens(text):
    return {word for word in tokens(text) if word not in EQUIPMENT_WORDS and word not in GENERIC_WORDS}


def catalog_name(entry):
    return norm(entry["exercicio"].replace("_", " "))


def classify_padrao(name, muscles, category):
    lowered = name.lower()
    if category == "stretching" or "stretch" in lowered:
        for muscle in muscles:
            if muscle in STRETCH_PATTERNS:
                return STRETCH_PATTERNS[muscle], "palavra"
        return "mobilityThoracic", "palavra"
    for padrao, pattern in NAME_PATTERNS:
        if re.search(pattern, lowered):
            return padrao, "palavra"
    for muscle in muscles:
        if muscle in MUSCLE_PATTERNS:
            return MUSCLE_PATTERNS[muscle], "musculo"
    return None, "nenhum"


def load_catalog(path=CATALOG):
    entries = []
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if stripped.startswith('{"categoria"'):
            entries.append(json.loads(stripped.rstrip(",")))
    return entries


def equipment_compatible(catalog_equipment, source_equipment, table):
    allowed = table.get(catalog_equipment, set())
    if isinstance(source_equipment, (set, list, tuple)):
        if not source_equipment:
            return catalog_equipment == "bodyweight"
        return bool(allowed & set(source_equipment))
    return source_equipment in allowed


def similarity(left, right):
    left_tokens, right_tokens = tokens(left), tokens(right)
    if not left_tokens or not right_tokens:
        return 0.0
    jaccard = len(left_tokens & right_tokens) / len(left_tokens | right_tokens)
    return jaccard


def refined_score(entry_name, pool_name):
    ratio = SequenceMatcher(None, " ".join(sorted(tokens(entry_name))), " ".join(sorted(tokens(pool_name)))).ratio()
    return max(similarity(entry_name, pool_name), ratio * 0.95)


def own_candidates(entry, pool, limit=MAX_PER_KIND):
    name = catalog_name(entry)
    shortlist = sorted(pool, key=lambda item: similarity(name, item["nome"]), reverse=True)[:FUZZY_SHORTLIST]
    results = []
    for item in shortlist:
        compatible = equipment_compatible(entry["equipamento"], item["equipamento"], FED_EQUIPMENT)
        exact = norm(item["nome"]) == name
        if exact:
            score, reviewed = (1.0, True) if compatible else (0.7, False)
        else:
            score = refined_score(name, item["nome"])
            score = score if compatible else score * 0.8
            reviewed = False
        if score >= MIN_OWN_SCORE:
            results.append(candidate(item, score, reviewed, False))
    results.sort(key=lambda value: value["confianca"], reverse=True)
    return results[:limit]


def equivalents(entry, pool, exclude=(), limit=MAX_PER_KIND):
    name = catalog_name(entry)
    results = []
    for item in pool:
        if item["padrao"] != entry["padrao"] or item["id"] in exclude:
            continue
        if not equipment_compatible(entry["equipamento"], item["equipamento"], FED_EQUIPMENT):
            continue
        if not set(item.get("musculos", [])) & PADRAO_MUSCLES.get(entry["padrao"], set()):
            continue
        shared = core_tokens(name) & core_tokens(item["nome"])
        if not shared:
            continue
        union = core_tokens(name) | core_tokens(item["nome"])
        score = 0.2 + 0.6 * len(shared) / len(union)
        if score < MIN_EQUIVALENT_SCORE:
            continue
        results.append(candidate(item, score, False, True))
    results.sort(key=lambda value: value["confianca"], reverse=True)
    return results[:limit]


def wger_candidates(entry, pool, limit=MAX_PER_KIND):
    name = catalog_name(entry)
    shortlist = sorted(pool, key=lambda item: similarity(name, item["nome"]), reverse=True)[:FUZZY_SHORTLIST]
    results = []
    for item in shortlist:
        compatible = equipment_compatible(entry["equipamento"], item["equipamento"], WGER_EQUIPMENT)
        exact = norm(item["nome"]) == name
        score = 0.9 if exact else refined_score(name, item["nome"]) * 0.9
        score = score if compatible else score * 0.8
        if score >= MIN_OWN_SCORE:
            results.append(candidate(item, score, False, False))
    results.sort(key=lambda value: value["confianca"], reverse=True)
    return results[:limit]


def candidate(item, score, reviewed, equivalent):
    result = {
        "origem": item["origem"],
        "id": item["id"],
        "nome": item["nome_original"],
        "quadros": item["quadros"],
        "equivalente": equivalent,
        "confianca": round(score, 3),
        "revisado": reviewed,
    }
    for key in ("passos", "autor", "autores", "licenca", "link"):
        if key in item:
            result[key] = item[key]
    return result


def fed_pool(raw):
    pool = []
    for item in raw:
        if not item.get("images"):
            continue
        padrao, _ = classify_padrao(item["name"], item.get("primaryMuscles", []), item.get("category"))
        pool.append({
            "origem": "freeExerciseDb",
            "id": item["id"],
            "nome": item["name"],
            "nome_original": item["name"],
            "equipamento": item.get("equipment"),
            "padrao": padrao,
            "musculos": item.get("primaryMuscles", []),
            "quadros": item["images"],
            "passos": item.get("instructions", []),
        })
    return pool


def wger_pool(raw):
    pool = []
    for item in raw:
        if not item.get("images"):
            continue
        english = next((t for t in item["translations"] if t["language"] == WGER_ENGLISH), None)
        if not english:
            continue
        license_info = item.get("license") or {}
        author = next((i.get("license_author") for i in item["images"] if i.get("license_author")), None) or item.get("license_author") or ""
        authors = [i.get("license_author") or author for i in item["images"]]
        pool.append({
            "origem": "wger",
            "id": str(item["id"]),
            "nome": english["name"],
            "nome_original": english["name"],
            "equipamento": [e["name"] for e in item.get("equipment", [])],
            "quadros": [i["image"] for i in item["images"]],
            "autor": author,
            "autores": authors,
            "licenca": license_info.get("short_name", ""),
            "link": f"https://wger.de/en/exercise/{item['id']}/view/",
        })
    return pool


def build(catalog, fed, wger):
    result = {}
    for entry in catalog:
        own = own_candidates(entry, fed)
        taken = {item["id"] for item in own}
        result[entry["id"]] = {
            "nome": entry["nome"],
            "padrao": entry["padrao"],
            "equipamento": entry["equipamento"],
            "proprios": own,
            "equivalentes": equivalents(entry, fed, taken),
            "wger": wger_candidates(entry, wger),
        }
    return {"versao": 1, "ids": result}


def candidate_ref(item):
    return f"{item['origem']}:{item['id']}"


def select_reviewed(candidates, review):
    result = {}
    for catalog_id, refs in review.items():
        block = candidates["ids"].get(catalog_id)
        if not block or not refs:
            continue
        by_ref = {candidate_ref(item): item for kind in ("proprios", "equivalentes", "wger") for item in block.get(kind, [])}
        kept = [by_ref[ref] for ref in refs if ref in by_ref]
        if kept:
            result[catalog_id] = kept
    return result


def merge_review(files, removals):
    merged = {}
    for path in files:
        merged.update(json.loads(Path(path).read_text()))
    for catalog_id, ref in removals:
        if catalog_id in merged:
            merged[catalog_id] = [item for item in merged[catalog_id] if item != ref]
    return {key: value for key, value in merged.items() if value}


def wger_credit(item):
    author = item.get("autor") or WGER_DEFAULT_AUTHOR
    license_name = LICENSE_NAMES.get(item.get("licenca", ""), item.get("licenca", ""))
    return author, license_name


def mfit_map(catalog):
    result = {}
    for entry in sorted(catalog, key=lambda item: item["id"]):
        result.setdefault(norm(entry["nome"]), entry["id"])
    return result


def download(url, target):
    if target.exists():
        return target
    target.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "training-exercise-media"})
    with urllib.request.urlopen(request, timeout=60) as response:
        target.write_bytes(response.read())
    return target


def load_sources():
    fed = json.loads(download(FED_URL, CACHE / "fed.json").read_text())
    wger = json.loads(download(WGER_URL, CACHE / "wger.json").read_text())["results"]
    return fed, wger


def command_candidatos():
    fed_raw, wger_raw = load_sources()
    catalog = load_catalog()
    result = build(catalog, fed_pool(fed_raw), wger_pool(wger_raw))
    CANDIDATES.parent.mkdir(parents=True, exist_ok=True)
    CANDIDATES.write_text(json.dumps(result, ensure_ascii=False, indent=1, sort_keys=True) + "\n")
    blocks = result["ids"].values()
    print("ids", len(result["ids"]))
    print("proprio revisado", sum(1 for b in blocks if any(c["revisado"] for c in b["proprios"])))
    print("com proprio", sum(1 for b in blocks if b["proprios"]))
    print("com equivalente", sum(1 for b in blocks if b["equivalentes"]))
    print("com wger", sum(1 for b in blocks if b["wger"]))
    print("com algum", sum(1 for b in blocks if b["proprios"] or b["equivalentes"] or b["wger"]))


def frame_name(origin, frame):
    if origin == "wger":
        return "wger_" + frame.rsplit("/", 2)[-2] + "_" + frame.rsplit("/", 1)[-1]
    return frame.replace("/", "_")


def longest_side(path):
    output = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)], check=True, capture_output=True, text=True).stdout
    return max(int(value) for value in re.findall(r"pixel(?:Width|Height): (\d+)", output))


def copy_frame(origin, frame, destination):
    source = CACHE / "images" / frame_name(origin, frame)
    url = frame if origin == "wger" else FED_IMAGE_URL + frame
    download(url, source)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if source.suffix.lower() == ".gif":
        shutil.copyfile(source, destination)
        return
    command = ["sips", "-s", "format", "jpeg", "-s", "formatOptions", str(JPG_QUALITY)]
    if longest_side(source) > MAX_SIDE:
        command += ["-Z", str(MAX_SIDE)]
    subprocess.run(command + [str(source), "--out", str(destination)], check=True, stdout=subprocess.DEVNULL)


def image_name(origin, frame):
    name = frame_name(origin, frame)
    suffix = ".gif" if name.lower().endswith(".gif") else ".jpg"
    return str(Path(name).with_suffix(suffix))


def command_revisar(args):
    removals = []
    files = []
    iterator = iter(args)
    for arg in iterator:
        if arg == "--remover":
            catalog_id, ref = next(iterator).split("=", 1)
            removals.append((catalog_id, ref))
        else:
            files.append(arg)
    merged = merge_review(files, removals)
    REVIEW.write_text(json.dumps(merged, ensure_ascii=False, indent=1, sort_keys=True) + "\n")
    print("ids", len(merged))


def command_emitir():
    candidates = json.loads(CANDIDATES.read_text())
    selected = select_reviewed(candidates, json.loads(REVIEW.read_text()))
    steps_pt = json.loads(STEPS_PT.read_text())
    images_dir = MEDIA_DIR / "Images"
    if images_dir.exists():
        shutil.rmtree(images_dir)
    midias = {}
    credits = []
    missing = set()
    for catalog_id, items in sorted(selected.items()):
        midias[catalog_id] = []
        for item in items:
            names = []
            for frame in item["quadros"]:
                name = image_name(item["origem"], frame)
                copy_frame(item["origem"], frame, images_dir / name)
                names.append(name)
            entry = {"origem": item["origem"], "quadros": names, "equivalente": item["equivalente"]}
            if item["origem"] == "freeExerciseDb":
                if item["id"] in steps_pt:
                    entry["passos"] = steps_pt[item["id"]]
                else:
                    missing.add(item["id"])
            else:
                author, license_name = wger_credit(item)
                entry.update({"autor": author, "licenca": license_name, "link": item.get("link", "")})
                authors = item.get("autores") or [author] * len(names)
                for name, frame_author in zip(names, authors):
                    credits.append(f"- `{name}`: {frame_author or WGER_DEFAULT_AUTHOR}, {license_name}, {item.get('link', '')}")
            midias[catalog_id].append(entry)
    if missing:
        print("sem tradução dos passos:", sorted(missing), file=sys.stderr)
        sys.exit(1)
    patterns = json.loads(STEPS_PT.with_name("exercise-media-padroes-pt.json").read_text())
    output = {
        "versao": 1,
        "midias": midias,
        "mfit": mfit_map(load_catalog()),
        "padroes": {key: {"passos": value} for key, value in patterns.items()},
    }
    (MEDIA_DIR / "exercise-media.json").write_text(json.dumps(output, ensure_ascii=False, indent=1, sort_keys=True) + "\n")
    header = (
        "# Créditos das imagens\n\n"
        "As imagens dos exercícios vêm do free-exercise-db (https://github.com/yuhonas/free-exercise-db), "
        "em domínio público (Unlicense).\n\n"
        "As imagens abaixo vêm do wger (https://wger.de), com a licença e o autor indicados em cada linha.\n\n"
    )
    (MEDIA_DIR / "CREDITS.md").write_text(header + "\n".join(sorted(set(credits))) + "\n")
    files = [path for path in images_dir.glob("*") if path.is_file()]
    megabytes = sum(path.stat().st_size for path in files) / 1_000_000
    print(f"ids: {len(midias)}, imagens: {len(files)}, total: {megabytes:.1f} MB")
    if megabytes > SIZE_LIMIT_MB:
        print(f"acima de {SIZE_LIMIT_MB} MB", file=sys.stderr)
        sys.exit(1)


def main(argv):
    commands = {"candidatos": command_candidatos, "emitir": command_emitir}
    if len(argv) >= 2 and argv[1] == "revisar":
        command_revisar(argv[2:])
    elif len(argv) == 2 and argv[1] in commands:
        commands[argv[1]]()
    else:
        print("uso: exercise-media.py candidatos|revisar <arquivos> [--remover ID=REF]|emitir", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main(sys.argv)
