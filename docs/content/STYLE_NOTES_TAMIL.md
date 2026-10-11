# Tamil style notes

Rules for drafting the Tamil course (for the Telugu speaker). They come from the owner's review of the first five
lessons: the drafted text before review (commit `4930a25`) compared with the reviewed text (commit `265bcc1`),
19 of 100 items changed. Read this before drafting a Tamil lesson, and add a rule here whenever the owner corrects
something new. This document holds no Tamil: examples are cited by item id, so open the lesson file to see them.

## What the owner changed, and the rule it gives

1. **Use the English word speakers actually say.** Native words that sound bookish were replaced by the
   everyday English word: small change, "try", "pay", "correct" (ta-l01-u03-i15 and i16, ta-l01-u04-i10, i11 and
   i13, ta-l01-u02-i16). *Rule:* in shops, money, transport and phone talk, prefer the loanword plus the light
   verb ("do / make") over a native verb. Do not "improve" a loanword into pure Tamil.
2. **Spell the spoken form, not the written one.** Examples: the Chennai-style short forms for "opens"
   (ta-l01-u04-i16), "later" (ta-l01-u04-i20), "somebody" (ta-l01-u05-i11), and the plain command ending for
   "open the door" (ta-l01-u05-i12). *Rule:* when two spellings exist, use the one a Chennai speaker texts.
3. **Pick the verb the owner would use.** "Work" in an office is expressed with the "do" verb, not the "make"
   verb (ta-l01-u05-i07); hot weather is the "hot" adjective, never the "sunshine" one (ta-l01-u05-i15).
   *Rule:* when two verbs fit, choose the commoner one and check the other as a wrong option, not the answer.
4. **Say the thing the prompt names.** Price sentences name the price (ta-l01-u04-i02 and i03); "only" in the
   prompt shows up as an "only" word in the answer (ta-l01-u03-i17); "What do you want to eat?" is built on
   "want", not on "going to eat" (ta-l01-u03-i06). *Rule:* every content word in the English prompt has a
   counterpart in the answer, unless the language truly drops it.
5. **Register labels follow how the owner would say it, not the grammar of the question.** A "where is X?" asked
   of a stranger was relabelled casual with a respectful variant (ta-l01-u02-i01), and "how much is it?"
   became casual with a respectful variant (ta-l01-u03-i14). *Rule:* a sentence with no "you" is `neutral`
   only if its other-register version would be identical; if a polite ending changes it, label the plain form
   `casual` and give the polite ending as the `registerVariant`.
6. **A `registerVariant` changes the register and nothing else.** One variant dropped a pronoun the answer
   still needed (ta-l01-u01-i08). *Rule:* keep the same words; swap only the pronoun and the ending.
7. **Wrong options keep the pattern and change one word.** When the answer changed, the wrong options were
   changed with it (ta-l01-u03-i06, ta-l01-u04-i02, i03 and i11). *Rule:* after editing an answer, re-read all of
   its wrong options and its accepted spellings.

## House style (from the five reviewed lessons)

- **Romanisation:** informal Latin spelling as in Tamil WhatsApp chats. Long vowels are doubled (aa, ee, oo); the
  retroflex "zh" is written zh; dental stops are written dh and th. Suffixes on English words are joined with a
  hyphen. Question words and the yes/no question ending are written as spoken.
- **Registers:** casual (you = the informal pronoun, address words for a male or a female friend) and respectful
  (you = the polite pronoun, polite endings). `neutral` means the sentence has no you-form. The male-friend and
  female-friend address words are recorded in `addressee`.
- **Accepted spellings:** 3 to 6 including the canonical one. Vary vowel length, doubled consonants, dh/th,
  the hyphen before a suffix, and the final question mark. Do not list a different sentence as an "accepted
  spelling". Inside one item only case and surrounding spaces are ignored when checking for repeats.
- **Wrong options:** real, natural sentences that mean something else, in the same register and about the same
  length. A neutral item has 3; an item with a `registerVariant` has 2 plus the variant.
- **Glosses (`tokens`):** each `word` is a piece of the canonical answer, in the order it appears; `english` is a
  short gloss.
- **`script`:** the canonical answer spelled in Tamil letters as spoken, English loanwords included. No Latin
  letters in that field; no Tamil letters anywhere else.
- **Notes:** only where a learner would otherwise be tripped (who the address word is for, a false friend).
- **Length:** Level 1 answers are 2 to 4 words; add about one word per level.

## Open points for the owner to settle during review

- The hometown prompt (ta-l01-u08-i01) names Vijayawada in the Tamil course and Chennai in the Telugu course
  (te-l01-u08-i01), so each learner says their own town. Change both if you would rather they match.
- Whether the casual share is too low in Level 1 (about 8% casual, 26% respectful, 66% with no you-form against
  the syllabus target of 40/40/20). Level 1 is dominated by statements; from Level 2 on, more questions to a
  friend will be written to move the mix.

## Level 2 drafting notes (2026-10-12, unreviewed)

Level 2 (`ta-l02-u01` to `ta-l02-u12`, 240 phrases) was drafted before Level 1 was reviewed, at the owner's request,
so it follows the rules above as they stood and may repeat any mistake you correct in Level 1. When you review
Level 1, expect the same corrections to apply to Level 2 and add them here.

- **Pattern wrong options.** From Level 2 each item has at least one wrong option that differs only by the
  pattern taught (past or future instead of present, a negative, the other person or gender). Check these first:
  a pattern option that is also a natural correct answer must be changed.
- **Register mix.** Level 2 is about 20% casual, 14% respectful and 66% with no you-form against the syllabus
  target of 40/40/20 (Level 1 was 8/26/66). Statements about things and people have no you-form, so the
  share cannot reach the target unless more questions to a friend or an elder are written; say if you want
  Level 3 skewed that way.
- **Loanwords used as spoken** (phone, bus, shirt, weather, boss, charger, parking, ATM, exit, jacket and
  similar) with the usual light verbs; correct any that you would say in Tamil.
- Items I am least sure of: ta-l02-u01-i04 to i06, ta-l02-u02-i15, ta-l02-u04-i11, ta-l02-u06-i06 and i12,
  ta-l02-u08-i03 and i20, ta-l02-u09-i04, i07 and i20, ta-l02-u12-i03, i10 and i18.
