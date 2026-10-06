# BLT.ai v1 plan: text-only English→Tamil multiple choice

Supersedes the Phase 1–5 ordering in `BUILD_PLAN.md` for v1. Read with DECISIONS 024–029. Voice is v2 and is out of scope here.

Paths are relative to the repo root. `K/` = `Packages/BLTKit/`. `APP/` = `BLTApp/BLTApp/` (app sources), `UITESTS/` = `BLTApp/BLTAppUITests/`. The Xcode project is `BLTApp/BLTApp.xcodeproj`.

## 1. v1 definition

**Screens.** Scenarios (home) → Question → Feedback → (next / finished). Progress and Settings are reachable from home.

**Question.** The English `sourcePrompt` plus exactly four shuffled options: the `canonical` form, the `registerVariant` (the same sentence in the other spoken register) when the item has one, and 2 or 3 `distractors` so the total is always four. The prompt names the audience ("to a friend", "to an elder") whenever the item has a register.

**Feedback (three states, never red).**
1. **Correct** — chose `canonical`. Affirming tone.
2. **Right sentence, wrong register for this person** — chose `registerVariant`. Nudge tone: says what to use with whom, shows the canonical form.
3. **Not quite** — chose a distractor. Neutral tone: shows the canonical form, says the item will return shortly.
Feedback also shows the word-by-word gloss (`tokens`) and `note`. The gloss is never shown on the Question screen, because it would give the answer away.

**Review status.** Items with `reviewStatus: unreviewed` show an "Unreviewed draft" badge on Question and Feedback; scenario cards show "n of 20 reviewed"; Settings states it plainly (DECISIONS 025).

**Scheduling.** SM-2 style. Ease factor starts at 2.5, floor 1.3; intervals 1, 6, then ×EF, capped at 365 days.
- `correct`: quality 5, normal steps.
- `wrongRegister`: quality 3; repetitions do not increase; interval 1 day.
- `wrong`: quality 1; repetitions reset; due now; requeued in the session.
- **Learned** = repetitions ≥ 2 and last outcome `correct`.
- **Register accuracy** = correct ÷ (correct + wrongRegister), over attempts on items that have a register variant; "—" until there is one. (Neutral items cannot produce `wrongRegister`.)

**Session.** Due items in the scenario (earliest first), then unseen items in content order, up to 10; if nothing is planned, "Review anyway" picks the 10 earliest-due. A wrong item is reinserted 3 positions later, at most twice, with options reshuffled. Only the first presentation of an item per session is recorded and scheduled.

**Persistence.** One JSON file in Application Support behind `ProgressStore` (DECISIONS 028). **No network, no audio, no speech, no UserDefaults** in v1.

**Content.** 5 scenarios × 20 items in `content/*.json`, Claude-drafted and labelled `unreviewed` (DECISIONS 025–027). Code never contains real Tamil.

**Deferred to v2:** audio, recorder, player, transcriber, transliterator, pronunciation ladder, "keep my recordings", Task 0.1 (device probe), register rules classifier, Phase 3.

## 2. Content schema (frozen; the loader reads exactly this)

```json
{ "scenarioId": "s01-greetings", "title": "", "subtitle": "",
  "registerPolicy": "", "romanisationNote": "",
  "items": [{
    "id": "s01-i01", "sourcePrompt": "",
    "register": "casual | respectful | neutral",
    "addressee": "male | female | any",
    "canonical": "", "acceptedAnswers": ["3 to 6, includes canonical"],
    "registerVariant": "string, or null iff register is neutral",
    "distractors": ["2 when registerVariant exists, else 3"],
    "tokens": [{"tamil": "", "english": ""}],
    "note": "string or null", "reviewStatus": "unreviewed | reviewed" }] }
```

Validation rules: exactly 4 distinct options (case-insensitive, trimmed); `canonical` in `acceptedAnswers`; no option other than `canonical` in `acceptedAnswers`; `registerVariant == null` iff `register == neutral`; 3–6 accepted answers; `tokens` non-empty; every `tokens[].tamil` word appears (case-insensitive) in `canonical`; no Tamil-script code points (this is Latin-script English words and romanised Tamil only); unknown keys ignored; unknown `reviewStatus` is an error, never defaulted; ≤ 200 items per file, ≤ 1 MB per file, ≤ 500 characters per string.

