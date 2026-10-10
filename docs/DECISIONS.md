# BLT.ai — decision log

Lightweight ADRs. Superseded decisions are kept, not deleted — the reasoning that led somewhere wrong is often more useful than the conclusion, and in two cases here the reversal is the most interesting thing in the record.

Status values: **active**, **superseded by NN**, **pending** (decided, not yet applied), **open**.

---

## 001 — Target colloquial Tamil for Telugu speakers, not grammar
**Status:** active

Tamil is strongly diglossic — written (செந்தமிழ்) and spoken (கொடுந்தமிழ்) differ in verb morphology, pronouns, and case endings. Every mainstream app teaches the written register, so a learner finishes able to read a signboard and unable to hold a conversation.

Tamil and Telugu are both Dravidian: shared SOV order, agglutinative case suffixing, dative-subject constructions, large shared Sanskrit-derived lexicon. A Telugu speaker already owns the grammar.

**Decision:** skip grammar instruction entirely. Spend all learner effort on lexical substitution, register, and listening at natural speed.

**Consequence:** the thesis is language-pair-specific. It does not transfer to English L1 — see 020.

## 002 — Don't train a model
**Status:** active

The original plan involved sourcing a dialogue dataset and fine-tuning. Teaching ~120 colloquial phrases is a content problem, not an ML problem.

**Decision:** use pretrained AI4Bharat IndicConformer-TA. No training, no fine-tuning, no GPU budget.

**Consequence:** the hard problems moved to content quality and scoring design, which is where they belonged.

## 003 — Romanised Tamil, not Tamil script
**Status:** active

Young Tamil speakers text each other in Latin script. Script acquisition is a ~40-hour tax unrelated to the goal of speaking to a 25-year-old.

**Consequence:** the register rules in 008 match on romanised surface forms, so the romanisation scheme (see OPEN_ITEMS) is load-bearing for the classifier.

## 004 — Voice-first, not voice-only
**Status:** active

Pure audio gives no way to render "you said X, target was Y," so feedback becomes unactionable. It also fails on trains, in offices, and for anyone who can't speak aloud.

**Decision:** voice is the stimulus and the response; text is the feedback surface only. Navigation is tap-only.

## 005 — iOS 17 deployment target, not 26
**Status:** superseded by 029

iOS 26's `SpeechAnalyzer` is better but narrows device support, and its supported-locale list likely excludes Tamil anyway. Verify on hardware (Task 0.1) before relying on any Apple speech API.

## 006 — Pronunciation instruction cut
**Status:** superseded by 007

Drilling மழை/மலை in week one teaches that Tamil is a minefield where small errors mean total failure — demoralising and false. Cut phoneme-level scoring entirely.

**Why superseded:** the cut conflated *teaching* pronunciation with *measuring* it. Measurement without gating was available and wasn't considered.

**Worth keeping:** this cut also corrected an error in the original framing. Telugu has ళ ≈ Tamil ள and ఱ ≈ ற (archaic, merged with ర in modern speech). Only ழ /ɻ/ is genuinely absent from Telugu, so the difficulty was overstated from the start.

## 007 — Pronunciation measured, never gating
**Status:** active

**Decision:** score pronunciation on every attempt from day one. It never changes the verdict, never blocks progression, never appears in red.

Two separate knobs, and conflating them is the error to avoid:
- **Detection threshold** — per phoneme, where GOP separates "produced as target" from "produced as something else." Calibrated from data, then fixed. A measurement decision.
- **Tolerance** — per user, what share of instances may fall below detection before the app says anything. Adaptive. A pedagogical decision.

Separating them means the detector never needs recalibrating as users advance, and the ladder is one integer on the progress record.

**Ladder:** level 1 not scored → 2 at 50% → 3 at 65% → 4 at 75% (v1 ceiling) → 5+ at 85%–native baseline (v2). Advancement is one-way in v1.

**Why 75%:** a naive implementation requires every scored instance to clear, i.e. 100%. A quarter of that was given back as headroom. There was never a prior numeric baseline — thresholds come from calibration, and picking one before the data exists is guessing.

**Level 5 is capped at the measured native baseline, not 100%.** Natives won't score 100% — ASR noise and coarticulation cost instances. Shipping an unreachable rung is a bug.

## 008 — Register classification by rules, not a model
**Status:** active

Tamil's formal/colloquial split is highly regular where it matters: வாருங்கள்→வாங்க, போகிறேன்→போறேன், அவர்கள்→அவங்க, என்னுடைய→என்னோட.

**Decision:** ~40 rules over romanised suffixes plus a small lexicon of formal/colloquial pairs. Not a model.

**Consequence:** unglamorous, highly accurate, and it produces the app's best feedback state — *"Understood, but that's how a news anchor would say it."* It also survives the ML going sideways, which is why the on-thesis feature carries no model risk.

## 009 — Semantic acceptance over exact match
**Status:** active

There is rarely one correct way to say something. Exact matching makes the app feel broken within about ten items, which is the most common way a language app loses a user.

**Decision:** 3–6 authored accepted answers per item. Exact match first (fast path); on miss, an on-device sentence encoder and max cosine similarity.

## 010 — ScoringEngine protocol boundary
**Status:** active

