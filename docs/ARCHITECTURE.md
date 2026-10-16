# BLT.ai architecture (v1, as built)

blt.ai is a text-only, multiple-choice SwiftUI app. Today it teaches colloquial Tamil to Telugu speakers; it is a two-way course, Tamil and Telugu, for a couple learning each other's language (see "Two courses" below; Levels 1 and 2 are drafted for both courses, and only the first five Tamil lessons are native-reviewed). Everything runs on the device: there is no backend, no account, and no network code. Unless a section says "planned", this page describes what exists today. The voice product in [`PRD.md`](PRD.md) and [`BUILD_PLAN.md`](BUILD_PLAN.md) is the v2 plan, not the current code.

## Module map

The logic lives in a local Swift package, `Packages/BLTKit`. The app target is a thin shell that wires it together.

```mermaid
graph TD
    App[BLTApp: app shell and composition root] --> Features
    Features[BLTFeatures: screens and view models] --> Session
    Features --> Design[BLTDesign: theme and components]
    Features --> ContentStore
    Features --> Progress
    Session[BLTSession: question builder, planner, state machine] --> Catalog
    Session --> Progress[BLTProgress: scheduler, progress and profile stores]
    ContentStore[BLTContentStore: bundled and imported lesson loading] --> Catalog
    Catalog[BLTCatalog: content loader and validator] --> Core
    Progress --> Core[BLTCore: identifiers, register, outcome]
    Design --> Core
    ContentStore --> Core
```

| Module | Responsibility | Depends on |
|---|---|---|
| `BLTCore` | Small shared value types: item and scenario ids, register, addressee, outcome, review status | none |
| `BLTCatalog` | Reads lesson JSON, validates it (schema, option rules, size limits) and builds the `Catalog`. Never throws: every problem becomes a `ContentIssue` and valid items survive | Core |
| `BLTProgress` | SM-2 scheduling, the progress file and the profile (name and language) file, exam results, the practice log, streak rules and reminder planning, the cheat sheet unlock record, with typed errors, and the one-time clean-up of the old build's files | Core |
| `BLTSession` | Picks what to ask (due items first, then new ones, shuffled), builds the four options, runs the question state machine, and builds a topic's cheat sheet | Core, Catalog, Progress |
| `BLTDesign` | Palette, theme, buttons, shimmer, completion bar, and the streak visuals (flame, week strip, month calendar, celebration). The only module that knows colours | Core |
| `BLTContentStore` | Finds the bundled lesson files, layers the learner's imported lessons over them, and validates and stores imports | Core, Catalog |
| `BLTFeatures` | The screens (intro, onboarding, Home, session, Progress, Settings) and their view models | all of the above |
| `BLTApp` | Entry point and the composition root: the one place that chooses concrete types | BLTFeatures |

`BLTFeatures` keeps its screens and view models `internal`. The app target uses only `RootView`, `AppDependencies`, `CourseServices`, `LessonImporting`, `LessonChange` and the DEBUG-only `PreviewCatalog` fixtures; its own tests reach the rest with `@testable import`. The lower modules stay public because other modules use them.

## How a practice session works

1. **Content** is JSON in [`content/`](../content/), bundled into the app. `BLTContentStore` adds any imported files on top; `BLTCatalog` validates everything and produces the `Catalog`.
2. **Planning** (`SessionPlanner`): items that are due come first, then new items, up to ten, shuffled so answers cannot be learned by position.
3. **Questions** (`QuestionBuilder`): the correct answer, the other-register version (for casual and respectful items) and wrong options, shuffled. Each answer becomes an `Outcome`: correct, right sentence in the wrong register, or wrong.
4. **Scheduling** (`SM2Scheduler`): the outcome updates the item's review state. A wrong answer is due again at once; an item counts as complete only while its latest answer is correct.
5. **Persistence** (`FileProgressStore`): one small JSON file per store, written atomically with complete file protection. A corrupt file is reported and never overwritten.

## Data on the device

| File (Application Support/BLT) | Holds |
|---|---|
| `profile.json` | The learner's display name and the language being learned (shared by both courses) |
| `courses/<language>/progress.json` | That language's review states and answer history |
| `courses/<language>/content/` | That language's imported lesson files and their manifest (only after an import) |
| `courses/<language>/exam.json` | That language's final-exam attempts (score only) |
| `courses/<language>/practice.json` | That language's log of finished practice sessions (time and number answered). The streak, freezes and goal days are computed from it, never stored |
| `courses/<language>/cheatsheets.json` | That language's cheat sheet unlocks: the ids of topics that were ever complete, so a sheet stays open after a later slip |
| `practice-preferences.json` | Device-wide daily-practice settings: reminders on or off, quiet hours, whether the notification prompt was already shown |

`<language>` is `tamil` or `telugu`. The bundled lessons are `content/<language>/` inside the app. The display name is the only personal data and it never leaves the device ([`DECISIONS.md`](DECISIONS.md) 030).

