# BLT.ai: handoff

Read this first in a new session, then `CLAUDE.md`. Last updated 2026-10-09 (end of the Wave 1 session).

## Start here (next session)
**Where the course work stands (2026-10-09).** Wave 1 of `plan.md` is built. Merged: #11 (`scripts/content-index.sh`) and #12 (editor: `level`, `tamilScript`, duplicate checks). **#13 (C1: catalog format and validator rules) is open and its CI was still running when this was written.** The owner told the previous session: "merge them once CI is green". Check first: `git fetch && git log --oneline origin/main -3` and `gh pr list`. If #13 is open and `gh pr checks 13` is all green with `mergeStateStatus` CLEAN, squash-merge it (`gh pr merge 13 --squash --delete-branch`). If CI fails, read the failure ("Summarise UI test failures" step prints messages), fix on the PR branch, and do not merge red.

**After #13 is merged**
1. `git switch main && git pull --ff-only`, then run the full check: `BLT_SIM="iPhone 17" scripts/test.sh package`, `swiftlint lint --config .swiftlint.yml --strict`, `bash scripts/check-forbidden-apis.sh`, `bash scripts/content-index.sh --check`.
2. Update `progress.md` (done, decisions, deviations, next action) and remove the three finished agent worktrees (`git worktree list`; `git worktree remove` the `agent-aee0692f924af5bdb`, `agent-a238e319db7773c75`, `agent-ad900df867829901c` ones).
3. Stop and report to the owner (TL;DR first) before starting Wave 2.

**Wave 2 (in `plan.md`; needs #13).** Three chunks on different files, so they can run in parallel as Sonnet agents in worktrees:
- **C4 Shipped content and tests.** Add `level` 1 to the five lesson files (`number` 1, title from `docs/COURSE_SYLLABUS.md`, `position` 1 to 5 in lesson order; this edits owner-reviewed files, so show the owner the diff first and change nothing else in them). Replace "exactly 5 files" in `Tests/BLTContentTests/ShippedContentTests.swift` with: at least 5 files, every file exactly 20 items, level numbers with no gaps, zero issues; any lesson id of the form `lNN-uNN` must have `tamilScript` on every item. Add `bash scripts/content-index.sh --check` and its `--self-test` to the guardrail job in `.github/workflows/ci.yml`; document the script in `docs/MVP_PLAN.md` and the README scripts list.
- **C5 Home grouped by level.** `BLTFeatures/Home/*`, accessibility ids, `HomeUITests`, `PreviewCatalog`. Sections per level with completion, a "Continue" suggestion, collapsed finished levels, "Other lessons" for files without a level; nothing locked. Flip DECISIONS 039 to active when it lands.
- **C6 Import limit 10 to 20** in `BLTContentStore/ImportedContentStore.swift`, its tests and the README import section (amends 036).
Then: PRs, merge one at a time, full check, update `progress.md`.

**Then content (Wave 3 onward).** One level at a time, owner reviews each before the next is drafted. Before drafting Level 1's seven new lessons, create `docs/content/STYLE_NOTES.md` (it does not exist yet) from the owner's reviewed lessons 1 to 5: spelling conventions, the casual and respectful forms, how variants are listed, the owner's corrections. Run `bash scripts/content-index.sh` first so no prompt or answer repeats. New lessons are named `content/l01-u06-<slug>.json`, `scenarioId` `l01-u06`, items `l01-u06-i01`, every item has `tamilScript` and `reviewStatus: unreviewed`.

**Things the last session learned (read these)**
- **Duplicates silently drop items.** C1's loader keeps the earlier item and drops a later one that repeats a prompt or canonical anywhere in the catalog (bundled and imported). Every drafted phrase needs a prompt and an answer unique across the whole course. Accepted-spelling duplicates inside one item compare only case and surrounding spaces; punctuation-only variants are allowed on purpose.
- **Three checkers, one rule.** Swift (`CatalogRegistry.fingerprint`: `isLetter || isNumber` on characters), the editor (`\p{L}\p{N}`) and `content-index.sh` (Unicode categories L and N) can differ on combining marks only. Romanised English-letter content is unaffected; revisit if `tamilScript` ever joins the prompt or canonical comparison (it must not).
- **C1 changed test fixtures outside its brief** (`BLTContentStoreTests/ImportWorld.swift`, `BootstrapTests.swift`, and fixtures in `BLTCatalogTests`): they now derive prompt and canonical from the item id because every item used to share one. It is a separate commit in #13.
- **Editor follow-ups (owner):** look at the new level and Tamil-script boxes in a browser (only a human can judge the layout); the CSV review sheet has no `tamilScript` column although DECISIONS 040 says the field is reviewed with the item (small follow-up chunk if wanted).
- **Sandbox quirks (Claude Code).** In a sandboxed Bash, `gh` fails with a TLS error (`OSStatus -26276`) and `git worktree add` cannot write `.git/config`. Retry those commands with the sandbox disabled; the owner can change the sandbox with `/sandbox`.
- A hook blocks command lines containing `rm -rf`; ask the owner to run such a command, or avoid it.
- `gh pr merge` needs the PR's required checks green. After merging one PR, the others briefly report `UNKNOWN`; wait a few seconds and re-check.

**Do not commit `BLTApp/BLTApp.xcodeproj/project.pbxproj`.** It carries the owner's local signing team id (an uncommitted change in the owner's main checkout).