A single-method protocol with a crude week-2 implementation and a real week-6 one. Everything upstream depends on the protocol, never the concrete type.

**Consequence:** the placeholder buys a working end-to-end loop without becoming load-bearing. Swapping engines is one line at the composition root — and if it isn't one line, the boundary was done wrong.

## 011 — Zero network requests
**Status:** superseded by 012

No analytics, no crash reporter, no backend. A verifiable security property, removal of nearly the whole attack surface, and a one-sentence claim.

**Why superseded:** it left the app blind, and it demonstrated zero infrastructure competence — which is half the target-role surface for a portfolio project.

## 012 — Network confined to one module
**Status:** active

**Decision:** from v1.5, the `Telemetry` module is the only component permitted to open a connection. It is off by default and the app is fully functional without it. CI greps for network APIs and exempts exactly one path; a PR widening that exemption is a design change, not a build fix.

**Consequence:** the claim becomes *"makes no network requests unless you turn telemetry on, and shows you the exact payload before it sends,"* which is a stronger portfolio signal than either extreme. Designing data collection is harder to demonstrate than avoiding it.

## 013 — "ZDR" replaced by "no raw user content is retained"
**Status:** active

Zero data retention and a product that learns from usage are mutually exclusive. The accurate claim is narrower: nothing transmitted can reconstruct what a user said.

**Consequence:** precision bought more credibility than the stronger-sounding wrong word would have. Worth saying out loud in an interview.

## 014 — Identity: the full arc
**Status:** active (as 014c)

The most instructive sequence in the project.

**014a — rotatable pseudonymous install ID.** *Superseded.* Enough to link a learning curve without naming anyone.

**014b — no identity at all.** *Superseded.* Correct reasoning for anonymous cohort telemetry: an identifier you don't need is a liability. Dropped install ID, kept a session-scoped ephemeral ID.

**014c — named profile.** *Active.* The actual requirement turned out to be tracking one known person over time, not measuring a cohort of strangers. A user-chosen display name, typed at onboarding after explicit consent, which doubles as the deletion key. It need not be a real name.

**Why the middle step mattered:** 014b is what revealed the privacy machinery was solving a problem this project doesn't have. An anonymous ID between two people who have met is privacy theatre. 014b also demonstrated something real — removing data from a design removes the machinery that would have guarded it. Phase 6 shrank by a week when identity came out and grew back when it returned.

**Precise timestamps:** excluded under 014b as a fingerprinting vector, restored under 014c. With a name attached there is nothing left to fingerprint.

## 015 — Transcripts excluded from telemetry
**Status:** active

A transcript is user-generated content and may contain anything the user said, including speech unrelated to the prompt.

**Decision:** never transmitted, in either stream.

**Cost, acknowledged:** knowing *what* a learner said when they failed an item is materially more diagnostic than knowing *that* they failed. Excluded anyway, because a claim that holds only when users say what you expected is not a claim. This is the most expensive exclusion in the design and the one to be able to defend out loud.

## 016 — No third-party crash SDK
**Status:** active

**Decision:** three tiers — TestFlight/Xcode Organizer for crashes (free, zero code), MetricKit for hangs and performance (native, next-day delivery), own structured errors with breadcrumbs for non-fatal failures.

**Rejected:** Sentry, Crashlytics. A third-party SDK with network access breaks the 012 boundary, adds supply-chain surface to a repo whose low dependency count is a stated feature, and transmits on its own schedule outside the consent surface.

**Note:** tier 3 catches what matters most in practice — ASR returning nothing, a model failing to load, an audio session refusing to activate. None of these crash, so none reach tiers 1 or 2.

## 017 — Breadcrumbs as a closed enum
**Status:** active

A breadcrumb reading `scored item 042, transcript "naan varen"` leaks exactly what 013 and 015 forbid, through the diagnostics path, where nobody is looking.

**Decision:** breadcrumbs carry item IDs and state-machine states only, modelled as a closed enum with no case capable of holding free text, a file path, or a payload body.

**Consequence:** the rule is compiler-enforced, not review-enforced. Verify by reading the type definition, not by auditing call sites — if the type permits arbitrary text, no amount of call-site discipline holds. This is the highest-risk line in the design.

## 018 — Audio deletion is unconditional and swept
**Status:** active

Original phrasing — "does not persist past scoring" — quietly assumed scoring always completes.

**Decision:** two mechanisms. The unlink sits in a `defer` at the top of the scoring path so a scoring failure still deletes. And a launch-time sweep clears the recording directory, because a crash between recording and scoring orphans a file no in-session path reaches.

**Consequence:** four lifecycle tests on Task 1.3 — directory empty after success, after scoring failure, after mid-attempt interruption, and after crash-then-relaunch. Without them, P2 is a policy statement rather than a tested property.

## 019 — No CLV; a modelled LTV sensitivity table instead
**Status:** active

No revenue, no paid tier, two users. Lifetime value is undefined, and a CLV figure built on invented numbers is what a sharp interviewer pulls on.

**Decision:** a model with every input labelled external-benchmark or assumed, output as a sensitivity table, first cell stating no input is measured. Own retention data deliberately excluded as an input — a two-person curve is a worse estimator than a published benchmark.

