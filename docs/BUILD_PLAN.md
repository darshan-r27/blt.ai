# BLT.ai — 0 to 1

> **Status (2026-10-07): this is the v2 (voice) design.** v1 shipped as text-only multiple choice. For what exists, read [`ARCHITECTURE.md`](ARCHITECTURE.md), [`MVP_PLAN.md`](MVP_PLAN.md) and `DECISIONS.md` 024 to 037. Since 2026-10-09 the product has two courses, Tamil and Telugu (DECISIONS 042): the voice phases below apply to both languages, and the work in progress is `plan.md` in the repo root.

Sequenced build plan. Each task is one PR, has explicit acceptance criteria, and is sized for a single Claude Code session. Work them in order; the dependency chain is real.

**Aligned to PRD v7.** Phase 6 is the opt-in telemetry backend, and is v1.5 — do not start it before Phase 5 ships.

**Phase 3 scope.** Phase 3 is semantic acceptance, register classification, and the pronunciation tolerance ladder.

**How to use this with Claude Code:** paste the task block as the prompt, with `docs/PRD.md` and `docs/SECURITY.md` in context. Do not paste more than one task at a time — the acceptance criteria are what keep the agent honest, and they get diluted when batched.

---

## Phase 0 — Answer the blocking questions (before any code)

### Task 0.1 — Device capability probe

Build a throwaway single-view iOS app that prints, on a **physical device**:

```swift
print(SFSpeechRecognizer.supportedLocales().map(\.identifier).sorted())
print(AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language.hasPrefix("ta") || $0.language.hasPrefix("te") }
        .map { "\($0.language) \($0.name) \($0.quality.rawValue)" })
```

If targeting iOS 26+, also check `SpeechTranscriber.supportedLocales`.

**Acceptance:** output pasted into `docs/DECISIONS.md` with device model and OS version. The Speech framework does not work in Simulator, so this must run on hardware.

**Why first:** if `ta-IN` isn't supported, the week-2 placeholder engine has to wrap whisper.cpp instead of Apple's framework, which changes the week-1 dependency decision.

### Task 0.2 — User interviews

Recruit 8–10 Telugu L1 speakers, 20–35, who want to learn Tamil. Ask one question and shut up: *what have you wanted to say to a Tamil speaker and couldn't?*

**Acceptance:** `docs/RESEARCH.md` with raw notes and a ranked list of situations. Your 8 scenarios come from this list, not from your own guesses.

### Task 0.3 — Pick a romanisation scheme

Open question in PRD §11. The register rules in PRD §8.2 are written against surface forms, so this decision is load-bearing for Phase 3 and cannot be deferred past content authoring.

Write out 20 sample utterances in both ISO 15919 and in WhatsApp-style ad-hoc Latin. Show them to two native speakers. Pick one.

**Acceptance:** an ADR in `docs/DECISIONS.md` naming the scheme, with the sample sheet attached. Every downstream doc and content file uses it consistently.

---

## Phase 1 — Walking skeleton (weeks 1–2)

Goal: an end-to-end loop with three hardcoded items and deliberately crude scoring. Prove the audio pipeline before investing in content or ML.

### Task 1.1 — Project scaffold

Create an Xcode project named `BLTApp` with display name `BLT.ai` and bundle id `ai.blt.app` — module names can't contain dots. iOS 27 deployment target (DECISIONS 029), SwiftUI lifecycle, Swift 6 language mode with strict concurrency set to `complete`. SPM only. Set up the module folder structure from PRD §7. Add SwiftLint with a committed config. Add a GitHub Actions workflow that builds and runs tests on every push.

**Acceptance:** clean build with zero warnings under strict concurrency. CI green. `.gitignore` covers `xcuserdata`, `*.xcconfig`, `DerivedData`.

### Task 1.2 — Content schema and loader

Define `Scenario` and `Item` as Codable structs. Item carries:

| Field | Type | Note |
| --- | --- | --- |
| `id` | String | unique, stable |
| `canonical` | String | the colloquial Tamil form, romanised |
| `audioFile` | String | bundle resource name |
| `acceptedAnswers` | [String] | 3–6 paraphrases, includes `canonical` |
| `formalVariant` | String | deliberately textbook phrasing, for the register classifier |
| `teluguGloss` | String | |
| `teluguPrompt` | String | the situation description shown in beat 2 |
| `distractors` | [String] | exactly 3, for beat 1 |
| `targetPhones` | [PhoneSpan] | `{phone, index, length}` into `canonical`. Which sounds this item exercises. |

Write a loader that reads bundled JSON and **validates it** — every referenced audio file exists, `canonical` appears in `acceptedAnswers`, `formalVariant` does *not*, exactly three distractors, no duplicate ids, no empty strings, every `targetPhones` span in bounds of `canonical`. Fail loudly at launch in debug, skip the malformed item in release.

**Acceptance:** unit tests covering each validation failure mode. Treat the bundled JSON as untrusted input even though you authored it (see SECURITY.md).

### Task 1.3 — Audio capture

`AudioRecorder` using `AVAudioEngine`. Hold-to-record with level metering for the waveform. Write to the app container, not `tmp`. Handle: permission denied, permission not yet requested, interruption by a phone call, route change when headphones are unplugged, and app backgrounding mid-recording.

The mic tap closure runs on a real-time audio thread. Capture only locals inside it — never touch a `@MainActor` object, and do not reach for `@unchecked Sendable` to make it compile.

**Lifecycle is part of this task, not a later cleanup.** Two mechanisms:

- **Unconditional deletion.** The unlink goes in a `defer` at the top of the scoring path, never at the end of a success branch. A scoring failure must still delete the file. This is the likely accidental-retention path.
- **Launch-time orphan sweep.** On every launch, before anything else runs, clear the recording directory. A crash or force-quit between recording and scoring leaves a file no in-session path will ever reach, and that is how audio accumulates without anyone intending it. When "keep my recordings" is on, the sweep clears only files with no corresponding attempt record.

**Acceptance:** all five failure paths have a UI state and a test. No `@unchecked Sendable` anywhere in the file. Four lifecycle tests assert the recording directory is empty after: a successful attempt, a scoring failure, a mid-attempt interruption, and a simulated crash-then-relaunch. Without those four, SECURITY.md P2 is a policy statement rather than a tested property.

### Task 1.4 — Playback

`AudioPlayer` for bundled AAC. Replay, speed control at 0.75× and 1.0× via `AVAudioUnitTimePitch` — preserve pitch, because resampling makes elided colloquial speech harder to parse, not easier. Configure `AVAudioSession` so record and playback coexist without a category thrash on every transition.

**Acceptance:** rapid alternation between playback and record does not drop audio or produce a session error.

### Task 1.5 — ExactMatchEngine

Implement `ScoringEngine` using whatever ASR Task 0.1 said is available. Normalise the transcript (lowercase, strip punctuation, collapse whitespace), then exact-match against `acceptedAnswers`. Return `.understood` or `.notUnderstood`. Never returns `.understoodButFormal` — that's Phase 3.

This is the placeholder. Do not optimise it. Do not let anything upstream depend on its concrete type.

**Acceptance:** conforms to the protocol. Is referenced exactly once, at the composition root.

### Task 1.6 — Session state machine

The three-beat loop as an explicit state machine: `listening → comprehending → producing → scoring → feedback → next`. Make illegal transitions unrepresentable — use an enum with associated values, not a bag of booleans.

`Verdict` is a three-case enum from the start (`understood`, `understoodButFormal(colloquial: String)`, `notUnderstood`), even though Phase 1 only ever produces two of them. Adding the case later means touching every switch in the app.

`Verdict` also carries `pronunciation: PronunciationSignal?`. Phase 1 always sets it nil. It is **advisory only** — no progression, scheduling, or verdict logic may read it. Model this so the constraint is visible: keep the signal out of any equatable or comparable conformance used for progression.

**Acceptance:** state machine is unit-testable with no UIKit/SwiftUI import. Tests cover every legal transition. All three verdict cases exhaustively handled. A test asserts that two verdicts differing only in `pronunciation` produce identical progression outcomes.

