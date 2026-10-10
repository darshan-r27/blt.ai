#!/usr/bin/env bash
# Lists every lesson item and guards against repeats, per course (docs/DECISIONS.md 038, 042, 044).
# A drafting aid: run it before writing new phrases so the same sentence is not written twice, and
# use --mirror to see where the Tamil and Telugu courses ask different English questions.
#
# Usage:
#   scripts/content-index.sh [--language L] [--dir <path>]          one line per item (default mode)
#   scripts/content-index.sh --check [--language L] [--dir <path>]  exit 1 and list problems if a rule is broken
#   scripts/content-index.sh --mirror [--strict] [--dir <path>]     compare the Tamil and Telugu courses
#   scripts/content-index.sh --self-test                            prove the rules on temporary fake files
#     L is `tamil` or `telugu`; it limits the index or check to that course (not valid with --mirror).
#
# Which files are read: <dir>/*.json and <dir>/<subfolder>/*.json, one level deep. A subfolder named
# `exam` (exam papers) and subfolders starting with a dot are skipped. The language of a lesson comes
# ONLY from its `language` key. A missing or unknown value (anything but tamil or telugu) is a problem
# that names the file; it is never guessed or defaulted.
#
# Default output, tab separated, courses in the order tamil, telugu, then file path, then item order:
#   language, item id, normalised prompt key, normalised canonical key, original English prompt,
#   original canonical
# A key is the text lowercased with every character that is not a letter or digit removed.
#
# --check fails when, inside ONE course (a Tamil and a Telugu lesson may share a prompt or canonical):
#   * two items share a sourcePrompt (compared by key),
#   * two items share a canonical (compared by key),
#   * two items share an id, or two lessons share a scenarioId,
#   * one item lists the same accepted spelling twice (compared ONLY trimmed and lowercased, so
#     variants that differ by a question mark, hyphen or space are allowed on purpose),
#   * a file is not valid JSON, has no `items` list, or has a missing or unknown `language`,
#   * the folder has no lesson *.json at all.
# Success prints: content-index: N items in M files (tamil X, telugu Y), no duplicates
# Problems name item ids and the offending text, never more. Unknown extra keys are ignored.
#
# --mirror pairs lessons across the courses by their scenarioId after the language prefix (`ta-` or
# `te-`): ta-l02-u03 pairs with te-l02-u03. Items pair by their `-iNN` suffix. One line each for:
#   * a lesson present in only one course,
#   * paired lessons with different item counts,
#   * paired items whose English sourcePrompt differs (compared by key, so a changed question mark or
#     capital is not a difference; both original prompts and both item ids are printed).
# It ends with: content-index: mirror: P pairs, U unpaired, D differing prompts
# Differences are allowed (some sentences do not work in both languages), so --mirror exits 0 even
# with differences. It exits 1 only on hard problems (bad JSON, missing language, unreadable folder,
# a repeated scenarioId in one course), or on any difference when --strict is given. The duplicate
# rules of --check are not run by --mirror.
#
# The folder defaults to `content` under the repository root, found relative to this script.
# Needs python3 (standard library only, run isolated with -I). Written for bash 3.2 and the stock
# macOS python3. No network; writes only inside its own temp dir (self-test).
#
# Exit 0 = ok, 1 = problems (or self-test failure), 2 = usage error.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEFAULT_DIR="$SCRIPT_DIR/../content"

read -r -d '' PY_PROGRAM <<'PY' || true
import json
import os
import re
import sys
import unicodedata

mode, directory, only_language, strict = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

LANGUAGES = ("tamil", "telugu")
PREFIX = {"tamil": "ta-", "telugu": "te-"}


def key(text):
    """Lowercase, then keep only letters and digits."""
    return "".join(c for c in text.lower() if unicodedata.category(c)[0] in ("L", "N"))


def one_line(text):
    """Flatten tabs and line breaks so each printed record stays on one line."""
    return " ".join(text.split("\t")).replace("\r", " ").replace("\n", " ")


def strip_prefix(language, ident):
    """ta-l02-u03 -> l02-u03 (only the prefix of the lesson's own language is removed)."""
    prefix = PREFIX[language]
    return ident[len(prefix):] if ident.startswith(prefix) else ident


