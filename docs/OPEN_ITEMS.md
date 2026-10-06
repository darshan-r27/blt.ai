# BLT.ai — open items

Things not yet settled, or settled but not yet applied. Review this before starting any task; several of these would change work in progress.

---

## Blocking — resolve before writing code

**Device capability probe (Task 0.1).** Does `SFSpeechRecognizer.supportedLocales()` include `ta-IN`? Determines whether the week-2 placeholder engine is twenty lines wrapping Apple's framework or two hundred wrapping whisper.cpp — which changes the week-1 dependency decision. Must run on a physical device; Speech APIs don't work in Simulator.

**Romanisation scheme (Task 0.3).** ISO 15919, or the ad-hoc Latin orthography Tamil speakers use in WhatsApp? Lean toward the latter — it matches the register goal. This is load-bearing: the register rules in DECISIONS 008 match on surface forms, so changing it later means rewriting both the content and the classifier.

**User interviews (Task 0.2).** The 8 scenarios should come from "what have you wanted to say to a Tamil speaker and couldn't," not from a textbook contents page.

---

## Decided but not applied

**Phase 2 reordering (DECISIONS 021).** BUILD_PLAN Phase 2 still runs script → paraphrase → red-line → record. The corrected order is record → transcribe → select → derive rules, per RECORDING_GUIDE §2 and §9. Task 2.3's red-line mostly dissolves into a selection pass. **BUILD_PLAN needs rewriting before Phase 2 starts.**

---

## Undecided

**Source language: Telugu or English.** The schema has `teluguGloss` and `teluguPrompt`. Renaming to `sourceGloss` and `sourcePrompt` makes the codebase source-agnostic — one field change, no logic change — allowing English glosses to ship first (authorable solo, unblocked) with Telugu added to the same items later.

Arguments on record:
- The transfer thesis (DECISIONS 001) only holds for Telugu L1. An English speaker shares no syntax, no case system, no lexicon, and no retroflexes. Lexical substitution onto shared syntax is *generative*; 120 English→Tamil phrases are just 120 memorised phrases.
- Telugu→Tamil colloquial is essentially unserved. English→Tamil has dozens of apps.
- The register classifier is language-internal to Tamil and works either way.
- The pronunciation ladder would need recalibrating for English L1 — 50% is punishing for someone with no retroflexes at all.

**A second Tamil speaker is required regardless of this decision.** One fluent person reading a generated script produces formal register through orthographic interference (DECISIONS 021). Two people improvising a scene produce colloquial Tamil automatically. This is the real constraint, and it's a couple of hours from one friend rather than a budget line.

**"Keep my recordings" toggle.** Currently opt-in, off by default, and it's the one path where "audio does not survive the attempt" stops being unconditional. It also complicates the launch sweep, which must distinguish a deliberately-retained recording from an orphan — getting that backwards either deletes something the user asked to keep or leaves orphans forever. Dropping the toggle makes P2 unconditional and the sweep two lines.

---

## Not yet built

**Wireframes.** Only the three-beat session loop exists. Missing: Scenarios (home), Progress, Settings.

Progress is the one worth doing next — it carries the colloquial-rate headline, per-phoneme rates, and the tolerance ladder with the next rung's requirement stated plainly. Getting that legible without drifting into gamification is the actual design problem. Settings has grown too: profile name, two telemetry toggles, "see what's sent," "delete everything."

---

## Carried from the docs

Full context in the source documents; listed here so they aren't lost.

- **PRD §11** — which sentence encoder survives 8-bit quantisation with usable cosine separation on short, romanised, ASR-noisy Tamil; how many accepted paraphrases per item (start at 4); the 30-attempt advancement window is a guess; profile name changes don't merge history.
- **PRD §8.5 / BACKEND §12** — whether confusion-table detection has enough resolution for level 3 (65%), or whether GOP needs to arrive before v2. Answerable only once calibration recordings exist. If transcript-level detection turns out binary in practice, the 50/65/75 ladder will feel steppy.
- **BACKEND §12** — the shared ingest write key is extractable from the binary (accepted at two users); MetricKit payloads are large and next-day, sample if they dominate; 30 days for diagnostics retention is a guess.
- **BUILD_PLAN Phase 3 fallbacks** — if the encoder doesn't separate at int8, ship fp16 or exact-match-plus-register. If learner and native pronunciation distributions don't separate at Task 3.7, ship the ladder at levels 1–2 and document GOP as the diagnosed requirement. Do not raise the ceiling to make the feature look more complete than the measurement supports.
