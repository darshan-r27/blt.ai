# BLT.ai — product requirements

**Name:** BLT.ai — "Budugu Learns Tamil"
**Owner:** Darshan
**Status:** Draft v7
**Type:** Portfolio project. Not shipping to the App Store.

**Changes from v6:** named profiles replace anonymous events; diagnostics stream added (§12).
**Changes from v5:** all persistent identity removed from telemetry (§12). No install ID.
**Changes from v4:** optional, opt-in telemetry backend added for v1.5 (§12, `docs/BACKEND.md`). v1 itself is unchanged and still ships with no network requests.
**Changes from v3:** pronunciation restored as a scored-but-not-gating dimension, with a progressive tolerance ladder (§8.5).
**Changes from v2:** renamed from Kaadhu to BLT.ai.
**Changes from v1:** pronunciation scoring cut from scope (§3). Replaced with semantic acceptance and register classification (§8).

### Naming notes

Budugu (బుడుగు) is Mullapudi Venkata Ramana's mischievous schoolboy — near-universally recognised by Telugu speakers in the target age band, which is exactly the recognition a name wants to borrow. Two consequences:

- The character is under copyright and the name is associated with a specific estate. Fine for a portfolio project that is never distributed commercially; a trademark conversation if that ever changes. Note it in the README rather than discovering it later.
- Do not use the character's likeness, and do not let the app's copy adopt his voice. The name is an allusion, not a licence.

---

## 1. Problem

Tamil is strongly diglossic. Written/formal Tamil (செந்தமிழ்) and spoken Tamil (கொடுந்தமிழ்) differ in verb morphology, pronoun forms, and case endings — not just in vocabulary. Every mainstream language app teaches the written register.

A Telugu speaker aged 20–35 who wants to talk to a Tamil speaker of the same age therefore finishes existing courses able to read a signboard and unable to hold a conversation. They sound like a newsreader.

**Secondary problem:** the incumbent category optimises for session count via gamification. Streaks, gems, animated mascots. This is a retention mechanic, not a pedagogy. It produces users with 400-day streaks who cannot order food.

## 2. Why this user pair

Tamil and Telugu are both Dravidian. They share:

- SOV word order
- Agglutinative case suffixing
- Dative-subject constructions ("to-me anger came")
- A large Sanskrit-derived shared lexicon
- Inclusive/exclusive first person plural
- Most of the consonant inventory, including the retroflex series — Telugu ళ maps closely onto Tamil ள

A Telugu speaker already owns the grammar and most of the sound system. What they lack is:

1. **Lexical substitution** — the same sentence frame, different content words. This is the bulk of the work and the fastest path to being understood.
2. **Register and pragmatics** — வாங்க vs வாருங்கள், how young people actually agree, hedge, interrupt, and soften a refusal. This is what textbooks get wrong and what the product exists to fix.
3. **Listening at natural speed** — colloquial Tamil elides heavily (வந்துவிட்டேன் → வந்துட்டேன் → வந்துட்டே). A learner who can read a sentence often cannot hear it. This is a comprehension problem, not an articulation problem.

Pronunciation is a fourth dimension, but a **tracked** one rather than a taught one. Of the Tamil sounds that give Telugu speakers trouble, only ழ /ɻ/ is genuinely absent from Telugu — ள maps closely onto Telugu ళ, and ற onto the archaic ఱ. The app measures pronunciation from day one and reports it, but never teaches it explicitly and never blocks on it. See §8.5.

This is the product thesis: **skip grammar instruction entirely**, because it largely transfers. Spend the user's effort on vocabulary, register, and ear training. No incumbent is built this way.

## 3. Non-goals

Explicitly out of scope for v1. Each is a deliberate cut, not an oversight.

| Cut | Reason |
| --- | --- |
| Pronunciation *instruction* | Measured, reported, never taught or gated. See below and §8.5. |
| Tamil script | Young Tamil speakers text in Latin script. Script is a ~40-hour tax unrelated to the goal. Romanised only. |
| Tamil → Telugu direction | Doubles content cost, halves depth. One direction, done well. |
| English → Tamil for English-L1 learners | The Dravidian-transfer thesis needs a Telugu-L1 learner, so teaching English speakers is a different product. English is used only as the *prompt language* for Telugu speakers who are fluent in English (DECISIONS 024). |
| Gamification | Streaks, XP, leaderboards, mascot. Anti-goal. |
| Backend in v1 | The v1 app ships with no network requests at all. An opt-in telemetry service arrives in v1.5 — see §12. Progress sync stays cut permanently: it needs identity, brings PII, and is worth less than telemetry. |
| Grammar explanation | See §2. |
| Accounts, sync, social | Portfolio scope. |