## 3. Human-gated items (with defaults)

| # | Item | Status / default |
|---|---|---|
| H1 | Xcode shell | **Done** (`BLTApp/BLTApp.xcodeproj`, iOS 27, `ai.blt.app`). |
| H2 | Add `content/` to the app target as a **folder reference** (blue folder), so files land in `Bundle.main/content/` | Needed before C10. Xcode: drag `content` into the project, choose "Create folder references", tick the BLTApp target. |
| H3 | Native review of content | Ships all `unreviewed`; a second Tamil speaker promotes items by editing `reviewStatus` in a PR that touches `content/` only. Uncertain items are listed in the content review. |
| H4 | CI | Pin GitHub Actions by commit SHA (agents cannot look these up). Run on `pull_request` and pushes to `main`. |
| H5 | Review each merged wave | Human reviews against §7 before the next wave starts. |
| H6 | v2 only | Physical-device checks, Task 0.1, native recording sessions. |

## 4. Standards for every chunk

- **Worktree:** `git worktree add ../blt.ai-wt/<ID> -b v1/<id-slug> main`.
- **Simulator:** each parallel agent uses a *different* device from `xcrun simctl list devices available` (iPhone 17, 17e, Air, 18 Pro, 18 Pro Max); set `BLT_SIM` accordingly. Own `-derivedDataPath`.
- **Test command:** `scripts/test.sh package [-only-testing:<Target>]` (wraps `xcodebuild -scheme BLTKit-Package -destination "platform=iOS Simulator,name=$BLT_SIM" test` in `K/`) and `scripts/test.sh app`.
- **Definition of done:** acceptance tests pass in Simulator; zero warnings (warnings are errors); `scripts/check-forbidden-apis.sh` clean; `swiftlint --strict` clean; only owned files touched; Swift Testing; fixtures obviously fake (`zz-…`, no real Tamil); one-paragraph summary of what changed and what the human should verify.
- **Contract change:** stop and report. Never edit a frozen contract inside a feature chunk.
- **Approval:** the chunk spec *is* the approved plan (CLAUDE.md "plan before writing" is satisfied); ask only if acceptance is ambiguous.
- **Modules:** `BLTCore`, `BLTCatalog`, `BLTProgress`, `BLTSession`, `BLTDesign`, `BLTFeatures` (prefixed; `Progress` collides with `Foundation.Progress`). Avoid the type name `ProgressView`; use `ProgressScreen`. Package: tools-version 6.2, `platforms: [.iOS(.v27)]`, one library product per module, `.treatAllWarnings(as: .error)`. Dependencies: Core none; Catalog→Core; Progress→Core; Session→Core,Catalog,Progress; Design→Core; Features→all.

## 5. Frozen Wave 0 contracts

