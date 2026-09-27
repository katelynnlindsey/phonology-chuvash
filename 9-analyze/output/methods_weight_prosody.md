# Weight, edges and sentence type

Four analyses added after the cleaning rebuild, all on the 574,344-vowel
dataset. Scripts: `analyses/gemination_mora.R`,
`analyses/prosody_sentence_type.R`, `analyses/default_adjudication.R`, and
the two extractors `7-extract/reextract/build_phone_table.py` and
`build_utterance_table.py`.

---

## 1. Where the consonant durations come from

`data/leveled` carries vowels only, so gemination needed a new extraction.
`build_phone_table.py` flattens the **pre-recode** Chuvash Voice grids
(`1-raw_data/chuvash_voice/textgrids`) into one row per phone with its
orthographic word, position in the word, neighbours and whether it is
intervocalic: **1,424,952 rows, 29,716 recordings, 253,983 word tokens**.

Two constraints on that choice, both worth stating in the paper:

* `5-recode/chuvash_phonology.py` collapses nine of the fourteen long
  consonants to singletons, so the recoded grids cannot answer the question
  at all. The pre-recode grids agree with the recoded ones on **100%** of
  interval boundaries (300 files checked), so these are the same durations
  the rest of the study uses.
* **Common Voice is excluded by necessity.** Its only pre-recode grids
  (`textgrids_VOX`) are a different third-party alignment — 18.9% boundary
  agreement with the grids the measurements come from, on 486 matched files.
  Everything in §2–§4 is therefore one speaker reading prose. That removes
  between-speaker variance and also removes any claim to cross-speaker
  generality.

**The aligner has a hard floor at 30 ms**, and 5.67% of all 1.4 M phones sit
exactly on it. A long consonant pinned to the floor was clipped, not
measured, so `gemination_models.csv` reports `pct_long_at_floor` per place
and excludes any place above 40%.

---

## 2. Are the orthographic geminates phonetically long?

Intervocalic, word-medial position only — where a geminate can occur, and
where the syllabic environment is held constant. Mixed model per place:
`log(duration) ~ long + utt_final + (1|word_label) + (1|file_name)`.

| place | n long | n singleton | median long | median short | model ratio | % at floor |
|---|---|---|---|---|---|---|
| /l/ | 7,385 | 19,868 | 80 | 60 | 1.32 | 3.6 |
| /n/ | 3,631 | 27,673 | 90 | 70 | 1.11 | 4.0 |
| /ɕ/ | 3,525 | 4,717 | 150 | 90 | **1.71** | 0.9 |
| /s/ | 2,197 | 17,188 | 130 | 80 | 1.68 | 0.4 |
| /t/ | 1,722 | 13,908 | 90 | 60 | 1.32 | 0.4 |
| /r/ | 1,315 | 34,805 | 70 | 40 | 1.52 | 4.9 |
| /k/ | 1,155 | 9,723 | 70 | 70 | 1.22 | 0.7 |
| /ʃ/ | 938 | 4,754 | 130 | 80 | 1.63 | 0.6 |
| /p/ | 491 | 9,701 | 70 | 60 | 1.12 | 3.3 |
| /χ/ | 221 | 6,734 | 100 | 70 | 1.16 | 8.1 |
| /m/ | 183 | 12,945 | 40 | 80 | *0.60* | **43.2** |
| /v/ | 75 | 10,789 | 30 | 60 | *0.53* | **100.0** |

Across the ten measurable places — **22,580 long against 149,071 singleton
tokens** — the model ratio runs from **1.11 to 1.71, median 1.32**. Report
the per-place ratios rather than a pooled one: the long and singleton token
sets have very different place compositions (/l/ and /ɕ/ dominate the long
set, /r/ and /n/ the singleton set), so a pooled ratio is an artefact of that
composition.

/mː/ and /vː/ are the excluded pair. Every one of the 75 /vː/ tokens is at
exactly 30 ms — all five quantiles from the 10th to the 90th are 30 — which
is the floor, not a short geminate. The words are genuine geminates
(`сиввӗн`, `сӑввине`, `кӗвви`, `уйрӑммӑнах`), so this is a measurement limit
on rare segments, not evidence about Chuvash.

---

## 3. Word-final weight: the four rhyme shapes

Raw cell medians (`gemination_final.csv`):

| final shape | n | types | median C | median V | median rhyme |
|---|---|---|---|---|---|
| short C + full V | 106,328 | 15,015 | 70 | 90 | 160 |
| long C + full V | 11,129 | 2,144 | 110 | 100 | 200 |
| short C + reduced V | 9,838 | 799 | 60 | 70 | 140 |
| long C + reduced V | 1,531 | 283 | 90 | 80 | 160 |

Those four cells hold different consonants and different vowels, so the
equality of the first and last is not yet a controlled comparison. The model
in `gemination_weight_model.csv` estimates them as a 2×2 with the
consonant's identity, word length, the utterance edge and the pause in:
`log(C+V) ~ c_long * v_class + c_phone + word_nphone + utt_final +
pre_pause + (1|word_label) + (1|file_name)`, 128,567 tokens, 15 consonants,
18,178 word types.

