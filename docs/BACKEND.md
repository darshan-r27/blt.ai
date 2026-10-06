# BLT.ai — backend design

**Status:** Draft v3
**Scope:** v1.5. The v1 app ships with no backend and does not depend on one.

**Changes from v2:** named profiles replace anonymous events. Diagnostics stream added (TestFlight + MetricKit + structured errors). Retention split by stream.

---

## 1. Why this exists

Two users: you and one other person, both known to each other. That changes what this system is for.

It is **not** statistical measurement. At n=2 there is no cohort, no significance, and no generalisable finding. Any README claiming otherwise is the weak point a reviewer will pull on.

It is three other things, all legitimate:

1. **A longitudinal case study of one learner.** Watching one person go Telugu → Tamil over months, with real data, is a genuine product artifact. It is a case study, and calling it that is both honest and more interesting than a fake cohort.
2. **Debuggability.** Without crash and error reporting you will hear "it stopped working" and have nothing. That is the difference between a toy and something maintained.
3. **An infrastructure artifact.** Schema design, consented collection, enforced retention, IaC, teardown. The only component in the project that demonstrates any of it.

### On the design history

This document has reversed itself once, and the reversal should be recorded rather than hidden.

v1 kept a rotatable pseudonymous install ID. v2 removed all identity, on the correct reasoning that anonymous cohort telemetry needs no identifier. v3 restores identity as a **named profile**, because the actual requirement turned out to be tracking one known person over time, not measuring a cohort of strangers.

The middle step was not wasted. It is what revealed that the privacy machinery was solving a problem this project does not have. An anonymous ID between two people who have met is privacy theatre.

## 2. The claim

> **No raw user content is retained.** Audio never leaves the device. Transcripts never leave the device. Identity is a name the user chooses, not an identifier the app assigns — and everything collected is visible in-app and deletable by the user.

The strong half is unchanged from every prior draft and was always the important half. What changed is that identity is now present, consented, and legible rather than absent.

**Off by default.** A user who declines at onboarding and never opens Settings makes no network request, ever.

**Inspectable.** "See what's sent" renders the exact pending payload as formatted JSON, generated from the live queue. Not a sample, not a description.

**Deletable.** "Delete everything" issues a server-side delete keyed on the profile name and clears the local queue. It is a real delete, not a tombstone.

## 3. Identity

At first launch, after the consent screen, the user types a display name. That string is the identifier.

- **User-chosen.** The onboarding copy says plainly that it need not be a real name. A pseudonym works identically.
- **Local plus transmitted.** Stored in the app container, sent with every event.
- **Changeable.** Editing it in Settings re-keys future events. Prior events keep the old name; the app says so rather than implying a merge.
- **The deletion key.** "Delete everything" is a delete by profile name.

`sessionID` remains: a UUIDv4 held in memory for one practice session, used to order attempts within a sitting. It is not persisted and carries no meaning across sessions.

**Precise timestamps are now fine.** They were excluded in v2 as a fingerprinting vector. With a name already attached there is nothing left to fingerprint, so full-resolution timestamps are collected — they make the learning curve and the diagnostics timeline far more useful.

## 4. Two streams, one endpoint

All events go to `POST /events`. A `stream` discriminator routes them.

| Stream | Contents | Retention |
| --- | --- | --- |
| `learning` | Practice attempts and session outcomes | Indefinite — it is the point |
| `diagnostic` | Crashes, hangs, caught errors, MetricKit payloads | 30 days, then deleted |

One endpoint, one client module, one deployment. The streams differ in schema and retention policy, not in transport.

## 5. Data classification

Both tables are the contract. A field not listed is not collected, and adding one means editing this document first.

### Learning events

| Field | Question it answers |
| --- | --- |
| `profileName` | Whose curve this is |
| `sessionID` | Orders attempts within one sitting |
| `timestamp` | Learning curve over time, session duration |
| `itemID` | Which items are hard |
| `scenarioID` | Module progress and completion |
| `verdictClass` | Comprehension and production accuracy |
| `registerOutcome` | Colloquial rate — the headline |
| `spanFraction` | Pronunciation rate, ladder calibration |
| `toleranceLevel` | Which rung the attempt came from |
| `positionInSession` | Where sessions are abandoned |
| `appVersion`, `osVersion` | Regression triage |

### Diagnostic events