The single-course build kept `progress.json` and `content/` directly in `BLT/`. Nothing is migrated (no learner had progress, and the lesson ids changed); `LegacyStorageSweep` (in `BLTProgress`) removes those two paths once at the first launch of the new build. It touches only those two names, never follows a symbolic link, leaves `profile.json` and `courses/` alone, and is skipped for UI-test launches.

## Lesson import

Settings can import lesson files from the Files app ([`DECISIONS.md`](DECISIONS.md) 036). The batch is validated as a whole, all or nothing, against the catalog the learner would end up with. Accepted files are stored under a hash of the scenario id, never the user's file name. A manifest, written last, says which are active, and an import is ignored if a newer build ships different bundled lessons for that scenario.

## Composition and dependency injection

The learner's language is only known after the profile has loaded, so the root is not built on one fixed set of dependencies. `RootView(profileStore:makeCourse:onLessonsChanged:)` takes a closure that `CompositionRoot` answers per language with `CourseServices`: the `AppDependencies` for that language (its catalog, `language`, progress store, scheduler and clock) and the importer that stores lessons for that language only. `RootView` builds Home only once the profile has a language, and gives Home that language as its identity, so switching language in Settings rebuilds Home and every view model under it on the other course. There are no singletons.

`AppDependencies.language` is a required parameter: nothing builds a course for a language it was not told, and a profile with no language is asked for one rather than given Tamil. After a lesson import or removal the app creates a new root, which asks `makeCourse` again for the current language, so the catalog is loaded afresh while the stores are the ones already open and progress is untouched.

## What keeps the rules true

| Rule | Enforced by |
|---|---|
| No network, audio or speech APIs, no new Info.plist permissions | `scripts/check-forbidden-apis.sh` (source and project files) and `scripts/check-binary.sh` (the built app) |
| Warnings are errors, strict concurrency | `Package.swift` settings, `scripts/test.sh`, SwiftLint strict |
| No machine name or real email in commit history | `scripts/check-identity.sh` in CI and as a pre-push hook |
| Lesson text (Tamil and Telugu) only in `content/`; test fixtures are obviously fake | content conformance tests and review |
| Imported and bundled lessons are untrusted input | the same validator for both |

## Testing

- **Package tests** (Swift Testing): fast and deterministic, with in-memory stores and fake `zz` fixtures. This is where almost all behaviour is checked.
- **Rules live in the package.** What a wrong answer does, what Home's completion figure counts, what Reset clears and keeps, what survives a relaunch: view-model and store tests (for example `SessionCompletionFlowTests` and `ProgressSurvivesAndResetsFlowTests`), which run in milliseconds. A UI test checks a rule only when the screen or the real app process is the thing under test (DECISIONS 045).
- **UI tests** (XCUITest) come in two tiers, chosen by test class (`scripts/test.sh tiers` prints them):
  - *PR tier:* `AccessibilityUITests` (an accessibility audit of each screen at the default text size) and `HappyPathUITests` (one happy path per screen). This is what a pull request runs.
  - *Full tier:* every class, which adds the audits and reachability checks at the largest text size (`AccessibilityLargeTextUITests`) and the detailed screen tests (onboarding, Home card, End session, feedback screens, persistence, settings). It runs on every push to `main`, nightly and on demand.
  - A new screen gets one happy-path test and one default-size audit in the PR tier, and its largest-size audit in the full tier. The shared audit code and its few documented exceptions are in `AccessibilityAuditCase`.
- **Content conformance tests** read the real `content/` folder and fail if any shipped item is invalid.
- **CI** (GitHub Actions on the `xcode-27` preview image) runs the guardrails and lint, the package tests, and the UI tests as separate parallel jobs; the app is built once (`build-for-testing`) and the tests run without rebuilding. A small gate job named `Package and app tests` reports both test jobs as one required check. Changes reach `main` through pull requests with `Guardrails and lint` and `Package and app tests` required. UI tests retry up to three times, and the job summary lists every test that needed a retry. Measurements behind the tiers: [`TEST_TIMINGS.md`](TEST_TIMINGS.md).

## Two courses

[`DECISIONS.md`](DECISIONS.md) 042 to 044 and `plan.md` describe the change. The engine does not look at the language, so the module map did not change.

| Area | How it works |
|---|---|
| Language | `CourseLanguage` (`tamil`, `telugu`) in `BLTCore`; chosen at onboarding (after the name), stored on the profile, switchable in Settings. A profile without one is asked, never assumed |
| Lessons | `content/tamil/` and `content/telugu/` (100 lessons each planned, in 8 levels); each file names its `language` and `level`; a lesson in the other course is rejected, bundled or imported |
| Lesson format | Required `language`; gloss key `word`; `script` checked against the language's own script |
| Data on the device | `courses/<language>/` holds progress and imports; `profile.json` is shared (see above) |
| Composition | Dependencies built per language on request (see above); switching language rebuilds Home |
| Home | Grouped by level, with a Continue suggestion and the language being learned |
| Reset progress | Clears only the language being learned; the confirmation names it |
| Import | Into the current language only; a file for the other language is refused with a plain message |
| Exam | One 100-question paper per language (041, 046). The engine, the screen, score-only result storage (`courses/<language>/exam.json`) and the paper loader are built; Home shows the exam card only when a paper loads, and no paper is written yet |