```swift
// BLTCore
public struct ItemID: RawRepresentable, Hashable, Sendable, Codable { public let rawValue: String; public init(rawValue: String) }
public struct ScenarioID: RawRepresentable, Hashable, Sendable, Codable { public let rawValue: String; public init(rawValue: String) }
public enum ReviewStatus: String, Sendable, Codable, CaseIterable { case unreviewed, reviewed }
public enum Register: String, Sendable, Codable, CaseIterable { case casual, respectful, neutral }
public enum Addressee: String, Sendable, Codable, CaseIterable { case male, female, any }
/// The only attempt result Scheduler/ProgressStore ever see. v2 voice maps into it too.
public enum Outcome: String, Sendable, Codable, CaseIterable { case correct, wrongRegister, wrong }
public enum Verdict: Sendable, Equatable {
    case correct
    case wrongRegister(correct: String)     // chose registerVariant
    case notQuite(correct: String)          // chose a distractor -> requeue
    public var outcome: Outcome { get }
}

// BLTCatalog (domain types are not Codable; only C2's Raw* types decode)
public struct Token: Sendable, Equatable { public let tamil: String; public let english: String }
public struct Item: Sendable, Equatable, Identifiable {
    public let id: ItemID; public let scenarioID: ScenarioID
    public let sourcePrompt: String; public let register: Register; public let addressee: Addressee
    public let canonical: String; public let acceptedAnswers: [String]
    public let registerVariant: String?          // nil iff register == .neutral
    public let distractors: [String]             // 2 with a variant, else 3
    public let tokens: [Token]; public let note: String?; public let reviewStatus: ReviewStatus
}
public struct Scenario: Sendable, Equatable, Identifiable {
    public let id: ScenarioID; public let title: String; public let subtitle: String
    public let romanisationNote: String?; public let items: [Item]
}
public struct Catalog: Sendable, Equatable {
    public let scenarios: [Scenario]; public let issues: [ContentIssue]
    public func item(_ id: ItemID) -> Item?; public var allItemIDs: Set<ItemID> { get }
}
public struct ContentIssue: Sendable, Hashable {   // closed: no free text, no paths
    public enum Field: String, Sendable, Hashable, CaseIterable {
        case scenarioId, title, subtitle, id, sourcePrompt, register, addressee, canonical,
             acceptedAnswers, registerVariant, distractors, tokens, note, reviewStatus }
    public enum Rule: Sendable, Hashable {
        case notAFileURL, unreadableFile, fileTooLarge, malformedJSON
        case missingField(Field), emptyField(Field), fieldTooLong(Field), tamilScriptInField(Field), unknownValue(Field)
        case wrongDistractorCount, registerVariantMismatch, canonicalNotAccepted, otherOptionAccepted
        case wrongAcceptedCount, duplicateOptionText, duplicateItemID, duplicateScenarioID
        case tokenNotInCanonical, tooManyItems, emptyScenario }
    public let fileIndex: Int; public let scenarioID: ScenarioID?; public let itemID: ItemID?; public let rule: Rule
}

// BLTProgress
public struct ReviewState: Sendable, Equatable, Codable {
    public var itemID: ItemID; public var repetitions: Int; public var intervalDays: Int
    public var easeFactor: Double; public var due: Date; public var lastOutcome: Outcome; public var lastReviewed: Date
    public var isLearned: Bool { repetitions >= 2 && lastOutcome == .correct }
    public func isDue(at now: Date) -> Bool { due <= now }
}
public struct AttemptRecord: Sendable, Equatable, Codable { public let itemID: ItemID; public let outcome: Outcome; public let at: Date }
public struct ProgressSnapshot: Sendable, Equatable { public var reviews: [ItemID: ReviewState]; public var attempts: [AttemptRecord]; public static let empty: ProgressSnapshot }
public protocol Scheduler: Sendable {   // pure; previous == nil means first ever attempt
    func review(_ previous: ReviewState?, itemID: ItemID, outcome: Outcome, at now: Date) -> ReviewState
}
public enum ProgressStoreError: Error, Sendable, Equatable { case unreadable, corrupt, unsupportedSchemaVersion(Int), writeFailed, eraseFailed }
public protocol ProgressStore: Sendable {
    func load() async throws(ProgressStoreError) -> ProgressSnapshot
    func record(_ attempt: AttemptRecord, updating review: ReviewState) async throws(ProgressStoreError) // same itemID
    func eraseAll() async throws(ProgressStoreError)
}

// BLTSession
public struct AnswerOption: Sendable, Equatable, Identifiable {
    public enum Kind: Sendable, Equatable { case canonical, registerVariant, distractor }
    public let id: Int          // 0 canonical, 1 variant (if any), then distractors; display order = array order
    public let text: String; public let kind: Kind
}
public struct Question: Sendable, Equatable, Identifiable {
    public let item: Item; public let options: [AnswerOption]   // exactly 4, shuffled
    public var id: ItemID { item.id }
    public func verdict(for optionID: AnswerOption.ID) -> Verdict?   // nil = unknown id
}
public struct QuestionBuilder: Sendable {
    public init()
    /// nil if option count != 4 or option texts collide (trimmed, case-insensitive)
    public func makeQuestion(for item: Item, using rng: inout some RandomNumberGenerator) -> Question?
}

// BLTDesign
public enum FeedbackTone: Sendable { case affirm, nudge, neutral; public init(_ outcome: Outcome) }
public enum AccessibilityID { /* static constants: feedbackCorrect, feedbackWrongRegister, feedbackNotQuite,
   badgeUnreviewed, continueButton, progressRegisterAccuracy, progressLearned, progressDue,
   settingsReset, scenarioCard(prefix) */ }

// BLTFeatures
public struct AppDependencies: Sendable {
    public let catalog: Catalog; public let store: any ProgressStore
    public let scheduler: any Scheduler; public let now: @Sendable () -> Date
}
```

