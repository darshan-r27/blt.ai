# blt.ai becomes a two-way course: Tamil and Telugu, for a couple learning each other's language

This replaces the single-course plan. That plan's Wave 1 was built and merged (PRs #11 to #13: `level`,
`tamilScript`, the duplicate rules, the editor fields and `scripts/content-index.sh`) and is reused here; its
later waves are replaced by this plan. Progress is tracked in `progress.md`.

## Context
Today blt.ai teaches colloquial Tamil to a Telugu speaker. The owner wants a new thesis: **BLT = Budugu Learns
Tamil / Telugu**, one app for a cross-language couple, each learning the other's language with English as the
shared medium. The learner gives a name and picks the language they want to learn; everything else (lessons,
progress, exam, import, review labels) works the same for either language.

Decided with the owner:
- **Reviewers:** the owner reviews Tamil; the owner's partner, a native Telugu speaker, reviews Telugu.
- **Size:** both courses are 2,000 phrases (100 lessons, 8 levels), drafted one level at a time.
- **Telugu variety:** standard Coastal Andhra spoken Telugu, casual and respectful registers, romanised.
- **Switching:** the language can be changed in Settings; each language keeps its own progress.
- **Mirrored:** one syllabus, and wherever natural the same English prompt in both courses.
- Carried over from the approved course plan: graded levels that are ordered but not locked, duplicate rules,
  a native-script field per phrase, and a 100-question exam with a pass mark of 75 (now one per language).

**Why this is mostly not a rewrite.** Lessons are data files and the engine never looks at the language, so
the code change is: a language on the profile, per-language content and storage, a language step in
onboarding, and copy. The large cost is content: 3,900 phrases to draft and about 65 hours of review split
between two people (about 32 hours Tamil, 33 hours Telugu).

**Limits to state plainly.** Multiple choice proves recognition, not speech. Telugu drafts are Claude-written
and stay labelled "Unreviewed draft" until the partner checks them.

## Decisions most likely to change
1. **Reset progress clears only the language being learned** (and says so in the confirmation). The other
   language's progress is untouched.
2. **Old profiles ask again.** A profile saved before this change has no language; the app shows the language
   step rather than assuming Tamil (no silent default).
3. **Lesson file changes** (one format for both languages):
   - New required `language`: `tamil` or `telugu`. A file in the wrong course is rejected, including imports.
   - Word-gloss key `tokens[].tamil` is renamed `tokens[].word`. The five existing files are rewritten once;
     the old key is an error afterwards.
   - The planned `tamilScript` becomes `script`, checked against the lesson language's own script
     (Tamil U+0B80 to U+0BFF, Telugu U+0C00 to U+0C7F). Either script stays banned in every other field.
   - `level: { number, title, position }` and the duplicate rules as already decided (038, 039).
4. **Layout and ids.** `content/tamil/*.json` and `content/telugu/*.json`. Paired lessons share a key:
   `ta-l02-u03` and `te-l02-u03`. The five existing Tamil lessons are renamed to this scheme (`ta-l01-u01` to
   `ta-l01-u05`, files and item ids to match) when they move in chunk B1. They stay `reviewed`. The owner
   confirmed on 2026-10-09 that no learner has progress on them, so nothing needs to survive the rename.
5. **Storage on the phone.** `Application Support/BLT/courses/<language>/` holds `progress.json`, imported
   lessons and the exam result. **Nothing is migrated:** there is no learner progress to keep, and the old
   lesson ids no longer exist. The old build's `progress.json` and imported `content/` folder are removed once
   at the first launch of the new build (tested), so no orphaned files are left behind.
6. **Mirroring is checked, not forced.** `scripts/content-index.sh --mirror` lists paired lessons whose English
   prompts differ. Differences are allowed where a sentence does not work in one language.
7. **The Telugu reviewer works on their own computer** (decided). They get the editor and the
   `content/telugu` folder by downloading the public repo (no account or tools needed; the editor is one
   offline HTML page opened in Chrome). Reviewed files come back to the owner by AirDrop, the owner checks the
   full diff, and they are committed through a PR. Either phone picks up new lessons through the existing
   Settings > Import lessons (AirDrop to Files, then import), so neither person waits for a rebuild.
8. **Model for drafting.** Strongest available for Tamil and Telugu content; Sonnet for code.

## Frozen contracts and rules that change (ADRs written in Wave 0)
- **042 Two-course thesis** (replaces the framing of 001; extends 025 "no real Tamil in code" to Telugu).
- **043 Language on the profile, per-language storage, switching, reset scope** (changes `UserProfile`, adds
  `language` to `AppDependencies`).
