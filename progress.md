# Progress: two-way course plan (plan.md)

## Daily practice (plan.md "Daily practice")
**Wave 1 built, not pushed (branch `wave1`, from `plan/daily-practice`; PR #39 for the plan is still open).**
- S1 practice log and streak rules: `BLTProgress/Practice/` (`PracticeSession`, `PracticeLog`, file and in-memory stores, `StreakCalculator`, `StreakSummary`), 43 tests.
- S2 reminder planning: `QuietHours`, `ReminderPlanner`, `ReminderScheduling`, `FakeReminderScheduler` in `BLTProgress/Practice/` and `BLTApp/BLTApp/LocalReminderScheduler.swift` (the only `UserNotifications` import), 19 tests.
- S3 streak visuals: `BLTDesign` flame badge, week strip, month calendar, celebration, palette tones (amber, blue, green), labels, and every accessibility id Waves 2 and 3 need.
- Merged and checked together: package tests pass, SwiftLint strict clean, forbidden-API scan clean, app target builds. One concurrency warning in `StreakCelebrationView` (found in the merged build) is fixed.
- Decisions made by the agents: a gap over 24 h misses `ceil(gap/24h) - 1` windows, one freeze each; a freeze is earned at each multiple of 7 chain dates, cap 2, kept across a reset; fall-back night (25 h) breaks a rolling-24 h streak unless a freeze is held; the planner takes a `ReminderContext` (SwiftLint's 5-parameter cap); reminder text is title "N day streak" plus a language-only body.
- Not verified: how any streak view looks or animates (previews only), real notification delivery, `.completeFileProtection` (device only).
**Wave 2 built, not pushed (branch `wave2`, on top of `wave1`).**
- S4 Home: flame chip, Today card (chapter rows, goal-met mark), week strip, freezes line, calm note when the log cannot be read; `HomeViewModel(dependencies:practiceLog:calendar:streakCalculator:)`, `ScenariosView(onOpenStreak:)`, `loadPractice()`; Reset also erases the practice log.
- S5 session end and streak screen: `SessionViewModel(... practiceLog:calendar:onSessionRecorded:)` records a chapter once (summary reached, or early end with at least one answer); summary shows the burst, count, "Daily goal met", week strip and days to the next freeze; new `StreakView(viewModel:onDone:)` with `StreakViewModel(practiceLog:calendar:now:locale:dailyGoal:)`, month paging, deadline text.
- S6 Settings: Daily practice section (reminders toggle, quiet hours, read-only daily goal 2), `PracticePreferences` store (device-wide file), notification pre-prompt (`NotificationsPromptView`, `NotificationsPromptRule.shouldAsk`), Reset also erases the practice log ("Your streak is cleared too.").
- Merged and checked together: package tests pass, SwiftLint strict clean (300 files), forbidden-API scan clean, no compiler warnings, no shared or frozen file touched, `UserNotifications` imported only in `LocalReminderScheduler.swift`.
- For S7: pass the real per-course `PracticeLogStore` to Home, Session and Streak view models, and the device-wide preferences store to Settings; supply `openSystemSettings` (`UIApplication.open(UIApplication.openSettingsURLString)`), because `openURL` is on the forbidden list; call `HomeViewModel.loadPractice()` when Home returns after a session; present the pre-prompt from session end (`shouldAsk` is true only for the first finished session across both courses); `onSessionRecorded` and `onPracticeSettingsChanged` are where reminders get rescheduled; the Continue card is kept under the Today card because `HomeUITests` needs `homeContinueLesson` (decide in S7); the daily goal is fixed at 2 and not yet passed into `SessionViewModel`.
- Not verified: how any new screen looks (previews only), VoiceOver order, largest text size layout, Reduce Motion, the system permission dialog, the flame haptic.
**Wave 3 built, not pushed (branch `wave3-s7`, on top of `wave2`).**
- S7 wiring: `AppDependencies.practiceLog` (per course), new `PracticeServices` (preferences store, reminder scheduler, both courses' logs, open-settings), `ReminderRescheduler`, `HomeFlow` (streak cover, pre-prompt, reschedule on session recorded, setting change, Reset, launch and foreground), `CompositionRoot` (`courses/<language>/practice.json`, `practice-preferences.json`, the real scheduler), UI-test launch arguments `--uitest-practice=<n>`, `--uitest-practice-<language>=<n>`, `--uitest-notifications=<state>` with a fake scheduler; DECISIONS 047; one shared streak calculator for Home, Session and the streak screen.
- UI tests written and now run (2026-10-14): PR tier `HappyPathUITests` (3 new) passed; `DailyPracticeUITests` (9) and `AccessibilityPracticeUITests` (4) pass; the new large-text audits and reachability checks pass. Found and fixed: Home's plain audit reported 8 Dynamic Type findings because the lazy lesson list did not build rows that scroll away at large text (now a plain `VStack`); the capped month grid failed the streak-screen audit (at accessibility sizes it is now a list of marked days, nothing is capped); the Reminders switch test tapped the label (now taps the switch). Known and not ours: on the iPhone 17 simulator both name-entry audits fail ("keyboard did not dismiss"), also on code without this feature; they pass on iPhone 17e. One timeout of the change-name audit under load passed on rerun. NOT run: the rest of the full tier (the existing classes), and the full PR tier once more after the fixes.
- Checked: package tests, SwiftLint strict, forbidden-API scan, Debug and Release builds with warnings as errors, `scripts/check-binary.sh`.
- Docs updated by the orchestrator: ARCHITECTURE "Daily practice", HANDOFF item 0, README.
- Next: run the whole full tier once on a quiet machine, owner looks at the screens, then push and open PRs.

## Next (2026-10-14)
- Daily practice feature: all three waves built locally; see above for what is owed.

## Done (2026-10-12)
- Level 2 content for both courses drafted (12 lessons, 240 phrases each, `unreviewed`), ahead of the Level 1 review at the owner's request.
- Tamil-script backfill for lessons 1 to 5 opened as PR #35 for the owner to read.
- Exam paper format, loader and blueprint checks (DECISIONS 046), wired into the app; no paper exists yet.
- Exam screen E3 (PR #32): Home entry, sitting, result, Reset clears exam results. Invisible until a paper exists (E4).
- Level 1 content for both courses (PRs #29, #30): Tamil lessons 6 to 12 and all 12 Telugu lessons, 480 phrases, all `unreviewed`; `docs/content/STYLE_NOTES_TAMIL.md` and `STYLE_NOTES_TELUGU.md`.
- CI: serial simulator (#27) and a PR path filter that skips the UI job for content-only changes (#28).

## Done (2026-10-11)
- Single-course plan, syllabus, DECISIONS 038 to 041 and the first 100 reviewed Tamil phrases (PRs #8, #9, #11 to #13).
- Two-way thesis and documents (PR #15): DECISIONS 042 to 044, `docs/REVIEWER_GUIDE.md`, the new `plan.md`.
- Wave 1 (PRs #16 to #21): `CourseLanguage` and accessibility ids; the two-language lesson format (`language`, `script`, `word`) with neutral names; the editor; `content-index.sh` per language and `--mirror`; optional profile language (schema 2); two-tier UI tests and parallel CI.
- Wave 2 (PR #22): Tamil lessons moved to `content/tamil/` with `ta-l01-uNN` ids and `level`; per-language loading and import; import limit 20.
- Exam engine and exam result storage (PRs #23, #24), unwired.
- Waves 3 and 4 (PR #25): language step, Home grouped by level, Settings language switch, per-language wiring and storage, legacy file removal, wrong-language import message, UI tests for the new flow.

## Decisions
- Owner reviews Tamil; partner reviews Telugu on their own computer; reviewed files return by AirDrop and are committed through a PR; phones get lessons through Settings > Import lessons.
- Both courses 2,000 phrases in 8 levels, one level at a time; standard Coastal Andhra Telugu; one syllabus and shared English prompts where natural; language switchable with separate progress; Reset clears only the current language.
- Waves 3 and 4 landed as one PR so the existing UI tests never saw the language step without its wiring.
- Audio, pronunciation scoring and native script in the app are v2.

## Deviations
- The editor's duplicate rule inside one item compares only case and surrounding spaces (punctuation-only variants are wanted); prompts and answers across a course also ignore spacing and punctuation.
- A1 left two compatibility shims that a follow-up commit removed (`Token.tamil`, `Scenario`'s Tamil default); `tamilScriptInField` became `nativeScriptInField`.
- Q1's per-test time limit is opt-in (`BLT_TEST_TIMEOUT`), because xcodebuild does not retry a test that hits it.
- The PR tier grew from 13 to 16 UI tests (two language-step audits, one Settings audit).
- D1 found and fixed a bug in the Settings switch (the iOS 27 popover cleared its own binding), and added a narrow contrast exception for the disabled language Continue button.
- PR #14 (an earlier handoff) was closed as superseded.

## Not proven yet
- ADR 045's goal: after the fix the UI job took 18.6 then 13.9 minutes; two more app-code PR timings and a green full tier on `main` are owed.
- None of the Level 1 Telugu, nor Tamil lessons 6 to 12, has been checked by a native speaker.
- The new screens have been tested and walked once in the simulator, not reviewed by eye. Device-only checks (file protection, AirDrop import, VoiceOver, largest text) are open.

## Next action
- Owner reviews Tamil Levels 1 and 2 (Level 1 lessons 6 to 12, all of Level 2) and the Telugu reviewer checks Telugu Levels 1 and 2, in the editor; corrections go into the style notes; then Level 3. The exam screen (E3) is built; the exam papers wait for Level 8 (format and loader are built). See `docs/HANDOFF.md`.