### On pronunciation: measured, not taught

Phoneme drilling is the wrong first lesson. A learner pushed on the மழை/மலை contrast in week one concludes that Tamil is a minefield where small errors mean total failure. That is demoralising and also false — Tamil speakers disambiguate from context constantly, and a Telugu-accented ழ is understood in the overwhelming majority of real exchanges.

But dropping measurement entirely has its own cost: articulation errors fossilise, and a user who spends six months saying *malai* for *mazhai* finds it harder to fix later than if they had been nudged early.

The resolution is to separate measurement from gating. Pronunciation is scored on every attempt from day one and surfaced as a soft signal. It never changes the verdict, never blocks progression, and never appears in red. The strictness of the signal rises as the user advances, on the ladder in §8.5.

**Consequence that must be handled:** ASR will transcribe *malai* as a different word from *mazhai*, and naive string matching would mark the attempt wrong for the wrong reason. §8.3 defines the policy.

## 4. Target user

Telugu L1, 20–35, urban, works or studies somewhere with Tamil speakers (Chennai, Bangalore, Hyderabad IT campuses, US diaspora). Owns an iPhone. Comfortable in English for UI chrome. Motivated by a specific social situation, not by a streak.

## 5. Core loop

Three beats per item. The loop is voice-first: audio in, audio out, text only as feedback.

**1. Listen** — a native Tamil utterance plays at natural speed. No text on screen. The user taps to replay as many times as needed, and can drop to 0.75× if stuck. Then three Telugu glosses appear; they tap the one that matches. This is comprehension, and it is where the item is introduced.

**2. Produce** — a situation is described in Telugu text ("tell him to go to T. Nagar"). The user holds the mic button and says the Tamil. Release to score.

**3. Compare** — a verdict, then the romanised transcript of what they said next to the target. Three possible verdicts:

- **Understood** — semantically equivalent to an accepted answer, in colloquial register. Green, move on.
- **Understood, but formal** — correct meaning, textbook phrasing. The single most important feedback state in the app. Shows the colloquial form side by side and plays it.
- **Not understood** — meaning missed. Shows the target, plays native audio, offers retry.

Beneath the verdict, when the user is at tolerance level 2 or above and the attempt fell below tolerance, a single muted line names the sound: *"ழ in mazhai came out closer to ల."* No colour, no icon, no score number. Dismissible, and never shown on a `notUnderstood` verdict — one correction at a time.

Two playback buttons throughout: yours, native.

**Why not voice-only:** pure audio gives no way to render "you said X, target was Y", so feedback becomes unactionable. It also fails on trains, in offices, and for users who can't speak aloud right now. Voice is the stimulus and the response; text is the feedback surface only. Navigation is tap-only.

## 6. Screens

Five. That is the whole app.

### 6.1 Scenarios (home)
Vertical list of 8 scenario cards. Each shows title, a one-line Telugu subtitle, item count, and a thin completion bar. No hero image, no illustration. Tap to enter.

### 6.2 Session
The three-beat loop above. Full-bleed, one item at a time. Progress dots at top. A single back affordance. Nothing else on screen.

### 6.3 Feedback
Rendered as beat 3 within Session rather than a pushed screen, so the user never loses the audio context.

### 6.4 Progress
Four numbers over time: comprehension accuracy (beat 1), production accuracy (beat 2), **colloquial rate** — the share of correct productions in colloquial rather than formal register — and pronunciation rate per target phoneme.

Colloquial rate is the headline metric because it is the thing the product claims to teach. Pronunciation sits below it, with the current tolerance level shown and the next level's requirement stated plainly. Plus items due for review and total speaking time. No streak, no XP.

### 6.5 Settings
Playback speed default (0.75× / 1.0×), mic permission status, recording retention toggle, delete all local data, export progress as JSON, about/licences.

