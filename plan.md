# Full course: 1,900 more phrases in 8 graded levels, plus a 100-question final exam

On approval this file is copied to `plan.md` in the repo root, and progress is tracked in `progress.md`.

## Context
The app ships 5 lesson files of 20 phrases (100 total). The owner wants a multi-month course that takes a
Telugu speaker to holding everyday conversations in colloquial Tamil: 1,900 more phrases (95 subcategories of 20),
deduplicated against the existing 100, and a 100-question final exam with a 75% pass mark.

Decided with the owner:
- **Graded course:** about 8 levels taken in order, each adding sentence patterns through everyday situations.
- **One level at a time:** Claude drafts a level, the owner reviews it, corrections feed the next level.
- **Exam:** about 70 unseen sentences plus about 30 from the bank.
- **Levels are ordered but not locked.** The exam unlocks when every level is complete.
- **Tamil script:** each new phrase carries a Tamil-script spelling (for later audio). The app does not show it yet.

**What a pass will and won't prove.** The app is multiple choice, so a 75% pass shows the learner recognises
correct colloquial Tamil for sentences they have not memorised. It does not prove they can say it. Speaking
practice is the separate voice work (v1.2). The syllabus and the exam screen will say this plainly.

**Review cost.** 2,000 phrases at about a minute each is roughly 33 hours of owner review. This sets the pace
of the whole project. The app keeps showing "Unreviewed draft" on anything not yet checked (ADR 035).

## Decisions most likely to change
1. **Level count and sizes.** 100 subcategories as 8 levels of 12 or 13. The existing five become part of
   Level 1. The syllabus (chunk S0) fixes the final split and needs owner approval before any drafting.
2. **Where level information lives.** Each lesson file gains an optional `level: { "number": 3, "title": "...", "position": 7 }`
   (`position` orders lessons inside a level, because the first five keep ids that sort after the new ones).
   Files without it (old imports) appear under "Other lessons". Alternative rejected: a separate course manifest
   file, because the loader and the import treat every `content/*.json` as a lesson.
3. **`tamilScript` is optional per item.** New phrases must have it (enforced by the shipped-content test for
   Level 1 new units onward); the existing 100 are backfilled later. Tamil script stays banned in every other field.
4. **Duplicate rules.** Catalog-wide, ignoring case, spacing and punctuation: no two items share a
   `sourcePrompt`; no two items share a `canonical`. Inside one item, ignoring only case and surrounding spaces
   (the editor's existing rule): no accepted spelling listed twice. Punctuation variants are wanted there. Distractors may repeat across items.
5. **Exam scoring:** only the canonical answer counts. Picking the other register is not a correct exam answer
   (same rule as Home completion, ADR 033). Pass is 75 of 100. Retakes any time, order reshuffled.
6. **Exam does not touch scheduling.** Exam answers write no SM-2 records. Results go in a new `exam.json`,
   so the frozen `ProgressStore` contract is unchanged.
7. **File and id naming for new lessons:** `content/l03-u07-<slug>.json`, `scenarioId` `l03-u07`, items
   `l03-u07-i01`. Existing five keep their ids so saved progress survives.
8. **Import limit** rises from 10 to 20 files so a whole level can be imported at once.
9. **Model for drafting Tamil.** Recommend the strongest available model for drafting content; Sonnet for code.

## Preconditions (owner)
- Clear the two duplicates in S05 (`s05-i05`, `s05-i10`) and say when S05 is done. The new duplicate rule
  makes CI fail otherwise.
- `BLTApp.xcodeproj/project.pbxproj` has a local signing change (team ID). It must not be committed.

## Changes to frozen documents (need ADRs, written in S0)
- ADR 038 duplicate rules; ADR 039 course levels and lesson naming; ADR 040 `tamilScript` field;
  ADR 041 final exam. `docs/MVP_PLAN.md` section 2 (schema) and chunk C3 ("exactly 5 files") are amended to match.

## Wave 0: syllabus (main session, no code)
**S0 Syllabus and decisions.** Files: `docs/COURSE_SYLLABUS.md` (new), `docs/DECISIONS.md`, `docs/MVP_PLAN.md`.
- 8 levels, 100 subcategory titles, and for each: the situation, the sentence patterns it introduces, and what
  it reuses. Outline: L1 survival topics (existing five plus numbers, time, help, introductions); L2 present
  tense, having, liking, wanting, where things are; L3 past; L4 future, can, must, permission; L5 negatives,
  requests, if; L6 joining ideas (because, but, and then, "he said that"); L7 long real-life conversations
  (doctor, bank, office, landlord, travel, relatives); L8 opinions, stories, idioms and slang.
- Notes for a Telugu speaker: sounds and patterns that differ from Telugu get extra items.
- Exam blueprint: questions per level and per pattern (about 70 new, 30 from the bank).
- English only. No Tamil phrases in this document.
- Done when: the owner approves the syllabus. **Stop here for approval.**

## Wave 1: format and tools (parallel, different files)
**C1 Catalog format.** Files: `Packages/BLTKit/Sources/BLTCatalog/{RawScenario,Scenario,RawItem,Item,ContentIssue,ContentValidator}.swift`,
new `Level.swift`, `Tests/BLTCatalogTests/*`.
- Add optional `level` and `tamilScript`. `tamilScript`, when present, must contain Tamil-script characters and
  no Latin letters. Same level number must always carry the same title.
- Add the three duplicate rules as catalog-level issues (the validator already does catalog-level id checks).
- Fixtures stay obviously fake (`zz` text); the Tamil-script fixture uses a repeated single letter, not a word.
- Proof: `BLT_SIM="iPhone 17" scripts/test.sh package`.

**C2 Editor.** Files: `tools/content-editor/index.html`, `tools/content-editor/README.md`.
- Level number and title on the lesson; a Tamil-script box per item with the same checks; the three duplicate
  rules across all loaded files.
- Proof: headless Chrome run of the editor's checks against `content/*.json` (as done for earlier editor work).

**C3 Drafting aid.** File: `scripts/content-index.sh` (new, Python 3 standard library only).
- Prints every existing prompt and canonical answer (normalised) and fails on duplicates. Used before each
  drafting round and in CI's guardrail job.
- Proof: `bash scripts/content-index.sh --check` exits 0 on main; a `--self-test` plants a duplicate and fails.

## Wave 2: app and existing content (parallel; needs C1)
**C4 Shipped content and its tests.** Files: `content/scenario-0{1..5}-*.json` (add `level` 1 only),
`Tests/BLTContentTests/ShippedContentTests.swift`, `.github/workflows/ci.yml` (add C3 check).
- Replace "exactly 5 files" with: at least 5 files, every file exactly 20 items, level numbers contiguous from 1,
  every `l..-u..` lesson has `tamilScript` on all items, zero validator issues.
- Proof: `BLT_SIM="iPhone 17" scripts/test.sh package`.

**C5 Home grouped by level.** Files: `Packages/BLTKit/Sources/BLTFeatures/Home/*`,
`BLTDesign/AccessibilityID.swift`, `BLTApp/BLTAppUITests/HomeUITests.swift`, `PreviewCatalog.swift`.
- Sections per level with a level completion figure, a "Continue" suggestion for the next unfinished lesson,
  collapsed finished levels, "Other lessons" for files without a level. Nothing is locked.
- Reuses `CatalogProgress` and `ScenarioCard`.
- Proof: `scripts/test.sh app -only-testing:BLTAppUITests/HomeUITests` and the Home accessibility audits.

**C6 Import limit.** Files: `BLTContentStore/ImportedContentStore.swift` and its tests, README import section.
- `maxFilesPerImport` 10 to 20. Proof: package tests.

After Wave 2: full check (`scripts/test.sh package`, `scripts/test.sh app`, `swiftlint lint --strict`,
`bash scripts/check-forbidden-apis.sh`), one PR per chunk, update `progress.md`.

## Wave 3 onward: content, one level at a time (repeats 8 times)
For each level N (Level 1 needs only its 7 new subcategories):
1. **Draft.** Claude drafts the level's lesson files from the syllabus, all `reviewStatus: unreviewed`, with
   `tamilScript`, using `scripts/content-index.sh` output and `docs/content/STYLE_NOTES.md` as inputs.
2. **Check.** Validator, duplicate check and shipped-content tests pass. PR merges the drafts.
3. **Owner review** in the editor. The learner can already use the drafts, labelled as unreviewed.
4. **Learn.** Claude turns the owner's corrections into rules in `docs/content/STYLE_NOTES.md` (spelling
   choices, register preferences, words to avoid) and shows the full `git diff content/` before committing.