- **044 Lesson format for two languages** (amends 038 to 040; rewrites `docs/MVP_PLAN.md` section 2).
- 041 (exam) becomes one exam per language.
- `CLAUDE.md`: headline, the content rule, and the module notes. No hard constraint is relaxed: no network,
  no audio, no speech, no third-party SDK.

## Wave 0: thesis and documents (main session, no code)
**T0.** Files: `docs/PRD.md` (new thesis section at the top), `docs/DECISIONS.md` (042 to 044),
`docs/COURSE_SYLLABUS.md`, `docs/ARCHITECTURE.md`, `docs/MVP_PLAN.md`, `docs/HANDOFF.md`, `README.md`,
`CLAUDE.md`, `docs/BUILD_PLAN.md`, `docs/REVIEWER_GUIDE.md` (new), `plan.md`, `progress.md`.
- Syllabus: the 100 lessons stay as approved and now serve both courses. Section 4 splits into "Notes for a
  Telugu speaker learning Tamil" and "Notes for a Tamil speaker learning Telugu" (the second is for the
  partner to correct). Adds the Telugu register policy and the mirroring rule. English only.
- Adds `docs/REVIEWER_GUIDE.md`: one page for the Telugu reviewer (get the files, open the editor, what
  "reviewed" means, how to send files back, how to import on the phone).
- Done when the owner approves the docs PR.

**T1 (tiny, merged before Wave 1).** Files: new `Packages/BLTKit/Sources/BLTCore/CourseLanguage.swift` + test,
`BLTDesign/AccessibilityID.swift` (all new ids for Waves 3 and 4, added up front so later chunks do not collide).
- `CourseLanguage`: `tamil`, `telugu`, display name, script range. Proof: package tests.

## Wave 1: format, tools, profile (parallel, different files)
**A1 Catalog format (a delta: `level`, `tamilScript` and the duplicate rules already exist).**
`Packages/BLTKit/Sources/BLTCatalog/*`, `Tests/BLTCatalogTests/*`.
- Add the required `language`; rename `tamilScript` to `script` and check it against the lesson language's
  script; rename the gloss key to `word`; reject a lesson whose language is not the course's. The duplicate
  rules stay as built.
- Fixtures are fake `zz` text; a script fixture is one letter repeated.
- **Also updates the five shipped files in place** (adds `language`, renames the gloss key), in the same PR, so
  the shipped-content tests never go red. The files do not move yet.
**A2 Editor (a delta).** `tools/content-editor/index.html`, its README. The same three changes, with
language-aware labels and script check.
**A3 Drafting aid (a delta).** `scripts/content-index.sh` exists with `--check` and `--self-test`. Add a
per-language index and the `--mirror` report.
**A4 Profile.** `Packages/BLTKit/Sources/BLTProgress/Profile/*`, its tests.
- `UserProfile.learningLanguage` (optional), profile file schema 2, schema 1 files load with no language.
- Proof for all: `BLT_SIM="iPhone 17" scripts/test.sh package`; A2 by headless Chrome; A3 by its self-test.

## Test suite reshape (chunk Q1; runs beside Wave 1, must finish before Wave 4 adds UI tests)
**Why.** The UI suite takes about 50 minutes locally and 12 to 45 minutes on CI, and the preview runner hangs a
UI query at random, so every PR waits half an hour and is retried up to three times. Wave 4 would add more.

**Q1.** Files: `BLTApp/BLTAppUITests/*`, `.github/workflows/ci.yml`, `scripts/test.sh`, new DECISIONS 045,
`docs/ARCHITECTURE.md` (Testing section), `docs/HANDOFF.md` (commands).
1. **Measure first.** Record each UI test's duration and retry count from the result bundles of the last few
   CI runs. Put the table in the PR. Nothing is cut on a guess.
2. **Move logic down.** A UI test that only checks a rule (completion figures, what a reset clears, what a
   wrong answer does) is replaced by a view-model test in the package, where it runs in milliseconds. A UI
   test is kept only where the screen itself is the thing under test.
3. **Two tiers.**
   - *PR tier (required check):* one happy path per screen and the accessibility audits at the default text
     size. Target: the whole PR check under 15 minutes.
   - *Full tier:* everything, including the audits at the largest text size. Runs on every merge to `main`,
     nightly, and on demand. A failure there is reported, and is fixed before the next content or code PR.
4. **Build once.** Build for testing in one step and run tests without rebuilding; package tests and UI tests
   run as parallel jobs.