def json_text(text):
    return json.dumps(text, ensure_ascii=False)


problems = []  # hard problems: unreadable or malformed content
rule_problems = []  # (language, text): accepted spellings listed twice, found while reading

# Collect lesson files: <dir>/*.json and <dir>/<subfolder>/*.json, one level deep, skipping exam.
try:
    entries = sorted(os.listdir(directory))
except OSError:
    print("content-index: cannot read directory: " + directory, file=sys.stderr)
    sys.exit(1)
names = []
for entry in entries:
    path = os.path.join(directory, entry)
    if entry.endswith(".json") and os.path.isfile(path):
        names.append(entry)
    elif os.path.isdir(path) and entry != "exam" and not entry.startswith("."):
        try:
            sub_entries = sorted(os.listdir(path))
        except OSError:
            problems.append(entry + "/: cannot read folder")
            continue
        for sub in sub_entries:
            if sub.endswith(".json") and os.path.isfile(os.path.join(path, sub)):
                names.append(entry + "/" + sub)
if not names:
    print("content-index: no lesson *.json files in " + directory, file=sys.stderr)
    sys.exit(1)

lessons = []  # dicts: file, language, sid, items [(id, prompt, canonical)]
for name in names:
    try:
        with open(os.path.join(directory, name), encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, UnicodeDecodeError) as err:
        problems.append(name + ": cannot read file as UTF-8 (" + type(err).__name__ + ")")
        continue
    except ValueError as err:
        problems.append(name + ": not valid JSON (" + str(err) + ")")
        continue
    if not isinstance(data, dict) or not isinstance(data.get("items"), list):
        problems.append(name + ": missing an `items` list")
        continue
    language = data.get("language")
    if not (isinstance(language, str) and language in LANGUAGES):
        if language is None:
            problems.append(name + ": `language` is missing; it must be tamil or telugu")
        else:
            problems.append(name + ": `language` is " + json_text(language) + "; it must be tamil or telugu")
        continue
    sid = data.get("scenarioId")
    lesson = {"file": name, "language": language, "sid": sid if isinstance(sid, str) else None, "items": []}
    lessons.append(lesson)
    for index, item in enumerate(data["items"], start=1):
        if not isinstance(item, dict):
            problems.append(name + ": item " + str(index) + " is not an object")
            continue
        item_id = item.get("id")
        prompt = item.get("sourcePrompt")
        canonical = item.get("canonical")
        label = item_id if isinstance(item_id, str) else name + " item " + str(index)
        if not (isinstance(item_id, str) and isinstance(prompt, str) and isinstance(canonical, str)):
            problems.append(label + ": `id`, `sourcePrompt` and `canonical` must all be strings")
            continue
        lesson["items"].append((item_id, prompt, canonical))
        accepted = item.get("acceptedAnswers", [])
        if not isinstance(accepted, list) or not all(isinstance(a, str) for a in accepted):
            problems.append(label + ": `acceptedAnswers` must be a list of strings")
            continue
        seen = {}
        for answer in accepted:
            norm = answer.strip().lower()
            if norm in seen:
                rule_problems.append((language,
                    label + ": accepted spelling listed twice: "
                    + json_text(seen[norm]) + " and " + json_text(answer)
                ))
            else:
                seen[norm] = answer

if only_language:
    lessons = [lesson for lesson in lessons if lesson["language"] == only_language]
    rule_problems = [p for p in rule_problems if p[0] == only_language]
rule_problems = [text for _language, text in rule_problems]

# Rows, stable-sorted by course, keeping file then item order inside a course.
rows = []  # (language, id, prompt, canonical)
for lesson in sorted(lessons, key=lambda l: LANGUAGES.index(l["language"])):
    for item_id, prompt, canonical in lesson["items"]:
        rows.append((lesson["language"], item_id, prompt, canonical))


def report_problems(lines, scanned):
    for line in lines:
        print("content-index: " + line, file=sys.stderr)
    if mode != "index":
        print("content-index: " + str(len(lines)) + " problem(s) in " + str(scanned) + " files", file=sys.stderr)