5. **Gate.** The next level is drafted only after the owner says the current one is done.
- Proof per level: `BLT_SIM="iPhone 17" scripts/test.sh package` and `bash scripts/content-index.sh --check`.

## Exam (can be built any time after Wave 2; content comes last)
**E1 Exam engine.** Files: new `BLTSession/Exam{Machine,Result,Paper}.swift`, tests.
- Fixed paper, shuffled order and options, no per-question feedback, score and per-level breakdown at the end.
**E2 Exam storage.** Files: new `BLTProgress/Exam/{ExamResultStore,FileExamResultStore}.swift`, tests.
- `exam.json` in Application Support with `.completeFileProtection`. No SM-2 writes. Cleared by Reset progress.
**E3 Exam screen and wiring** (later wave; needs E1, E2). Files: new `BLTFeatures/Exam/*`, `RootView.swift`,
`CompositionRoot.swift`, UI tests.
- Entry on Home, enabled when every level is complete. Result screen: score, pass or not, weakest levels.
**E4 Exam paper** (after Level 8 is reviewed). File: `content/exam/final.json`, loader support in `BLTContentStore`.
- About 70 new items in the normal item format, plus about 30 references to bank item ids (no copied text).
  New items use only patterns and words the course taught, and pass the same duplicate rules.
- A subfolder keeps it out of the lesson list (the lesson loader reads only files directly in `content/`).
- Proof: package tests, `scripts/test.sh app`, and an owner walkthrough on the simulator.

## Not in this plan
- Audio clips, pronunciation scoring and showing Tamil script in the app (the v1.1 and v1.2 work discussed).
- Backfilling `tamilScript` on the existing 100 phrases (a later content pass).
- Reshaping the slow UI test suite.

## Verification
1. `BLT_SIM="iPhone 17" scripts/test.sh package`
2. `BLT_SIM="iPhone 17" scripts/test.sh app`
3. `swiftlint lint --config .swiftlint.yml --strict`
4. `bash scripts/check-forbidden-apis.sh` and `bash scripts/content-index.sh --check`
5. Simulator: Home shows levels, the next-lesson suggestion works, an imported level appears in its level.
6. Owner's iPhone: import a reviewed level through Files; confirm labels follow `reviewStatus`.
7. CI green on each PR.