## 020 — Content is recorded, never scraped
**Status:** active

Film dialogue, song lyrics, and scraped YouTube audio are rights-encumbered. Songs are also the wrong register — literary Tamil, inverted syntax. Films are performative and dialect-marked. A public repo containing ripped audio is a liability attached to your name.

**Decision:** record with native speakers. Use IndicVoices/Common Voice for native calibration baselines only. Use films and vlogs as *research* — watch, note how people talk, write scripts reflecting it.

**TTS is not a substitute** for teaching audio: Tamil TTS is trained predominantly on read speech, which is the formal register the product exists to fix. Acceptable as a development placeholder only.

## 021 — Elicit, don't read
**Status:** pending — Phase 2 not yet reordered

Reading written Tamil aloud pulls a speaker toward formal register through orthographic interference. This affects fluent speakers too — it is an artifact of literacy, not of proficiency. The conventional script-then-record workflow causes the exact failure the product exists to prevent.

**Decision:** invert the order. Describe a situation out loud, let two speakers enact it, record, transcribe afterward in romanised Tamil exactly as spoken, then select items. The corpus is the output of the session, not its input.

**Consequence:** Task 2.3's register red-line largely dissolves into a selection pass. BUILD_PLAN Phase 2 still has the old ordering and needs rewriting.

## 022 — The backend exists for portfolio reasons, not measurement
**Status:** active

Expected user count is two. At n=2 telemetry has no analytical value — a retention curve from two people is noise.

**Decision:** build it anyway, and say why. It demonstrates a pipeline designed around a privacy guarantee, that guarantee enforced in code and tested, and a real deployment with IaC and teardown. It is also a genuine longitudinal case study of one learner.

**Consequence:** the README must call it a case study, not a cohort finding. Dashboard charts built on seeded data carry a visible synthetic label in the chart, not a footnote. A reviewer who catches an unlabelled synthetic chart discounts everything else in the repo.

## 023 — Name: BLT.ai
**Status:** active

"Budugu Learns Tamil." Budugu (బుడుగు) is Mullapudi Venkata Ramana's schoolboy, near-universally recognised by Telugu speakers in the target age band.

**Caveats:** the character is under copyright. Fine for a portfolio project never distributed commercially; a trademark conversation if that changes. The name is an allusion — don't use the likeness or adopt his voice in the copy. Xcode target is `BLTApp` (module names can't contain dots), bundle id `ai.blt.app`.

## 024 — v1 is a text-only English→Tamil multiple-choice MVP; voice is v2
**Status:** active

The primary user is a Telugu speaker who is also fluent in English, so the transfer thesis in 001 is unchanged: the audience is still Telugu L1. English is the *prompt* language because it is the shared working language, not because the audience changed.

**Decision:** MVP v1 is text-to-text. An English prompt, four romanised-Tamil options (the colloquial form, the textbook form, two wrong), feedback, SM-2-style review. No audio, no microphone, no speech recognition. MVP v2 adds the voice loop from the original plan (listen, produce, compare).

**Consequences:**
- The register feature survives: picking the textbook form yields "understood, but that's how a news anchor would say it." It is language-internal to Tamil and needs no audio.
- Audio, recorder, player, transcriber, transliterator, pronunciation ladder, and "keep my recordings" move to v2. The Simulator can verify the whole v1 loop; the device probe (Task 0.1) no longer blocks v1.
- The network-confinement and no-third-party-SDK constraints apply unchanged. The audio-lifecycle constraints apply from v2.
- Distractor quality carries the learning value in a multiple-choice format, so content review matters more, not less.
- Schema uses the source-agnostic names `sourceGloss` / `sourcePrompt` (OPEN_ITEMS "Source language"). Telugu cognate hints are a possible later addition, not v1.

## 025 — v1 content is Claude-drafted and labelled unreviewed
**Status:** active — supersedes 020 and the "do not generate content" rule for v1 text content only

020 required all content to come from native speakers recorded in person. That still holds for v2 audio. For v1 text, the owner decided Claude drafts the content so the app is buildable now: 5 scenarios of 20 items, covering everyday communication.

**Decision:** every item carries a `reviewStatus` (`unreviewed` | `reviewed`). Claude-authored items ship as `unreviewed`; an item becomes `reviewed` only when a native speaker has checked its colloquial form, its textbook form, and its distractors. The app and README state the review status plainly.

**Why the label matters:** Claude is more likely than a native speaker to drift toward textbook register, mis-spell informal romanisation, or choose a phrase nobody says. The register feature depends on exactly that distinction, so unlabelled generated content would undermine the product's central claim.

**Consequences:** a second Tamil speaker is still needed to promote items to `reviewed`. Content lives in data files, not code, so review changes never touch Swift.

## 026 — Two spoken registers only: casual and respectful
**Status:** active — refines 008 for v1

The owner's direction: teach the bare minimum of register, casual (`nee`, `un-`) and respectful (`neenga`, `unga-`), and skip written or literary forms such as `neengal`.

**Decision:** every item carries a `register` (`casual` | `respectful` | `neutral`). The "other option" in each question is the same sentence in the *other spoken register* (`registerVariant`), not a textbook form. The prompt names the audience ("to a friend", "to an elder"), so choosing the wrong register for the audience is a register mistake, not a vocabulary one. `neutral` items have no you-form and no register variant, so they carry a third wrong distractor instead.