if mode == "index":
    for language, item_id, prompt, canonical in rows:
        print("\t".join([language, one_line(item_id), key(prompt), key(canonical), one_line(prompt), one_line(canonical)]))
    for line in problems + rule_problems:
        print("content-index: " + line, file=sys.stderr)
    sys.exit(1 if (problems or rule_problems) else 0)

# A repeated scenarioId in one course makes pairing ambiguous and breaks progress keys.
for language in LANGUAGES:
    seen_sid = {}
    for lesson in lessons:
        if lesson["language"] == language and lesson["sid"] is not None:
            if lesson["sid"] in seen_sid:
                problems.append(
                    lesson["file"] + ": scenarioId " + json_text(lesson["sid"]) + " is also used in "
                    + seen_sid[lesson["sid"]] + " (" + language + ")"
                )
            else:
                seen_sid[lesson["sid"]] = lesson["file"]

if mode == "mirror":
    by_language = {language: {} for language in LANGUAGES}
    for lesson in lessons:
        if lesson["sid"] is None:
            problems.append(lesson["file"] + ": `scenarioId` must be a string (needed to pair lessons)")
            continue
        by_language[lesson["language"]].setdefault(strip_prefix(lesson["language"], lesson["sid"]), lesson)

    def item_map(lesson):
        mapping = {}
        for item_id, prompt, _canonical in lesson["items"]:
            match = re.search(r"-i\d+$", item_id)
            mapping.setdefault(match.group(0) if match else strip_prefix(lesson["language"], item_id), (item_id, prompt))
        return mapping

    pairs = unpaired = differing = count_mismatches = 0
    for lesson_key in sorted(set(by_language["tamil"]) | set(by_language["telugu"])):
        tamil = by_language["tamil"].get(lesson_key)
        telugu = by_language["telugu"].get(lesson_key)
        if tamil is None or telugu is None:
            present = tamil or telugu
            unpaired += 1
            print("content-index: mirror: lesson only in {}: {} ({})".format(present["language"], present["sid"], present["file"]))
            continue
        pairs += 1
        if len(tamil["items"]) != len(telugu["items"]):
            count_mismatches += 1
            print("content-index: mirror: item count differs in {}: tamil {}, telugu {}".format(
                lesson_key, len(tamil["items"]), len(telugu["items"])))
        tamil_items, telugu_items = item_map(tamil), item_map(telugu)
        for suffix, (tamil_id, tamil_prompt) in tamil_items.items():
            if suffix in telugu_items and key(tamil_prompt) != key(telugu_items[suffix][1]):
                differing += 1
                telugu_id, telugu_prompt = telugu_items[suffix]
                print("content-index: mirror: prompt differs: {} {} | {} {}".format(
                    tamil_id, json_text(tamil_prompt), telugu_id, json_text(telugu_prompt)))
    print("content-index: mirror: {} pairs, {} unpaired, {} differing prompts".format(pairs, unpaired, differing))
    if problems:
        report_problems(problems, len(names))
        sys.exit(1)
    if strict and (unpaired or count_mismatches or differing):
        print("content-index: mirror: --strict: the courses differ", file=sys.stderr)
        sys.exit(1)
    sys.exit(0)

problems += rule_problems
for language in LANGUAGES:
    mine = [row for row in rows if row[0] == language]
    for field, pick in (("sourcePrompt", 2), ("canonical", 3)):
        groups = {}
        for row in mine:
            groups.setdefault(key(row[pick]), []).append(row)
        for group_key, members in groups.items():
            if len(members) > 1 and group_key:
                parts = ["{} {}".format(m[1], json_text(m[pick])) for m in members]
                problems.append("[" + language + "] same " + field + " in " + str(len(members)) + " items: " + "; ".join(parts))
    ids = {}
    for row in mine:
        ids.setdefault(row[1], 0)
        ids[row[1]] += 1
    for item_id, count in ids.items():
        if count > 1:
            problems.append("[" + language + "] item id " + json_text(item_id) + " is used " + str(count) + " times")