### Task 1.7 — Session UI

Build the three beats per the wireframe. No animation beyond a 150ms opacity crossfade between beats. No images. Dynamic Type support and VoiceOver labels on every control — an audio-first app that fails a screen reader user is an embarrassment you will be asked about.

**Acceptance:** full VoiceOver pass. Largest accessibility text size doesn't clip. Reduce Motion respected.

**Phase 1 exit:** three hardcoded items, end to end, on a real device.

---

## Phase 2 — Content (weeks 3–4)

Runs partly in parallel with Phase 1; the recording session has a lead time. Heavier than v1 because of the paraphrase and register fields.

### Task 2.1 — Script the scenarios

8 scenarios from the Task 0.2 research, 12–15 items each. Write the canonical form in genuinely colloquial Tamil. The default failure mode is writing formal Tamil without noticing, because that's what's written down everywhere.

### Task 2.2 — Author paraphrases and formal variants

For each item: 3–6 accepted paraphrases, plus one deliberately formal variant.

The paraphrases must be things a Tamil speaker would actually accept, not translations of each other. Get these from the native speakers directly — ask "what else could someone say here?" rather than generating and asking for approval, which produces agreement bias.

The formal variant is the register classifier's target. Write it as a textbook would: full -ுங்கள் endings, unreduced -கிற- present tense, அவர்கள் rather than அவங்க.

**Acceptance:** every item has ≥3 paraphrases and exactly 1 formal variant. Spot-check 20 items with a second native speaker who didn't author them.

### Task 2.3 — Register red-line

Two native speakers, 20–35, mark every canonical form that sounds like a newsreader. Expect to rewrite 30–40% on the first pass. This is the highest-leverage two hours in the project.

### Task 2.4 — Build the register rule set

From the authored canonical/formal pairs, extract the morphological patterns. Target ~40 rules covering polite imperative, present tense, 3rd neuter, plurals, and genitives, plus a lexicon of formal/colloquial word pairs.

This is content work, not code — produce a JSON rule file that Task 3.4 consumes.

**Acceptance:** the rule set correctly classifies every authored formal variant as formal, and every canonical form as colloquial. If it can't, the rules are too narrow or the content is inconsistent. Both are worth knowing now.

### Task 2.5 — Build the minimal-pair confusion table

~30 Tamil word pairs differing only in ழ/ள/ல, ற/ர, or ண/ந, with glosses for both. Per PRD §8.3. This table is both the semantic-acceptance safety net and the v1 pronunciation detector, so it earns more care than its size suggests.

**Acceptance:** JSON file, each entry with both romanised forms and both English glosses. Reviewed by a native speaker for whether the pair is genuinely confusable in speech. Coverage check: every word in the content that contains a `targetPhones` span either appears in the table or is confirmed to have no confusable partner.

### Task 2.6 — Annotate target phoneme spans

Mark which sounds each item exercises, as character spans into `canonical`. ~120 items, done by hand. Tedious and worth doing properly — these spans are what the tolerance ladder counts.

**Acceptance:** every item has ≥0 spans (some items legitimately exercise none), all spans in bounds, spot-checked against the audio for 20 items.

### Task 2.7 — Record

Two Tamil speakers, one session, quiet room, cardioid condenser, 48kHz/24-bit. Record each canonical form twice. Paraphrases need no audio.

Also record the calibration set: 6 Telugu-L1 learners **and 3 native speakers** attempting the same 30 items (PRD §8.4). The native recordings establish the level-5 cap and prove the detector isn't flagging correct speech — do not skip them to save an hour.

**Acceptance:** normalised to -16 LUFS, trimmed, converted to AAC, named by item id. Raw WAVs archived outside the repo. Consent forms for the calibration speakers stored outside the repo.

### Task 2.8 — Telugu prompts

Generate with AI4Bharat Indic-TTS. These are scaffolding, not the learning target, so synthetic is fine.

---

## Phase 3 — Real scoring (weeks 5–7)

The part that makes this a portfolio piece rather than a tutorial project.

### Task 3.1 — Convert IndicConformer to Core ML

