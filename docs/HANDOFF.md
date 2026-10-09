# BLT.ai: handoff

Read this first in a new session, then `CLAUDE.md`. Last updated 2026-10-09.

## Start here (next session)
**Task: build Wave 1 of `plan.md`.** Read `plan.md` (the chunks), `progress.md` (status), `docs/COURSE_SYLLABUS.md`
(what the course is) and DECISIONS 038 to 041 (the rules being built). Then run the three chunks below in parallel
as Sonnet agents in separate worktrees, one PR per chunk.

| Chunk | Owns (touch nothing else) | Proof |
|---|---|---|
| **C1 Catalog format** | `Packages/BLTKit/Sources/BLTCatalog/*` (new `Level.swift`), `Packages/BLTKit/Tests/BLTCatalogTests/*` | `BLT_SIM="iPhone 17" scripts/test.sh package` |
| **C2 Editor** | `tools/content-editor/index.html`, `tools/content-editor/README.md` | Headless Chrome run of the editor's checks against `content/*.json` |
| **C3 Drafting aid** | `scripts/content-index.sh` (new; Python 3 standard library only) | `bash scripts/content-index.sh --check` and `--self-test` |

What each must do is in `plan.md` under "Wave 1". The details that are easy to get wrong:
- **C1** adds two optional fields and three duplicate rules.
  - Lesson: `level` = `{ number, title, position }`. Same `number` must always have the same `title`.
  - Item: `tamilScript`. When present it must contain Tamil-script characters (U+0B80 to U+0BFF) and no Latin
    letters. Tamil script stays an error in every other field.
  - Duplicates. Catalog-wide, ignoring case, spacing and punctuation: no two items share a `sourcePrompt`; no two
    share a `canonical`. Inside one item, ignoring **only** case and surrounding spaces (same as the editor's
    `norm`): no accepted spelling twice. Do not ignore punctuation there: about 50 reviewed items list variants
    that differ only by a question mark, hyphen or space, on purpose. Add them as new `ContentIssue.Rule` cases; the
    catalog-wide ones go where the existing cross-file id checks run.
  - Fixtures are fake `zz` text. A Tamil-script fixture is one letter repeated, never a real word.
  - `Scenario` and `Item` are part of the frozen contracts (`docs/MVP_PLAN.md` section 5): add fields with defaults
    so existing call sites compile, and do not change existing ones. When C1 lands, rewrite `MVP_PLAN.md` section 2
    (it has a "pending changes" note now) and flip DECISIONS 038 to 040 from pending to active.
- **C2** mirrors C1's rules in the editor's `validate`, and runs the duplicate rules across every loaded file.
- **C3** is also added to CI's guardrail job later, in Wave 2 chunk C4 (not now).

**Blocker for C1 (owner).** Four items still list an accepted spelling twice: `s01-i07`, `s01-i19`, `s05-i05`
(each a capital-letter variant) and `s05-i10` (an exact repeat). The owner's review edits to
`content/scenario-05-home-family.json` are also uncommitted. The new duplicate rule makes the
shipped-content test fail until the owner fixes them. Do not edit or commit that file: ask the owner. C2 and C3 are
not blocked.

**Do not commit `BLTApp/BLTApp.xcodeproj/project.pbxproj`.** It carries the owner's local signing team id.

After Wave 1: merge one PR at a time, run the full check, update `progress.md`, then stop and report before Wave 2.

## What this is
**blt.ai** (Budugu Learns Tamil): an iOS 27 / SwiftUI app that teaches colloquial Tamil to Telugu speakers who are fluent in English. **v1 is text-only multiple choice** (English prompt, four romanised-Tamil options, feedback, scheduling); voice is later. Portfolio project, not distributed. Repo: `github.com/darshan-r27/blt.ai` (public), workspace `~/Claude/dev/blt.ai`.

Product rules that matter: two spoken registers only (casual `nee/da/di`, respectful `neenga`; no written/literary Tamil); common English loanwords stay English; never red except Reset progress (037); no network, audio or speech in v1; the only personal data is a display name stored on the device (030).

## Where things are
| Path | What |
|---|---|
| `CLAUDE.md` | Standing rules (read automatically). |
| `plan.md`, `progress.md` | The current build plan (full course) and where it stands. |
| `docs/COURSE_SYLLABUS.md` | Owner-approved syllabus: 8 levels, 100 lessons, exam blueprint. English only. |
| `docs/ARCHITECTURE.md` | How the code is organised (modules, data flow, storage, enforcement). |
| `docs/MVP_PLAN.md` | The v1 plan: frozen contracts (§5, §6a, §6b), chunks, review checklist (§7). |
| `docs/DECISIONS.md` | ADRs 001-041. Newest decisions win; 024-037 define v1; 038-041 are pending (the course). |
| `Packages/BLTKit/` | Swift package: BLTCore, BLTCatalog, BLTProgress, BLTSession, BLTDesign, BLTContentStore, BLTFeatures + tests. |
| `BLTApp/BLTApp.xcodeproj` | App shell. Sources in `BLTApp/BLTApp/`; UI tests in `BLTApp/BLTAppUITests/`. Links only the `BLTFeatures` product. |
| `content/scenario-0N-*.json` | 5 lessons x 20 items, Claude-drafted, bundled into the app as a folder reference. |
| `tools/content-editor/index.html` | Offline review/edit tool for the content (open in **Chrome**). See its README. |
| `scripts/` | `test.sh`, `check-forbidden-apis.sh`, `check-binary.sh`, `check-identity.sh`, `githooks/pre-push`. |