From v1.5, a data group:
- Profile name, editable. Changing it re-keys future events; prior events keep the old name and the screen says so rather than implying a merge.
- **Share my progress** and **Share diagnostics** — two independent toggles, both off until the user opts in at onboarding.
- **See what's sent** — renders the exact pending payload as formatted JSON, generated from the live queue. Not a sample, not a description. If a field looks alarming here, it shouldn't be collected.
- **Delete everything** — server-side delete by profile name across both streams, returning a count so the app can confirm what was removed.

## 7. Architecture

### Constraint: the core target makes no network requests

No analytics SDK, no crash reporter, no remote config, no third-party anything. All content and models ship in the bundle. Progress is local. Export is a user-initiated file share.

From v1.5 there is exactly one exception: the `Telemetry` module, which is **off by default** and which the app functions completely without. No other module may open a connection, and this is a review-enforced boundary rather than a convention.

The resulting claim is narrower than v1's but stronger as a demonstration: *the app makes no network requests unless you turn telemetry on, and shows you the exact payload before it sends.* Designing data collection is a better portfolio signal than avoiding it.

### Stack

| Layer | Choice | Note |
| --- | --- | --- |
| UI | SwiftUI, iOS 27 | Portfolio project, not distributed (DECISIONS 029); matches the simulator runtime available. Swift 6 strict concurrency on. |
| Audio capture | AVAudioEngine | Tap runs on a real-time thread; capture locals only, never a `@MainActor` object. Recording deleted in a `defer` so a scoring failure still deletes; orphans swept at launch. |
| Playback | AVAudioPlayer + AVAudioUnitTimePitch | Bundled AAC. Speed change must preserve pitch. |
| ASR | Core ML, converted from AI4Bharat IndicConformer-TA (120M) | Fallback: whisper.cpp small via SPM. |
| Semantic matching | Core ML sentence encoder (distilled LaBSE or IndicBERT) | See §8.1. |
| Register classification | Rule set over morphological endings + lexicon | See §8.2. |
| Pronunciation (v1) | Confusion-table substitution detection over the ASR transcript | See §8.5. Cheap, discrete, no alignment. |
| Pronunciation (v2) | GOP over CTC frame posteriors | Continuous confidence. Needed for levels 4+. |
| Persistence | SwiftData | Local store, no CloudKit. |
| Telemetry (v1.5) | Local SQLite queues → TLS → FastAPI + Postgres | Opt-in, off by default. Two streams, one endpoint. See `docs/BACKEND.md`. |
| Diagnostics (v1.5) | TestFlight + MetricKit + structured errors | No third-party crash SDK. See `docs/BACKEND.md` §6. |
| Dependencies | SPM only, exact-version pinned | See SECURITY.md. |

### Module boundaries

The Xcode target is `BLTApp` — a bundle identifier can carry `blt.ai` but a Swift module name cannot contain a dot. Display name is BLT.ai.

```
BLTApp
├── Catalog      scenario + item models, bundled JSON loading, validation
├── Session      the three-beat state machine (the only stateful thing)
├── Audio        capture, playback, format conversion, level metering
├── Scoring      ScoringEngine protocol + implementations
├── Progress     SwiftData models, spaced repetition scheduling
├── Telemetry    v1.5. Both event queues, batching, flush. The ONLY networked module.
├── Diagnostics  v1.5. MetricKit subscriber, breadcrumb buffer, error capture.
└── DesignSystem type scale, spacing, the ~6 components that exist
```

### The one decision that matters

`ScoringEngine` is a protocol with a single method. Implementations swap behind it.

```swift
protocol ScoringEngine {
    func score(recording: URL, against item: Item) async throws -> Verdict
}
```

- `ExactMatchEngine` — ASR, normalise, Levenshtein against the single target. Ships week 2. Deliberately crude.
- `SemanticEngine` — accepts paraphrases, classifies register, scores pronunciation. Ships week 6. The real one.

`Verdict` carries an optional `PronunciationSignal` alongside the three semantic cases. The signal is advisory: no consumer of `Verdict` may branch progression on it. Enforce this in review — it's the constraint most likely to erode quietly.

Everything upstream depends on the protocol, never the concrete type. This is what makes the week-2 placeholder safe: it buys a working end-to-end loop without ever becoming load-bearing. Document this in the repo README — it's the kind of thing an interviewer will ask about.

## 8. Scoring

The hard problem is no longer *how did you say it*. It is *does what you said work, and does it sound like a person*.

### 8.1 Semantic acceptance

