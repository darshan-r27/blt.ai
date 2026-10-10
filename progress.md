# Progress: full course plan (plan.md)

## Done
- Plan approved and merged (#8): `plan.md`, `docs/COURSE_SYLLABUS.md` (owner-approved 2026-10-09), DECISIONS 038 to 041.
- Content: all five lessons (100 items) reviewed and merged (#9); four repeated accepted spellings removed.
- Wave 1 (parallel Sonnet agents): C3 `scripts/content-index.sh` merged (#11); C2 editor `level`, `tamilScript` and duplicate checks merged (#12); C1 catalog format and validator rules open as #13 (CI running; owner said merge when green).

## Decisions
- Graded course of 8 levels; one level drafted and reviewed at a time; exam about 70 new plus 30 from the bank; levels ordered, not locked; `tamilScript` on new phrases.
- Accepted-spelling duplicates inside an item compare only case and surrounding spaces (punctuation variants are wanted); prompts and canonicals across the catalog also ignore spacing and punctuation.
- A later item that repeats a prompt or canonical is dropped and the earlier one wins (C1 loader).

## Deviations from the plan
- `level` has a `position` field (orders lessons inside a level; the first five keep ids that sort last).
- C1 edited test fixtures outside its file list (items shared one prompt and canonical; now derived from the item id). Separate commit in #13.
- C1 added more `ContentIssue.Rule` cases than "three rules" (each rule needs its own case, plus level and `tamilScript` checks).
- The ADR 038 wording was narrowed after checking the reviewed lessons (punctuation-only spelling variants are deliberate).

## Waiting on the owner
- Look at the editor's new level and Tamil-script boxes in a browser.
- Decide the drafting model for the Tamil (before Wave 3) and whether to add a `tamilScript` column to the CSV review sheet.

## Next action
- Merge #13 when green, run the full check, update this file, report. Then Wave 2: C4 shipped content and tests (and `content-index.sh` in CI), C5 Home grouped by level, C6 import limit 20. Details in `docs/HANDOFF.md`.
