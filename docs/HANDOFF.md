# BLT.ai: handoff

Read this first in a new session, then `CLAUDE.md`. Last updated 2026-10-06.

## What this is
**blt.ai** (Budugu Learns Tamil): an iOS 27 / SwiftUI app that teaches colloquial Tamil to Telugu speakers who are fluent in English. **v1 is text-only multiple choice** (English prompt, four romanised-Tamil options, feedback, scheduling); voice is v2. Portfolio project, not distributed. Repo: `github.com/darshan-r27/blt.ai` (public from 2026-10-06), workspace `~/dev/blt.ai`.

Product rules that matter: two spoken registers only (casual `nee/da/di`, respectful `neenga`; no written/literary Tamil); common English loanwords stay English; never red; no network, audio or speech in v1; the only personal data is a display name stored on the device (ADR 030).

## Where things are
| Path | What |
|---|---|
| `CLAUDE.md` | Standing rules (read automatically). |
| `docs/MVP_PLAN.md` | The v1 plan: frozen contracts (§5, §6a, §6b), chunks, review checklist (§7). |
| `docs/DECISIONS.md` | ADRs 001-035. Newest decisions win; 024-035 define v1. |
| `docs/OPEN_ITEMS.md` | Older open questions (some now decided). |
| `Packages/BLTKit/` | Swift package: BLTCore, BLTCatalog, BLTProgress, BLTSession, BLTDesign, BLTFeatures + tests. |
| `BLTApp/BLTApp.xcodeproj` | App shell. Sources in `BLTApp/BLTApp/`; UI tests in `BLTApp/BLTAppUITests/`. Links only the `BLTFeatures` product. |
| `content/scenario-0N-*.json` | 5 scenarios x 20 items, Claude-drafted, bundled into the app as a folder reference. |
| `tools/content-editor/index.html` | Offline review/edit tool for the content (open in **Chrome**). See its README. |
| `tools/app-icon/` | SVG sources + `render.sh` for the app icon (light, dark, tinted). |
| `scripts/` | `test.sh`, `check-forbidden-apis.sh`, `check-binary.sh`. |

## Commands (run from the repo root)
```bash
BLT_SIM="iPhone 17" scripts/test.sh package   # package tests (warnings are errors)
BLT_SIM="iPhone 17" scripts/test.sh app       # build + UI tests (slow: minutes)
swiftlint lint --config .swiftlint.yml --strict
bash scripts/check-forbidden-apis.sh          # also: --self-test
bash scripts/check-binary.sh <path to built .app>
```
Standard simulator: **iPhone 17** (only an iOS 27 runtime is installed). Parallel runs need *different* devices (`xcrun simctl list devices available`). Debug-only launch arguments for UI tests: `--uitest-fixtures`, `--uitest-reset`, `--uitest-name=<Name>`.

## Status
Merged on `main` and verified (package tests, lint, guard, app build, Release build + binary check):
- Waves 0-3: package + contracts, guardrails, loader, scheduler, stores, session engine, design system, session UI, Home/Progress/Settings, app wiring, privacy manifest.
- UI changes: lilac theme, deep-purple accent, "blt.ai" intro, name-only onboarding, "Hi <name>" shimmer greeting on Home, completion-% cards, End-session control, randomised sessions (sampled + shuffled), Settings statement that follows the data, app icon "Two voices".

**In flight / not done**
1. **C11 UI tests: merged and green** (onboarding 6, feedback flow 6, end session 5, home 5, persistence 4, accessibility audits 21). The full target takes ~50 minutes in the simulator and gets killed if run in one go: run it per class (`scripts/test.sh app -only-testing:BLTAppUITests/<Class>`). The audits found two real defects, both fixed (intro title now has the spoken label "B L T dot A I"; Change name sheet uses a plain top bar instead of the system toolbar). The two name screens (name entry, Change name) are audited with the system keyboard dismissed (`dismissKeyboard` in `AccessibilityUITests.swift`): on a GitHub runner the keyboard's empty prediction cells are reported as unlabelled, and at the largest text size the keyboard covers Continue and the helper text, which the audit reports as contrast failures (both screens still scroll, and the reachable-at-XXXL tests cover using them with the keyboard up). CI prints each failing test's message from the result bundle ("Summarise UI test failures" step). Three narrow audit ignores remain in `AccessibilityUITests.swift`: `isSystemToolbarButtonDynamicTypeIssue` (probably now unnecessary since the Change name buttons are plain), `isOccludedByContinueBar` (gloss chip under the Continue bar at the largest text size, justified by a visual check only) and `isSettingsTextBehindSheet` (the Settings text behind the Change name sheet: a contrast false positive seen only on the runner). The audit is also retried once if the audit tool itself times out. Revisit the first two.
2. **Content review (owner, by hand):** edits are being saved straight into `content/*.json` and are **uncommitted** (`scenario-01`, `scenario-02` at last check). All 100 items are still `unreviewed`. Commit them only when the owner says they are done.
3. **Settings statement** flips to "Every lesson was checked by a native Tamil speaker…" only when all items are `reviewed` (ADR 035). Use the editor's "Mark reviewed" for that.