**Consequence:** the Feedback state formerly called "understood, but formal" becomes "right sentence, wrong register for this person" and says what to use with whom. This keeps the register-awareness feature and drops the news-anchor framing, so register feedback now needs no ~40-rule classifier in v1, only item data. Schema change: `formalVariant` → `registerVariant` (nullable), plus `register`.

## 027 — Gendered casual address taught; common English loanwords kept as spoken
**Status:** active — refines 026

Two owner directions for v1 content:
- **Casual speech carries gendered address.** Casual items to a close friend end in `da` (male) or `di` (female); each item records `addressee` (`male` | `female` | `any`). Respectful speech has no gendered address.
- **Common English loanwords stay English.** Tamil speakers say `phone pannu`, `bus`, `ticket`, `bill`, `thanks`, `sorry`; the app teaches those forms rather than literary Tamil replacements. The target is the ordinary Tamil speaker, who knows these words.

**Consequence:** `romba thanks` and `wait pannu` are correct answers, and a Sanskritised Tamil substitute would be the wrong one. Content validation must not flag Latin-script English words in romanised fields.

## 028 — v1 progress is stored in a single JSON file, not SwiftData
**Status:** active — departs from PRD §7

**Decision:** review state and the attempt log (item ID, outcome, timestamp) live in one Codable JSON file in the app's Application Support directory, written atomically with `.completeFileProtection`, behind a `ProgressStore` protocol. SwiftData is not used in v1.

**Why:** the data is on the order of a hundred review records plus an attempt log. Plain value types are `Sendable` and stay clean under Swift 6 strict concurrency, where SwiftData `@Model` classes and `ModelContext` isolation add friction. Reset is deleting one file, and the schema version is explicit. The protocol boundary lets SwiftData replace it later without touching callers.

**Consequences:** a corrupt file throws and is never silently overwritten. v2 can swap the store behind the same protocol.

## 029 — iOS 27 deployment target and iPhone 17 simulator as the standard
**Status:** active — supersedes 005

**Decision:** the app targets iOS 27, and iPhone 17 is the standard test simulator. `IPHONEOS_DEPLOYMENT_TARGET = 27.0`; Swift packages declare `.iOS(.v27)`.

**Why:** 005 chose iOS 17 to widen device support and avoid iOS 26's `SpeechAnalyzer`. This is a portfolio project that is not distributed (README), so device reach has no value, and the only simulator runtime installed is iOS 27, so testing on the real deployment target is simpler and more honest than testing on a newer OS than we claim to support. The `SpeechAnalyzer` concern belonged to v2 voice and is revisited there (Task 0.1).

**Consequence:** the original reasoning is kept in 005. Docs that said iOS 17 were updated in the same change. Nothing in v1 depends on iOS 27-only APIs, so lowering the target later is a one-line change if distribution ever matters.

## 030 — v1 collects a display name only, stored on the device
**Status:** active — implements 014c for v1 (no telemetry yet)

**Decision:** on first launch the app asks for one thing: a display name. It is shown in the greeting ("Hi <name>") and nothing else. It is stored in a local JSON file (`Application Support/BLT/profile.json`, atomic write, `.completeFileProtection`) behind a `ProfileStore` protocol and never leaves the device: v1 has no network code (CLAUDE.md constraint 1; enforced by the forbidden-API guard and the binary check). There is no account, password, email, or identifier of any kind.

**Not collected:** age, gender, location, contacts, device identifiers. They have no use in v1 (nothing is personalised; there is no cohort analysis, DECISIONS 022), so collecting them would be data we hold without a purpose. Adding any field later means editing this ADR first; if it ever feeds telemetry, `docs/BACKEND.md` §5 (the exhaustive field tables) must be edited first and consent shown (DECISIONS 012, 014c).

**Rules:** the name is trimmed, 1 to 40 characters, no control characters; any script is allowed because it is the user's own name. "Change name" lives in Settings. Reset progress does not delete the name. Quitting a session mid-way keeps every answer already given, because each answer is saved the moment it is made.

**Privacy manifest:** `NSPrivacyCollectedDataTypes` stays empty because nothing is collected off-device.

## 031 — Scenario cards show answered progress, not the native-review count
**Status:** superseded by 033 (cards now show a completion percentage) — amended 025

The Home card line "n of 20 reviewed" counted items whose `reviewStatus` is `reviewed` (native-speaker review of the AI-drafted content), but sat next to the learner's own progress and read as "questions you've reviewed". The owner is verifying the content JSON by hand, so the card now shows the learner's progress instead: **"n of 20 answered"** (distinct items answered at least once).

**Unchanged:** the item-level "Unreviewed draft" badge on Question and Feedback and the Settings statement ("drafted by an AI … n of 100 reviewed") still disclose review status honestly (025). Only the card changed.

## 032 — Intro title "blt.ai" and a deep-purple accent
**Status:** active