Take `ai4bharat/indicconformer_stt_ta_hybrid_ctc_rnnt_large`, export via `coremltools`. Quantise to 8-bit and measure the WER delta on the calibration set — do not assume it's negligible.

**Acceptance:** model runs on device, latency measured for a 3-second utterance, WER before and after quantisation recorded in `docs/DECISIONS.md`.

### Task 3.2 — Convert a sentence encoder to Core ML

Candidates: distilled LaBSE, IndicBERT. The open question from PRD §11 is which survives 8-bit quantisation with usable cosine separation on short, romanised, ASR-noisy Tamil.

Do not pick on reputation. Build a small harness: embed the accepted-answer sets from 30 items, embed 30 learner transcripts from the calibration set, and measure separation between in-set and out-of-set pairs for each candidate at fp16 and int8.

**Acceptance:** a table in `docs/DECISIONS.md` comparing candidates on separation, model size, and on-device latency. Target under 100ms on an A15. The chosen model named with reasoning.

### Task 3.3 — Semantic acceptance

Exact match against `acceptedAnswers` first — it's cheap and catches the median case. Only on miss, embed the transcript and take max cosine similarity against the set. Above threshold, accept.

**Acceptance:** unit tests with fixture transcripts. The exact-match fast path is measurably faster than the encoder path, proven by a benchmark test, not asserted.

### Task 3.4 — Register classifier

Consume the rule file from Task 2.4. Given an accepted transcript, return colloquial or formal, and when formal, the colloquial form to show.

Rules apply to surface forms, so this depends on the Task 0.3 romanisation decision. If that decision changes, this file is rewritten.

**Acceptance:** classifies all ~120 canonical forms as colloquial and all ~120 formal variants as formal. Every rule has a unit test with a positive and a negative case. No rule fires on a form it wasn't written for.

### Task 3.5 — Minimal-pair policy and pronunciation detection

Implement PRD §8.3. When the transcript differs from an accepted answer *only* by a substitution in the Task 2.5 confusion table, accept the attempt semantically and attach a `PronunciationSignal` naming the substitution.

The same pass produces the v1 pronunciation score: for each `targetPhones` span in the item, decide whether the transcript shows the target phone or a confusable substitute. Output is a per-attempt fraction of spans cleared.

**Acceptance:** tests for the three semantic cases — substitution only (accept + signal), substitution plus another error (reject), no substitution (normal path). Plus: a fully correct attempt produces a signal with 100% spans cleared and no user-visible note. An item with zero spans produces a nil signal, not a zero score.

### Task 3.6 — Tolerance ladder

Implement PRD §8.5. A `ToleranceLevel` type holding the five rungs and their thresholds, a rule for advancement (sustained performance over 30 attempts), and persistence of the user's current level.

Three constraints that are easy to get wrong:
- Level 1 records signals but shows nothing.
- Advancement is one-way. No demotion in v1.
- Level 5's threshold is read from the measured native baseline (Task 3.7), not hardcoded at 85% or 100%.

**Acceptance:** unit tests for every rung transition, including the boundary case at exactly threshold. A test asserts no path exists from a higher level to a lower one. A test asserts level 5's threshold never exceeds the configured native baseline.

### Task 3.7 — Calibration

Set thresholds from the calibration recordings. Three separate jobs.

**Semantic acceptance.** Optimise for low false rejection — telling a learner their valid paraphrase is wrong is the fastest way to lose them.

**Register classifier.** Measure the false-positive rate on "that's formal." Target near zero, even at the cost of missing genuine formality.

**Pronunciation.** Measure the native baseline per target phoneme from the 3 native recordings. This caps level 5. Then plot the learner and native distributions together and check they separate. If they don't, the detector is not measuring what you assume, and the ladder is built on sand — stop and diagnose before wiring it to UI.

**Acceptance:** three confusion matrices in the repo, a plot of acceptance rate against threshold, and a learner-vs-native distribution plot per phoneme. Native baseline recorded in `docs/DECISIONS.md` as a number the code reads, not a comment.

### Task 3.8 — Swap in SemanticEngine

Change one line at the composition root. If it's more than one line, Task 1.5 was done wrong.