if problems:
    report_problems(problems, len(names))
    sys.exit(1)
counts = {language: len([r for r in rows if r[0] == language]) for language in LANGUAGES}
print("content-index: {} items in {} files (tamil {}, telugu {}), no duplicates".format(
    len(rows), len(lessons), counts["tamil"], counts["telugu"]))
PY

run_python() { # run_python <index|check|mirror> <dir> <language-or-empty> <strict 0|1>
  python3 -I -c "$PY_PROGRAM" "$1" "$2" "$3" "$4"
}

# --- Self-test --------------------------------------------------------------------------------
# Builds throw-away lesson files with obviously fake text and runs this script on them.
SELF_TMP=""
cleanup() { if [[ -n "$SELF_TMP" && -d "$SELF_TMP" ]]; then rm -rf "$SELF_TMP"; fi; }

# lesson <file> <language|-> <scenarioId> <item-json>...: write a minimal lesson file.
# A language of "-" leaves the `language` key out.
lesson() {
  local file=$1 lang=$2 sid=$3 body="" sep="" item langkey=""
  shift 3
  if [[ "$lang" != "-" ]]; then langkey="\"language\":\"$lang\","; fi
  for item in "$@"; do body="${body}${sep}${item}"; sep=","; done
  printf '{"scenarioId":"%s",%s"items":[%s],"zzExtra":true}\n' "$sid" "$langkey" "$body" > "$file"
}

# zzitem <id> <prompt> <canonical> <accepted-json-list>
zzitem() {
  printf '{"id":"%s","sourcePrompt":"%s","canonical":"%s","acceptedAnswers":%s,"zzUnknownKey":1}' "$1" "$2" "$3" "$4"
}

