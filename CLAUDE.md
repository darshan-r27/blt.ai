# BLT.ai

iOS app teaching colloquial Tamil to Telugu speakers. Voice-first, on-device, no backend.

Read `@docs/PRD.md` before any product decision. Read `@docs/BUILD_PLAN.md` for the task you're on. Read `@docs/SECURITY.md` before touching audio, file storage, `Info.plist`, or dependencies. Read `@docs/BACKEND.md` before any telemetry work.

## Hard constraints

These are not preferences. Violating one is a bug regardless of whether tests pass.

1. **Network access is confined to one module.** No `URLSession`, `NWConnection`, `CFStream`, or `WKWebView` anywhere except `Telemetry/` (which does not exist before v1.5 — until then the rule is absolute). No third-party SDK with network capability. Set `requiresOnDeviceRecognition = true` on any `SFSpeechRecognizer` and handle the failure rather than letting it fall back to Apple's servers.
   Telemetry is opt-in and off by default. Identity is a user-chosen profile name, never an Apple identifier. Never send audio, transcripts, device model, location, or any Apple identifier. `sessionID` is in-memory only and must never be written to disk. The two field tables in `docs/BACKEND.md` §5 are exhaustive — adding a field means editing that doc first and asking.
2. **Breadcrumbs are a closed enum.** Diagnostic breadcrumbs carry item IDs and state-machine states only. No case may carry a free-text `String`, a file path, or a payload body. This is the easiest way to leak user content, through a path nobody watches — if you find yourself wanting a string breadcrumb, stop and ask.
3. **No third-party crash SDK.** Diagnostics are TestFlight, MetricKit, and our own structured errors. Sentry, Crashlytics, and equivalents break the single-networked-module boundary and add supply-chain surface. Do not propose one.
4. **Audio never survives the attempt that produced it** unless the user has explicitly opted in. Recordings go to the app container with `.completeFileProtection`, never `tmp`. Deletion is unconditional — put the unlink in a `defer` at the top of the scoring path, never at the end of a success branch, so a scoring failure still deletes. The app also sweeps the recording directory on every launch, because a crash between recording and scoring orphans a file that no in-session code path reaches.
5. **Pronunciation is advisory.** `Verdict.pronunciation` must not influence progression, scheduling, or the semantic verdict. If you find yourself branching on it outside the feedback view, stop and ask.
6. **No `@unchecked Sendable`, no `nonisolated(unsafe)`.** Strict concurrency is `complete`. If a race won't resolve, say so — do not silence it.
7. **SPM only, exact-version pinned.** Adding a dependency requires asking first, with a one-line justification. Target count is zero to two.
8. **No `print()` in the shipping target.** Use `Logger` with `privacy: .private` on anything user-derived. No transcripts, file paths, or scores in release logs.

## Commands

```bash
# Build
xcodebuild -scheme BLTApp -destination 'platform=iOS Simulator,name=iPhone 17' build

# Test
xcodebuild -scheme BLTApp -destination 'platform=iOS Simulator,name=iPhone 17' test

# Lint
swiftlint --strict
```

The standard target is **iOS 27** and the standard simulator is **iPhone 17** (the only runtime installed here is iOS 27). List devices with `xcrun simctl list devices available`; parallel agents should each use a different device (DECISIONS 029).

Speech and microphone APIs **do not work in Simulator.** Anything touching `AudioRecorder`, `SFSpeechRecognizer`, or the scoring engines must be verified by the human on a physical device. Say so explicitly when you finish such a task rather than reporting it as done.

## Conventions

- Swift 6, strict concurrency `complete`, iOS 27 deployment target
- SwiftUI only. No UIKit unless there is no alternative, and then say why
- Module structure per PRD §7: `Catalog`, `Session`, `Audio`, `Scoring`, `Progress`, `DesignSystem`
- One type per file, named for the type
- Dependency injection at the composition root. No singletons, no `shared`
- Protocols for anything with more than one implementation, especially `ScoringEngine`
- Tests live beside the module they test

## How to work here

**One task at a time.** Tasks come from `docs/BUILD_PLAN.md` and each has acceptance criteria. Do not start the next task, do not do "while I'm here" refactors, do not fix unrelated things you notice. Mention them instead.

**Plan before writing.** For any task touching more than one file, outline the approach and wait for approval.

**Ask rather than assume** when:
- a task's acceptance criteria are ambiguous
- a dependency would help
- the PRD and the build plan disagree
- something is impossible as specified

Guessing wastes more of the human's time than asking does. He is reviewing for security, not rewriting your code, so a wrong assumption buried three files deep is expensive.

**Definition of done:** acceptance criteria met, tests written and passing, `swiftlint --strict` clean, build has zero warnings, and a one-paragraph summary of what changed and what the human should verify on device.

## What not to do

- Do not mark a task complete when part of it is unverified. Say which part.
- Do not write code that silently falls back — to a network path, a default value, a cloud recognizer. Surface the error.
- Do not add a dependency to avoid writing forty lines.
- Do not restructure existing modules as a side effect of a feature task.
- Do not generate Tamil content outside the v1 content task. Per DECISIONS 025, v1 text content is Claude-drafted, must carry `reviewStatus: unreviewed`, and lives only in the content data files. Code and test fixtures never contain real Tamil phrases; fixtures must be obviously fake. v2 audio content still comes from native speakers.

## Context

This is a portfolio project. The repo is read by hiring managers as much as it is run. Clear code with honest comments beats clever code. When you make a non-obvious decision, note it in `docs/DECISIONS.md` rather than in a code comment.