There is rarely one correct way to say something. "Take me to T. Nagar" has half a dozen valid Tamil renderings and a learner who produces a different-but-fine one must not be told they failed. Exact matching makes the app feel broken within about ten items — this is the single most common way a language app loses a user.

**Approach.** Each item carries a set of accepted answers (3–6, written during content authoring). ASR produces a transcript. Embed the transcript and each accepted answer with an on-device sentence encoder; take max cosine similarity. Above threshold, accept.

The encoder is the interesting engineering: a distilled multilingual model (LaBSE or IndicBERT) quantised to 8-bit and converted to Core ML, running in under 100ms on an A15. Measure the WER-to-similarity interaction — ASR errors degrade the embedding, so the threshold must be set against real learner audio, not clean text.

**Fallback.** Exact match against the accepted set catches most cases cheaply. Only run the encoder when exact match fails. This keeps the median path fast.

### 8.2 Register classification

The feature that makes this app the thing it claims to be.

Given an accepted transcript, decide whether it is colloquial or textbook. Tamil's formal/colloquial split is highly regular in exactly the places that matter:

| Formal | Colloquial | Pattern |
| --- | --- | --- |
| வாருங்கள் | வாங்க | polite imperative -ுங்கள் → -ுங்க |
| போகிறேன் | போறேன் | present -கிற- → -ற- |
| இருக்கிறது | இருக்கு | 3rd neuter, heavy reduction |
| அவர்கள் | அவங்க | plural -கள் → -ங்க |
| என்னுடைய | என்னோட | genitive |

This is a rule set over romanised suffixes plus a small lexicon of formal/colloquial word pairs, not a model. Perhaps 40 rules covers the space the content actually exercises. It is unglamorous, it is highly accurate, and it produces the app's best feedback state: *"Understood — but that's how a news anchor would say it. Here's what your friend would say."*

**Content requirement:** every item carries both forms. The formal variant is authored deliberately so the classifier has a target, not inferred at runtime.

### 8.3 The minimal-pair policy

Because pronunciation is out of scope, a learner saying *malai* for *mazhai* must not be silently marked wrong for the wrong reason.

**Policy.** Maintain a confusion table of Tamil word pairs that differ only in ழ/ள/ல, ற/ர, or ண/ந. When the ASR transcript differs from an accepted answer *only* by a substitution in that table, the attempt is **semantically accepted** and a `PronunciationSignal` is attached naming the substitution.

Whether that signal is shown to the user depends on their tolerance level (§8.5). At level 1 it is recorded silently. At level 2+ it surfaces as the muted line described in §5.

Accepted, recorded, never penalised in the verdict. This table is also the v1 pronunciation scorer — see below.

### 8.4 Calibration

Record 6 Telugu-L1 learners attempting 30 items, **and 3 native speakers attempting the same 30**. The native recordings are not optional — they establish the baseline that caps level 5 and prove the detector isn't flagging correct speech.

Use the set to:
- set the semantic acceptance threshold, optimising for low false rejection
- check the register classifier's false-positive rate on "that's formal" is near zero — telling a learner their correct colloquial phrasing is textbook is the worst error this app can make
- measure the native pronunciation baseline per target phoneme
- sanity-check that learner and native distributions separate at all. If they don't, the detector is not measuring what you think it is, and that is worth knowing before any of it reaches a user.

Ship the calibration set and the notebook in the repo.

### 8.5 Pronunciation tolerance

Two separate knobs. Conflating them is the design error to avoid.

**Detection threshold** — per phoneme, the line between "produced as the target" and "produced as something else." Derived from calibration data (§8.4) and then fixed. A measurement decision.

**Tolerance** — per user, the share of scored instances that may fall below detection before the app says anything. Adaptive. A pedagogical decision.

Separating them means the detector never needs recalibrating as users advance, and the ladder reduces to a single integer on the user's progress record.

#### The ladder

| Level | Tolerance | Meaning | Advance when |
| --- | --- | --- | --- |
| 1 — Ear | not scored | First encounters. Signals recorded, never shown. | 3 scenarios completed |
| 2 — Attempt | 50% | Producing something recognisable. | 50% sustained over 30 attempts |
| 3 — Clear | 65% | Consistently intelligible. | 65% sustained over 30 attempts |
| 4 — Fluent | 75% | **v1 ceiling.** | — |
| 5+ | 85% → native baseline | v2/v3 only. | — |

