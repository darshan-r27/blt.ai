# BLT.ai — security review

Written for the case where an AI agent writes most of the code and a human reviews it. Each item is something to check in a diff, not a principle to agree with.

Two properties do most of the work here. Hold them and most of the rest follows.

> **P1 — The only module permitted to open a network connection is `Telemetry`, which is off by default.**
> **P2 — Raw audio never leaves the device, and does not survive the attempt that produced it unless the user opted in.**

---

## Verifying P1

The claim is only worth making if it's checkable. In v1 the exempt path is empty; from v1.5 it is exactly one directory.

- [ ] No `URLSession`, `NWConnection`, `CFStream`, or `WKWebView` anywhere in the target **except `Telemetry/`**. Grep in CI and fail the build on a hit.
- [ ] The CI exemption names one path. A PR that widens it is a design change and fails review, not just the build.
- [ ] A fresh install with telemetry off makes zero connection attempts under a blocking proxy. Test, not assertion.
- [ ] Telemetry defaults to off in a fresh install and after an upgrade. An upgrade that silently enables it is a consent violation.
- [ ] No third-party SDK with network capability. In practice: no third-party SDKs at all.
- [ ] Core ML models are bundled, not downloaded. If a model must fetch on first launch, P1 is dead — say so plainly rather than hedging.
- [ ] A CI step runs the app under a proxy with an allow-nothing policy and asserts zero connection attempts.
- [ ] Apple's frameworks count. `SFSpeechRecognizer` falls back to server-side recognition for some locales — set `requiresOnDeviceRecognition = true` and handle the failure case rather than silently degrading to a network call. This is the most likely way P1 breaks by accident.

## Verifying P2

- [ ] Recordings go to the app container, never `NSTemporaryDirectory()` and never a shared container.
- [ ] Files written with `.completeFileProtection`, not the default `.completeUntilFirstUserAuthentication`.
- [ ] Audio is written to disk during an attempt — it has to be, since the scoring engine reads a file. The claim is that it does not *survive* the attempt, not that it never touches storage. Be precise about this when describing it.
- [ ] **Deletion is unconditional.** The unlink sits in a `defer` at the top of the scoring path, not at the end of a success branch. A scoring failure — ASR returns nothing, model won't load, audio session dies mid-attempt — must still delete the file. This is the likely accidental-retention path, not the happy one.
- [ ] **Launch-time orphan sweep.** On every launch, delete every file in the recording directory before anything else runs. A crash or force-quit between recording and scoring leaves a file that no in-session code path will ever reach. Without the sweep, audio accumulates silently and nobody intended it.
- [ ] The sweep respects the opt-in: when "keep my recordings" is on, it clears only files with no corresponding attempt record.
- [ ] Pronunciation scoring does not change any of this — the stored artefact is a span fraction, never audio.
- [ ] Stored pronunciation signals contain no audio reference. A signal that retains a file URL past scoring is a retention leak wearing a different hat. "Keep my recordings" is opt-in, off by default, with a visible indicator when on.
- [ ] Settings has a working "delete all recordings" that actually unlinks, and a test that asserts the directory is empty afterward.
- [ ] `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are absent from Info.plist. Either one exposes the container over USB and iTunes file sharing.
- [ ] Recordings excluded from iCloud backup via `isExcludedFromBackupKey`.
- [ ] Tests, not assertions: the recording directory is empty after a successful attempt, after a scoring failure, after a mid-attempt interruption, and after a simulated crash-then-relaunch. If these four don't exist, P2 is a policy statement rather than a property.

## Telemetry and diagnostics (v1.5)

The two data tables in `docs/BACKEND.md` §5 are the contract. These checks verify the code matches them.

### Both streams

- [ ] Every field in an outgoing payload appears in a §5 table. A field in code but not in the doc is a bug in one of them — resolve before merge.
- [ ] No audio, no transcript, no Apple identifier, no device model, no location. Grep both event structs.
- [ ] Both toggles default off on a fresh install **and after an upgrade**. An upgrade that silently enables collection is a consent violation.
- [ ] Declining consent at onboarding leaves the app fully functional and makes zero connection attempts under a blocking proxy.
- [ ] "See what's sent" renders from the live queue, not a hand-written sample. A test asserts the two match — a preview that drifts is worse than none.
- [ ] "Delete everything" is verified server-side and returns a real count. Not a tombstone, not a local-only clear.
- [ ] `sessionID` is in-memory only. Grep the queue schemas, `UserDefaults`, and the app container.

### The breadcrumb rule — highest risk item here

A breadcrumb reading `scored item 042, transcript "naan varen"` leaks exactly what the public claim forbids, through the diagnostics path, where nobody is looking.

- [ ] Breadcrumbs are a **closed enum**. No case carries a free-text `String`, no case carries a file path or payload body.
- [ ] Verify by reading the type definition, not by auditing call sites. If the type permits arbitrary text, no amount of call-site discipline holds.
- [ ] MetricKit payloads are forwarded verbatim. Nothing app-side augments them with local context.

### Ingest

- [ ] Undeclared fields rejected with a 422, not ignored.
- [ ] Source IP stripped at the edge before any handler; never logged.
- [ ] Write key present, read from environment on the server and from a gitignored `.xcconfig` on the client. Never in a tracked file, never in `Info.plist`.
- [ ] The key is extractable from the app binary. This is accepted and documented in BACKEND.md §10 — confirm the doc still says so rather than quietly implying stronger auth.

### Retention

- [ ] The diagnostics purge job exists, runs nightly, and writes a run record.
- [ ] Integration test: diagnostics dated 31 days ago are deleted **and** no learning event is touched. P0 on failure — it means a stated policy is false.
- [ ] No secret in Terraform state, tracked files, or CI logs.

## Permissions and privacy declarations

- [ ] `NSMicrophoneUsageDescription` states the actual use in one sentence, no marketing language. "BLT.ai records your voice on-device to check what you said and how you said it. Recordings are not uploaded."
- [ ] `NSSpeechRecognitionUsageDescription` present if the Speech framework is used.
- [ ] `PrivacyInfo.xcprivacy` present and accurate. Required-reason APIs must be declared with a valid reason code; `NSPrivacyTracking` is false; collected data types list is empty. An inaccurate manifest is worse than none — it's a false statement in a file that's meant to be authoritative.
- [ ] Permission denial is a first-class UI state, not an alert-and-dead-end.
- [ ] No permission is requested at launch. Request at the moment of first use, with context on screen explaining why.

## Supply chain

- [ ] SPM only. No CocoaPods, no Carthage, no vendored binaries.
- [ ] Dependencies pinned to exact versions. `Package.resolved` committed.
- [ ] Every dependency justified in one line in the README. The target count is zero to two.
- [ ] Any `.xcframework` or binary target has a checksum in the manifest.
- [ ] Core ML model files have a SHA-256 recorded in the repo, verified by a build-phase script. Bundled model weights are executable-adjacent content and deserve the same integrity treatment as a binary dependency.
- [ ] Dependabot or equivalent enabled.

## Input handling

Treat bundled content JSON as untrusted. It's authored by you today; it may be authored by a contributor, generated by a script, or edited by an agent tomorrow.

- [ ] Content JSON is schema-validated at load. Phoneme spans bounds-checked against string length.
- [ ] Audio filenames from JSON are resolved against the bundle by identifier lookup, never by string-concatenating a path. A `../` in a filename must not be able to reach outside the bundle.
- [ ] Malformed item in release: skipped and counted, not crashed on, not rendered.
- [ ] Imported lessons (DECISIONS 036) get the same schema validation as bundled content, all or nothing; stored with `.completeFileProtection` under a hashed name (never the user's file name); no `UIFileSharingEnabled`, no document types, no network API.
- [ ] No `try!` or force-unwrap on anything derived from file contents.

## Concurrency

Swift 6 strict concurrency is a security control here, not just hygiene — the audio path is the one place in this app where a data race is plausible and would be hard to diagnose.

- [ ] Strict concurrency set to `complete`, not `targeted`.
- [ ] Zero `@unchecked Sendable`. If one appears, it's masking a real race; ask the agent to solve it rather than silence it.
- [ ] Zero `nonisolated(unsafe)`.
- [ ] The `AVAudioEngine` tap closure captures only locals. No `@MainActor` access inside it.
- [ ] No `DispatchSemaphore` bridging async to sync.

## Logging

- [ ] No transcripts, no file paths, no scores in release logs. Use `Logger` with `privacy: .private` on anything user-derived.
- [ ] No `print()` in the shipping target. Lint rule enforced.
- [ ] Debug-only diagnostics wrapped in `#if DEBUG`.