## 6. Chunks and waves

```
Wave 0: C0 (main session) ∥ C1
Wave 1: C2 ∥ C4 ∥ C5 ∥ C6 ∥ C7            (all need C0 only)
Wave 2: C3(C2) ∥ C8(C6,C7) ∥ C9(C4,C7)
Wave 3: C10(H2, C3, C8, C9)
Wave 4: C11(C10)
```
File ownership never overlaps within a wave. `Package.swift` and every §5 file belong to C0 alone.

**C0 — Package and frozen contracts** (done by the main session, not a medium-effort agent: ~20 declaration files, transcribed from §5). Owns `K/Package.swift`, all §5 files, `K/Sources/BLTDesign/{FeedbackTone,AccessibilityID}.swift`, `K/Sources/BLTFeatures/{AppDependencies,PreviewCatalog}.swift` (`#if DEBUG`, all strings start `zz`), one seed test per test target (`VerdictTests`, `ItemContractTests` with `Fixtures/valid-minimal.json`, `ReviewStateTests`, `QuestionBuilderTests`, `FeedbackToneTests`, `PreviewCatalogTests`, `ContentDirectoryTests`). *Accept:* `xcodebuild -list` shows `BLTKit-Package`; package tests pass; `Verdict.outcome` maps all 3; `QuestionBuilder` yields 4 distinct kinds, deterministic under a seeded generator, `nil` on collision or wrong option count; `isLearned` truth table; `FeedbackTone(.wrong) == .neutral`; `ContentDirectoryTests` finds `content/*.json` via `#filePath`.

