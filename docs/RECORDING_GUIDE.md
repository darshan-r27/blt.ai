# BLT.ai — recording guide

How to get ~120 colloquial Tamil utterances with their Telugu glosses, in two sessions, without a studio.

---

## 1. What public data can and cannot do

| Need | Public data? | What to do |
| --- | --- | --- |
| Teaching audio for your 120 items | **No** | Record. A general corpus contains other sentences, not yours. |
| Native baseline for the pronunciation detector | **Yes** | IndicVoices or Common Voice Tamil. Saves three calibration speakers. |
| Learner audio (Telugu-L1 attempting Tamil) | **No** | Record. L2 Tamil corpora don't exist. You, your user, two friends. |
| Register reference — how people actually talk | **Yes** | IndicVoices conversational Tamil. Listen before you write anything. |
| ASR model | **Yes** | IndicConformer-TA, pretrained. No data needed. |

**Why not TTS for teaching audio.** Tamil TTS is trained predominantly on read speech, which is the formal register the product exists to fix. Synthesising your items would teach the exact thing you're trying to unteach. Use it as a placeholder during Phases 1–3 so you aren't blocked, then replace it.

**Worth reading first:** AI4Bharat published their collection blueprint with IndicVoices — protocols, prompt repository, transcription guidelines. Skim it before your session.

## 2. The one principle

**Elicit, don't read.**

Reading written Tamil aloud pulls a speaker toward formal register automatically. Orthography carries register, and a literate Tamil speaker shown வாருங்கள் will say வாருங்கள் — even if they'd never say it in the situation you're depicting. This is the single biggest risk to the corpus, and the conventional script-then-record workflow causes it.

So the order inverts:

1. Describe a situation out loud, in English or Telugu. Never show Tamil text.
2. The speakers enact it. Two people, improvised, in character.
3. Record the whole thing, including the false starts.
4. Transcribe afterward, in romanised Tamil, exactly as spoken.
5. Select the 12–15 best utterances per scenario as your items.

The corpus is the *output* of the session, not its input. Your canonical forms are whatever real speakers actually said.

**Do not correct them mid-take.** If someone says something you think is "wrong," it's data. Colloquial speech contains elision, hesitation, and grammar no textbook endorses. That's the register.

## 3. Setup

**People.** Two Tamil speakers, 20–35. You can be one. Get a second with a different voice — ideally a different gender, since a learner trained on one voice overfits to it. A Telugu speaker for the gloss pass, who can be your actual user.

**Gear.** A USB condenser mic (~$100, Samson Q2U or Audio-Technica AT2020USB) beats a phone by a lot. A phone in a quiet room is acceptable. Record 48kHz/24-bit if you can.

**Room.** Small, soft, no hard parallel surfaces. A bedroom with a made bed and curtains drawn is better than a living room. Closet with clothes in it is better still. Turn off fans, AC, and the fridge if you can hear it.

**Session length.** Two sessions of 90 minutes, not one of three hours. Voices tire and register drifts formal when people get self-conscious.

## 4. Protocol

**Before recording:**
- Consent form signed (§7). Do this even between friends — it's the difference between a portfolio project and a sloppy one.
- Record 30 seconds of room tone. You'll want it.
- Explain the goal in one sentence: *"Talk the way you'd actually talk, not the way you'd write."*

**Per scenario:**
1. Read the prompt card aloud. Don't hand it over — hearing it keeps them in speech mode.
2. Let them run the scene. 2–4 minutes. Don't interrupt.
3. Run it again with the roles swapped.
4. Run a third time with the complication on the card.
5. Slate each take verbally: *"Scenario 3, take 2."*

**After each scenario, capture three extras** while it's fresh:

- **Paraphrases.** "What else could you have said there?" Ask for alternatives to the 4–5 lines you want to keep. Ask them to *say* the alternatives, not list them.
- **The formal variant.** "Now say that line the way a news anchor would." You need both forms for the register classifier, and this is the cheapest moment to get it.
- **The Telugu gloss.** Your Telugu speaker gives the natural Telugu equivalent — meaning-for-meaning, not word-for-word.