self_test() {
  SELF_TMP=$(mktemp -d "${TMPDIR:-/tmp}/content-index-selftest.XXXXXX")
  trap cleanup EXIT
  local failures=0 cases=0 d RC=0 OUT=""

  fail() { echo "self-test FAILED: $1" >&2; failures=$((failures + 1)); }
  run() { OUT=$(bash "$SCRIPT_DIR/content-index.sh" "$@" 2>&1) && RC=0 || RC=$?; }
  fresh() { d="$SELF_TMP/$1"; mkdir -p "$d"; }

  # expect <pass|fail> <description> [extra args]: --check on $d exits 0 or 1.
  expect() {
    local want=$1 desc=$2 got=pass
    shift 2
    cases=$((cases + 1))
    run --check --dir "$d" "$@"
    if (( RC != 0 )); then got=fail; fi
    if [[ "$got" != "$want" ]]; then fail "$desc (expected $want, got $got)"; fi
  }
  # expect_rc <exit-code> <description> <args...>: any invocation exits with the given code.
  expect_rc() {
    local want=$1 desc=$2
    shift 2
    cases=$((cases + 1))
    run "$@"
    if (( RC != want )); then fail "$desc (expected exit $want, got $RC)"; fi
  }
  # expect_out <present|absent> <fixed-text> <description>: the last run's output has or lacks the text.
  expect_out() {
    local want=$1 text=$2 desc=$3 got=absent
    cases=$((cases + 1))
    if printf '%s\n' "$OUT" | grep -qF -- "$text"; then got=present; fi
    if [[ "$got" != "$want" ]]; then fail "$desc (expected output $want: $text)"; fi
  }

  fresh clean
  lesson "$d/a.json" tamil zz-a "$(zzitem zz-a1 'zz one' 'zz aaa' '["zz aaa","zz aab"]')" "$(zzitem zz-a2 'zz two' 'zz bbb' '["zz bbb"]')"
  lesson "$d/b.json" tamil zz-b "$(zzitem zz-b1 'zz three' 'zz ccc' '["zz ccc"]')"
  expect pass "a clean set"
  expect_out present "3 items in 2 files (tamil 3, telugu 0), no duplicates" "success line with per-course counts"

  fresh dup-prompt
  lesson "$d/a.json" tamil zz-a "$(zzitem zz-a1 'ZZ Hello, there!' 'zz aaa' '["zz aaa"]')"
  lesson "$d/b.json" tamil zz-b "$(zzitem zz-b1 'zz hello there' 'zz bbb' '["zz bbb"]')"
  expect fail "duplicate prompt inside one course, differing only by case and punctuation"

  fresh dup-canonical
  lesson "$d/a.json" tamil zz-a "$(zzitem zz-a1 'zz one' 'zz aaa bbb?' '["zz aaa bbb?"]')"
  lesson "$d/b.json" tamil zz-b "$(zzitem zz-b1 'zz two' 'ZZ-aaa bbb' '["ZZ-aaa bbb"]')"
  expect fail "duplicate canonical inside one course"

  fresh dup-unicode
  lesson "$d/a.json" telugu zz-a "$(zzitem zz-a1 'zz café' 'zz aaa' '["zz aaa"]')"
  lesson "$d/b.json" telugu zz-b "$(zzitem zz-b1 'ZZ CAFÉ' 'zz bbb' '["zz bbb"]')"
  expect fail "duplicate prompt with a non-ASCII letter"

  fresh dup-id
  lesson "$d/a.json" tamil zz-a "$(zzitem zz-x1 'zz one' 'zz aaa' '["zz aaa"]')"
  lesson "$d/b.json" tamil zz-b "$(zzitem zz-x1 'zz two' 'zz bbb' '["zz bbb"]')"
  expect fail "the same item id twice in one course"

  fresh dup-accepted-case
  lesson "$d/a.json" tamil zz-a "$(zzitem zz-a1 'zz one' 'zz aaa' '["zz aaa","ZZ Aaa "]')"
  expect fail "accepted spellings differing only by case"

  fresh accepted-question-mark
  lesson "$d/a.json" tamil zz-a "$(zzitem zz-a1 'zz one' 'zz aaa?' '["zz aaa?","zz aaa"]')"
  expect pass "accepted spellings differing only by a question mark"

  fresh broken-json
  printf '{"scenarioId":"zz","language":"tamil","items":[' > "$d/a.json"
  expect fail "broken JSON"

  fresh no-items
  printf '{"scenarioId":"zz","language":"tamil"}\n' > "$d/a.json"
  expect fail "a file without items"

  fresh empty
  expect fail "a folder with no JSON files"

  # --- Courses are checked separately ---
  fresh isolation
  mkdir "$d/tamil" "$d/telugu"
  lesson "$d/tamil/a.json" tamil ta-zz-01 "$(zzitem ta-zz-01-i01 'zz one' 'zz aaa' '["zz aaa"]')"
  lesson "$d/telugu/a.json" telugu te-zz-01 "$(zzitem te-zz-01-i01 'zz one' 'zz aaa' '["zz aaa"]')"
  expect pass "identical prompts and canonicals in the two courses"
  expect_out present "2 items in 2 files (tamil 1, telugu 1), no duplicates" "subfolder layout is read"

  fresh dup-in-tamil-only
  mkdir "$d/tamil" "$d/telugu"
  lesson "$d/tamil/a.json" tamil ta-zz-01 "$(zzitem ta-zz-01-i01 'zz one' 'zz aaa' '["zz aaa"]')" "$(zzitem ta-zz-01-i02 'zz one' 'zz bbb' '["zz bbb"]')"
  lesson "$d/telugu/a.json" telugu te-zz-01 "$(zzitem te-zz-01-i01 'zz one' 'zz aaa' '["zz aaa"]')"
  expect fail "a duplicate prompt inside one course"
  expect_out present "[tamil] same sourcePrompt" "the problem names the course"
  expect pass "--language telugu ignores the Tamil duplicate" --language telugu
  expect fail "--language tamil still sees the Tamil duplicate" --language tamil

  fresh missing-language
  lesson "$d/a.json" - zz-a "$(zzitem zz-a1 'zz one' 'zz aaa' '["zz aaa"]')"
  expect fail "a lesson with no language"
  expect_out present "a.json: \`language\` is missing" "the problem names the file and the key"
  expect_rc 1 "--mirror fails on a lesson with no language" --mirror --dir "$d"
  expect_rc 1 "the default index fails on a lesson with no language" --dir "$d"

  fresh unknown-language
  lesson "$d/a.json" zzlang zz-a "$(zzitem zz-a1 'zz one' 'zz aaa' '["zz aaa"]')"
  expect fail "a lesson with an unknown language"
  expect_out present "must be tamil or telugu" "the unknown-language message"

  fresh exam-skipped
  mkdir "$d/tamil" "$d/exam"
  lesson "$d/tamil/a.json" tamil ta-zz-01 "$(zzitem ta-zz-01-i01 'zz one' 'zz aaa' '["zz aaa"]')"
  printf 'not json at all' > "$d/exam/paper.json"
  printf 'not json either' > "$d/tamil/exam.txt"
  expect pass "an exam folder is skipped"

  fresh exam-only
  mkdir "$d/exam"
  printf 'not json at all' > "$d/exam/paper.json"
  expect fail "a folder holding only an exam folder counts as empty"

  # --- Index mode ---
  fresh index
  mkdir "$d/tamil" "$d/telugu"
  lesson "$d/tamil/a.json" tamil ta-zz-01 "$(zzitem ta-zz-01-i01 'zz one' 'zz aaa' '["zz aaa"]')"
  lesson "$d/telugu/a.json" telugu te-zz-01 "$(zzitem te-zz-01-i01 'zz one' 'zz aaa' '["zz aaa"]')"
  cases=$((cases + 1))
  local lines
  lines=$(bash "$SCRIPT_DIR/content-index.sh" --dir "$d" 2>/dev/null | cut -f1 | tr '\n' ' ')
  if [[ "$lines" != "tamil telugu " ]]; then fail "index lists tamil then telugu in the first column (got: $lines)"; fi
  cases=$((cases + 1))
  lines=$(bash "$SCRIPT_DIR/content-index.sh" --dir "$d" --language telugu 2>/dev/null | cut -f1 | tr '\n' ' ')
  if [[ "$lines" != "telugu " ]]; then fail "--language telugu lists only telugu (got: $lines)"; fi
  expect_rc 2 "--language with an unknown course" --dir "$d" --language klingon
  expect_rc 2 "--mirror with --language" --mirror --language tamil --dir "$d"
  expect_rc 2 "--strict without --mirror" --check --strict --dir "$d"

  # --- Mirror ---
  fresh mirror-clean
  mkdir "$d/tamil" "$d/telugu"
  lesson "$d/tamil/a.json" tamil ta-zz-01 "$(zzitem ta-zz-01-i01 'zz one?' 'zz aaa' '["zz aaa"]')" "$(zzitem ta-zz-01-i02 'zz two' 'zz bbb' '["zz bbb"]')"
  lesson "$d/telugu/a.json" telugu te-zz-01 "$(zzitem te-zz-01-i01 'ZZ one' 'zz aaa' '["zz aaa"]')" "$(zzitem te-zz-01-i02 'zz two' 'zz bbb' '["zz bbb"]')"
  expect_rc 0 "--mirror with no differences" --mirror --dir "$d"
  expect_out present "mirror: 1 pairs, 0 unpaired, 0 differing prompts" "a changed question mark and capital are not differences"
  expect_rc 0 "--mirror --strict with no differences" --mirror --strict --dir "$d"

  fresh mirror-unpaired
  mkdir "$d/tamil" "$d/telugu"
  lesson "$d/tamil/a.json" tamil ta-zz-01 "$(zzitem ta-zz-01-i01 'zz one' 'zz aaa' '["zz aaa"]')"
  lesson "$d/telugu/a.json" telugu te-zz-01 "$(zzitem te-zz-01-i01 'zz one' 'zz aaa' '["zz aaa"]')"
  lesson "$d/telugu/b.json" telugu te-zz-02 "$(zzitem te-zz-02-i01 'zz two' 'zz bbb' '["zz bbb"]')"
  expect_rc 0 "--mirror reports an unpaired lesson and still exits 0" --mirror --dir "$d"
  expect_out present "lesson only in telugu: te-zz-02 (telugu/b.json)" "the unpaired lesson is named"
  expect_out present "mirror: 1 pairs, 1 unpaired, 0 differing prompts" "the unpaired summary"
  expect_rc 1 "--mirror --strict fails on an unpaired lesson" --mirror --strict --dir "$d"

  fresh mirror-prompt
  mkdir "$d/tamil" "$d/telugu"
  lesson "$d/tamil/a.json" tamil ta-zz-01 "$(zzitem ta-zz-01-i01 'zz one' 'zz aaa' '["zz aaa"]')"
  lesson "$d/telugu/a.json" telugu te-zz-01 "$(zzitem te-zz-01-i01 'zz changed' 'zz aaa' '["zz aaa"]')"
  expect_rc 0 "--mirror reports a differing prompt and still exits 0" --mirror --dir "$d"
  expect_out present "prompt differs: ta-zz-01-i01 \"zz one\" | te-zz-01-i01 \"zz changed\"" "both ids and both prompts are printed"
  expect_out present "1 pairs, 0 unpaired, 1 differing prompts" "the differing-prompt summary"
  expect_rc 1 "--mirror --strict fails on a differing prompt" --mirror --strict --dir "$d"

  fresh mirror-count
  mkdir "$d/tamil" "$d/telugu"
  lesson "$d/tamil/a.json" tamil ta-zz-01 "$(zzitem ta-zz-01-i01 'zz one' 'zz aaa' '["zz aaa"]')" "$(zzitem ta-zz-01-i02 'zz two' 'zz bbb' '["zz bbb"]')"
  lesson "$d/telugu/a.json" telugu te-zz-01 "$(zzitem te-zz-01-i01 'zz one' 'zz aaa' '["zz aaa"]')"
  expect_rc 0 "--mirror reports an item-count mismatch and still exits 0" --mirror --dir "$d"
  expect_out present "item count differs in zz-01: tamil 2, telugu 1" "the count mismatch"
  expect_rc 1 "--mirror --strict fails on a count mismatch" --mirror --strict --dir "$d"

  fresh mirror-broken
  mkdir "$d/tamil"
  printf '{"scenarioId":' > "$d/tamil/a.json"
  expect_rc 1 "--mirror fails on broken JSON" --mirror --dir "$d"
  expect_rc 1 "--mirror fails on an unreadable folder" --mirror --dir "$SELF_TMP/no-such-folder"

  if (( failures > 0 )); then
    echo "content-index: self-test FAILED ($failures of $cases cases)" >&2
    exit 1
  fi
  echo "content-index: self-test passed ($cases cases)"
}