**Lesson import (DECISIONS 036): merged.** Settings > Import lessons (Files picker, up to 10 `.json`, all or nothing, applied at once; Remove imported lessons undoes it). Verified on the iPhone 17 simulator with a real file in Files (import, relaunch, remove, and a broken file). Not yet verified on a real iPhone: AirDrop the `content/*.json` files, Save to Files, import. It does not remove the weekly Xcode re-sign on a free Apple ID.

**Known gaps and watch-items**
- Not visually verified by a human: shimmer on a device, VoiceOver, largest Dynamic Type on every screen, damaged-profile "Start over" screen, Progress screen on lilac.
- Progress screen still shows due/learned/attempt counts (only Home cards were simplified).
- The Reset progress confirmation draws its destructive button in system red (seen on iOS 27); the Remove imported lessons dialog avoids that by using no destructive role. Decide whether to do the same for Reset.
- System UI (keyboard return key) stays blue; the reset button and some dialogs use a destructive role that could render red on some iOS versions.
- `.completeFileProtection` is not enforced in Simulator: check on a device.
- CI (`.github/workflows/ci.yml`) runs on GitHub's `xcode-27` preview image and is green on `main` as of 2026-10-07 (SwiftLint SHA-256 and checkout pinned). That image intermittently hangs a UI query for 2 to 7 minutes in a different test each run ("Timed out while evaluating UI query"), so the UI step uses `-retry-tests-on-failure -test-iterations 3`; a run takes 12 to 45 minutes. A failing run prints each failed test's message ("Summarise UI test failures" step). macOS minutes are free now the repo is public.
- Package content tests read the live `content/` folder: if the editor saves mid-run they can fail transiently; rerun before suspecting code.
- The owner's v2 (voice) plan is deferred: see ADR 024 and `docs/BUILD_PLAN.md` phases 1.3+, 3.x.

## How we work here (keep doing this)
- **The main session orchestrates; Sonnet agents execute small chunks** in isolated worktrees (`isolation: "worktree"`), each with exact file ownership, acceptance criteria, its own simulator, and a short final report. Opus plans.
- **Merge one agent at a time**, run package tests + lint + guard (and the app build when UI changed), then push. Verify once per wave, not after every tiny change.
- **Never `git add -A` or `git add .`** (the home directory was once a git repo): stage explicit paths and check `git rev-parse --show-toplevel`.
- **Frozen contracts** (`MVP_PLAN.md` §5/§6a) change only through a deliberate ADR + plan edit.
- **Agent reports: ask for a 3-line TL;DR plus exceptions, 25 lines max.** Keep screenshots out of the main session where possible.
- Ask the owner before overriding anything they set in Xcode or in the docs. Report outcomes with a TL;DR first (succeeded / failed / actions needed).
- Tests must use obviously fake `zz` fixtures; no real Tamil text in Swift files (content lives only in `content/*.json`).
- Do not run UI tests on the same simulator as another agent.

## Owner decisions still open
- Purple accent applied everywhere except system UI: any further polish?
- Whether to simplify the Progress screen to match Home.
- Whether to add a filled Save in Change name (currently a tinted toolbar button).
- When to commit the content edits and mark items `reviewed`.

## Token/quota hygiene
Start a fresh session at milestones using this file; do not let one session grow past ~60% of its window. Batch requests into one complete message; keep agent reports short; run UI tests only at milestones.