### Task 3.9 — Feedback UI

Build the three verdict states from PRD §5 beat 3. The `understoodButFormal` state is the most important surface in the app — it gets the side-by-side, the native audio of the colloquial form, and copy that frames formality as a stylistic miss rather than an error. Nothing red.

The pronunciation line sits beneath the verdict: muted text, no colour, no icon, no numeric score, dismissible. Suppressed entirely at level 1, and never shown on a `notUnderstood` verdict — one correction at a time.

**Acceptance:** all three verdict states reachable in a UI test, each with and without a pronunciation signal. A test asserts the line is absent at level 1 and absent on `notUnderstood` at every level. VoiceOver reads the verdict before the transcript, and the pronunciation line last.

---

## Phase 4 — Progress and polish (week 8)

### Task 4.1 — SwiftData persistence
Attempts, verdicts, register outcomes, pronunciation signals, current tolerance level, item scheduling. Store the signal, not the audio.

Persist the raw per-attempt span fraction rather than a pass/fail against the level in force at the time. Thresholds will move between versions, and a stored boolean cannot be re-evaluated against a new ladder — a stored fraction can.

### Task 4.2 — Spaced repetition
SM-2 over items, with one modification: an item that scored `understoodButFormal` re-enters the queue sooner than one that scored `understood`. Register is the thing being taught, so it should drive scheduling.

### Task 4.3 — Progress screen
Comprehension accuracy, production accuracy, colloquial rate, and pronunciation rate per target phoneme, over time. Colloquial rate is the headline. Current tolerance level shown with the next rung's requirement stated plainly — "clear 65% to reach Clear" — so advancement is legible rather than mysterious. Items due, total speaking time. No streak, no XP.

### Task 4.4 — Settings
Default playback speed, recording retention, delete all data, export JSON, licences.

### Task 4.5 — Privacy manifest
`PrivacyInfo.xcprivacy`, honest `NSMicrophoneUsageDescription`. See SECURITY.md.

---

## Phase 5 — The artifact (week 9)

For a portfolio piece this phase is not optional. It is the phase a hiring manager actually consumes.

### Task 5.1 — README
Problem, thesis, architecture diagram, the three decisions you'd defend, what you'd do differently. Two minutes to read.

### Task 5.2 — Decision log
`docs/DECISIONS.md` as lightweight ADRs. The interesting ones:

- iOS 17 over 26, and what that cost (superseded: iOS 27 per DECISIONS 029)
- zero-network as a hard constraint
- the `ScoringEngine` protocol boundary, and why the placeholder was safe
- pronunciation measured but never gating — the two-knob split between a calibrated detection threshold and an adaptive tolerance, and why one knob doing both jobs gets messy by month three
- 75% as the v1 ceiling, and why the top rung is capped at the measured native baseline rather than 100%
- a rule set rather than a model for register classification
- telemetry opt-in and off by default, and why "no raw user content is retained" replaced the inaccurate "ZDR" framing
- the identity arc: anonymous ID → no identity → named profile, and why the middle step was the one that clarified the requirement
- three-tier diagnostics with no third-party crash SDK, and what that trade costs
- the breadcrumb enum — enforcing a privacy rule in the type system rather than in review
- presenting one learner's curve as a case study rather than as a cohort finding
- excluding transcripts from telemetry despite their diagnostic value
- reporting a modelled LTV sensitivity table rather than a CLV figure
- romanisation scheme
- sentence encoder selection, with the comparison table from Task 3.2

The pronunciation design is the best interview material here. The arc is worth telling straight: it was in scope, cut as pedagogically wrong, then restored as measurement-without-gating on a progressive ladder. The final design is better than the original precisely because it went through the cut — a reviewer who asks "why not just score pronunciation?" gets a real answer rather than a defensive one.

### Task 5.3 — Validation study
Pre/post with the 8–10 recruits from Task 0.2. Held-out items. Primary measure is colloquial rate; pronunciation rate is secondary and reported without a success claim attached, since v1 does not teach it. Report the result honestly including if it's null — a null result you diagnosed is a stronger signal than a positive one you didn't question.

