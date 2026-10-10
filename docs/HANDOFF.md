# BLT.ai: handoff

Read this first in a new session, then `CLAUDE.md`. Last updated 2026-10-09.

## Start here (next session)
**blt.ai is now a two-way course (DECISIONS 042): Tamil for the Telugu speaker and Telugu for the Tamil speaker,
for a couple who share English.** The owner approved `plan.md` on 2026-10-09. Wave 0 (the documents) is done.
`main` is still the Tamil-only app described below. The earlier single-course plan's Wave 1 is merged (PRs #11
to #13) and is reused: optional `level` and `tamilScript`, the three duplicate rules, the editor fields, and
`scripts/content-index.sh`. So A1 to A3 below are deltas on that work, not new builds.

**Next task: chunk T1 of `plan.md`, then Wave 1.** Read `plan.md`, `docs/COURSE_SYLLABUS.md` and DECISIONS 038
to 044 first.

| Chunk | Owns (touch nothing else) | Proof |
|---|---|---|
| **T1** (main session, merge first) | new `Packages/BLTKit/Sources/BLTCore/CourseLanguage.swift` + test; `BLTDesign/AccessibilityID.swift` (ids for Waves 3 and 4) | package tests |
| **A1 Catalog format** | `Packages/BLTKit/Sources/BLTCatalog/*`, `Tests/BLTCatalogTests/*`, the five `content/*.json` files (format only) | package tests |
| **A2 Editor** | `tools/content-editor/index.html` and its README | headless Chrome run of the editor's checks |
| **A3 Drafting aid** | `scripts/content-index.sh` (exists; add per-language index and `--mirror`) | its `--check` and `--self-test` |
| **A4 Profile** | `Packages/BLTKit/Sources/BLTProgress/Profile/*` and its tests | package tests |

A1 to A4 run in parallel after T1, as Sonnet agents in separate worktrees, one PR each. Details that are easy
to get wrong:
- **A1.** Lesson: add the required `language` (`tamil`/`telugu`); `level` already exists. Item: rename
  `tamilScript` to `script`, which must contain characters of the lesson language's script (Tamil U+0B80 to
  U+0BFF, Telugu U+0C00 to U+0C7F) and no Latin letters. Both scripts stay errors in every other field. The
  gloss key is `word`; the old key `tamil` is an error, never a fallback.
- **Duplicates are already built** (catalog-wide prompt and answer checks; no accepted spelling twice in one
  item). Leave them as they are; they apply to each course separately.
- **A1 also updates the five shipped files in place** (adds `language`, renames the gloss key to `word`), in
  the same PR, so the shipped-content tests stay green. It changes no lesson text and no review status. The
  files move to `content/tamil/` later, in Wave 2.
- `Scenario`, `Item`, `UserProfile` and `AppDependencies` are frozen contracts (`docs/MVP_PLAN.md` section 5):
  add fields with defaults so existing call sites compile. When A1 lands, rewrite `MVP_PLAN.md` section 2 and
  flip DECISION 044 from pending to active.
- Fixtures are fake `zz` text; a script fixture is one letter repeated. No Tamil or Telugu in Swift or docs.
- **A4.** `learningLanguage` is optional. A schema-1 profile loads with no language; nothing defaults to Tamil.

**Do not commit `BLTApp/BLTApp.xcodeproj/project.pbxproj`.** It carries the owner's local signing team id.

After Wave 1: merge one PR at a time, run the full check, update `progress.md`, then stop and report.

## What this is
**blt.ai** (Budugu Learns Tamil / Telugu): an iOS 27 / SwiftUI app for a couple learning each other's language, with English as the shared medium. **Text-only multiple choice** (English prompt, four romanised options, feedback, scheduling); voice is v2. Portfolio project, not distributed. Repo: `github.com/darshan-r27/blt.ai` (public), workspace `~/Claude/dev/blt.ai`. **Built today:** the app and the first five Tamil lessons. **Planned:** the language choice, the Telugu course, and 2,000 phrases per course.

Product rules that matter: two spoken registers only per language (casual and respectful; no written or literary forms); Telugu is the standard Coastal Andhra spoken variety; common English loanwords stay English; never red except Reset progress (037); no network, audio or speech; the only personal data is a display name stored on the device (030).

## Where things are
| Path | What |
|---|---|
| `CLAUDE.md` | Standing rules (read automatically). |
| `plan.md`, `progress.md` | The current build plan (two courses) and where it stands. |
| `docs/COURSE_SYLLABUS.md` | Owner-approved syllabus both courses follow: 8 levels, 100 lessons, exam blueprint. English only. |
| `docs/REVIEWER_GUIDE.md` | How a native speaker reviews a course (written for the Telugu reviewer). |
| `docs/ARCHITECTURE.md` | How the code is organised (modules, data flow, storage, enforcement). |
| `docs/MVP_PLAN.md` | The v1 plan: frozen contracts (§5, §6a, §6b), chunks, review checklist (§7). |
| `docs/DECISIONS.md` | ADRs 001-044. Newest decisions win; 024-037 define v1; 038-044 are pending (two courses). |
| `Packages/BLTKit/` | Swift package: BLTCore, BLTCatalog, BLTProgress, BLTSession, BLTDesign, BLTContentStore, BLTFeatures + tests. |
| `BLTApp/BLTApp.xcodeproj` | App shell. Sources in `BLTApp/BLTApp/`; UI tests in `BLTApp/BLTAppUITests/`. Links only the `BLTFeatures` product. |
| `content/scenario-0N-*.json` | 5 lessons x 20 items, Claude-drafted, bundled into the app as a folder reference. |
| `tools/content-editor/index.html` | Offline review/edit tool for the content (open in **Chrome**). See its README. |
| `scripts/` | `test.sh`, `check-forbidden-apis.sh`, `check-binary.sh`, `check-identity.sh`, `githooks/pre-push`. |

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

**Wave 0 PR (`two-way-thesis` branch):** the thesis rewrite across the docs, DECISIONS 042 to 044, the reviewer guide and the new `plan.md`. Docs only.

**Content review:** all 100 Tamil phrases (lessons 1 to 5) are reviewed and on `main`. No Telugu content exists. Tamil is reviewed by the owner; Telugu by the owner's partner on their own computer, with files returned by AirDrop and committed through a PR after the owner has seen the full `git diff content/`.

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
- Tamil and Telugu content is drafted only in a content task, always `unreviewed`, one level at a time, and only after the owner has finished reviewing the previous level.
- Do not run UI tests on the same simulator as another agent.

## Owner decisions still open
- The Telugu reviewer should check section 4b of the syllabus before Telugu Level 1 is drafted.
- Whether `plan.md` and `progress.md` stay in the public repo long term.
- Which model drafts the Tamil and Telugu (the plan recommends the strongest available; Sonnet for code).
- v2: which voice source, on-device only or not, and whether a pronunciation score may gate progress.
- Whether to simplify the Progress screen to match Home.

## Token/quota hygiene
Start a fresh session at milestones using this file; do not let one session grow past ~60% of its window. Batch requests into one complete message; keep agent reports short; run UI tests only at milestones.