## Daily practice

[`DECISIONS.md`](DECISIONS.md) 047 and `plan.md` ("Daily practice") describe it. A chapter is one practice session; the daily goal is two chapters. Everything stays on the device.

| Piece | Where | How it works |
|---|---|---|
| Log and streak rules | `BLTProgress/Practice/` | `PracticeLogStore` (file and in-memory) holds finished sessions. `StreakCalculator` is a pure function of the log, the time and a calendar: rolling 24-hour window, one freeze earned per 7 streak days (at most 2), goal days, the "practise by" deadline and the day sets for the calendar views |
| Reminders | `BLTProgress/Practice/` and `BLTApp/BLTApp/LocalReminderScheduler.swift` | `ReminderPlanner` (pure) turns the last session, quiet hours and the streak into at most two reminders, 20 and 23 hours after the last session, moved out of quiet hours. `LocalReminderScheduler` is the only file that imports `UserNotifications`; the text names the streak length and the language, never a phrase or the learner's name |
| Settings and permission | `BLTProgress/Practice/PracticePreferences*`, `BLTFeatures/Settings/` | One device-wide preferences file; a pre-prompt after the first finished session, shown once |
| Screens | `BLTDesign` (flame, week strip, month calendar, celebration), `BLTFeatures/{Home,Session,Streak,Settings}` | Home shows the chip, the Today card and the week; the session summary shows the streak; the streak screen has the calendar |
| Wiring | `PracticeServices`, `ReminderRescheduler`, `HomeFlow` in `BLTFeatures`; `CompositionRoot` | Per-course log on `AppDependencies.practiceLog`; device-wide pieces in `PracticeServices`. Reminders are rescheduled when a session is recorded, a setting changes, Reset runs, at launch and on return to the foreground |

Reset progress for a language also clears that language's practice log and cancels its reminders. The preferences file is not progress, so Reset keeps it.

## Cheat sheets

[`DECISIONS.md`](DECISIONS.md) 048 and `plan.md` ("Cheat sheets") describe it. A finished topic gets a word list: its distinct words in teaching order, each with its English meaning and first example phrase. It is a word list, not a verb and adverb list, because the lesson data has no part-of-speech labels.

| Piece | Where | How it works |
|---|---|---|
| Sheet builder | `BLTSession/CheatSheet/` (`CheatSheet`, `CheatSheetEntry`, `CheatSheetBuilder`) | A pure function of a `Scenario`: distinct words (case-insensitive) in teaching order, meanings joined with "; ", the first phrase that uses the word, and an unreviewed flag if any phrase using it is unreviewed |
| Unlock record | `BLTProgress/CheatSheet/` (`CheatSheetUnlockStore`, `FileCheatSheetUnlockStore`, `InMemoryCheatSheetUnlockStore`, `CheatSheetUnlockError`) | The ids of topics ever complete, in `courses/<language>/cheatsheets.json`. Written atomically with complete file protection; a damaged file is reported and never overwritten; `add` is idempotent |
| Labels and ids | `BLTDesign` (`CheatSheetLabels`, the `cheatSheet*` ids in `AccessibilityID`) | Every visible string and VoiceOver label is a pure function, unit-tested |
| Screens | `BLTFeatures/CheatSheet/` (`CheatSheetView`, `CheatSheetListView`, their view models, `CheatSheetCopy`) and `BLTFeatures/Home/` (the card button, `HomeCheatSheetsEntry`) | Plain, non-lazy lists so the accessibility audit sees every row; the list opens a sheet in its own full-screen cover |
| Wiring | `AppDependencies.cheatSheetUnlocks`, `HomeFlow`, `CompositionRoot` | `HomeViewModel.load()` records every topic that is complete now and sets `unlockedCheatSheetIDs` to the stored plus the complete ones. `HomeFlow` presents the sheet (card button) and the list (Home row) as full-screen covers closed by Close |

Reset progress for a language also erases that language's cheat sheet record. The sheet is computed from the lesson data each time it opens, so nothing about its words is stored.

## Where v2 (voice) plugs in

`Outcome` and the session state machine are deliberately independent of how an answer is produced, so spoken answers can feed the same scheduler. The audio and scoring modules described in the PRD do not exist yet and would be new modules beside these. Their constraints (on-device speech only, audio deleted after each attempt) are written down in `CLAUDE.md` and [`SECURITY.md`](SECURITY.md) so they apply from the first line.

## Decisions

The reasoning behind each choice is in [`DECISIONS.md`](DECISIONS.md), including the ones that were reversed. Decisions 024 to 037 define v1; 038 to 046 define the two-course plan; 047 defines daily practice; 048 defines cheat sheets.
