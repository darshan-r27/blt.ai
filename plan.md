# blt.ai becomes a two-way course: Tamil and Telugu, for a couple learning each other's language

On approval this replaces `plan.md` in the repo root (the single-course plan it supersedes was never built past
its syllabus). Progress is tracked in `progress.md`.

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
   `ta-l02-u03` and `te-l02-u03`. The five existing Tamil lessons keep their ids so saved progress survives.
5. **Storage on the phone.** `Application Support/BLT/courses/<language>/` holds `progress.json`, imported
   lessons and the exam result. Existing Tamil data is moved there once at launch (tested, all or nothing).
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
**A1 Catalog format.** `Packages/BLTKit/Sources/BLTCatalog/*` (new `Level.swift`), `Tests/BLTCatalogTests/*`.
- Everything in decision 3, plus the duplicate rules: catalog-wide prompt and answer checks ignore case, spacing
  and punctuation; inside one item only case and surrounding spaces are ignored.
- Fixtures are fake `zz` text; a script fixture is one letter repeated.
- **Also updates the five shipped files in place** (adds `language`, renames the gloss key), in the same PR, so
  the shipped-content tests never go red. The files do not move yet.
**A2 Editor.** `tools/content-editor/index.html`, its README. Same rules, language-aware labels and script check.
**A3 Drafting aid.** `scripts/content-index.sh` (new, Python 3 standard library): per-language index,
`--check` for duplicates, `--mirror` report, `--self-test`.
**A4 Profile.** `Packages/BLTKit/Sources/BLTProgress/Profile/*`, its tests.
- `UserProfile.learningLanguage` (optional), profile file schema 2, schema 1 files load with no language.
- Proof for all: `BLT_SIM="iPhone 17" scripts/test.sh package`; A2 by headless Chrome; A3 by its self-test.

## Wave 2: content and storage (needs Wave 1; B1 and B2 merge as one PR)
Moving the lesson files and teaching the loader the new folders must land together, or the app would load no
lessons. The two chunks are built in parallel on different files and merged as a single PR.

**B1 Existing content and its tests.** Move the five files to `content/tamil/` and add `level`. `Tests/BLTContentTests/*`: per language, at least 5 Tamil files, 20 items each, levels
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
- Build dependencies for the chosen language; per-language paths; the one-time move of existing Tamil data;
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
- Reshaping the slow UI test suite.

## Verification
1. `BLT_SIM="iPhone 17" scripts/test.sh package`
2. `BLT_SIM="iPhone 17" scripts/test.sh app` (per class), then a Release build and `scripts/check-binary.sh`
3. `swiftlint lint --config .swiftlint.yml --strict`, `bash scripts/check-forbidden-apis.sh`,
   `bash scripts/content-index.sh --check`
4. Simulator: fresh install picks Telugu and sees Telugu lessons; switch to Tamil and back with progress intact;
   reset clears one language; an upgraded install keeps its Tamil progress and is asked for a language.
5. Owner's iPhone: upgrade over the current install (progress must survive); import a Telugu lesson file into
   the Telugu course and confirm a Tamil file is refused there.
6. CI green on each PR.