5. **Faster tests.** Animations and the shimmer off under the UI-test launch arguments; fixtures instead of
   real lessons everywhere.
6. **Flakes are visible.** Retries stay, but the summary step lists every test that needed one.
- Constraint: nothing about accessibility is dropped, only moved to the full tier. Branch protection names the
  required checks, so the owner updates it if job names change (the PR says exactly what to set).
- Proof: three PR runs in a row under 15 minutes; the full tier green on `main`; package test count has grown
  by at least the number of UI tests removed.

## Wave 2: content and storage (needs Wave 1; B1 and B2 merge as one PR)
Moving the lesson files and teaching the loader the new folders must land together, or the app would load no
lessons. The two chunks are built in parallel on different files and merged as a single PR.

**B1 Existing content and its tests.** Move the five files to `content/tamil/`, rename them and their ids to
`ta-l01-u01` to `ta-l01-u05`, and add `level`. Lesson text and review status do not change. `Tests/BLTContentTests/*`: per language, at least 5 Tamil files, 20 items each, levels
with no gaps, `script` required on every new-style lesson, no Tamil or Telugu script in any Swift file.
`.github/workflows/ci.yml` runs A3's check. The Xcode folder reference already bundles subfolders, so the
project file is not touched.
**B2 Content store.** `Packages/BLTKit/Sources/BLTContentStore/*`, its tests.
- Load and import per language directory; reject a lesson whose `language` is not the course's; import limit
  10 to 20. Reuses the existing manifest and all-or-nothing import.
- The one call site in `BLTApp/BLTApp/CompositionRoot.swift` passes `.tamil` explicitly until chunk D1 reads
  the language from the profile. That is the only app-target line this chunk may touch.

## Wave 3: screens (parallel; different folders; needs Wave 1)
**C1 Onboarding.** `BLTFeatures/Onboarding/*`: intro copy for the new thesis; after the name, a language step
with two clear choices; the gate shows that step when a profile has no language.
**C2 Home.** `BLTFeatures/Home/*`, `PreviewCatalog.swift`: lessons grouped by level, next-lesson suggestion,
"Other lessons" group, and which language is being learned. Reuses `CatalogProgress` and `ScenarioCard`.
**C3 Settings.** `BLTFeatures/Settings/*`: "Language I'm learning" switch; the content statement names the
right language; Reset wording says which language it clears. Reset keeps `BLTWarningButtonStyle` (037).
- Proof: package tests for the view models; UI tests come with Wave 4.

## Wave 4: wiring and UI tests (needs Waves 2 and 3)
**D1.** `BLTFeatures/{AppDependencies,RootView}.swift`, `BLTApp/BLTApp/{CompositionRoot,BLTAppMain,UITestLaunch}.swift`,
`BLTApp/BLTAppUITests/*`.
- Build dependencies for the chosen language; per-language paths; the one-time removal of the old build's files;
  switching language reuses the reload used after a lesson import (`CompositionRoot.reloaded`, root `.id`).
- New launch argument `--uitest-language=<tamil|telugu>`. UI tests: choose a language at onboarding, switch
  in Settings and see separate progress, reset one language only, old profile is asked for a language.
  Accessibility audits for the new and changed screens at default and largest text size.
- Proof: `scripts/test.sh app` per class, then the full check and a Release build with `check-binary.sh`.

## Content: one level at a time, both languages together (repeats 8 times)
1. **Prompts first.** For each lesson of the level, write the 20 English prompts once.
2. **Draft both.** Tamil and Telugu answers, wrong options, word glosses and `script`, all `unreviewed`.
   Level 1: Tamil needs 7 new lessons; Telugu needs all 12, the first five mirroring the existing Tamil ones.
3. **Check.** Validator, duplicate check, mirror report, shipped-content tests. One PR per language per level.
4. **Review.** Owner reviews Tamil, partner reviews Telugu, in the editor.
5. **Learn.** Corrections become rules in `docs/content/STYLE_NOTES_TAMIL.md` and `STYLE_NOTES_TELUGU.md`.
   The full `git diff content/` is shown before any commit of review edits.
6. **Gate.** A language's next level is drafted only after its reviewer says the current one is done. The two
   languages may move at different speeds.

## Exam (code any time after Wave 4; papers last)
As in the approved plan (engine, storage, screen), with one paper per language at
`content/<language>/exam/final.json`, each written after that language's Level 8 is reviewed. New-sentence
prompts are shared between the two papers where natural.

## Daily practice: two chapters a day, streaks, and reminders