### Task 5.4 — Demo video
90 seconds. Screen recording with audio. No slides. Show the loop, show the `understoodButFormal` state catching a textbook phrasing, show the progress screen.

### Task 5.5 — TestFlight
Internal testing build. Link in the README.

**Ship here.** Phase 5 is a complete, defensible v1. Everything below is v1.5 and is optional in the sense that the project is already a finished artifact without it.

---

## Phase 6 — Telemetry and diagnostics (weeks 10–11, v1.5)

Design doc is `docs/BACKEND.md`. Read it first. The two data tables in §5 are the contract — no task here may add a field without editing that doc.

### Task 6.1 — Schema and ingest API

Postgres schema for both streams per BACKEND.md §5. FastAPI service with one `POST /events` endpoint taking a batch, routed by a `stream` discriminator. Strict validation — reject undeclared fields with a 422 rather than ignoring them. Payload size cap, per-IP rate limit. Strip the source IP at the edge before any handler sees it; never log it.

Shared write key auth, read from environment. Events now carry a name, so an unauthenticated endpoint would let anyone write events attributed to your user.

**Acceptance:** a request with an undeclared field is rejected, not silently accepted. A test asserts no code path writes an IP to storage or logs. A request without a valid key is rejected. Load test at 100× expected volume.

### Task 6.2 — Diagnostics retention job and the ingest guarantee test

Nightly job deletes `diagnostic` events older than 30 days and writes a run record with counts. Learning events are never touched.

Two tests, both P0 on failure:
- Insert diagnostics dated 31 days ago, run the job, assert they are gone **and** that no learning event was deleted.
- Assert no undeclared field, no IP, and no transcript-shaped value ever reaches storage.

**Acceptance:** both tests exist and pass. A failure means a stated policy in BACKEND.md is false.

### Task 6.3 — Infrastructure as code

Terraform for one small instance, Postgres, TLS termination, the nightly cron. Containerised service, `docker compose` for local development.

For a portfolio aimed at infrastructure roles this task carries disproportionate weight — it is the only place demonstrating a deployment story. State in the backend, secrets out of the repo, a documented teardown.

**Acceptance:** `terraform apply` from clean produces a working environment; `terraform destroy` leaves nothing. No secret in any tracked file. The write key lives in a gitignored `.xcconfig` on the client side and in environment config on the server.

### Task 6.4 — Breadcrumb type and error capture

Before any diagnostics plumbing, define the breadcrumb type. A **closed enum** of breadcrumb cases carrying item IDs and state-machine states. No free-text case, no associated `String` that could hold a transcript.

Then an in-memory ring buffer of the last 50, and a `caughtError` diagnostic emitted with the buffer attached on any caught error.

**Do this task before 6.5 and 6.6.** The enum is what makes the §5 breadcrumb rule compiler-enforced instead of review-enforced, and retrofitting it after free-text breadcrumbs exist means auditing every call site.

**Acceptance:** the enum has no case capable of carrying arbitrary text. A test attempts to construct a breadcrumb from a transcript string and fails to compile — document this as a commented-out example rather than a live test.

### Task 6.5 — MetricKit subscriber

`MXMetricManager` subscriber receiving `MXDiagnosticPayload` and `MXMetricPayload`. Serialise Apple's JSON and forward verbatim through the diagnostic queue without augmentation.

Payloads arrive **next-day**, not in real time. Do not build a workflow assuming immediacy, and say so in the settings copy if the user might expect otherwise.

**Acceptance:** subscriber registers and survives backgrounding. Payloads are forwarded unmodified. Nothing in the app augments a payload with app-side context.

### Task 6.6 — Client Telemetry module

Two local SQLite queues, learning and diagnostic. Flush on wifi at 50 events or 24 hours. Never blocks UI. Silent failure, no retry past three attempts — a diagnostics pipeline that causes bugs is worse than none.

**The only module permitted to open a network connection.** The CI grep enforcing zero-network on the rest of the target exempts exactly `Telemetry/` and nothing else.

