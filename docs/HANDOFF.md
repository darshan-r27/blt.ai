# BLT.ai: handoff

Read this first in a new session, then `CLAUDE.md`. Last updated 2026-10-06.

## What this is
**blt.ai** (Budugu Learns Tamil): an iOS 27 / SwiftUI app that teaches colloquial Tamil to Telugu speakers who are fluent in English. **v1 is text-only multiple choice** (English prompt, four romanised-Tamil options, feedback, scheduling); voice is v2. Portfolio project, not distributed. Repo: `github.com/darshan-r27/blt.ai` (private), workspace `~/dev/blt.ai`.

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
1. **C11 UI tests** (onboarding, feedback flow, end session, persistence, accessibility audits): the agent was interrupted by a rate limit and resumed; its last completed full run (2026-10-06 16:47) still had failures, mostly accessibility audits, and it was re-running. Do not run UI tests in its worktree or on iPhone 17 while it is alive (`pgrep -fl 'xcodebuild test'`). When it merges, restore "including accessibility audits" in the README's Run it section. Its work is in the worktree `.claude/worktrees/agent-ac36e04d770fc4b77` (branch `worktree-agent-ac36e04d770fc4b77`). It must commit, `git merge main`, delete `DebugTmpUITests.swift`, and report. Until it is merged there are no real UI tests (the template ones are fine).
2. **Content review (owner, by hand):** edits are being saved straight into `content/*.json` and are **uncommitted** (`scenario-01`, `scenario-02` at last check). All 100 items are still `unreviewed`. Commit them only when the owner says they are done.
3. **Settings statement** flips to "Every lesson was checked by a native Tamil speaker…" only when all items are `reviewed` (ADR 035). Use the editor's "Mark reviewed" for that.

**Known gaps and watch-items**
- Not visually verified by a human: shimmer on a device, VoiceOver, largest Dynamic Type on every screen, damaged-profile "Start over" screen, Progress screen on lilac.
- Progress screen still shows due/learned/attempt counts (only Home cards were simplified).
- System UI (keyboard return key) stays blue; the reset button and some dialogs use a destructive role that could render red on some iOS versions.
- `.completeFileProtection` is not enforced in Simulator: check on a device.
- CI (`.github/workflows/ci.yml`) is pinned (SwiftLint SHA-256, checkout by commit SHA) and targets GitHub's `xcode-27` preview image, the only hosted image with the iOS 27 SDK. First run is the push of 2026-10-06: check its result before trusting it. macOS minutes are billed at 10x while the repo is private.
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