## Repo hygiene

- [ ] No API keys, no provisioning profiles, no `.p12`, no team identifiers in tracked files.
- [ ] `.gitignore` covers `xcuserdata`, `DerivedData`, `*.xcconfig`, `*.mobileprovision`.
- [ ] Secret scanning enabled on the GitHub repo.
- [ ] No raw participant audio from the calibration study committed. Consent forms for those recordings stored outside the repo. If you publish the calibration data, it's de-identified and consented for that use.
- [ ] Licence file present. Audio assets' licensing stated explicitly and separately from the code licence — the two are almost never the same, and conflating them is the most common licensing error in projects like this.

---

## Reviewing agent-written Swift

Failure modes to look for specifically, roughly in order of how often they show up:

1. **Silent fallback.** Code that degrades to a network path, a cloud recognizer, or a default value rather than surfacing an error. Grep for `?? ` on anything security-relevant.
2. **Permission assumed.** A happy path written as though authorisation always succeeds.
3. **Concurrency silenced.** `@unchecked Sendable` or `nonisolated(unsafe)` added to make a warning go away.
4. **Scope creep in dependencies.** A package pulled in for one utility function.
5. **Over-broad file access.** Writing to `tmp` or a shared container because it was easier.
6. **Logging the interesting thing.** Transcripts and scores logged during debugging and never removed.
7. **Validation dropped.** Schema checks written in one PR and bypassed in the next when they're inconvenient.

Ask for the diff of the security-relevant files specifically rather than reviewing everything at equal depth. `AudioRecorder`, the content loader, the composition root, `Info.plist`, `PrivacyInfo.xcprivacy`, and `Package.resolved` are where the risk lives. The SwiftUI view code is not.