The intro title is **blt.ai** (it was "For the love of Tamil"; the tagline stays). The app accent is deep purple instead of system blue: light `#5B3FA8` with white text, dark `#B79CF0` with dark text `#1A1821`; accent tint `#E4DBF6` / `#33294F`. It is applied once through `bltTheme()` and `BLTPrimaryButtonStyle`, and through the `AccentColor` asset for system dialogs. The page stays lilac (`#F0EAFA` light, `#1A1821` dark); feedback tones are unchanged.

**App icon:** "Two voices": a Telugu అ bubble overlapping a Tamil அ bubble, in standard, dark and tinted variants (`tools/app-icon/`).

**Known limits:** the iOS keyboard's return key and some system keyboard UI stay system blue (SwiftUI tint does not reach them). The Settings reset button and confirmation dialogs use a destructive role, which could render red on some iOS versions; revisit if seen.

## 033 — Home: shiny greeting on top; cards show completion %, wrong answers stay incomplete
**Status:** active — supersedes the card counts in 031

The greeting "Hi <name>" is the first element on Home, in a shimmering deep-purple heading (`ShimmerText`), above a plain "Scenarios" label. The large "Scenarios" navigation title and the overall "n items due" / "Nothing is due for review right now." lines are gone: if nothing is pressing, nothing is shown.

Each scenario card shows its title, subtitle and one completion percent with a bar (`CompletionBar`), replacing "x due · y new · z learned" and "n of N answered". An item is **complete** only when its latest outcome is `correct`; never answered, `wrongRegister` and `wrong` are incomplete, so a wrong answer keeps the scenario below 100% and the session planner (unchanged) re-presents it. The percent rounds down, so 100% means every item is complete.

**Accessibility:** every shimmer gradient stop, the highlight peak and every blend between them keeps at least 4.5:1 against the page in light and dark (tested); Reduce Motion gives a static gradient; the sweep is hidden from VoiceOver.

## 034 — Sessions sample and shuffle questions
**Status:** active

**Decision:** `SessionPlanner` takes a random generator (`plan(…using:)`, `reviewAnywayPlan(…using:)`; the old non-random signatures are removed on purpose). Due items are always selected first (earliest due first, so wrong answers always beat new items); any remaining places are filled with a random sample of the unseen items instead of the first ones in content order; the whole selection is then shuffled, so due and new items interleave. "Review anyway" picks the earliest-due items as before and shuffles their order.

**Why:** with a fixed content order every session opened with the same questions in the same order, so answers could be remembered by position rather than learned. **Trade-off:** scheduling priority is unchanged (what is selected still follows due dates); only the choice among unseen items and the presentation order are random. `SessionViewModel` passes its injected `SessionRandomSource`, so tests seed it.

## 035 — "About the content" follows the data
**Status:** active — refines 025

The owner wants Settings to say that every lesson is checked by a native Tamil speaker before the learner sees it. The statement is therefore data-driven: when every item's `reviewStatus` is `reviewed` it reads "Every lesson was checked by a native Tamil speaker before it was added to the app." and the "n of N reviewed" line is hidden; until then it keeps the honest draft wording and the count. It flips automatically once the owner marks items reviewed (content editor, "Mark reviewed"). The per-item "Unreviewed draft" badge is unchanged and disappears item by item.

**Why not an unconditional claim:** with 0 of 100 items marked reviewed the app would assert something its own data contradicts, which is exactly what 025 exists to prevent.

## 036 — Lessons can be imported from the Files app
**Status:** active

**Decision:** Settings has an "Import lessons" action (system Files picker, `.json`, up to 10 files) so reviewed content reaches a phone without a rebuild. A chosen file uses the same schema as `content/*.json`. An imported scenario replaces the bundled scenario with the same `scenarioId`, or is added when the id is new. The app applies it at once (it rebuilds its root with the new catalog; progress is untouched) and "Remove imported lessons" returns to the bundled content.

**Safety:** imported files are untrusted input. They go through the same `ContentLoader` validator as bundled content, **all or nothing**: if any chosen file has any issue, nothing changes and the learner sees a plain message (no partial imports, no silently dropped items). Validation runs against the catalog the learner would end up with, so duplicate item or scenario ids across files are rejected. Accepted files are written to `Application Support/BLT/content/` with `.completeFileProtection`; the stored name is a hash of the scenario id, never the user's file name. A manifest, written last, says which files are active, so a crash mid-import leaves the previous state. The picker returns a user-chosen local file: no network API is involved and the constraints in CLAUDE.md still hold. No Info.plist keys are added (`UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` stay banned).

**Stale imports:** the manifest records the hash of the bundled file an import replaced. If a newer build ships a different bundled file for that scenario, the import is ignored and the bundled one wins, so a reinstall never leaves older imported lessons shadowing newer bundled ones. Imports of new scenario ids are kept.

**What this does not do:** it does not remove the weekly Xcode run on a free Apple ID. That run renews the app's 7-day signature, which no in-app feature can do; only a paid developer programme or a sideload refresher changes that. The import only means content can change between runs. One-tap AirDrop ("Open in blt.ai") was left out on purpose: it needs a custom Info.plist document type, and files saved to Files and picked in-app work without it.

**Threat note:** a person who imports a hostile file could show offensive text to themselves. Content is plain text only and import is deliberate and local, so this is accepted.