**Approved by the owner on 2026-10-14, with the wireframe.** Built by Sonnet agents in worktrees (at most
three at a time), with `progress.md` updated after each wave. Decision record: DECISIONS 047 (written in S7).

### Context
The courses are long (2,000 phrases each) and the app has no reason to come back tomorrow. The owner wants a
daily target of two "chapters", a Duolingo-style streak that is graphic and animated, and two reminders before
the streak lapses (20 hours and 23 hours after the last session). Everything stays on the device: local
notifications only, no network, no account (hard constraint 1 holds; `UserNotifications` is not on the
forbidden list and needs no Info.plist usage string).

### Decided with the owner
- **Streak window: rolling 24 hours, with quiet hours.** The streak survives if the learner finishes a session
  within 24 hours of the previous one. Reminders fire 20 h and 23 h after the last session. A reminder that
  would land in quiet hours (default 10 pm to 8 am, changeable) moves to 30 minutes before quiet hours start
  on the evening before; if both land on the same time, only one is sent.
- **Chapter = one practice session** (up to 10 questions, about 5 minutes; due reviews count). Daily goal: 2.
- **One finished session keeps the streak.** The second meets the daily goal, shown as a separate mark.
- **Earned freezes.** One freeze per 7 streak days, hold at most 2, used automatically on a missed window and
  shown as a snowflake. With none left the streak resets calmly; the longest streak is kept and shown.

### Decisions I made (most likely to change first)
1. **What the number counts.** Calendar dates on which the learner practised, inside an unbroken chain (no gap
   over 24 hours, or a gap covered by a freeze). A learner practising every 23 hours gets one day per date.
2. **Per course.** Each language has its own streak, goal and log, like its progress (DECISIONS 043).
   Reminders follow the language being learned. Reset progress for a language clears its streak too.
3. **A session counts when it reaches its summary screen** with at least one answer. Ending a session early
   with answers also counts; opening and leaving does not.
4. **Stored as a log, computed on read.** A new `practice.json` per course lists finished sessions (time and
   number answered). Streak, freezes, goal days and the next reminder times are all computed from it, so
   there is one source of truth and the rules are easy to test. The frozen `ProgressStore` is unchanged.
5. **Permission is asked after the first finished session**, with a one-line reason shown first. If declined,
   the Settings toggle explains how to turn notifications on in iOS Settings. Nothing nags.
6. **Notification text never contains a phrase or the learner's name** (lock screens are public). It names
   the streak length and the language being learned.
7. **Colour.** The flame is amber, freezes blue, goal-met green. New tones go through the palette's existing
   no-red test; Reset progress stays the only red (DECISIONS 037).