## What this is
**blt.ai** (Budugu Learns Tamil): an iOS 27 / SwiftUI app that teaches colloquial Tamil to Telugu speakers who are fluent in English. **v1 is text-only multiple choice** (English prompt, four romanised-Tamil options, feedback, scheduling); voice is later. Portfolio project, not distributed. Repo: `github.com/darshan-r27/blt.ai` (public), workspace `~/Claude/dev/blt.ai`.

Product rules that matter: two spoken registers only (casual `nee/da/di`, respectful `neenga`; no written/literary Tamil); common English loanwords stay English; never red except Reset progress (037); no network, audio or speech in v1; the only personal data is a display name stored on the device (030).

## Where things are
| Path | What |
|---|---|
| `CLAUDE.md` | Standing rules (read automatically). |
| `plan.md`, `progress.md` | The current build plan (full course) and where it stands. |
| `docs/COURSE_SYLLABUS.md` | Owner-approved syllabus: 8 levels, 100 lessons, exam blueprint. English only. |
| `docs/ARCHITECTURE.md` | How the code is organised (modules, data flow, storage, enforcement). |
| `docs/MVP_PLAN.md` | The v1 plan: frozen contracts (§5, §6a, §6b), chunks, review checklist (§7). |
| `docs/DECISIONS.md` | ADRs 001-041. Newest decisions win; 024-037 define v1; 038 and 040 are active once #13 merges (the duplicate rules, `tamilScript`); 039 (levels) and 041 (exam) are pending. |
| `Packages/BLTKit/` | Swift package: BLTCore, BLTCatalog, BLTProgress, BLTSession, BLTDesign, BLTContentStore, BLTFeatures + tests. |
| `BLTApp/BLTApp.xcodeproj` | App shell. Sources in `BLTApp/BLTApp/`; UI tests in `BLTApp/BLTAppUITests/`. Links only the `BLTFeatures` product. |
| `content/scenario-0N-*.json` | 5 lessons x 20 items, Claude-drafted, bundled into the app as a folder reference. |
| `tools/content-editor/index.html` | Offline review/edit tool for the content (open in **Chrome**): Mark reviewed, Previous/Next, gloss reordering, `level` and `tamilScript` fields, duplicate checks. See its README. |
| `scripts/` | `test.sh`, `check-forbidden-apis.sh`, `check-binary.sh`, `check-identity.sh`, `content-index.sh` (lists prompts and answers; `--check` fails on duplicates; `--self-test`), `githooks/pre-push`. |

## Commands (run from the repo root)
```bash
BLT_SIM="iPhone 17" scripts/test.sh package   # package tests (warnings are errors)
BLT_SIM="iPhone 17" scripts/test.sh app       # build + UI tests (slow: run per class, see below)
swiftlint lint --config .swiftlint.yml --strict
bash scripts/check-forbidden-apis.sh          # also: --self-test
bash scripts/check-binary.sh <path to built .app>
bash scripts/check-identity.sh                 # every commit uses a no-reply email (also in CI)
git config core.hooksPath scripts/githooks    # once per clone: pre-push hook runs the same check
```
Standard simulator: **iPhone 17** (only an iOS 27 runtime is installed). Parallel runs need *different* devices (`xcrun simctl list devices available`). Debug-only launch arguments for UI tests: `--uitest-fixtures`, `--uitest-reset`, `--uitest-name=<Name>`.