| Field | Notes |
| --- | --- |
| `profileName` | Whose device |
| `timestamp` | |
| `kind` | `crash` / `hang` / `caughtError` / `metricKit` |
| `errorDomain`, `errorCode` | For `caughtError` |
| `breadcrumbs` | Last ~50 state transitions. **Item IDs and state-machine states only.** |
| `metricKitPayload` | Apple's JSON, forwarded verbatim. Already scrubbed by the OS. |
| `appVersion`, `osVersion` | |

### Not collected, in either stream

| Field | Why not |
| --- | --- |
| Raw audio | Never leaves the device. Non-negotiable. |
| **Transcripts** | User-generated content that may contain anything the user said. Excluded even though it would materially improve item-level diagnostics. |
| **Breadcrumbs containing user content** | See below. The single easiest way to break §2 by accident. |
| Location, contacts, photos | Never requested, never accessed |
| Any Apple identifier | IDFA, IDFV, device check token |
| Device model | `osVersion` covers the triage need |

### The breadcrumb rule

A breadcrumb reading `scored item 042, transcript "naan varen"` leaks exactly what §2 promises not to transmit — through the diagnostics path, where nobody is looking.

**Breadcrumbs carry item IDs and state-machine transitions. Nothing else.** Never a transcript, never a file path, never a payload body. Model this as a closed enum of breadcrumb types rather than a free-text string, so the rule is enforced by the compiler instead of by review attention.

This is the highest-risk line in the document.

## 6. Crash and diagnostic strategy

Three tiers, each catching what the others miss. No third-party SDK.

### Tier 1 — TestFlight and Xcode Organizer

Free, built in, zero code. Symbolicated crash reports for TestFlight builds appear in Xcode's Organizer. You already ship TestFlight in Task 5.5, so this costs nothing beyond asking your tester to leave analytics sharing enabled in iOS Settings.

Catches: hard crashes. Misses: everything non-fatal.

### Tier 2 — MetricKit

`MXMetricManager` delivers daily payloads to the app on-device. `MXDiagnosticPayload` covers crashes, hangs, CPU exceptions, and disk-write exceptions; `MXMetricPayload` covers launch time, memory, and battery. Apple scrubs them before delivery. Forward the JSON verbatim through the ingest endpoint.

Delivery is **next-day**, not real time. Do not design a workflow that assumes immediacy.

Catches: hangs, performance regressions, crash diagnostics with stack traces. This is also the best portfolio line in the diagnostics section — MetricKit is native, free, and almost nobody uses it.

### Tier 3 — Structured errors and breadcrumbs

An in-memory ring buffer of the last ~50 state transitions. Any caught error emits a `caughtError` diagnostic with the buffer attached.

Catches: the things that matter most in practice — ASR returning nothing, a model failing to load, an audio session refusing to activate. None of these crash, and none reach Tiers 1 or 2.

### Why not Sentry or Crashlytics

A third-party SDK with network access breaks the single-networked-module boundary enforced everywhere else in this project, adds supply-chain surface to a repo whose dependency count is a stated feature, and transmits on its own schedule outside the consent surface. The three tiers above get ~90% of the value for none of that.

Worth writing up in `DECISIONS.md` — it's a real trade, made with reasons, and the kind of thing that reads well.

## 7. Retention

Split by stream, because they have different purposes and different leak surfaces.

**Learning events: indefinite.** A multi-month learning curve is the artifact. Deleting it defeats the system.

**Diagnostic events: 30 days.** Debug data has no long-term value and carries the breadcrumb risk. Nightly job deletes anything older, writes a run record with counts.

**Integration test:** insert diagnostics dated 31 days ago, run the job, assert they are gone and that no learning event was touched. **P0 on failure** — it means a stated retention policy is false.

**User deletion:** "Delete everything" cascades both streams by profile name, synchronously, and returns a count so the app can confirm what was removed.

## 8. KPIs

All of these are now measurable. Whether they are *meaningful* at n=2 is a separate question, answered honestly per metric.

### Meaningful at this scale

**Learning curve (headline).** Colloquial rate against cumulative attempts, per profile. This is the product thesis rendered as a line. For one dedicated learner over months it is a real result — a case study, not a cohort finding, and worth presenting as exactly that.

**Module progress.** Per-scenario completion state and items remaining. The thing you asked for: where your user is, at any point in time.

**Ladder progression.** Which rung, and how long each took. Directly tests whether 50 / 65 / 75 were spaced sensibly for a real learner rather than for six calibration speakers.

