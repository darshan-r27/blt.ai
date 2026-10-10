#!/usr/bin/env bash
# Lists every lesson item in content/*.json and guards against repeats (docs/DECISIONS.md 038).
# A drafting aid: run it before writing new phrases so the same sentence is not written twice.
#
# Usage:
#   scripts/content-index.sh [--dir <path>]            one line per item (default mode)
#   scripts/content-index.sh --check [--dir <path>]    exit 1 and list problems if any rule is broken
#   scripts/content-index.sh --self-test               prove the rules on temporary fake lesson files
#
# Default output, tab separated, sorted by file name then item order:
#   item id, normalised prompt key, normalised canonical key, original English prompt, original canonical
# A key is the text lowercased with every character that is not a letter or digit removed.
#
# --check fails when:
#   * two items in the whole set share a sourcePrompt (compared by key),
#   * two items in the whole set share a canonical (compared by key),
#   * one item lists the same accepted spelling twice (compared ONLY trimmed and lowercased, so
#     variants that differ by a question mark, hyphen or space are allowed on purpose),
#   * a file is not valid JSON or has no `items` list, or the folder has no *.json.
# Problems name item ids and the offending text, never more. Unknown extra keys are ignored.
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
import sys
import unicodedata

mode, directory = sys.argv[1], sys.argv[2]
sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")


def key(text):
    """Lowercase, then keep only letters and digits."""
    return "".join(c for c in text.lower() if unicodedata.category(c)[0] in ("L", "N"))


def one_line(text):
    """Flatten tabs and line breaks so each printed record stays on one line."""
    return " ".join(text.split("\t")).replace("\r", " ").replace("\n", " ")


problems = []
rows = []  # (id, prompt, canonical) in file-name then item order

try:
    names = sorted(n for n in os.listdir(directory) if n.endswith(".json"))
except OSError:
    print("content-index: cannot read directory: " + directory, file=sys.stderr)
    sys.exit(1)
names = [n for n in names if os.path.isfile(os.path.join(directory, n))]
if not names:
    print("content-index: no *.json lesson files in " + directory, file=sys.stderr)
    sys.exit(1)

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
        rows.append((item_id, prompt, canonical))
        accepted = item.get("acceptedAnswers", [])
        if not isinstance(accepted, list) or not all(isinstance(a, str) for a in accepted):
            problems.append(label + ": `acceptedAnswers` must be a list of strings")
            continue
        seen = {}
        for answer in accepted:
            norm = answer.strip().lower()
            if norm in seen:
                problems.append(
                    label + ": accepted spelling listed twice: "
                    + json.dumps(seen[norm], ensure_ascii=False) + " and "
                    + json.dumps(answer, ensure_ascii=False)
                )
            else:
                seen[norm] = answer

if mode == "index":
    for item_id, prompt, canonical in rows:
        print("\t".join([one_line(item_id), key(prompt), key(canonical), one_line(prompt), one_line(canonical)]))
    for line in problems:
        print("content-index: " + line, file=sys.stderr)
    sys.exit(1 if problems else 0)

for field, pick in (("sourcePrompt", 1), ("canonical", 2)):
    groups = {}
    for row in rows:
        groups.setdefault(key(row[pick]), []).append(row)
    for group_key, members in groups.items():
        if len(members) > 1 and group_key:
            parts = ["{} {}".format(m[0], json.dumps(m[pick], ensure_ascii=False)) for m in members]
            problems.append("same " + field + " in " + str(len(members)) + " items: " + "; ".join(parts))

if problems:
    for line in problems:
        print("content-index: " + line, file=sys.stderr)
    print("content-index: " + str(len(problems)) + " problem(s) in " + str(len(names)) + " files", file=sys.stderr)
    sys.exit(1)
print("content-index: {} items in {} files, no duplicates".format(len(rows), len(names)))
PY

run_python() { # run_python <index|check> <dir>
  python3 -I -c "$PY_PROGRAM" "$1" "$2"
}

# --- Self-test --------------------------------------------------------------------------------
# Builds throw-away lesson files with obviously fake text and runs this script's own --check on them.
SELF_TMP=""
cleanup() { if [[ -n "$SELF_TMP" && -d "$SELF_TMP" ]]; then rm -rf "$SELF_TMP"; fi; }

