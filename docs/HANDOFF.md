# BLT.ai: handoff

Read this first in a new session, then `CLAUDE.md`. Last updated 2026-10-16 (cheat sheets built, v0.5.0; Level 1 drafted for both courses and merged, unreviewed; CI path filter merged).

## Start here (next session)
**blt.ai is a two-way course (DECISIONS 042): Tamil for the Telugu speaker and Telugu for the Tamil speaker.**
**Everything in `plan.md` except the exam papers and the review and drafting of Levels 3 to 8 is built and merged on `main`** (Waves 0 to 4, the exam engine and exam storage). The app asks for a name and a language, shows the chosen course's lessons grouped by level, keeps separate progress and imported lessons per language, and switches language in Settings. Both courses have Levels 1 and 2 drafted (480 phrases each); only Tamil lessons 1 to 5 are reviewed, the rest is `unreviewed` (the Settings count reads "100 of 480 reviewed" for Tamil). Nothing is waiting in an unmerged branch or an open PR.

**What to do next, in this order**
0a. **Cheat sheets (built 2026-10-16, v0.5.0, DECISIONS 048; PR #47).** Read `plan.md` section "Cheat sheets". A finished topic's card gets a "Cheat sheet" button and Home gets a "Cheat sheets" list. The sheet is an auto-built word list (not a verb and adverb sheet: the lesson data has no part-of-speech labels); the unlock is stored per language in `courses/<language>/cheatsheets.json` and Reset progress clears it. Built in Waves 1 to 3 (C1 to C6). UI tests: `HappyPathUITests` (one new), `CheatSheetUITests`, `AccessibilityCheatSheetUITests`; launch argument `--uitest-cheatsheets=<ids>` (or `--uitest-cheatsheets-<language>=<ids>`) marks topics complete, the fixtures' ids are `zz-scenario` and `zz-scenario-telugu`. **Still owed:** (a) retake and add `docs/images/cheatsheet.png` and `docs/images/cheatsheet-list.png` (the README already links them) from a current build; (b) the owner's checks on an iPhone: finish a topic and read its sheet, VoiceOver on a row (it should read "word, meaning"), and that the sheet still opens after the topic is no longer 100%; (c) how the screens look at the largest text size by eye (the audits pass, previews were not viewed rendered); (d) after the merge, tag `v0.5.0` only when the owner says so.
0. **Daily practice feature (approved 2026-10-14): built, merged as PRs #40, #41 and #42 (the plan is #39).** **Still owed:** (a) the new UI tests have run and pass (`DailyPracticeUITests`, `AccessibilityPracticeUITests`, the new `AccessibilityLargeTextUITests` checks, the three `HappyPathUITests`); the whole full tier ran once on iPhone 17e (77 tests): all pass except `AccessibilityLargeTextUITests.testIntroAndNameEntryControlsAreReachableAtXXXL`, which fails the same way without this feature (Continue not hittable on the name screen at the largest size), so it is a separate follow-up. On the iPhone 17 simulator the two name-entry audits fail ("keyboard did not dismiss") even on code without this feature; use iPhone 17e for them; (b) the owner looks at the new screens in Xcode previews or the simulator (flame, week strip, calendar, burst, Settings section, prompt): nothing has been seen by eye; (c) on the owner's iPhone: allow notifications, finish a session, confirm the reminders at +20 h and +23 h and the quiet-hours shift, VoiceOver on the streak screen, and `.completeFileProtection` on `practice.json`. Rules and shape are in DECISIONS 047 and `docs/ARCHITECTURE.md` "Daily practice". Local notifications only; the one file that imports `UserNotifications` is `BLTApp/BLTApp/LocalReminderScheduler.swift`. No lesson text or learner name in notification text. Known choices: a 25-hour fall-back night breaks a streak unless a freeze is held; the notification prompt is asked once, after the very first finished session; the Continue card stays under the Today card because `HomeUITests` needs it.
1. **Course content: Levels 1 and 2 are drafted for both courses and wait for review.** Level 1: PRs #29 and #30 (Tamil lessons 1 to 5 reviewed, the rest unreviewed). Level 2 (12 lessons, 240 phrases per language, all `unreviewed`) was drafted ahead of the Level 1 review at the owner's request. The drafting model is **Sonnet 5.5 at High effort**; the owner will check with Opus later. **Level 3 is drafted only after each language's reviewer says Levels 1 and 2 are done**, so their corrections land first (plan.md "Content" step 6); the Tamil and Telugu paces may differ. Rules for the drafter: read `docs/content/STYLE_NOTES_TAMIL.md` (rules from the owner's edits to lessons 1 to 5, plus the Level 2 notes) and `STYLE_NOTES_TELUGU.md` (the drafter's choices and the items least certain); update both with every review correction and re-apply them to the later level. Run `bash scripts/content-index.sh --check` before and after drafting and `--mirror` afterwards (a later duplicate is silently dropped by the loader). Files: `content/<language>/<ta|te>-lNN-uNN-<slug>.json`, items `<id>-iNN`, every item with `script`, all `unreviewed`; commit review edits only after the owner has seen the full `git diff content/`. Register mix is off the syllabus 40/40/20: Level 1 about 8% casual, 26% respectful, 66% no you-form; Level 2 about 20/14/66. Statements about things and people have no you-form, so reaching the target needs more questions to a friend or an elder in Level 3. The five original Tamil lessons' `script` spellings were backfilled (PR #35, merged after the owner read it).
2. **Exam papers (chunk E4).** The exam screen (E3, PR #32) is built: Home shows a "Final exam" card only when a course has a paper (`AppDependencies.examPaper`, `nil` today), locked until every level is complete; the sitting gives no feedback and stores a score-only attempt in `courses/<language>/exam.json`; Reset progress clears it. **Paper format and loader are built (DECISIONS 046, `ExamPaperLoader`, wired in `CompositionRoot.loadExamPaper`).** What remains is writing the papers: `content/<language>/exam/final.json` per the blueprint in `docs/COURSE_SYLLABUS.md` section 6 (about 70 new sentences with `examLevel`, about 30 `fromLessons` ids), after that language's Level 8 is reviewed; `ShippedExamPaperTests` then checks it. Until then there is no way to open the exam in the app, so it has no UI test and has not been seen by eye (SwiftUI previews exist in `Exam/ExamView.swift`).
3. **CI health.** The serial-simulator fix (#27) and a path filter (#28, DECISIONS 045) are merged: a PR that touches none of `Packages/`, `BLTApp/`, `scripts/test.sh` or the workflow skips the UI job (content-only PRs take about 7 minutes). The UI job on an app-code PR took 18.6 minutes (#27) and 13.9 minutes (#28). ADR 045 stays `pending` until three app-code PR runs are under 15 minutes and the full tier is green on `main` (check the push run of any merge that touched `Packages/` or `BLTApp/`).
4. **Small follow-ups** (none urgent): see "Known gaps and watch-items".

**Owner preferences to keep honouring**
- TL;DR first (what worked, what failed, what you need), plain language, short.
- **Every change updates GitHub in the same PR**: `CHANGELOG.md` (versioned), `README.md` (features and fresh screenshots), ARCHITECTURE, DECISIONS, HANDOFF (rule in `CLAUDE.md`, "Keep GitHub current").
- **Never archive any of the owner's sessions without asking** (auto-archive on PR close is turned off).
- Ask before overriding anything the owner set in Xcode or the docs. Do NOT commit `BLTApp/BLTApp.xcodeproj/project.pbxproj` (it carries the owner's local signing team id; an uncommitted change in the owner's clone). Stage explicit paths only.
- Remote Control is on for the working sessions. If a session resumes after a usage limit, the owner wants model effort **High** (a session cannot change its own effort; ask the owner or use the picker).
- Owner's own device checks still open: AirDrop to Files to Import, shimmer, VoiceOver, largest text, the damaged-profile screen, `.completeFileProtection` on `progress.json` and `exam.json`, and a look at the new screens (language step, Home by level, Settings language row), which were verified by tests and one simulator walk, not by eye.

**How the last sessions ran (reuse it)**
- One orchestrating session; Sonnet agents (at most three at once) each in its own git worktree on its own simulator (`iPhone 17`, `iPhone 17e`, `iPhone Air`, `iPhone 18 Pro`), each told not to push and to report in 25 lines. The orchestrator verifies claims that matter, rebases onto `main` with `git rebase --onto origin/main <old base> <branch>` (PRs are squash-merged, so plain rebases replay old commits), opens PRs, and merges them one at a time when CI is green. A small shell loop that waits on `gh pr view --json mergeStateStatus` (merge only on `CLEAN`, stop on a failing check) was used for the merges. A usage-limit cut-off is recoverable: the interrupted agent's commits stay in its worktree and `SendMessage` to its agent id resumes it.
- Claude Code quirks: `gh`, `git worktree add`, `xcodebuild`, `swiftlint` and headless Chrome need the sandbox off for that command (`/sandbox` changes it). The permission hook denies `git reset --hard`, `git push --force` and anything containing `rm -rf` (use `git switch -c <name> <base>`, merge-and-push, and ask the owner to run any `rm -rf`). Do not run `xcrun simctl shutdown all` while agents run.

## What this is
**blt.ai** (Budugu Learns Tamil / Telugu): an iOS 27 / SwiftUI app for a couple learning each other's language, with English as the shared medium. **Text-only multiple choice** (English prompt, four romanised options, feedback, scheduling); voice is v2. Portfolio project, not distributed. Repo: `github.com/darshan-r27/blt.ai` (public), workspace `~/Claude/dev/blt.ai`. **Built today:** the app, the language choice, the exam screen and paper loader, and Levels 1 and 2 of both courses (480 phrases each, mostly unreviewed). **Planned:** Levels 3 to 8 (2,000 phrases per course) and the exam papers.

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

**Content:** all 100 Tamil phrases (lessons 1 to 5, Level 1, ids `ta-l01-u01` to `ta-l01-u05`) are reviewed. Their `script` spellings were backfilled (the grandfathering in `ShippedContentTests` is gone). Telugu Level 1 exists as unreviewed drafts. Tamil is reviewed by the owner; Telugu by the owner's partner on their own computer, with files returned by AirDrop and committed through a PR after the owner has seen the full `git diff content/`.

**On a real iPhone:** the app installs and launches on the owner's iPhone with a free Apple ID (Debug build, 7-day signature; reinstall from Xcode weekly, do not delete the app, which would erase progress). The new build removes the old build's progress file and imported lessons at first launch (intended; the owner confirmed no learner progress exists).

**Test counts (2026-10-11):** about 560 package tests; 40 UI tests in two tiers (PR tier 16: `AccessibilityUITests`, `HappyPathUITests`; full tier adds `AccessibilityLargeTextUITests`, `LanguageUITests`, Onboarding, Home, Persistence, EndSession, FeedbackFlow, SettingsImport).

**Ideas discussed, not planned:** audio clips generated on the Mac from `script` and bundled (cloud voices' free tiers cover 1,000 phrases; the owner's own recordings or approved generated clips; needs an owner decision); pronunciation scoring (needs an experiment first; a score may not affect progress today, hard constraint 5; a cloud service would break the no-network rule).

## Known gaps and watch-items
- **`main` is protected.** Changes go through a PR with two required checks; PRs are squash-merged. The owner can bypass as admin.
- **CI speed (2026-10-12).** Root cause of the 26 to 38 minute PR runs: the test runner crashed bootstrapping in a *cloned* simulator, then xcodebuild waited 600 seconds (see `docs/TEST_TIMINGS.md`; the "flaky" `HappyPathUITests.testConfirmingEndReturnsHome` is just the first test in the clone). Fixed in #27 (serial, one booted simulator) and #28 (path filter). Still owed: two more app-code PR timings under 15 minutes for ADR 045, and a green full tier on `main`. Reruns (`gh run rerun <id> --failed`) recover genuine runner failures. Pushing to a branch cancels its running CI. Required checks are "Guardrails and lint" and "Package and app tests" (a gate job that accepts a skipped UI job only when the `changes` job said it was not needed); do not add "Package tests", "UI tests" or "Which tests this change needs" as required.
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
- CI: after the serial-simulator fix, whether the UI job also moves off the PR path (path-filtered on PRs, full tier after merge). The owner asked on 2026-10-11: yes, it can; a dev/staging branch is not worth it for one developer; a self-hosted runner on the owner's Mac is not advised on a public repo.
- (Decided 2026-10-11) the contrast exception on the disabled language Continue button is kept.
- Whether `plan.md` and `progress.md` stay in the public repo long term.
- v2: which voice source (own recordings or approved generated clips), on-device only or not, and whether a pronunciation score may gate progress.
- Whether to simplify the Progress screen to match Home.

## Token/quota hygiene
Start a fresh session at milestones using this file; do not let one session grow past ~60% of its window. Batch requests into one complete message; keep agent reports short; run UI tests only at milestones.