Adjusted final-rhyme duration, relative to short C + full vowel:

| shape | adjusted |
|---|---|
| short C + full V | 0.0% |
| long C + full V | **+19.4%** |
| short C + reduced V | **−12.1%** |
| long C + reduced V | **+4.6%** |

**The two effects are additive** — the interaction is t = −0.22. Lengthening
the consonant and reducing the vowel are independent, roughly equal and
opposite adjustments to the same total. A long consonant plus a reduced
vowel comes out 4.6% above a short consonant plus a full vowel, about 7 ms
on a 160 ms rhyme, under the 10 ms JND. Word-finally the two are the same
length.

---

## 4. The fleeting-vowel (zero-mora) hypothesis: not supported acoustically

Chuvash pairs пулӑ 'fish' with пулли 'its fish': the stem-final reduced
vowel disappears and the consonant geminates. A vowel that alternates this
way is the candidate for a fleeting, zero-mora vowel.

**The class was identified from text alone**, with no acoustics involved and
so no circularity: for every monolingual-corpus type ending in ӑ/ӗ after a
consonant, is `stem + C + C + и` attested (twice or more, since the corpus
carries de-hyphenated fragments)? Of **52,582** candidate types, **1,484
(2.8%)** have the geminate form. The method recovers the right words:

ҫӗнӗ~ҫӗнни, питӗ~питти, пулӗ~пулли, ырӑ~ырри, усӑ~усси, юрӑ~юрри,
шурӑ~шурри, сӑвӑ~сӑвви, алӑ~алли, турӑ~турри.

Acoustic comparison, **at the same final consonant** (10 consonants with
n≥100; 10,992 tokens, 964 types), with word length, utterance edge, pause
and frequency controlled:

| outcome | alternating − non-alternating | t |
|---|---|---|
| final vowel duration | +0.3% | 0.12 |
| final rhyme duration | +0.6% | 0.29 |
| final consonant duration | −0.4% | −0.10 |

All three are null. **An earlier pass without the consonant control found
the vowel 5% shorter (t = −2.41); that was entirely place of articulation**,
since the alternating class is dominated by л р н ҫ т. The corrected answer
is that the alternation is not audible in these three measures.

That does not refute the moraic analysis — it says the evidence for it is
morphological and phonological, not phonetic, at least in read speech from
one speaker. The positive weight evidence is §3.

---

## 5. Final lengthening, with stress in the same model

`log(duration) ~ vowel_label + stressed + syl_final + word_utt_final +
syl_final:word_utt_final + log_speech_rate + (1|speaker) + (1|file_name) +
(1|word_label)`, 527,444 vowels. `vowel_label` as a fixed effect absorbs
intrinsic duration, so each coefficient is a change for a vowel of the same
quality.

| term | % change in duration | t |
|---|---|---|
| stressed (rule A6) | **+4.4** | 44.3 |
| word-final syllable | +12.3 | 110.5 |
| in utterance-final word | −0.7 | −3.9 |
| word-final × utterance-final (interaction) | **+51.6** | 163.7 |

Read the interaction term with care: +51.6% is the *extra* effect of the two
positions coinciding, not the total. The quantity to quote is the sum of all
three position terms, which is the final syllable of an utterance-final word
against a non-final syllable elsewhere: **+69.0%**. Stress is worth **+4.4%**,
so the ratio is **15.6×**. Neither edge term does much alone — it is
specifically their conjunction. Cell medians: 70 ms for an unstressed non-final syllable
elsewhere against 130 ms for an unstressed word-final syllable in an
utterance-final word.

**Consequence for every duration-based claim in the paper.** A prominence
measure that does not hold utterance position fixed is largely measuring the
edge. See §6.

---

## 6. The A-vs-B adjudication, re-specified

A and B differ in exactly one configuration: a polysyllabic word all of
whose vowels are reduced. `stress_rule_comparison.R` compares the initial
syllable against the non-initial ones there — but in a disyllable
"non-initial" *is* the final syllable, so by §5 that contrast is mostly an
edge measurement. `default_adjudication.R` refits it with word-final
position, utterance-final position and position-within-utterance included.

Inventory 5, 24,223 word tokens / 37,824 vowels:

| cue | raw | edges controlled | t | JND |
|---|---|---|---|---|
| duration | −19.6 ms | **+0.59 ms** | 0.64 | 10 ms |
| intensity | +1.84 dB | **−0.21 dB** | −1.86 | 3 dB |
| f0 | +12.4 Hz | **−2.52 Hz** | −4.17 | 1 Hz |

Inventories 6 and 4 give the same pattern (`default_adjudication.csv`).