75% is the v1 ceiling by deliberate choice: a naive implementation would require every scored instance to clear, and a quarter of that requirement is given back as headroom. The lower rungs start well below it because a beginner held to 75% in week one learns only that they are failing.

**Level 5 is capped at the measured native baseline, not at 100%.** Native speakers will not score 100% — ASR noise, coarticulation, and regional variation all cost instances. Measure the native baseline during calibration and never set a tolerance above it. Shipping an unreachable top level is a bug, not ambition.

**Advancement is one-way in v1.** A bad week should not demote anyone. Regression handling is a v2 question with real UX risk; leave it alone.

#### Two implementations

The ladder is the same in both; only the detector changes.

- **v1 — confusion-table detection.** The §8.3 table already identifies ழ/ள/ல, ற/ர, and ண/ந substitutions from the transcript alone. Discrete, cheap, needs no forced alignment, and catches exactly the substitutions that matter. Sufficient for levels 1–3.
- **v2 — GOP over CTC posteriors.** Force-align against the target, take the log-posterior ratio of the target phone against its best competitor. Continuous confidence. Required for level 4+, where the distinction between "wrong phone" and "right phone, poorly articulated" starts to matter.

Build the ladder and the persistence in v1 against the cheap detector. Swapping the detector later touches one type. Building the ladder later touches the progress model, the feedback UI, and every stored attempt.

## 9. Content

**Volume:** 8 scenarios × 12–15 items = ~100–120 utterances. Not 500. For a portfolio, depth of treatment beats catalogue size.

**Scenarios:** auto rickshaw, ordering at a mess, office small talk, asking directions, phone call with a landlord, buying something at a shop, meeting a friend's parents, arguing about a bill.

Chosen because each has a predictable script, high real-world frequency, and a register the user actually wants. Derive them from interviews (BUILD_PLAN task 0.2), not from a textbook contents page.

**Per item, the content must carry:**

- one canonical colloquial Tamil form (romanised) + its native audio
- 3–6 accepted paraphrases (text only, no audio needed)
- one deliberately formal variant, for the register classifier
- Telugu gloss, Telugu situation prompt, three distractor glosses

The paraphrase and formal-variant fields are new in v2 and are the bulk of the added authoring cost. Budget an extra half-day of native-speaker time.

**Sourcing — legal, in order of preference:**

1. **Commission it.** Two Tamil native speakers, 20–35, Chennai or Bangalore. ~4 hours of recording covers 120 items with alternates. $200–500 on Upwork. You own it outright, it's higher quality than anything scraped, and the licence question disappears.
2. **AI4Bharat** — IndicConformer, Indic-TTS, IndicVoices. Mostly Apache-2.0. Use Indic-TTS for the *Telugu* prompts (scaffolding, not the learning target).
3. **Mozilla Common Voice** — CC0, has Tamil and Telugu. Useful for calibration, not for teaching audio.
4. **Bhashini** (MeitY) — free for non-commercial.

**Not usable:** film dialogue, song lyrics, scraped YouTube audio. Even for a portfolio piece, a public GitHub repo containing ripped copyrighted audio is a liability you don't want attached to your name. Watch vlogs and films as *research* — take notes on how people actually talk, then write scripts that reflect it. That is legal and it gets you the same linguistic signal.

**Register review:** every script gets red-lined by a native speaker for register before recording. The single most common failure mode here is writing formal Tamil by accident, because that's what's written down everywhere.

## 10. Success criteria

This is a portfolio piece, so the metric is not DAU.

**Ships if:**
- 8 scenarios, ~120 items, native audio throughout, with paraphrase sets and formal variants
- Semantic acceptance live, with a published threshold calibration
- Register classifier live, with a measured false-positive rate
- Minimal-pair policy implemented with its confusion table
- Pronunciation tolerance ladder live at levels 1–4, with the native baseline measured and the level-5 cap documented
- Zero network requests, verifiable
- Runs on a physical device, TestFlight build available
- Repo has PRD, decision log, security review, and a 90-second demo video

**Validated if:** 8–10 recruited Telugu speakers complete at least 3 scenarios, and colloquial rate on held-out items rises between pre-test and post-test. Even n=8 with a real pre/post design is more rigour than most portfolio projects show.

## 11. Open questions

