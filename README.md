# BLT.ai

"Budugu Learns Tamil" — an iOS app teaching **colloquial** Tamil to Telugu speakers. Voice-first, on-device, no gamification.

Portfolio project. Not shipping to the App Store.

## The problem

Tamil is strongly diglossic: written Tamil (செந்தமிழ்) and spoken Tamil (கொடுந்தமிழ்) differ in verb morphology, pronouns, and case endings. Every mainstream app teaches the written register, so a learner finishes able to read a signboard and unable to hold a conversation. They sound like a newsreader.

## The thesis

Tamil and Telugu are both Dravidian — shared SOV order, agglutinative case suffixing, dative-subject constructions, a large shared lexicon. A Telugu speaker already owns the grammar.

So skip grammar entirely and spend all learner effort on lexical substitution, register, and listening at natural speed. The app's distinctive feature follows directly: a classifier that detects when a learner produced the *textbook* form and shows them what a 25-year-old would actually say.

## Documents

Read in this order.

| Document | What it is |
| --- | --- |
| `docs/PRD.md` | Product spec. Problem, thesis, non-goals, screens, scoring design. |
| `docs/BUILD_PLAN.md` | Sequenced tasks with acceptance criteria. One task = one PR. |
| `docs/DECISIONS.md` | ADR log, including superseded decisions. Start here if you want the reasoning. |
| `docs/OPEN_ITEMS.md` | Unresolved, and decided-but-not-applied. Check before starting work. |
| `docs/SECURITY.md` | Review rubric. Audio handling, telemetry, supply chain. |
| `docs/BACKEND.md` | v1.5 telemetry and diagnostics design. Threat model, data classification. |
| `docs/RECORDING_GUIDE.md` | How to elicit colloquial Tamil without producing formal register. |
| `docs/WORKFLOW.md` | How this gets built with an AI coding agent, and how to review it. |
| `CLAUDE.md` | Standing instructions for the agent. Read automatically each session. |

## Three decisions worth reading

**Pronunciation is measured but never gates progression.** It was in scope, cut as pedagogically wrong, then restored as measurement-without-gating on a progressive tolerance ladder. The final design is better *because* it went through the cut. `DECISIONS.md` 006–007.

**Identity went anonymous → absent → named.** The middle step is what revealed the privacy machinery was solving a problem this project doesn't have. `DECISIONS.md` 014.

**Breadcrumbs are a closed enum, not strings.** A diagnostics breadcrumb containing a transcript would leak exactly what the privacy claim forbids, through a path nobody watches. Enforcing it in the type system rather than in review is the difference between a property and a policy. `DECISIONS.md` 017.

## What this is not

Not a cohort study. Expected user count is two, so telemetry has no statistical value — it exists as a longitudinal case study of one learner and as an infrastructure artifact. Any chart built on seeded data is labelled synthetic in the chart itself.