## Status
**Shipped on `main`:** the whole v1 app (onboarding, Home, sessions, Progress, Settings), lesson import from Files (036), Reset progress as a warning (037), the `BLTContentStore` module split, a narrowed `BLTFeatures` public API, `docs/ARCHITECTURE.md`, identity guard and CI.

**Course plan (merged):** `plan.md`, `progress.md`, `docs/COURSE_SYLLABUS.md`, DECISIONS 038 to 041 (#8). Wave 1 chunks: #11 and #12 merged, #13 open (see "Start here").

**Content review (owner, in the editor):** all five lessons (100 items) are reviewed and merged (#9, which also removed four repeated accepted spellings). Settings > About the content now reads "Every lesson was checked by a native Tamil speaker". New lessons from the course are drafted `unreviewed`, one level at a time.

**On a real iPhone:** the app installs and launches on the owner's iPhone with a free Apple ID (Debug build, 7-day signature). Not yet checked there: AirDrop to Files to Import, shimmer, VoiceOver, largest text size, the damaged-profile screen.

**Ideas discussed, not planned:** audio clips generated on the Mac and bundled (needs `tamilScript`, hence 040); pronunciation scoring (needs an experiment first; would touch hard constraint 5 and the no-network rule if a cloud service were used).

## Known gaps and watch-items
- **`main` is protected.** Changes go through a PR with two required checks; PRs are squash-merged. The owner can bypass as admin.
- **CI is slow and occasionally flaky.** It runs on GitHub's `xcode-27` preview image; a run takes 12 to 45 minutes. UI tests retry up to 3 times because the image sometimes hangs a UI query. Pushing to a branch cancels its running CI, so hold pushes until a run finishes.
- **The full UI test target takes about 50 minutes locally** and gets killed in one go: run it per class (`scripts/test.sh app -only-testing:BLTAppUITests/<Class>`).
- Three narrow accessibility-audit ignores remain in `AccessibilityUITests.swift` (documented in its header); two may no longer be needed.
- Package content tests read the live `content/` folder: if the editor saves mid-run they can fail transiently; rerun before suspecting code.
- `.completeFileProtection` is not enforced in Simulator: check on a device.
- Old agent worktrees and branches are still under `.claude/worktrees/` (local only). Leave them unless the owner asks for a clean-up.
- Old commits with the owner's previous identity are still reachable through merged PR refs on GitHub (only GitHub Support can purge them).

## How we work here (keep doing this)
- **The main session orchestrates; Sonnet agents execute small chunks** in isolated worktrees (`isolation: "worktree"`), at most three at a time, each with exact file ownership, acceptance criteria, its own simulator, and a short final report. Opus plans.
- **Merge one agent at a time**, run package tests + lint + guard (and the app build when UI changed). Verify once per wave, not after every tiny change. If a chunk fails its check twice, stop it and tell the owner.
- **Never `git add -A` or `git add .`**: stage explicit paths.
- **Frozen contracts** (`MVP_PLAN.md` §5/§6a) change only through a deliberate ADR + plan edit.
- **Agent reports: a 3-line TL;DR plus exceptions, 25 lines max.**
- Ask the owner before overriding anything they set in Xcode or in the docs. Report with a TL;DR first (succeeded / failed / actions needed), in plain language.
- Tests use obviously fake `zz` fixtures; no real Tamil text in Swift files (content lives only in `content/*.json`).
- Tamil content is drafted only in the content task, always `unreviewed`, one level at a time, and only after the owner has finished reviewing the previous level.
- Do not run UI tests on the same simulator as another agent.

## Owner decisions still open
- Which model drafts the Tamil for the course (the plan recommends the strongest available; Sonnet for code). Needed before Wave 3.
- Whether to add a `tamilScript` column to the editor's CSV review sheet.
- Whether `plan.md` and `progress.md` stay in the public repo long term.
- Audio and pronunciation scoring: which voice source, on-device only or not, and whether a score may gate progress (it would touch hard constraint 5).
- Whether to simplify the Progress screen to match Home.
- Real-device checks on the owner's iPhone: AirDrop to Files to Import, shimmer, VoiceOver, largest text, the damaged-profile screen.

## Token/quota hygiene
Start a fresh session at milestones using this file; do not let one session grow past ~60% of its window. Batch requests into one complete message; keep agent reports short; run UI tests only at milestones.