- Does `SFSpeechRecognizer.supportedLocales()` include `ta-IN`? Determines whether the week-2 placeholder engine is 20 lines or 200. Check on a physical device before writing any code — the Speech APIs don't work in Simulator.
- Which sentence encoder survives 8-bit quantisation with usable cosine separation on short, romanised, ASR-noisy Tamil? LaBSE is the safe pick; IndicBERT may be better on Indic scripts but is untested on romanised input. Decide empirically in Phase 3.
- Romanisation scheme: ISO 15919, or the ad-hoc Latin orthography Tamil speakers actually use in WhatsApp? Lean toward the latter — it matches the register goal, and the register rules in §8.2 are written against surface forms. But pick one and document it.
- How many accepted paraphrases per item is enough? Start at 4, measure false rejections during calibration, adjust.
- Does confusion-table detection have enough resolution for level 3 (65%), or does GOP need to arrive earlier than v2? Answerable only once the calibration recordings exist. If the transcript-level detector turns out to be binary in practice — either the substitution happened or it didn't, with no middle — the 50/65/75 ladder will feel steppy and GOP moves up the roadmap.
- Advancement currently requires sustained performance over 30 attempts. That number is a guess. Revisit after the validation study, and again once telemetry gives a real distribution.
- Profile name changes don't merge history. Merging needs a stable ID beneath the name, reintroducing what the anonymous draft removed. Currently no merge, and the app says so. Revisit only if it actually happens.
- The shared ingest write key is extractable from the binary. Proportionate at two users; per-device tokens are the next step if this ever grows.
- 30 days for diagnostics retention is a guess — long enough to debug something reported a week late, short enough to bound breadcrumb exposure.

## 12. Telemetry and diagnostics (v1.5)

Full design in `docs/BACKEND.md`. Summary:

**Why.** Two users, both known to each other. This is not statistical measurement — at n=2 there is no cohort and no generalisable finding. It is three other things: a longitudinal case study of one learner going Telugu → Tamil over months, a diagnostics path so "it stopped working" is debuggable, and the only component in the project that demonstrates schema design, consented collection, enforced retention, and a deployment.

**The claim.** No raw user content is retained. Audio never leaves the device, transcripts never leave the device. Identity is a name the user chooses rather than an identifier the app assigns, everything collected is visible in-app, and deletion actually deletes.

This supersedes both earlier framings — "ZDR", which was inaccurate, and the fully anonymous design, which was correct for a cohort that does not exist. An anonymous ID between two people who have met is privacy theatre. The design history is worth recording in `DECISIONS.md` rather than hiding: the anonymous draft is what revealed the privacy machinery was solving a problem this project doesn't have.

**Identity.** A display name typed at onboarding, after an explicit consent screen. It need not be a real name. It is the deletion key. A per-session in-memory `sessionID` orders attempts within a sitting and persists nowhere.

**Two streams, one endpoint.** `learning` events (practice attempts, retained indefinitely — they are the point) and `diagnostic` events (crashes, hangs, caught errors, MetricKit payloads, deleted after 30 days).

**Diagnostics, three tiers, no third-party SDK.** TestFlight and Xcode Organizer for crashes, free and zero code. MetricKit for hangs, CPU exceptions, and performance, forwarded verbatim. Structured errors with a breadcrumb buffer for the non-fatal failures that matter most in practice — ASR returning nothing, a model failing to load, an audio session refusing to activate. A third-party crash SDK would break the single-networked-module boundary and add supply-chain surface to a repo whose low dependency count is a stated feature.

**The breadcrumb rule.** Breadcrumbs carry item IDs and state-machine transitions only. Never a transcript, never a file path. Modelled as a closed enum so the compiler enforces it rather than review attention. This is the easiest way to break the claim by accident, through a path nobody is watching.

**KPIs.** Learning curve (colloquial rate against cumulative attempts — the headline), module progress, ladder progression and time-per-rung, per-item difficulty, abandonment point. Retention and activation are computable but meaningless at n=2; compute them, don't present them as findings.

**On LTV.** No revenue, no paid tier, two users: lifetime value is undefined and no CLV figure appears in the repo. The model's inputs are all external-benchmark or assumed, with a sensitivity table rather than a point estimate. Your own retention data is deliberately excluded as an input — a two-person curve is a worse estimator than a published benchmark, and using it would be the quiet kind of dishonesty the whole document exists to avoid.