## 5. The prompt cards

Read aloud. Never show Tamil text. Prompts are in English; the scene is played in Tamil.

---

**1 — Auto rickshaw**
*A is standing outside a metro station. B is an auto driver. A needs to get to T. Nagar and thinks the quoted fare is too high.*
Complication: the driver says the meter is broken.

**2 — Ordering at a mess**
*A has never eaten here. B works there and is busy. A wants to know what's good, what's not too spicy, and whether there's anything without onion.*
Complication: the thing A wants just ran out.

**3 — Office small talk**
*A and B are colleagues at a coffee machine. They've met twice. Neither has anything urgent to say.*
Complication: B is clearly having a bad day.

**4 — Asking directions**
*A is lost on a residential street looking for a specific building. B is a stranger who half-knows the area.*
Complication: B gives directions A doesn't quite follow, and A has to ask again without being rude.

**5 — Phone call with a landlord**
*A is a tenant. The water heater has been broken for four days. B is the landlord and has been avoiding the call.*
Complication: B says the plumber came and nobody was home.

**6 — Buying something at a shop**
*A wants a phone charger. B runs a small electronics shop. A isn't sure which one fits and doesn't want the expensive one.*
Complication: B pushes the expensive one.

**7 — Meeting a friend's parents**
*A is meeting B, a friend's mother, for the first time. B offers food. A has already eaten but shouldn't say so bluntly.*
Complication: B asks what A does and whether A is married.

**8 — Arguing about a bill**
*A was charged for something they didn't order. B is the cashier. Neither wants a scene.*
Complication: B insists the order was placed.

---

Scenarios 3 and 7 are where the register work concentrates — politeness, hedging, and softening are exactly where formal and colloquial Tamil diverge most. Give them extra takes.

## 6. After the session

1. **Listen through and mark keepers.** 12–15 utterances per scenario. Favour short ones — a learner repeating a 15-word sentence is practising memory, not speech.
2. **Transcribe in romanised Tamil**, exactly as spoken, including elisions (வந்துட்டே, not வந்துவிட்டேன்). Use the scheme chosen in Task 0.3.
3. **Segment and name** by item id. Normalise to −16 LUFS, trim, convert to AAC.
4. **Build the register rule set** (Task 2.4) from the canonical/formal pairs you captured. The patterns will be obvious once you have 120 of them side by side.
5. **Extract the minimal-pair table** (Task 2.5) from words that actually appear in your corpus, not from a general list.
6. **Archive raw WAVs outside the repo.** Consent forms too.

## 7. Consent

One page, signed before recording, stored outside the repo. Covers:

- What's being recorded and why
- That audio will be bundled into an app and distributed via TestFlight
- That the repo will be public and may be shown to employers
- That raw recordings are archived privately and not published
- Right to withdraw, and what that means practically once a build exists
- Contact

Do this even with friends. It takes ten minutes, it's the correct practice, and "we recorded under signed consent, archived outside the repo" is a line that belongs in your README.

## 8. Time and cost

| | |
| --- | --- |
| Two 90-minute sessions | 3 hrs |
| Transcription and segmentation | 4–6 hrs |
| Telugu gloss pass | 2 hrs |
| Rule set and confusion table | 3 hrs |
| **Total** | **~12–14 hrs** |
| **Cost** | **$0–100** (mic, if you don't have one) |

Down from the build plan's $300–600, because you're one of the voices.

## 9. What this changes in the build plan

Phase 2 currently runs script → paraphrase → red-line → record. That ordering causes the formal-register drift described in §2.

The corrected order: **record → transcribe → select → derive rules**. Task 2.3's register red-line largely disappears, because you're not writing Tamil that could drift formal — you're transcribing Tamil that was spoken. What replaces it is a *selection* pass: choosing which real utterances become items.