8. **Motion.** SF Symbol flame with SwiftUI symbol effects and a keyframe burst at session end; bigger burst
   and a badge at 7, 30, 50 and 100 days; a success haptic. With Reduce Motion on, the number fades in and
   nothing bounces. UI-test launches already switch animations off (#33).

### Improvements suggested beyond the request
- Quiet hours (above): 20 h after a 7 am session is 3 am.
- Freezes and a calm reset (above): a broken streak is the main reason learners quit, and "never red" applies.
- Goal-met kept separate from the streak (above), so a short day still counts.
- **Later, not in this plan:** a "send my streak to my partner" share card (iOS share sheet, no network in the
  app), and a home-screen widget with the flame. Both fit the couple idea; ask when wanted.

### Wireframe (approved together with this plan)
Four screens: Home top (flame chip with count, "Today: 1 of 2 chapters" card with the next chapter, this
week's strip of flames, freezes and goal marks, then the existing lessons by level); end of session (flame
burst, new count, "Daily goal met", the week strip filling in, next freeze); streak screen (count, deadline
"practise by 7:40 pm tomorrow", longest, freezes, goal days, a month calendar); reminders (the two
notifications, and a Settings "Daily practice" section: reminders on or off, quiet hours, daily goal 2).

### Chunks
**Wave 1 (parallel, different files)**
- **S1 Practice log and streak rules.** `Packages/BLTKit/Sources/BLTProgress/Practice/*` (new: session record,
  log file and in-memory stores, `StreakCalculator`, streak and daily-goal summaries) and tests.
  Constraints: pure functions over the log, injected clock and time zone, `.completeFileProtection`, atomic
  writes, damaged file reported not overwritten (same pattern as `FileProgressStore`).
  Proof: package tests covering 23-hour cadence, a 25-hour gap with and without a freeze, freeze earning and
  the cap of 2, time-zone travel, daylight-saving change, midnight crossings, reset.
- **S2 Reminder planning.** Pure `ReminderPlanner` (fire times from last session and quiet hours) in
  `BLTProgress/Practice/`, a `ReminderScheduling` protocol, a fake, and the concrete local-notification
  scheduler in the app target (`BLTApp/BLTApp/LocalReminderScheduler.swift`), which is the only file that
  imports `UserNotifications`. Two fixed notification ids, replaced on every reschedule.
  Proof: package tests for every quiet-hours case; `bash scripts/check-forbidden-apis.sh` clean.
- **S3 Streak visuals.** `Packages/BLTKit/Sources/BLTDesign/*`: flame badge, week strip, month calendar,
  celebration burst, new palette tones, VoiceOver labels ("13 day streak, 1 freeze left"), Reduce Motion.
  Also adds every new accessibility id for Waves 2 and 3 up front. Proof: package tests incl. palette tests.

**Wave 2 (parallel; needs Wave 1)**
- **S4 Home.** `BLTFeatures/Home/*`: flame chip, Today card (chapter 1 and 2), week strip. Reuses
  `ContinueLessonCard` patterns and `SessionPlanner` for what chapter 2 contains.
- **S5 Session end and streak screen.** `BLTFeatures/Session/SessionSummaryView.swift` and new
  `BLTFeatures/Streak/*`.
- **S6 Settings.** `BLTFeatures/Settings/*`: Daily practice section, quiet hours, permission pre-prompt.
- Proof: view-model tests in the package for each.

**Wave 3 (needs Wave 2)**
- **S7 Wiring, UI tests and docs.** `CourseServices`, `AppDependencies` (frozen contract: DECISIONS 047),
  `RootView`, `CompositionRoot`, `UITestLaunch` (a launch argument to seed a practice log), Reset clears the
  log, reschedule on session end, launch and return to foreground. UI tests: PR tier (streak shows and
  grows after a session), full tier (settings, reset, audits at the largest text size). Docs: DECISIONS 047,
  `docs/ARCHITECTURE.md`, `docs/HANDOFF.md`, `README.md`.

### Verification
1. `BLT_SIM="iPhone 17" scripts/test.sh package`
2. `BLT_SIM="iPhone 17" scripts/test.sh app --tier pr`, then the full tier per class
3. `swiftlint lint --config .swiftlint.yml --strict`, `bash scripts/check-forbidden-apis.sh`, Release build and
   `scripts/check-binary.sh`
4. Simulator: finish a session, see the burst and the count; check pending notifications at +20 h and +23 h
   (and the quiet-hours shift) through a debug-only listing; Reduce Motion on and off.
5. Owner's iPhone: allow notifications, finish a session in the morning and confirm the reminders arrive the
   evening before quiet hours; VoiceOver on the streak screen.
6. CI green on each PR.

## Deferred to v2 (planned, not dropped)
This plan is v1.x: text-only multiple choice for two languages. Voice stays in v2, as already decided (024).
The `script` field on every new phrase exists so v2 does not need a second review of 4,000 phrases.
- **Audio:** each phrase spoken aloud. Clips are generated or recorded on the Mac from `script`, approved in
  the editor by that language's reviewer, and bundled. No model or network in the app.
- **Pronunciation scoring:** the learner speaks and gets feedback. Needs the experiment discussed earlier
  (which on-device model can tell good from bad for colloquial Tamil and Telugu) before any build, and an
  owner decision on whether a score may affect progress (today it may not: hard constraint 5).
- **Native script in the app:** showing the Tamil or Telugu spelling beside the romanised answer.
`docs/PRD.md` and `docs/BUILD_PLAN.md` are updated in Wave 0 so the v2 sections cover both languages.

## Not planned
- A third language, or learning both languages at once on one Home screen.

## Verification
1. `BLT_SIM="iPhone 17" scripts/test.sh package`
2. `BLT_SIM="iPhone 17" scripts/test.sh app` (per class), then a Release build and `scripts/check-binary.sh`
3. `swiftlint lint --config .swiftlint.yml --strict`, `bash scripts/check-forbidden-apis.sh`,
   `bash scripts/content-index.sh --check`
4. Simulator: fresh install picks Telugu and sees Telugu lessons; switch to Tamil and back with progress intact;
   reset clears one language; an upgraded install starts clean, keeps its name, and is asked for a language.
5. Owner's iPhone: upgrade over the current install (name kept, old files gone); import a Telugu lesson file into
   the Telugu course and confirm a Tamil file is refused there.
6. CI green on each PR.
