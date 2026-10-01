# Morphological parsing of the Chuvash wordlist

**Scripts** `analyses/morph_induction.R` → `analyses/morph_validation.R` → `analyses/morph_stress_test.R`
**Outputs** `induced_suffixes.csv`, `morph_validation.csv`, `morph_accepted.csv`, `morph_parse.csv`, `morph_cell_counts.csv`, `morph_stress_test.csv`, `morph_alignment.csv`

## Why this exists

None of the four corpora carries morphological annotation. It had to be built
because two results depend on ruling out a morphological alternative: the
reduced vowels that define the right edge of the penultimate and
antepenultimate shape classes are overwhelmingly **suffixal**, so "the
rightmost full vowel is the penult" and "this word carries a suffix" are nearly
the same statement about a Chuvash word. Without a parse, the leftward walk of
the duration peak and the step up into the designated syllable could both be
restatements of "the last syllable of the stem is long."

## Method

Harris/Goldsmith signature induction over the 430,008 monolingual-corpus types
(429,891 after dropping code-switched Latin material and a residual soft sign).
For every type, all splits into prefix + residue were enumerated where the
prefix is itself an attested type of corpus frequency ≥ 2, giving **2,739,066
candidate splits** and **268,507 distinct candidate suffixes**.

Two decisions guard against circularity.

1. Induction runs on the **phonemic** form (`word_label_IPA`), not Cyrillic
   orthography. The analysis should not rest on orthography, and the phonemic
   form is also the representation the spoken data uses, so the downstream join
   is exact.
2. **No vowel-quality information is used anywhere.** Scoring is pure string
   recurrence. This is essential rather than cosmetic: Chuvash suffixes carry
   reduced vowels, so a parser that knew about vowel quality would reproduce
   the very shape classes it is meant to check independently.

Scores per candidate suffix: `n_stems` (distinct attested stems — the
signature productivity measure), `n_types`, `n_ending` (types ending in the
string whether decomposable or not), `decomposability = n_types / n_ending`,
and `tok_weighted`.

## Choosing the cut

The cut is fixed by agreement with an independently specified reference list of
Chuvash inflectional and common derivational suffixes, **never** by anything
downstream — a cut tuned on the stress result would be worthless. Precision is
scored in three categories rather than two, because Chuvash is agglutinating
and a string-based inducer legitimately finds `-sene` (plural + dative) as one
unit: each accepted suffix is **listed**, a **combination** segmentable into
listed suffixes, or **unexplained**. Precision = (listed + combination) /
accepted; recall is against the list.

F1 is maximised at **n_stems ≥ 500**: recall 0.817, precision 0.561. The
decomposability floor did **not** improve agreement and is therefore not part
of the cut — productivity alone, plus the reference-list filter, defines the
inventory. After intersecting with list-or-combination the accepted inventory
is **111 suffixes: 49 listed, 62 combinations**.

Rank stability of `n_stems` across stem-attestation floors of 1, 2, 5, 10 and
20 tokens: Spearman 0.850–0.963, top-50 overlap 47–48 of 50.

## Two constraints added after the first run failed

The unconstrained parse analysed лаша /laʃa/ 'horse' as *la-ʃ-a* and каларӗ as
*ka-l-a-r-ø*, and made 65.5% of types polymorphemic with 31% at five
morphemes. That is not Chuvash. The cause was single-phoneme suffixes: `-n`,
`-a`, `-e`, `-ø`, `-i` are real Chuvash suffixes, but **string recurrence
cannot identify them**, because nothing distinguishes a genitive *-n* from a
stem-final *n*. Once admitted they chew through roots one phoneme at a time.

- `MIN_SUF = 2` — only suffixes of two or more phonemes are parsed. This is a
  **stated limitation, not a repair**: words whose only affix is a single
  phoneme stay in the unparsed class. So the polymorphemic class is
  conservative and the monomorphemic class is really *"no confident parse"*.
  For the downstream test that is the safe direction — it weakens the contrast
  rather than manufacturing one.
- `MIN_STEM = 3` — a Chuvash root is at least CVC; *la* is not a stem.

Recursive stripping, up to three rounds, taking at each round the accepted
suffix with the highest stem count that leaves an attested word.

## Result of the parse

| morphemes | types | % of types | tokens |
|---|---|---|---|
| 1 | 261,868 | 60.9 | 13,425,169 |
| 2 | 113,587 | 26.4 | 7,931,658 |
| 3 | 44,281 | 10.3 | 1,716,296 |
| 4 | 10,155 | 2.4 | 164,367 |

Polymorphemic: 39.1% of types, 42.2% of tokens. The parse matched 98.0% of
spoken vowel rows and 95.1% of spoken word types.

## Known failure modes

Hand-inspection of twelve high-frequency types gives correct parses for
пулнӑ → *pul-nɵ*, ҫынсем → *ɕʉn-sem*, каларӗ → *kala-rø*, каласа → *kala-sa*,
шупашкарта → *ʃupaʃkar-ta*, ҫавӑнпа → *ɕaʋ-ɵn-pa*, хушшинче → *xuʃʃ-in-tɕe*,
and correctly leaves лаша monomorphemic. Two are wrong in opposite directions:

- **ҫӑкӑр** /ɕɵkɵr/ 'bread' is split as *ɕɵk-ɵr* — a false positive, where the
  possessive/plural `-ɵr` matched a stem-final sequence.
- **амӑшӗ** 'his/her mother' is left unparsed, because its suffix `-ø` is a
  single phoneme (the stated `MIN_SUF` limitation), and **пӗрремӗш** 'first'
  likewise.

Also questionable: вӗсене 'them' parses as *ʋøse-ne* with a stem that is not
independently a word of the language.

**The per-word parse error rate is not measured.** Twelve examples are an
illustration, not an estimate, and the reference list itself was written out
from the grammatical description of Chuvash rather than transcribed from a
single published table — it has not been checked by a Chuvash specialist.
**Both the list and a proper sample of parses need Kate's eyes before any of
this is published.** Everything downstream inherits this noise, and the
direction of the noise matters: because the monomorphemic class is really
"no confident parse", it is contaminated with genuinely suffixed words, which
biases the morphology test *against* finding a difference between the classes.

## What the parse was used for

See `morph_stress_test.csv`. Briefly: the duration step up into the designated
syllable is **+19.12 ms (t 11.3)** in words with no suffix parsed against
**+21.37 ms (t 17.3)** overall, on 10,049 steps across 19 within-vowel strata,
so suffixation does not explain it. The designation × suffixal-status
interaction is null on all three cues. Separately, suffixal syllables are
**+6.73 ms longer (t 4.0)** and **−0.70 dB quieter (t −4.0)** than stem
syllables at the same position with the same vowel, independent of
designation — a morphological effect in its own right.

Outside the word-final class the designated syllable coincides with the last
stem syllable **92.0%** of the time in the penultimate class and 91.0% in
all-reduced words, against a 45.9–49.5% chance rate for a suffixal syllable.
So the confound is real and large as a descriptive fact about Chuvash; it just
does not drive the acoustic effect.