**Acceptance:** with both toggles off, zero connection attempts under a blocking proxy. A telemetry failure never surfaces to the user or delays a session. `sessionID` appears in neither queue schema, `UserDefaults`, nor the app container. The CI exemption names one path and fails if it widens.

### Task 6.7 — Onboarding consent and settings surface

Onboarding: a plain-language consent screen naming what is collected and what never is, then the profile name field. Copy says the name need not be real. **Both toggles default off** — declining is a first-class path that leaves the app fully functional.

Settings: editable profile name, two independent toggles, "See what's sent," "Delete everything."

"See what's sent" renders from the live queue, not a hand-written sample, so it cannot drift from reality. "Delete everything" issues a server-side cascade by profile name and shows the returned count.

**Acceptance:** a fresh install declining consent makes no network request, ever. A test asserts the payload view matches what would actually be transmitted. Deletion is verified server-side, not assumed. Changing the profile name does not merge history, and the screen says so.

### Task 6.8 — Progress and KPI queries

SQL for BACKEND.md §8. The learning curve first — colloquial rate against cumulative attempts, per profile. That is the product thesis as a line, and the thing you actually wanted.

Plus a module-progress view: per scenario, per profile, completion state and items remaining.

A static dashboard is enough — Metabase or a committed notebook.

**Acceptance:** every KPI in §8 has a committed query. The learning curve renders from real data once there is any. The README states which metrics are computable but meaningless at n=2 and does not present them as findings.

### Task 6.9 — LTV model

A notebook with every input labelled external-benchmark or assumed. No measured inputs — retention comes from published language-app figures, cited. Sensitivity table, never a point estimate.

**Acceptance:** the first cell states no input is measured. Every input is tagged with provenance; benchmarks carry citations. No headline CLV figure anywhere in the repo.

---

## Timeline

| Weeks | Phase |
| --- | --- |
| 0 | Probe, interviews, romanisation decision |
| 1–2 | Walking skeleton |
| 3–4 | Content (overlaps 1–2) |
| 5–7 | Semantic acceptance + register |
| 8 | Progress + polish |
| 9 | README, study, demo — **v1 ships here** |
| 10–11 | Telemetry and diagnostics (v1.5) |

About nine weeks to a shippable v1 at a sustainable part-time pace, plus two for the backend. Named identity brings back the consent surface, the deletion path, and a retention job, and the diagnostics tiers are new work on top. Restoring pronunciation cost roughly three days, not two weeks, because v1 uses the confusion table you were already building rather than forced alignment. GOP is deferred to v2 and is not on this timeline.

**Do not start Phase 6 before Phase 5 ships.** Phase 5 produces a complete, defensible artifact. A half-built backend attached to a half-built app is worse portfolio material than a finished app with no backend — and the temptation to jump to the infrastructure work because it's more interesting is real.

**Where the risk sits.** Phase 2 is now the critical path, not Phase 3. Paraphrase authoring is slow, needs native speakers, and can't be parallelised with an agent. If it slips, ship fewer scenarios with full paraphrase coverage rather than more scenarios with thin coverage — eight shallow scenarios teach less than five deep ones and demo worse.

**Phase 3 fallbacks.** If the sentence encoder doesn't separate cleanly at int8, ship at fp16 and take the size hit, or ship on exact-match-plus-register and document semantic acceptance as the diagnosed next step. The register classifier is rules, so it works regardless — the on-thesis feature is not at risk from the ML going sideways.

If Task 3.7 shows learner and native pronunciation distributions failing to separate, ship the ladder at levels 1–2 only and document GOP as the diagnosed requirement for finer resolution. Do not raise the ceiling to make the feature look more complete than the measurement supports.

## Spending

| Item | Cost |
| --- | --- |
| Tamil voice talent + paraphrase authoring, ~6 hrs | $300–600 |
| Calibration: 6 learners + 3 natives, ~20 min each | $0–220 |
| Apple Developer Program | $99/yr |
| VPS + managed Postgres (v1.5) | $10–25/mo |
| GPU rental (model conversion, optional) | $0–30 |

Under $900, and most of it optional if you have bilingual friends. The increase over v1 is entirely paraphrase authoring, which is the highest-return line item on the list.