## Commands (run from the repo root)
```bash
BLT_SIM="iPhone 17" scripts/test.sh package   # package tests (warnings are errors)
BLT_SIM="iPhone 17" scripts/test.sh app       # build + UI tests (slow: run per class, see below)
swiftlint lint --config .swiftlint.yml --strict
bash scripts/check-forbidden-apis.sh          # also: --self-test
bash scripts/check-binary.sh <path to built .app>
bash scripts/check-identity.sh                 # every commit uses a no-reply email (also in CI)
git config core.hooksPath scripts/githooks    # once per clone: pre-push hook runs the same check
```
Standard simulator: **iPhone 17** (only an iOS 27 runtime is installed). Parallel runs need *different* devices (`xcrun simctl list devices available`). Debug-only launch arguments for UI tests: `--uitest-fixtures`, `--uitest-reset`, `--uitest-name=<Name>`.

## Status
**Shipped on `main`:** the whole v1 app (onboarding, Home, sessions, Progress, Settings), lesson import from Files (036), Reset progress as a warning (037), the `BLTContentStore` module split, a narrowed `BLTFeatures` public API, `docs/ARCHITECTURE.md`, identity guard and CI.

**Open PR #8 (`course-plan` branch):** `plan.md`, `progress.md`, the syllabus, DECISIONS 038 to 041, this file. Docs only. Wave 1 branches should start from `main` after it merges.

**Content review (owner, by hand in the editor):** lessons 1 to 4 are fully reviewed and committed. Lesson 5 has 2 of 20 reviewed, with uncommitted edits. Commit content only when the owner says it is done, and show the full `git diff content/` first.

**On a real iPhone:** the app installs and launches on the owner's iPhone with a free Apple ID (Debug build, 7-day signature). Not yet checked there: AirDrop to Files to Import, shimmer, VoiceOver, largest text size, the damaged-profile screen.

**Ideas discussed, not planned:** audio clips generated on the Mac and bundled (needs `tamilScript`, hence 040); pronunciation scoring (needs an experiment first; would touch hard constraint 5 and the no-network rule if a cloud service were used).

## Known gaps and watch-items
- **`main` is protected.** Changes go through a PR with two required checks; PRs are squash-merged. The owner can bypass as admin.
- **CI is slow and occasionally flaky.** It runs on GitHub's `xcode-27` preview image; a run takes 12 to 45 minutes. UI tests retry up to 3 times because the image sometimes hangs a UI query. Pushing to a branch cancels its running CI, so hold pushes until a run finishes.
- **The full UI test target takes about 50 minutes locally** and gets killed in one go: run it per class (`scripts/test.sh app -only-testing:BLTAppUITests/<Class>`).
- Three narrow accessibility-audit ignores remain in `AccessibilityUITests.swift` (documented in its header); two may no longer be needed.
- Package content tests read the live `content/` folder: if the editor saves mid-run they can fail transiently; rerun before suspecting code.
- `.completeFileProtection` is not enforced in Simulator: check on a device.
- Old agent worktrees and branches are still under `.claude/worktrees/` (local only). Leave them unless the owner asks for a clean-up.
- Old commits with the owner's previous identity are still reachable through merged PR refs on GitHub (only GitHub Support can purge them).

## How we work here (keep doing this)
- **The main session orchestrates; Sonnet agents execute small chunks** in isolated worktrees (`isolation: "worktree"`), at most three at a time, each with exact file ownership, acceptance criteria, its own simulator, and a short final report. Opus plans.
- **Merge one agent at a time**, run package tests + lint + guard (and the app build when UI changed). Verify once per wave, not after every tiny change. If a chunk fails its check twice, stop it and tell the owner.
- **Never `git add -A` or `git add .`**: stage explicit paths.
- **Frozen contracts** (`MVP_PLAN.md` §5/§6a) change only through a deliberate ADR + plan edit.
- **Agent reports: a 3-line TL;DR plus exceptions, 25 lines max.**
- Ask the owner before overriding anything they set in Xcode or in the docs. Report with a TL;DR first (succeeded / failed / actions needed), in plain language.
- Tests use obviously fake `zz` fixtures; no real Tamil text in Swift files (content lives only in `content/*.json`).
- Tamil content is drafted only in the content task, always `unreviewed`, one level at a time, and only after the owner has finished reviewing the previous level.
- Do not run UI tests on the same simulator as another agent.

## Owner decisions still open
- When lesson 5 is done (unblocks C1 and the commit of its review edits).
- Whether `plan.md` and `progress.md` stay in the public repo long term.
- Which model drafts the Tamil (the plan recommends the strongest available; Sonnet for code).
- Audio and pronunciation scoring: which voice source, on-device only or not, and whether a score may gate progress.
- Whether to simplify the Progress screen to match Home.

## Token/quota hygiene
Start a fresh session at milestones using this file; do not let one session grow past ~60% of its window. Batch requests into one complete message; keep agent reports short; run UI tests only at milestones.