# lesson <file> <item-json>...: write a minimal lesson file holding the given items.
lesson() {
  local file=$1 body="" sep="" item
  shift
  for item in "$@"; do body="${body}${sep}${item}"; sep=","; done
  printf '{"scenarioId":"zz","items":[%s],"zzExtra":true}\n' "$body" > "$file"
}

# zzitem <id> <prompt> <canonical> <accepted-json-list>
zzitem() {
  printf '{"id":"%s","sourcePrompt":"%s","canonical":"%s","acceptedAnswers":%s,"zzUnknownKey":1}' "$1" "$2" "$3" "$4"
}

self_test() {
  SELF_TMP=$(mktemp -d "${TMPDIR:-/tmp}/content-index-selftest.XXXXXX")
  trap cleanup EXIT
  local failures=0 cases=0 d

  expect() { # expect <pass|fail> <description> <dir>
    local want=$1 desc=$2 dir=$3 got=pass
    cases=$((cases + 1))
    if ! bash "$SCRIPT_DIR/content-index.sh" --check --dir "$dir" >/dev/null 2>&1; then got=fail; fi
    if [[ "$got" != "$want" ]]; then
      echo "self-test FAILED: $desc (expected $want, got $got)" >&2
      failures=$((failures + 1))
    fi
  }
  fresh() { d="$SELF_TMP/$1"; mkdir -p "$d"; }

  fresh clean
  lesson "$d/a.json" "$(zzitem zz-a1 'zz one' 'zz aaa' '["zz aaa","zz aab"]')" "$(zzitem zz-a2 'zz two' 'zz bbb' '["zz bbb"]')"
  lesson "$d/b.json" "$(zzitem zz-b1 'zz three' 'zz ccc' '["zz ccc"]')"
  expect pass "a clean set" "$d"

  fresh dup-prompt
  lesson "$d/a.json" "$(zzitem zz-a1 'ZZ Hello, there!' 'zz aaa' '["zz aaa"]')"
  lesson "$d/b.json" "$(zzitem zz-b1 'zz hello there' 'zz bbb' '["zz bbb"]')"
  expect fail "duplicate prompt differing only by case and punctuation" "$d"

  fresh dup-canonical
  lesson "$d/a.json" "$(zzitem zz-a1 'zz one' 'zz aaa bbb?' '["zz aaa bbb?"]')"
  lesson "$d/b.json" "$(zzitem zz-b1 'zz two' 'ZZ-aaa bbb' '["ZZ-aaa bbb"]')"
  expect fail "duplicate canonical across two files" "$d"

  fresh dup-unicode
  lesson "$d/a.json" "$(zzitem zz-a1 'zz café' 'zz aaa' '["zz aaa"]')"
  lesson "$d/b.json" "$(zzitem zz-b1 'ZZ CAFÉ' 'zz bbb' '["zz bbb"]')"
  expect fail "duplicate prompt with a non-ASCII letter" "$d"

  fresh dup-accepted-case
  lesson "$d/a.json" "$(zzitem zz-a1 'zz one' 'zz aaa' '["zz aaa","ZZ Aaa "]')"
  expect fail "accepted spellings differing only by case" "$d"

  fresh accepted-question-mark
  lesson "$d/a.json" "$(zzitem zz-a1 'zz one' 'zz aaa?' '["zz aaa?","zz aaa"]')"
  expect pass "accepted spellings differing only by a question mark" "$d"

  fresh broken-json
  printf '{"scenarioId":"zz","items":[' > "$d/a.json"
  expect fail "broken JSON" "$d"

  fresh no-items
  printf '{"scenarioId":"zz"}\n' > "$d/a.json"
  expect fail "a file without items" "$d"

  fresh empty
  expect fail "a folder with no JSON files" "$d"

  if (( failures > 0 )); then
    echo "content-index: self-test FAILED ($failures of $cases cases)" >&2
    exit 1
  fi
  echo "content-index: self-test passed ($cases cases)"
}

# --- Main -------------------------------------------------------------------------------------
mode=index
dir=$DEFAULT_DIR
while (( $# > 0 )); do
  case "$1" in
    --check) mode=check ;;
    --self-test) mode=selftest ;;
    --dir)
      if (( $# < 2 )); then echo "content-index: --dir needs a path" >&2; exit 2; fi
      dir=$2; shift ;;
    -h|--help) sed -n '2,26p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "content-index: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ "$mode" == selftest ]]; then self_test; exit 0; fi
run_python "$mode" "$dir"