**C1 — Guardrails** (Wave 0). Owns `.swiftlint.yml`, `scripts/check-forbidden-apis.sh`, `scripts/test.sh`, `.github/workflows/ci.yml`, `.gitignore`. Script (bash/grep/perl only) scans `K/{Sources,Tests}`, `APP/`, `UITESTS/` for the §7 bans; `EXEMPT_PATHS=()` empty in v1; `--self-test` checks every pattern against inline samples. **Also fails on** `ENABLE_OUTGOING_NETWORK_CONNECTIONS`, `ENABLE_INCOMING_NETWORK_CONNECTIONS`, `com.apple.security.network.*`, `NSAppTransportSecurity`, `NS*UsageDescription` keys, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace` anywhere in the project or plists. `test.sh` takes `package|app`, uses `BLT_SIM` (default "iPhone 17"). CI: script, pinned SwiftLint with SHA-256 check, package tests, app tests. *Accept:* `--self-test` exits 0 and every seeded pattern is detected; script exits 0 on the current tree.

**C2 — Content loader and validator** (Wave 1, iPhone 17). Owns `K/Sources/BLTCatalog/{ContentLoader,ContentValidator,RawScenario,RawItem}.swift`, `K/Tests/BLTCatalogTests/{ContentValidatorTests,ContentLoaderTests}.swift`, `Fixtures/*`. `ContentLoader(limits:).load(files:) -> Catalog` never throws; every problem becomes a `ContentIssue`; raw types are all-optional. *Accept:* one test per §2 rule, plus: non-file URL rejected; invalid items skipped and counted while valid siblings survive; unknown keys (e.g. `romanisationNote`, `registerPolicy`) tolerated; scenarios sorted by ID; Latin-script English words (e.g. `bus`, `GPay`) are *not* flagged; a Tamil-script code point in a field is (fixture uses `"\u{0B85}"`).

**C4 — SM-2 scheduler and summary** (Wave 1, iPhone 17e). Owns `K/Sources/BLTProgress/{SM2Scheduler,ProgressSummary}.swift` and tests. *Accept:* table-driven (e.g. `correct`×3 gives intervals 1, 6, 15, EF 2.5→2.6); `wrongRegister` keeps repetitions, interval 1, EF −0.14; `wrong` resets repetitions, due now; EF ≥ 1.3; interval ≤ 365; pure; summary: register accuracy `nil` with no variant-item attempts; learned and due counts restricted to known items; due includes `due == now`.

**C5 — Progress stores** (Wave 1, iPhone Air). Owns `K/Sources/BLTProgress/{FileProgressStore,InMemoryProgressStore,ProgressFile}.swift` and `FileProgressStoreTests`. `actor FileProgressStore(fileURL:)` stores `{schemaVersion:1, reviews, attempts}`; atomic write with `.completeFileProtection`; missing file → `.empty`; corrupt → throws `.corrupt`, **never overwritten**; future schema → `.unsupportedSchemaVersion`; `eraseAll` unlinks. *Accept:* round trip; corrupt and v2 rejected; erase leaves no file; 50 concurrent `record` calls lose nothing; in-memory store behaves identically (shared test).

**C6 — Session engine** (Wave 1, iPhone 18 Pro). Owns `K/Sources/BLTSession/{SessionPlanner,SessionMachine,SessionResult,QuestionBuilder}.swift` and tests. `SessionPlanner.plan(scenario:snapshot:now:limit:)`; `SessionMachine` states `.asking(Question)`, `.feedback(Question, chosen:, verdict:)`, `.finished(SessionResult)`; `choose(_:using:)` returns an `AttemptRecord` only for an item's first presentation; illegal events are no-ops. *Accept:* planner orders due before new, respects the cap, offers review-anyway; every legal transition; a wrong answer requeues at +3 (or the end), max twice, reshuffled, recording nothing; all 3 verdicts reached; `finished` counts first attempts by outcome; no SwiftUI import.

**C7 — Design system** (Wave 1, iPhone 18 Pro Max). Owns `K/Sources/BLTDesign/{Palette,OptionButton,GlossView,ReviewStatusBadge}.swift`, `PaletteTests`. Explicit light/dark palette: one tone each for affirm, nudge, neutral; no `.red`/`systemRed`. Option button: ≥44 pt target, Dynamic Type, VoiceOver label. `GlossView` takes plain strings (no Catalog dependency) in a wrapping layout. *Accept:* no palette hue within 345–15° (or saturation < 0.2); WCAG contrast ≥ 4.5:1 in both schemes; `#Preview`s.

**C3 — Shipped-content conformance** (Wave 2, iPhone 17; needs C2). Owns `K/Tests/BLTContentTests/{ShippedContentTests,NoContentInCodeTests}.swift`. *Accept:* every `content/*.json` loads with zero issues and exactly 20 items; exactly 5 files; no `.swift` file in `K/`, `APP/`, `UITESTS/` contains, as a quoted literal, any content option or accepted-answer string of 5+ characters; no Tamil-script code point in any `.swift` file.

**C8 — Session UI** (Wave 2, iPhone 17e; needs C6, C7). Owns `K/Sources/BLTFeatures/Session/{SessionViewModel,SessionView,QuestionView,FeedbackView}.swift` and `SessionViewModelTests`. `@MainActor @Observable` view model: on `choose`, if the machine returns a record, call `scheduler.review` then `store.record`; a store error sets a visible, non-blocking `saveFailed`. Feedback shows verdict, then canonical form, gloss and note; badge for unreviewed items; 150 ms crossfade (a cut under Reduce Motion); apply `AccessibilityID`s. *Accept:* with the in-memory store, the three verdicts produce the expected stored records; a requeue writes nothing; a failing stub store surfaces `saveFailed`; previews build.

**C9 — Home, Progress, Settings** (Wave 2, iPhone Air; needs C4, C7). Owns `K/Sources/BLTFeatures/Home/{HomeViewModel,ScenariosView}.swift`, `K/Sources/BLTFeatures/ProgressScreen/ProgressScreen.swift`, `K/Sources/BLTFeatures/Settings/SettingsView.swift`, `HomeViewModelTests`. *Accept:* per-scenario due, new and "n of 20 reviewed" counts; figures match `ProgressSummary`; Reset goes through a confirmation, calls `eraseAll`, reloads empty; a corrupt-store error shows an error state offering Reset and **never auto-resets**; no gamification.

**C10 — App wiring** (Wave 3; needs H2, C3, C8, C9). Owns `K/Sources/BLTFeatures/RootView.swift`, `APP/{MyApp,CompositionRoot,UITestLaunch}.swift` (rename `MyApp` → `BLTAppMain`), `APP/PrivacyInfo.xcprivacy`, `scripts/check-binary.sh`. Loads `Bundle.main` `content/*.json`; non-empty issues → `assertionFailure` in DEBUG, skipped and counted via `Logger` (IDs only) in release. Store at `ApplicationSupport/BLT/progress.json`. `--uitest-fixtures` uses `PreviewCatalog`; `--uitest-reset` erases. `check-binary.sh` runs `otool -L` and `nm -u` and fails on Network, WebKit, Speech, AVFAudio, AVFoundation, `URLSession`. *Accept:* `scripts/test.sh app` passes; manifest has tracking false and empty domains/types; project file has no `INFOPLIST_KEY_NS*UsageDescription`, file-sharing keys, or ATS keys; `check-binary.sh` passes; exactly one composition root.

**C11 — UI tests and accessibility** (Wave 4; needs C10). Owns `UITESTS/{FeedbackFlowUITests,PersistenceUITests,AccessibilityUITests}.swift`. *Accept:* with fixtures, tapping canonical, register-variant and distractor options reaches the respective feedback IDs; a wrong item reappears later in the session; the badge shows for an unreviewed fixture and not a reviewed one; Progress counts update and survive terminate-and-relaunch; `performAccessibilityAudit()` passes on all five screens at default and `accessibilityXXXL` sizes.

## 7. Review checklist for every PR

- **Network ban** (script + CI; exemption list empty in v1): no `URLSession`, `NSURLConnection`, `NWConnection`, `NWPathMonitor`, `CFStream`, `CFSocket`, `getaddrinfo`; no `WKWebView`, `AsyncImage`, `Link(`, `openURL`, `SFSafariViewController`, `ASWebAuthenticationSession`; no `import Network/WebKit/SafariServices/CloudKit/MultipeerConnectivity`; no `http` URL literals; `Data(contentsOf:)` only after an `isFileURL` check; project has no network entitlements.
- **No audio or speech in v1:** no `AVFoundation`, `AVFAudio`, `Speech`, `AVAudio*`, `SFSpeech*`, or `NS*UsageDescription`.
- **Concurrency:** no `@unchecked Sendable`, `nonisolated(unsafe)`, `DispatchSemaphore`; Swift 6, complete strict concurrency, zero warnings.
- **Logging:** no `print(`, `debugPrint(`, `NSLog(`; `Logger` only, `privacy: .private` on anything user-derived; no outcomes or answers in release logs.
- **Safety:** no `try!`, no force-unwrap on decoded data, no silent defaults; watch `??`, and never default `reviewStatus`.
- **Content stays in data files:** no Tamil script in `.swift`; C3's no-content-in-code test passes; fixtures are `zz-` fakes; a PR touching `content/` touches no Swift, and vice versa.
- **reviewStatus surfaced:** badge wherever an item's Tamil is shown; scenario cards show the reviewed count; Settings statement present.
- **Never red:** no `.red`/`systemRed`; feedback colour only from `FeedbackTone`.
- **Privacy manifest:** any new `UserDefaults`, `@AppStorage`, file-timestamp, uptime or disk-space API updates `PrivacyInfo.xcprivacy` in the same PR.
- **Supply chain:** `Package.resolved` absent or unchanged (zero dependencies); CI actions pinned by SHA.
- **Scope:** only the chunk's owned files changed; frozen §5 contracts unchanged; one type per file; no singletons; dependency injection at the composition root only.
- **Hygiene:** no team ID, `.xcconfig` or profiles; Xcode did not re-add network or sandbox settings to `project.pbxproj`.

## 8. Dispatch

After C0 merges, Wave 1 launches as five parallel Sonnet agents, one worktree each. Per-agent prompt: *"Chunk <ID> of `docs/MVP_PLAN.md` is your approved plan. Read CLAUDE.md, DECISIONS 024–029, and §2, §4, §5, and your chunk in `docs/MVP_PLAN.md`. Use simulator `<device>`. Stop and report if a contract must change."* Merge each wave's branches one at a time, running the full package tests after each merge, and review against §7 before the next wave.