# --- Main -------------------------------------------------------------------------------------
mode=index
dir=$DEFAULT_DIR
language=""
strict=0
while (( $# > 0 )); do
  case "$1" in
    --check)
      if [[ "$mode" == mirror ]]; then echo "content-index: --check and --mirror cannot be combined" >&2; exit 2; fi
      mode=check ;;
    --mirror)
      if [[ "$mode" == check ]]; then echo "content-index: --check and --mirror cannot be combined" >&2; exit 2; fi
      mode=mirror ;;
    --self-test) mode=selftest ;;
    --strict) strict=1 ;;
    --language)
      if (( $# < 2 )); then echo "content-index: --language needs tamil or telugu" >&2; exit 2; fi
      case "$2" in
        tamil|telugu) language=$2 ;;
        *) echo "content-index: --language must be tamil or telugu" >&2; exit 2 ;;
      esac
      shift ;;
    --dir)
      if (( $# < 2 )); then echo "content-index: --dir needs a path" >&2; exit 2; fi
      dir=$2; shift ;;
    -h|--help) sed -n '2,/^set -euo pipefail$/p' "${BASH_SOURCE[0]}" | sed '$d'; exit 0 ;;
    *) echo "content-index: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ "$mode" == mirror && -n "$language" ]]; then
  echo "content-index: --language does not apply to --mirror" >&2; exit 2
fi
if [[ "$strict" == 1 && "$mode" != mirror ]]; then
  echo "content-index: --strict only applies to --mirror" >&2; exit 2
fi

if [[ "$mode" == selftest ]]; then self_test; exit 0; fi
run_python "$mode" "$dir" "$language" "$strict"