No cue makes the initial syllable prominent. f0 clears its nominal
threshold but in the wrong direction and by 0.02 semitones on a 200 Hz
voice; the 1 Hz figure is a laboratory floor for steady tones, not a
threshold for running speech, and the paper should say so. **Verdict: B**,
on three times the sample the filtered estimate rested on, and with the one
apparently contradictory measurement explained rather than set aside.

---

## 7. Sentence type

`build_utterance_table.py` classifies every recording by the transcript's
final punctuation — the only sentence-type label either corpus carries.
Both corpora are read speech, so a question here is a written question read
aloud. Of 47,195 recordings: 41,726 statements, 2,626 questions, 1,599
exclamations, and 1,244 that end in a colon or in no sentence punctuation
and are excluded from the comparison.

f0 is taken from `phrase_f0_step1..20`, the utterance-level track at 20
equally spaced points, converted to semitones relative to the speaker's own
median so a 125 Hz voice and a 226 Hz voice are comparable.

End-of-utterance f0 and final-quarter slope:

| corpus | type | utterances | slope (st/step) | end (st) |
|---|---|---|---|---|
| Chuvash Voice | statement | 25,852 | −0.87 | −5.36 |
| Chuvash Voice | question | 1,750 | −0.41 | −1.78 |
| Common Voice | statement | 15,142 | −0.47 | −2.43 |
| Common Voice | question | 838 | −0.20 | −0.63 |

Questions fall much less far than statements in both corpora
(`sentence_type_models.csv`: +3.02 st on end-f0, t = 32.4).

**The split is conditioned on morphology.** Chuvash marks polar questions
with an enclitic -и/-ши; the same string is the third-person possessive, so
the label is orthographic, not a morphological diagnosis. Two checks
license using it:

* a sentence-final -и token appears in **27.99%** of questions against
  **0.95%** of statements — a 29-fold enrichment;
* statements whose last word ends in -и behave like all other statements
  (slope −0.688 vs −0.724; end −4.268 vs −4.279), so the string itself does
  nothing.

| group | utterances | slope | end (st) |
|---|---|---|---|
| question, -и on the last word | 546 | **+0.454** | **+2.70** |
| question, no marker | 763 | −0.291 | −1.03 |
| question with a wh-word | 1,279 | −0.714 | −3.38 |
| statement, -и on the last word | 390 | −0.688 | −4.27 |
| statement | 40,604 | −0.724 | −4.28 |

Clitic-marked polar questions are the **only** group that rises. wh-questions
have a statement contour. Unmarked questions sit between the two.

Methodological upshot for the stress analysis: only 546 of 45,192 utterances
carry a rising contour, so sentence type contaminates a pooled f0 measure
very little — but the f0 contours are stylised to 2 semitones, so nothing
smaller than a couple of semitones should be rested on regardless.

---

## 8. Codas, sonority and secondary stress on the rebuilt data

Within-word design: a word token is a stratum, its syllables are the units,
the outcome is being the most prominent syllable in that word. 527,444
vowels in 256,239 polysyllabic word tokens. Every test is run on the raw
measure and again after removing the vowel's own mean, because /a/ is 20 ms
longer and 2 dB louder than the high vowels for reasons unconnected with
stress.

| predictor | duration, raw | duration, intrinsic removed | intensity, raw | intensity, intrinsic removed |
|---|---|---|---|---|
| closed syllable | 0.661 | **0.653** | 1.148 | 1.146 |
| the vowel /a/ | 2.071 | **1.348** | 2.367 | 1.119 |
| a non-high vowel | 1.528 | **1.166** | 2.038 | 0.958 |

Rule-predicted stress rather than acoustic prominence: coda odds 0.915 (A6),
0.932 (B5).

**No coda attraction under any measure, adjustment or rule** — the odds are
*below* 1 on duration. Sonority survives intrinsic correction in the
duration dimension at an odds ratio of 1.35 (/a/) and 1.17 (non-high), and
vanishes in intensity. The strict subset (`word_complete & !iqr_outlier_any`,
247,858 vowels) gives 0.757 / 1.699 / 1.154, so the nulls are not an artefact
of readmitting the flagged rows.

Secondary stress: 118,153 words with three or more syllables, 154,504
non-primary syllables. By distance from the primary (duration z / intensity z):
−3 −0.119/+0.022, −2 −0.204/+0.094, −1 −0.301/+0.126, +1 +0.236/−0.067,
+2 +0.365/−0.155, +3 +0.167/−0.182.

Before the primary the duration profile falls monotonically towards it. After
it, duration rises to +2 and then drops at +3 — but the +3 cell holds only 816
syllables against 10,594 at +2, so that dip is thin, and in any case a single
peak two syllables after the primary is not the alternating every-other-syllable
pattern a secondary stress would produce. The decisive point is the *opposite
sign* of the two measures: syllables after the primary are longer and at the
same time **quieter** (intensity z falls monotonically from +1 to +3). Stress
lengthens and raises intensity together; final lengthening lengthens while
intensity declines. This is final lengthening. Mixture BIC falls monotonically
in k for both measures and is uninformative. **No secondary stress.**
