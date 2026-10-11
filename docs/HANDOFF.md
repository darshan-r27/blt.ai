# BLT.ai: handoff

Read this first in a new session, then `CLAUDE.md`. Last updated 2026-10-11 (Waves 0 to 4 and the exam engine and storage are merged).

## Start here (next session)
**blt.ai is a two-way course (DECISIONS 042): Tamil for the Telugu speaker and Telugu for the Tamil speaker.**
**Everything in `plan.md` except the exam screen, the exam papers and the course content is built and merged on `main`** (Waves 0 to 4, the exam engine and exam storage). The app asks for a name and a language, shows the chosen course's lessons grouped by level, keeps separate progress and imported lessons per language, and switches language in Settings. Tamil has the five reviewed lessons (100 phrases, Level 1); **Telugu has no lessons yet** (Home says so). Nothing is waiting in an unmerged branch or an open PR.

**What to do next, in this order**
1. **Course content (blocked on the owner).** Draft one level at a time, both languages together, per `plan.md` "Content"; Level 1 needs 7 new Tamil lessons and 12 Telugu lessons. Before drafting, the owner must decide **which model drafts the Tamil and Telugu** (the plan recommends the strongest available) and the Telugu reviewer should read `docs/COURSE_SYLLABUS.md` section 4b. Create `docs/content/STYLE_NOTES_TAMIL.md` (from the owner's reviewed lessons 1 to 5) and `STYLE_NOTES_TELUGU.md` first. Run `bash scripts/content-index.sh` before drafting (no repeated prompt or answer inside a course; a later duplicate is silently dropped by the loader) and `--mirror` afterwards. New lessons: `content/<language>/<ta|te>-lNN-uNN-<slug>.json`, `scenarioId` `<ta|te>-lNN-uNN`, items `<id>-iNN`, every item with `script`, all `unreviewed`; the owner reviews Tamil, the owner's partner reviews Telugu, in the editor; commit review edits only after the owner has seen the full `git diff content/`.
2. **Exam screen (chunk E3, plan.md "Exam").** The engine (`BLTSession/Exam`) and storage (`BLTProgress/Exam`, `courses/<language>/exam.json`) are merged and unwired. Build `BLTFeatures/Exam`: an entry on Home that is enabled only when every level of the current course is complete, 100 questions in one sitting with no feedback until the end, the result screen (score, pass at 75, weakest levels shown only when they are real weaknesses, the plain statement that a pass shows recognition, not speech), saving each attempt through `ExamResultStore`, and Reset progress clearing that course's exam results. Wire it through `CourseServices` (add the exam store beside the progress store). It cannot be exercised for real until Level 8 exists; test it with fixtures. Then the exam papers (chunk E4, `content/<language>/exam/final.json`, written after Level 8 is reviewed).
3. **CI health (decide with the owner first, see "Known gaps").** DECISIONS 045's goal (PR UI job under 15 minutes) was not met on the preview runner; ADR 045 stays `pending`.
4. **Small follow-ups** (none urgent): see "Known gaps and watch-items".

**Owner preferences to keep honouring**
- TL;DR first (what worked, what failed, what you need), plain language, short.
- **Never archive any of the owner's sessions without asking** (auto-archive on PR close is turned off).
- Ask before overriding anything the owner set in Xcode or the docs. Do NOT commit `BLTApp/BLTApp.xcodeproj/project.pbxproj` (it carries the owner's local signing team id; an uncommitted change in the owner's clone). Stage explicit paths only.
- Remote Control is on for the working sessions. If a session resumes after a usage limit, the owner wants model effort **High** (a session cannot change its own effort; ask the owner or use the picker).
- Owner's own device checks still open: AirDrop to Files to Import, shimmer, VoiceOver, largest text, the damaged-profile screen, `.completeFileProtection` on `progress.json` and `exam.json`, and a look at the new screens (language step, Home by level, Settings language row), which were verified by tests and one simulator walk, not by eye.

**How the last sessions ran (reuse it)**
- One orchestrating session; Sonnet agents (at most three at once) each in its own git worktree on its own simulator (`iPhone 17`, `iPhone 17e`, `iPhone Air`, `iPhone 18 Pro`), each told not to push and to report in 25 lines. The orchestrator verifies claims that matter, rebases onto `main` with `git rebase --onto origin/main <old base> <branch>` (PRs are squash-merged, so plain rebases replay old commits), opens PRs, and merges them one at a time when CI is green. A small shell loop that waits on `gh pr view --json mergeStateStatus` (merge only on `CLEAN`, stop on a failing check) was used for the merges. A usage-limit cut-off is recoverable: the interrupted agent's commits stay in its worktree and `SendMessage` to its agent id resumes it.
- Claude Code quirks: `gh`, `git worktree add`, `xcodebuild`, `swiftlint` and headless Chrome need the sandbox off for that command (`/sandbox` changes it). The permission hook denies `git reset --hard`, `git push --force` and anything containing `rm -rf` (use `git switch -c <name> <base>`, merge-and-push, and ask the owner to run any `rm -rf`). Do not run `xcrun simctl shutdown all` while agents run.

## What this is
**blt.ai** (Budugu Learns Tamil / Telugu): an iOS 27 / SwiftUI app for a couple learning each other's language, with English as the shared medium. **Text-only multiple choice** (English prompt, four romanised options, feedback, scheduling); voice is v2. Portfolio project, not distributed. Repo: `github.com/darshan-r27/blt.ai` (public), workspace `~/Claude/dev/blt.ai`. **Built today:** the app and the first five Tamil lessons. **Planned:** the language choice, the Telugu course, and 2,000 phrases per course.

Product rules that matter: two spoken registers only per language (casual and respectful; no written or literary forms); Telugu is the standard Coastal Andhra spoken variety; common English loanwords stay English; never red except Reset progress (037); no network, audio or speech; the only personal data is a display name stored on the device (030).

## Where things are
| Path | What |
|---|---|
| `CLAUDE.md` | Standing rules (read automatically). |
| `plan.md`, `progress.md` | The current build plan (two courses) and where it stands. |
| `docs/COURSE_SYLLABUS.md` | Owner-approved syllabus both courses follow: 8 levels, 100 lessons, exam blueprint. English only. |
| `docs/REVIEWER_GUIDE.md` | How a native speaker reviews a course (written for the Telugu reviewer; still marks `script` and the `content/<language>` folders as "planned", they now exist). |
| `docs/TEST_TIMINGS.md` | Measured UI-test durations and the ADR 045 reshape. |
| `docs/ARCHITECTURE.md` | How the code is organised (modules, data flow, storage, enforcement). |
| `docs/MVP_PLAN.md` | The v1 plan: frozen contracts (§5, §6a, §6b), chunks, review checklist (§7). |
| `docs/DECISIONS.md` | ADRs 001-045. Newest decisions win; 024-037 define v1; 038-040 and 042-044 are active; 041 (exam) and 045 (test tiers) are still pending. |
| `Packages/BLTKit/` | Swift package: BLTCore, BLTCatalog, BLTProgress, BLTSession, BLTDesign, BLTContentStore, BLTFeatures + tests. |
| `BLTApp/BLTApp.xcodeproj` | App shell. Sources in `BLTApp/BLTApp/`; UI tests in `BLTApp/BLTAppUITests/`. Links only the `BLTFeatures` product. |
| `content/tamil/ta-l01-u0N-*.json` | The 5 reviewed Tamil lessons (20 items each, Level 1), bundled as a folder reference; `content/telugu/` will hold the Telugu course (does not exist yet). |
| `tools/content-editor/index.html` | Offline review/edit tool for the content (open in **Chrome**). See its README. |
| `scripts/` | `test.sh`, `check-forbidden-apis.sh`, `check-binary.sh`, `check-identity.sh`, `content-index.sh` (per-language index, duplicate check, `--mirror`), `githooks/pre-push`. |

## Commands (run from the repo root)
```bash
BLT_SIM="iPhone 17" scripts/test.sh package   # package tests (warnings are errors)
BLT_SIM="iPhone 17" scripts/test.sh app --tier pr    # UI tests, PR tier: happy paths + default-size audits (16 tests)
BLT_SIM="iPhone 17" scripts/test.sh app --tier full  # every UI test (40; slow, so run per class, see below)
scripts/test.sh app --tier pr --build-only           # build once; then run with --no-build (what CI does)
scripts/test.sh tiers                                # which classes are in which tier (runs nothing)
scripts/test.sh flakes <xcodebuild log>              # list UI tests that failed an attempt in a log
swiftlint lint --config .swiftlint.yml --strict
bash scripts/check-forbidden-apis.sh          # also: --self-test
bash scripts/check-binary.sh <path to built .app>
bash scripts/check-identity.sh                 # every commit uses a no-reply email (also in CI)
git config core.hooksPath scripts/githooks    # once per clone: pre-push hook runs the same check
```
Standard simulator: **iPhone 17** (only an iOS 27 runtime is installed). Parallel runs need *different* devices (`xcrun simctl list devices available`). Debug-only launch arguments for UI tests: `--uitest-fixtures`, `--uitest-reset`, `--uitest-name=<Name>`.

## Status
**Shipped on `main`:** the whole v1 app (onboarding, Home, sessions, Progress, Settings), lesson import from Files (036, up to 20 files, per language, a wrong-language file is refused with its own message), Reset progress as a warning (037, clears only the current language), the two-language lesson format (`language`, `script`, `word`, `level`; duplicate rules per course), the editor and `content-index.sh` for it, `CourseLanguage`, the optional `learningLanguage` on the profile, onboarding language step, Home grouped by level, Settings language switch, per-language storage (`Application Support/BLT/profile.json` shared; `courses/<language>/progress.json` and `courses/<language>/content/`), a one-time removal of the old single-course build's files, the exam engine and exam storage (unwired), the two-tier UI test setup, identity guard, protected `main`.

**Content:** all 100 Tamil phrases (lessons 1 to 5, Level 1, ids `ta-l01-u01` to `ta-l01-u05`) are reviewed. They have no `script` yet (the five ids are listed as grandfathered in one constant in `ShippedContentTests`; delete it when they are backfilled). No Telugu content exists. Tamil is reviewed by the owner; Telugu by the owner's partner on their own computer, with files returned by AirDrop and committed through a PR after the owner has seen the full `git diff content/`.

**On a real iPhone:** the app installs and launches on the owner's iPhone with a free Apple ID (Debug build, 7-day signature; reinstall from Xcode weekly, do not delete the app, which would erase progress). The new build removes the old build's progress file and imported lessons at first launch (intended; the owner confirmed no learner progress exists).

**Test counts (2026-10-11):** about 560 package tests; 40 UI tests in two tiers (PR tier 16: `AccessibilityUITests`, `HappyPathUITests`; full tier adds `AccessibilityLargeTextUITests`, `LanguageUITests`, Onboarding, Home, Persistence, EndSession, FeedbackFlow, SettingsImport).

**Ideas discussed, not planned:** audio clips generated on the Mac from `script` and bundled (cloud voices' free tiers cover 1,000 phrases; the owner's own recordings or approved generated clips; needs an owner decision); pronunciation scoring (needs an experiment first; a score may not affect progress today, hard constraint 5; a cloud service would break the no-network rule).

## Known gaps and watch-items
- **`main` is protected.** Changes go through a PR with two required checks; PRs are squash-merged. The owner can bypass as admin.
- **CI is slow and flaky on GitHub's `xcode-27` preview runner, and ADR 045's speed goal was not met.** Measured on PRs #22 to #25: the UI job took 26, 36, 38 and (after a rerun) 31 minutes against a goal of under 15; one hung happy-path test cost 352 seconds, and #25's first attempt hit the 40-minute PR timeout and was rerun. Package tests take 5 to 11 minutes. On `main`, the full tier has failed twice from runner problems, not code: a package job whose tests all passed and then reported "the test runner hung before establishing connection", and a full-tier UI job that ran into its 90-minute limit. Reruns (`gh run rerun <id> --failed`) fix these. **Decision for the owner:** keep PR-tier UI tests at 25 to 40 minutes per PR, or run UI tests on the full tier only (fast PR loop; a UI regression would show after merge). Possible cheaper fix: retry the package job once on that specific hang. Pushing to a branch cancels its running CI, so hold pushes until a run finishes. Required checks are named "Guardrails and lint" and "Package and app tests" (a gate job); do not add "Package tests" or "UI tests" as required.
- **The full UI test target takes about 50 minutes locally** and gets killed in one go: run it per class (`scripts/test.sh app -only-testing:BLTAppUITests/<Class>`).
- Three narrow accessibility-audit ignores remain in `AccessibilityUITests.swift` (documented in its header); two may no longer be needed.
- Package content tests read the live `content/` folder: if the editor saves mid-run they can fail transiently; rerun before suspecting code.
- `.completeFileProtection` is not enforced in Simulator: check on a device.
- Old agent worktrees and branches are still under `.claude/worktrees/` (local only). Leave them unless the owner asks for a clean-up.
- **Follow-ups noticed (none urgent):** the disabled Continue button on the language step has a documented contrast exception (alternative: darken the disabled style); the release log records a missing Telugu folder as an error (quiet it once Telugu lessons exist); the editor has no one-click converter for old-format files and leaves a stale `tamil` key beside `word` if a gloss row is edited; `docs/REVIEWER_GUIDE.md` still says "planned" for things that exist; `ContentIssue`/Settings have no per-case wording for every import failure beyond `invalid` and `wrongLanguage`; animations and the shimmer are not switched off for UI tests (needs an app-source change); two of the three accessibility-audit ignores may be unnecessary; the name-entry audits fail on the owner's Mac for a keyboard reason but pass in CI (and passed once locally in the last run); DECISIONS 036 and the README still describe some single-course wording in places.
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
- **Which model drafts the Tamil and Telugu** (blocks all content work).
- The Telugu reviewer should check section 4b of the syllabus before Telugu Level 1 is drafted.
- CI: accept 25 to 40 minutes per PR, or move UI tests off the PR path (see "Known gaps").
- The disabled Continue button's contrast exception, or darken its style.
- Whether `plan.md` and `progress.md` stay in the public repo long term.
- v2: which voice source (own recordings or approved generated clips), on-device only or not, and whether a pronunciation score may gate progress.
- Whether to simplify the Progress screen to match Home.

## Token/quota hygiene
Start a fresh session at milestones using this file; do not let one session grow past ~60% of its window. Batch requests into one complete message; keep agent reports short; run UI tests only at milestones.