**Implementation notes:** the root view is rebuilt with a new identity after an import or removal (the learner lands on Home) and the "Lessons" alert is attached to the stable container above it, because an alert on a view being replaced is never shown. The Remove confirmation uses no destructive role: nothing is lost, and the system draws that role in red.

## 037 — Reset progress looks like a warning everywhere
**Status:** active — an exception to the "never red" rule

The owner wants Reset progress to look like a warning wherever it appears, so a learner cannot erase their progress by accident. Both in-page Reset buttons (Settings, and Home's error state) use `BLTWarningButtonStyle`: deep red text and outline on a pale red tint, a bold label and a warning triangle, so the warning is never colour alone. The colours are `Palette.destructive` (light `#8F1D14` on `#FBE4E1`, dark `#FFB4AB` on `#3D1A17`), tested to meet 4.5:1 against their own tint and against the page and cards. The confirmation dialog keeps the system's destructive button, which iOS draws in red, and its message says the reset cannot be undone. Reset stays a two-step action.

This is the only place red is allowed. `destructive` is deliberately kept out of `Palette.allColors`, which the no-red test covers, so every other colour is still checked red-free; wrong answers and feedback keep the neutral and nudge tones. The "Remove imported lessons" dialog uses no destructive role because nothing is lost (progress is kept and the files can be imported again).

## 038 — No duplicate prompts or answers across the course
**Status:** active — applied in the catalog validator (plan.md, chunk C1). Applies to each course separately (042)

The course grows from 100 to 2,000 phrases (`docs/COURSE_SYLLABUS.md`), drafted over months. Without a rule, the same sentence would be written twice. Three checks. Across the catalog, ignoring case, spacing and punctuation: no two items share a `sourcePrompt`, and no two items share a `canonical`. Inside one item, ignoring only case and surrounding spaces: no accepted spelling is listed twice. The narrower comparison inside an item is deliberate: accepted spellings often differ only by a question mark, a hyphen or a space, and those variants are wanted. Wrong options may repeat across items, because a good wrong option is often reused.

The checks live in the validator, so bundled lessons, imported lessons and the editor all apply the same rule. The catalog-wide checks run against the catalog the learner would end up with, like the existing duplicate-id checks (036). `scripts/content-index.sh` lists every existing prompt and answer so a drafter can avoid repeats before writing.

## 039 — The course has levels; lessons carry their level
**Status:** active — the `level` field and its validation (chunk C1) and Home grouped by level with a Continue suggestion (chunk C2) are built. Lesson naming and folders are amended by 044

The 100 lessons are grouped into 8 levels taken in order (`docs/COURSE_SYLLABUS.md`). Each lesson file gains an optional `level` object: `number`, `title`, and `position` (its place within the level). `position` is needed because the first five lessons keep their original ids, which would otherwise sort after the new ones. A file without `level` (an older import) is listed under "Other lessons". The same level number must always carry the same title.

New lessons are named `content/l03-u07-<slug>.json` with `scenarioId` `l03-u07` and item ids `l03-u07-i01`. The first five keep their ids so saved progress survives.

Home groups lessons by level and suggests the next unfinished one. **Nothing is locked**: the owner chose an ordered course the learner can move around in, because a locked level strands a learner who is stuck on one lesson. This replaces "exactly 5 files" in `docs/MVP_PLAN.md` (chunk C3) with: at least 5 files, exactly 20 items each, level numbers with no gaps. A separate course manifest file was rejected because the loader and the import treat every `content/*.json` as a lesson. The import limit rises from 10 to 20 files so a whole level can be imported at once (amends 036).

## 040 — New phrases carry a Tamil-script spelling
**Status:** active — applied in the catalog validator (plan.md, chunk C1). The field is renamed `script` and covers Telugu by 044 (pending)

Each item gains an optional `tamilScript` field: the canonical answer written in Tamil script. It exists so audio can be generated later without a second review of 2,000 phrases, since speech voices read Tamil script and not the informal Latin spelling. It is optional so the first 100 phrases stay valid; every lesson written under the new naming must have it, and the first 100 are backfilled later.

When present it must contain Tamil-script characters and no Latin letters. **Tamil script stays banned in every other field**, and in all Swift code and test fixtures. The app does not display the field yet; the product stays romanised (001, 024). It is drafted by Claude and reviewed by the owner with the rest of the item (025).

## 041 — A final exam of 100 questions, pass at 75
**Status:** pending — agreed with the owner; built in plan.md's exam chunks. One exam per course (042)

When every level is complete, Home offers a final exam: 100 questions in one sitting, no feedback until the end, pass at 75. About 70 are sentences the learner has not seen, built only from words and patterns the course taught; about 30 are taken from the lessons by id. The blueprint is in `docs/COURSE_SYLLABUS.md` section 6. The paper is written last, after Level 8 is reviewed.

**Scoring:** only the canonical answer counts. The same sentence in the other register is not a correct exam answer, matching Home completion (033). **The exam never touches scheduling:** exam answers write no review records, and results are stored in their own file, so the frozen `ProgressStore` contract is unchanged. Reset progress clears exam results too.

**What a pass means:** the questions are multiple choice, so a pass shows the learner recognises natural spoken Tamil in unfamiliar sentences. It does not show they can say it. The exam screen states this, and speaking stays with the voice work (024).

## 042 — blt.ai is a two-way course for a couple: Tamil and Telugu
**Status:** pending — agreed with the owner on 2026-10-09; built by plan.md. Reframes 001 and extends 025

The app began as colloquial Tamil for a Telugu speaker (001). The owner's real case is a couple, one Tamil speaker and one Telugu speaker, who share English. So the thesis becomes: **one app, two courses, each partner learns the other's language, English is the common medium.** BLT now reads "Budugu Learns Tamil / Telugu". The learner gives a name and picks the language they want to learn.

**What stays the same.** Everything 001 argued for Tamil holds for Telugu in mirror image: the two languages share word order, stacked endings and a large vocabulary, so the course spends its effort on words and on register and teaches no grammar terms. Each course teaches the spoken language only, in two registers (casual and respectful). Text-only multiple choice, three outcomes, spaced repetition, review labels, lesson import and every hard constraint in `CLAUDE.md` are unchanged. Voice stays in v2 (024), now for both languages.

**The two courses mirror each other.** One syllabus (`docs/COURSE_SYLLABUS.md`): 8 levels, 100 lessons, 2,000 phrases per course, and wherever it is natural the same English prompt answered in Tamil in one course and in Telugu in the other. The couple learn the same things and can practise on each other. Prompts differ only where a sentence does not work in one language; a script lists the differences, it does not forbid them. The duplicate rules (038) and the final exam (041) apply to each course separately.

**Telugu variety.** Standard spoken Telugu of Coastal Andhra, the variety closest to films and television, chosen by the owner because it is the most widely understood. Written and literary forms are out of scope, as for Tamil.

**Review.** Each course is checked by its native speaker: the owner reviews Tamil, the owner's partner reviews Telugu. Telugu content is Claude-drafted and `unreviewed` until then (025 applies to both languages). The rule "no real Tamil text in code or test fixtures" now covers Telugu too.

**What this costs.** Little code, because lessons are data and the engine never looks at the language. A lot of content: 3,900 phrases to draft and about 65 hours of review between two people.

## 043 — The learner's language lives on the profile; each language has its own data
**Status:** active — built in plan.md chunks A4, B2, C1, C3 and D1. Changes the frozen `UserProfile` and `AppDependencies` (`AppDependencies.language` is a required parameter). Per-language data lives under `Application Support/BLT/courses/<language>/`; the old build's `progress.json` and `content/` are removed once at launch (`LegacyStorageSweep`)

The profile gains the language being learned. Onboarding asks for it after the name. It can be changed later in Settings.

- **Separate data per language.** Progress, imported lessons and the exam result are stored per language under `Application Support/BLT/courses/<language>/`. Switching language loses nothing, and one phone can hold both partners' courses. Nothing is migrated from before this change: the owner confirmed on 2026-10-09 that no learner has progress yet, and the lesson ids change (044). The old build's progress file and imported lessons are removed once at the first launch of the new build.
- **No assumed language.** A profile saved before this change has no language. The app shows the language step; it does not default to Tamil. A wrong guess here would silently show a learner the wrong course.
- **Reset progress clears only the language being learned,** and the confirmation says which. It keeps the warning style of 037.
- **Switching reuses the lesson-import reload** (036): the root is rebuilt with the other language's catalog and stores.
- `AppDependencies` gains the language so screens can name it in their wording. Nothing else in the engine reads it.

## 044 — One lesson format for both languages
**Status:** active — agreed with the owner on 2026-10-09; built in plan.md chunks A1, A2 and B1. Amends 038 to 040 and rewrites `docs/MVP_PLAN.md` section 2. Chunk A1 applied the catalog format (required `language`, `script`, `word`, wrong-course rejection) and updated the five shipped lessons in place.

- **`language`** (`tamil` or `telugu`) is required on every lesson file. A lesson in the wrong course is rejected, bundled or imported, so a Telugu file cannot land in the Tamil course.
- **Folders and ids.** `content/tamil/` and `content/telugu/`. Paired lessons share a key: `ta-l02-u03` and `te-l02-u03`, with items `ta-l02-u03-i01`. The five original Tamil lessons are renamed to this scheme (`ta-l01-u01` to `ta-l01-u05`) and stay `reviewed`; this reverses the "keep their ids" part of 039, because there is no saved progress to protect.
- **The word-gloss key `tokens[].tamil` becomes `tokens[].word`.** The five existing files are rewritten once; afterwards the old key is an error and is never read as a fallback. Lesson files imported before this change must be re-exported.
- **`tamilScript` (040, built but not yet used by any lesson) becomes `script`:** the answer in the lesson language's own script (Tamil U+0B80 to U+0BFF, Telugu U+0C00 to U+0C7F), with no Latin letters. Both scripts stay banned in every other field and in all Swift code.
- `level` and the duplicate rules are as decided in 038 and 039. The import limit is 20 files.

## 045 — Two tiers of UI tests: a short required set, and the full set off the PR path
**Status:** pending — agreed with the owner on 2026-10-09; built in plan.md chunk Q1. It becomes active when three pull-request runs in a row finish under 15 minutes and the full tier is green on `main` (the checklist is at the end of this entry). Nothing below has run on GitHub yet.

The UI suite takes about 50 minutes locally and 12 to 45 minutes on CI, and GitHub's preview runner hangs a UI query at random, so every pull request waits and retries. The suite is reshaped before more UI tests are added.

- **Rules are tested in the package.** A UI test that only checks a rule is replaced by a view-model test. A UI test stays only where the screen itself is under test.
- **PR tier, required:** one happy path per screen and the accessibility audits at the default text size, aiming at under 15 minutes for the whole check.
- **Full tier, not blocking a PR:** every UI test, including audits at the largest text size, on every merge to `main`, nightly and on demand. A failure there is fixed before the next PR merges.
- The decision is made from measured durations and retry counts, not guesses. Retries stay, and every retried test is listed.

**Trade-off accepted:** a largest-text-size regression can reach `main` and be caught minutes later instead of before the merge. Accessibility coverage is moved, not reduced.

**What was built (chunk Q1)**

- **Measured first.** Ten completed CI runs, 50 tests: `docs/TEST_TIMINGS.md`. The whole job took 21 to 60 minutes (median about 34), the UI step 16.5 to 52. Six attempts failed and passed on retry; three of those had hung for 251 to 889 seconds, which is where the 45 and 60 minute runs came from.
- **Ten UI tests removed**, each after a package test of the same rule passed (405 package tests became 424): completion after right, wrong and other-register answers, a missed item coming back, an answer given before ending, option-to-feedback routing, a cancelled Reset, and what is saved or erased. 40 UI tests remain. The table is in `docs/TEST_TIMINGS.md`.
- **Tiers are chosen by test class**, so a tier cannot drift by method name. PR tier: `AccessibilityUITests` (the eight default-size audits) and `HappyPathUITests` (one happy path per screen), 13 tests. Everything else, including the new `AccessibilityLargeTextUITests` (the eight largest-size audits and the five reachability checks, moved unchanged), is full tier only. `scripts/test.sh app --tier pr|full` selects them and `scripts/test.sh tiers` prints the lists. A check moves tier; none was dropped or weakened.
- **Build once.** `scripts/test.sh app --build-only` (build-for-testing) then `--no-build` (test-without-building). Package tests and UI tests are separate parallel jobs.
- **Required check names are unchanged:** `Guardrails and lint` and `Package and app tests`. The second is now a small gate job (on `ubuntu-latest`) that passes only if the new `Package tests` and `UI tests` jobs both pass. Branch protection needs no change; the two new job names must not be added as required checks, or they would also block on the full tier.
- **Triggers.** Pull request: PR tier. Push to `main`, a nightly cron (03:17 UTC) and `workflow_dispatch` (tier chosen, default full): full tier. The concurrency group includes the event name so the nightly run does not cancel a push run.
- **No per-test time limit.** It was tried (`-test-timeouts-enabled`, 240 seconds, kept as the opt-in `BLT_TEST_TIMEOUT`): a test that hit the limit was failed after 4 minutes and was **not** retried, so it would turn a hung attempt that passes on retry into a failed job. A hang therefore still costs up to 15 minutes on the runner; the 13-test PR tier gives it fewer chances to happen.
- **Retries stay** (`-retry-tests-on-failure -test-iterations 3`). A step lists every test that failed an attempt (`scripts/test.sh flakes <log>`) in the job summary, so a test that only passes on retry is visible.

**Not done, and why.** Turning off animations and the shimmer under the UI-test launch arguments needs a change to the app target (`UITestLaunch.swift` or the shimmer view), which this chunk may not touch: a follow-up. A shared `.xctestplan` would be tidier than class lists but needs the project file, which is not committed.

**Checked locally on a shared Mac (iPhone 17), not on GitHub.** Package tests 424 pass. Each full-tier class passed run alone (Home, SettingsImport, Persistence, EndSession, FeedbackFlow, Onboarding, HappyPath). The two accessibility classes pass except the two name-entry audits (`testNameEntryAudit`, `testNameEntryAuditAtXXXL`), which fail here with "The keyboard did not dismiss"; the unchanged pre-reshape test fails the same way on this Mac, so it is a local simulator keyboard difference, not caused by the reshape, and it passed in all ten recorded CI runs. The PR tier took 17 minutes here, of which 5 were a hung `testHomeAudit` that passed on retry and 5 were the name-entry audit failing three times; its passing tests add up to about 3 minutes per simulator clone. Those numbers say nothing about the runner.

**To check once pull requests can open (the proof is still owed)**

1. Three pull-request runs in a row, each with `Guardrails and lint`, `Package tests`, `UI tests` and `Package and app tests` green and the `UI tests` job under 15 minutes (the build, the 13 tests, queueing excluded).
2. A push to `main` runs the full tier (40 tests) green, and the nightly run starts on schedule and does not cancel a push run.
3. In the job summary, "UI tests that failed an attempt" appears and lists any retried test.
4. A `workflow_dispatch` run with tier `pr` runs only the 13 tests.
5. Branch protection still shows exactly the two required checks and merging is not blocked by the gate job.
6. Note how often a hung UI query still costs a run more than 15 minutes (the "tests that needed a retry" summary and the step duration). If it happens in more than one of the three runs, the next step is a job-level rerun of only the failed tests, not a per-test limit.