**Per-item difficulty.** Failure rate per item. Even n=1 tells you an item failing every time is a content bug.

**Abandonment point.** Where in a session practice stops.

### Measurable but not meaningful

D1/D7/D30 retention and activation rate are computable now that identity exists. At n=2 they are noise. Compute them if you like; do not present them as findings.

### Modelled LTV

No revenue, no paid tier, two users. Lifetime value is undefined and no CLV figure appears in this repo.

The notebook carries a model with every input labelled **external-benchmark** or **assumed** — retention from published language-app figures, cited; conversion, ARPU, margin, and CAC assumed with sensitivity ranges. Your own retention data is deliberately not used as an input, because a two-person curve is a worse estimator than a published benchmark and using it would be the kind of quiet dishonesty this document exists to avoid.

Output is a sensitivity table, never a point estimate. The first cell states that no input is measured.

## 9. Architecture

```
iPhone ──TLS──▶ POST /events ──▶ Postgres
  │                  │              ├─ learning  (indefinite)
  │                  └─ strips IP   └─ diagnostic (30d, nightly purge)
  │
  ├─ learning queue ──┐
  ├─ diagnostic queue ┴─▶ batched, wifi, deferred
  └─ MetricKit subscriber (next-day payloads)

TestFlight ──▶ Xcode Organizer (out of band, no code)
```

**Client.** A `Telemetry` module holding both queues in local SQLite. Flush on wifi at 50 events or 24 hours. Never blocks the UI. Silent failure, no retry past three attempts — telemetry must never degrade the app, and a diagnostics pipeline that causes bugs is worse than none.

The **only** module permitted to open a network connection. Review-enforced, CI-enforced.

**Server.** Postgres plus a thin FastAPI service, containerised, one small instance, Terraform for infrastructure, `docker compose` locally.

**Auth on ingest.** Now warranted — events carry a name, so an unauthenticated endpoint would let anyone write events attributed to your user. A single shared write key, in the app's build config via a gitignored `.xcconfig`, rotatable. This is weak auth and that is acknowledged: it protects against drive-by writes, not against someone who extracts the binary. Proportionate to two users and no valuable data.

## 10. Threat model

| Threat | Mitigation | Residual |
| --- | --- | --- |
| Interception in transit | TLS 1.3, no cleartext fallback | Accepted |
| Server compromise | Reveals a chosen name and practice results. No audio, no transcripts, no contact details, no credentials. | A named person's Tamil practice history is exposed. Low harm, non-zero. Documented rather than dismissed. |
| **Breadcrumb content leak** | Closed enum, compiler-enforced. No free-text breadcrumbs. | The highest-risk item here. Verify by reading the type, not the call sites. |
| Ingest spoofing | Shared write key | Extractable from the binary. Accepted at this scale. |
| MetricKit payload contains something unexpected | Apple scrubs before delivery; forwarded verbatim without augmentation | Trusting Apple's scrubbing. Reasonable. |
| Scope creep into user content | §5 tables plus the breadcrumb enum | Process control |
| Diagnostics retained past 30 days | Nightly job with an integration test | Requires someone to check the run record |

## 11. Compliance posture

Identity is present, so this is personal data under GDPR and India's DPDP Act. The prior draft's "the question is uninteresting" position no longer holds.

The posture: explicit affirmative consent at onboarding with a plain-language description, off by default, data minimisation to the §5 tables, a user-chosen pseudonymous identifier, in-app visibility of the exact payload, user-initiated deletion that actually deletes, and a documented retention policy enforced by a tested job.

That is a defensible processing basis for a two-person project, and the point is that the reasoning is written down and the controls exist in code.

**This is not legal advice and I am not a lawyer.** If this ever ships commercially, that assessment needs a professional.

## 12. Open questions

- Profile name changes don't merge history. Should they? Merging needs a stable ID underneath the name, which reintroduces the thing v2 removed. Currently: no merge, app says so. Revisit only if it actually happens.
- The shared write key is weak and extractable. Fine at two users. If this ever grows, per-device tokens issued at onboarding are the next step — a real design change, not a config tweak.
- MetricKit payloads are large and next-day. If they dominate the diagnostics volume, sample them rather than forwarding all.
- 30 days for diagnostics is a guess. Long enough to debug something a user reports a week late, short enough to bound the breadcrumb exposure.
