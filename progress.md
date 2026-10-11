# Progress: two-way course plan (plan.md)

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
