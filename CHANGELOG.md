# Changelog

What changed in each version of blt.ai, newest first. These are project versions, not App Store versions (the app is not published; its Xcode version stays 1.0).

**How versions work.** `MINOR` goes up for a feature a learner can see or a change to how the app is built (v0.4.0 is daily practice, v0.5.0 is cheat sheets). `PATCH` goes up for a fix, a content or documentation change, or a tooling change. Every pull request that changes behaviour, a screen, storage, or the docs adds a line here under the version it ships in, and updates the README (features and screenshots) when a screen or a capability changed. The standing rule is in [`CLAUDE.md`](CLAUDE.md). Git tags (`v0.4.0` and so on) mark the merge commit of each version.

## v0.5.1 (2026-10-17): Cheat sheet screenshots

- README screenshots of the cheat sheet and the Cheat sheets list, taken from a current build on iPhone 17e (they were linked in v0.5.0 but not yet added).

## v0.5.0 (2026-10-16): Cheat sheets (PR #47, DECISIONS 048)

**New for the learner**
- **Cheat sheet button.** A topic's card gets a "Cheat sheet" button once the topic is complete. The sheet lists the topic's words in teaching order, each with its English meaning and the first phrase that uses it. Words from unreviewed phrases carry the "Unreviewed draft" label.
- **It is a word list, not a verb and adverb list.** The lesson data records only a word and its meaning, with no part-of-speech label, so the app cannot say which words are verbs or adverbs. A real verb and adverb sheet is a later content task (see DECISIONS 048).
- **It stays open.** A topic that slips below 100% later keeps its sheet.
- **Cheat sheets list.** A "Cheat sheets" row on Home lists every topic of the language you are learning: finished topics open, the others say "Finish this topic to see its cheat sheet".
- **Per language.** Each course has its own unlocks, and Reset progress clears the ones of the language you are on.

**Under the hood**
- New `courses/<language>/cheatsheets.json` (the ids of topics ever completed), written like the practice log; `AppDependencies.cheatSheetUnlocks` (per course, defaults to in-memory).
- Reset progress in Settings erases the unlock record (`SettingsViewModel`).
- `CheatSheetBuilder` is a pure function of a topic; `CheatSheetUnlockStore` has file and in-memory versions; new screens in `BLTFeatures/CheatSheet/`.
- UI tests: a PR-tier happy path, `CheatSheetUITests` and `AccessibilityCheatSheetUITests` (default and largest text size) in the full tier, and a `--uitest-cheatsheets=<ids>` launch argument. No network, no new dependency.
- README screenshots of the sheet and the list are added by the owner from a current build.

## v0.4.2 (2026-10-15): Quiet-hours pickers are labelled

- Settings, Daily practice: the two quiet-hours pickers now show "Quiet hours start" and "Quiet hours end" above their times. Before, they showed only "10 PM" and "8 AM", so it was unclear which was which (VoiceOver already read the names).
- README screenshot of the Daily practice settings retaken.

## v0.4.1 (2026-10-15): README shows daily practice

- README: new screenshots of the streak, the Today card, the streak screen, the Daily practice settings and the reminder prompt (Tamil and Telugu Home each with their own streak); the module, storage and roadmap text now cover daily practice.
- This changelog, and the rule that every change updates it.

## v0.4.0 (2026-10-15): Daily practice (PRs #39 to #43, DECISIONS 047)

**New for the learner**
- **Streak.** Practise within a rolling 24 hours to keep it going. One freeze is earned per 7 streak days (hold up to 2) and is used automatically on a missed window. A broken streak resets calmly and the longest streak is kept. Each language has its own.
- **Chapters and a daily goal.** One practice session is a chapter; two make a day. Home shows a flame chip, a "Today: 1 of 2 chapters" card and this week's strip with goal marks and freezes.
- **Session end.** The flame and the new count, "Daily goal met" in green, the week filling in, and the days to the next freeze. Bigger celebration at 7, 30, 50 and 100 days.
- **Streak screen.** The count, a plain-words "practise by" deadline, longest streak, freezes, goal days and a month calendar. At accessibility text sizes the calendar becomes a list of marked days.
- **Reminders.** At most two local notifications, 20 and 23 hours after your last session, moved out of quiet hours (default 10 pm to 8 am). The text never contains a phrase or your name. Asked once, after your first finished session; Settings has the switch, quiet hours and the daily goal (2 chapters, read-only for now).
- **Reset progress** also clears that language's streak and cancels its reminders.

**Under the hood**
- New practice log (`courses/<language>/practice.json`) and device-wide practice settings; the streak is computed from the log, never stored.
- `StreakCalculator` and `ReminderPlanner` are pure and heavily tested (23-hour cadence, 25-hour gaps with and without a freeze, daylight saving, time zones, quiet-hours cases).
- `LocalReminderScheduler.swift` is the only file that imports `UserNotifications`. No network, no new dependency.
- UI tests for the streak, the session end, the Settings section and the prompt, plus accessibility audits at the default and the largest text size. Home's lesson list is built eagerly so the Dynamic Type audit can see every row.

**Known**
- Not yet seen on a real iPhone: notification delivery at +20 h and +23 h, the system permission dialog, file protection on `practice.json`.
- On a fall-back night (25 hours between "the same time tomorrow") a streak breaks unless a freeze is held.
- On the iPhone 17 simulator the two name-entry accessibility audits fail ("keyboard did not dismiss"); they pass on iPhone 17e and fail the same way on older code.
- The two quiet-hours pickers in Settings show only their times; the "start" and "end" words are in the VoiceOver label but not on screen. (Fixed in v0.4.2.)

## v0.3.0 (2026-10-11 to 2026-10-12): Exam, Levels 1 and 2 for both courses (PRs #23 to #38)

- **Content.** Tamil Level 1 completed and Level 2 drafted; Telugu Levels 1 and 2 drafted (24 lessons, 480 phrases each, all unreviewed except the first five Tamil lessons). Tamil-script spelling added for lessons 1 to 5.
- **Final exam.** The engine, score-only result storage, the Home entry and sitting screens, and the exam paper file format and loader (DECISIONS 041, 046). No paper is written yet, so the exam does not appear.
- **Tests and CI.** UI tests run with animations off; the UI job is skipped on pull requests that change no app code; UI tests run on one simulator (DECISIONS 045).
- **Docs.** README with new screenshots, reviewer guide, style notes for both languages.

## v0.2.0 (2026-10-10 to 2026-10-11): Two courses, Tamil and Telugu (PRs #15 to #26, DECISIONS 042 to 044)

- **One app for a couple.** After the name, choose Tamil or Telugu; switch any time in Settings with each language's progress kept. Reset clears only the language you are on.
- **Home grouped by level**, with a Continue suggestion; levels are ordered but not locked.
- **One lesson format for both languages** (`language`, `word`, `script`), a content editor and a drafting aid that check duplicates, and per-language storage and import.

## v0.1.0 (2026-10-07 to 2026-10-10): Tamil course for a Telugu speaker (PRs #1 to #13)

- The first app: text-only multiple choice for colloquial Tamil, five lessons and 100 phrases, all reviewed by a native speaker.
- Feedback with a word-by-word gloss and a register note, three outcomes (correct, right sentence wrong register, wrong), SM-2 spaced repetition, shuffled sessions, never red.
- Lessons can be imported from the Files app. No account, no network, no analytics, enforced by scripts.
- The course plan (8 levels, 100 lessons, a final exam), CI on GitHub's `xcode-27` runner, and the module architecture.
