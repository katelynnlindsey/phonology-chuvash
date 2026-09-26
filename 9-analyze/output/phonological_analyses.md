# What the new analyses do to the stress argument

*2026-09-26. Consolidates `methods_inventory_phonotactics.md`,
`methods_vowel_space.md`, `methods_vowel_shift_position.md`,
`methods_coda_sonority.md`, `methods_speaker_structure.md` and
`minimal_word_diagnosis.md`. Every number below is a macro in
`results_macros.tex`.*

The draft argues three things: that Chuvash words fall into phonetically and
phonologically distinct stress patterns; that a subset is phonologically
stressless; and that rightmost stress is fundamentally sonority-sensitive. Rule
B5 — rightmost full vowel, else stressless, with /ʉ/ reduced — is the proposed
analysis. Here is where the new work leaves each claim.

## Supports the analysis

**The /ʉ/-is-reduced grouping now has two independent kinds of evidence.** It
had one: /ʉ/ never stands in an open monosyllable (0 of 37 wordlist types) while
/y/ does (8 of 52). It now also has an acoustic argument: **/ʉ/ and /ɵ/ are not
separable** — balanced accuracy 0.527 against a chance floor of 0.500, on
speaker-normalised F1/F2/F3. Whatever distinguishes ⟨ы⟩ from ⟨ӑ⟩ is not in the
formant space at this sample size. Two arguments that can fail independently now
point the same way.

**The corpus corroborates the minimal-word generalisation after all.** Restricted
to dictionary-attested word types the monolingual corpus reproduces the wordlist
to within 0.1–2.4 points, including **0.0% open-syllable monosyllables for both
/ø/ and /ʉ/**. The 28.1% that contradicted it was de-hyphenation failure and
letter-spaced emphasis in the source texts.

**Stress is not attracted to closed syllables.** Within word tokens, with
intrinsic vowel duration removed, the odds of the longest syllable being closed
are **0.78**; the loudest, 1.02; under rule B5, 0.85. Every value is at or below
1. Chuvash stress is not weight-sensitive in the coda-mora sense, which removes
the main competitor to a sonority account and explains the `weight` baseline's
0.63 accuracy as a real fact rather than a coding artifact.

**No secondary stress.** In words of three or more syllables the non-primary
syllables are flat at −0.33 z for every position before the primary, with no
alternation. That is what a stressless analysis predicts, and it is now a
measured negative rather than an absence of discussion.

**No apparent-time shift.** 0 of 12 age coefficients reach significance over 19
speakers. The synchronic description is not chasing a change in progress.

## Qualifies the analysis

**The sonority effect is real but a third of its apparent size.** Raw, the
longest syllable of a word is 3.17 times more likely to contain /a/. But /a/ is
intrinsically 20 ms longer and 3 dB louder than a high vowel regardless of
stress. With intrinsic duration removed the odds ratio is **1.48** for /a/ and
1.31 for non-high vowels; on intensity almost nothing survives (1.19 and 0.95).
So sonority-sensitivity holds **in the duration dimension, at an odds ratio near
1.3–1.5**. The claim should be stated at that size. A reviewer will ask for this
control, and surviving it is worth more than the larger uncontrolled number.

**Positional restriction is about height, not weight.** /ʉ/ stands in the first
syllable of **96.5%** of its polysyllabic tokens — stronger than the 89.5% the
draft reports from the wordlist. But /u/ is at 91.2% and /y/ at 86.0%, and both
are full vowels under every inventory. This is the familiar Turkic pattern in
which non-initial high vowels are largely suffixal. It corroborates a claim
about height and cannot by itself put /ʉ/ with the reduced vowels; the
minimal-word evidence has to do that.

**/y/ is not an independent acoustic target.** /i/ and /y/ separate at 0.518,
i.e. chance. /y/ is the rarest native vowel (0.7–0.9% of tokens) and its "full"
status rests on 52 wordlist monosyllables. The distributional argument stands;
it should not be buttressed by any claim about /y/ being acoustically distinct
here.

## Corrects the draft

**⟨ӑ⟩ is not rounded.** Tested within height/backness pairs, where rounding is
actually identified: /y/–/i/ shows ΔF2 −0.54 and ΔF3 −0.70, /ø/–/e/ −0.56 and
−0.38, /u/–/ʉ/ −0.35 and −0.35 — all rounded. /ɵ/–/a/ shows ΔF2 −0.21 but
**ΔF3 +0.013 (z = 0.97)**, which is what backness alone predicts. `VOWEL_ROUND`
should drop /ɵ/ and the prose should call it a back or central *unrounded*
reduced vowel.

**The vowel space does not resolve eight categories.** Agreement between a
Gaussian mixture and the phonemic eight peaks at four to six components
(adjusted Rand 0.47) and falls to 0.34 at eight. At six, the phonemes group as
{e, i, ø} and {u, ʉ, ɵ}. BIC is uninformative here — it falls monotonically to
the largest k tested — and should not be quoted as selecting a number.
Separability also tracks duration (r = 0.70), so some of the merging is
measurement noise on short vowels and this design cannot separate the two.

## Data facts the paper must state

**Chuvash Voice is one speaker.** 93.4% of its recordings fall in a single
acoustic voice cluster, against 78 clusters in a Common Voice sample with 102
known speakers. Ten minor clusters cover the rest, four of them at 108–144 Hz
against a 226 Hz dominant voice, so there are at least three or four other
people. One speaker supplies about 69% of all analysed vowels. This is the
study's principal limitation and it should be in the abstract's scope sentence,
not a footnote.

**The Chuvash Voice gender label is not credible.** Common Voice males sit at
125.5 Hz and females at 223.6 Hz; the dominant Chuvash Voice speaker is at
225.7 Hz and is labelled male. That label covers 193,978 vowels. Gender cannot
be used as a cross-corpus predictor until it is resolved.

**Gemination is recoverable and currently discarded.** The aligner labels
**33,315** long-consonant tokens across **14** types, but stage 5 collapses nine
of them onto their singletons. For Chuvash Voice the pre-recode grids have
identical boundaries and token counts, so this is a direct substitution, not a
re-alignment.

## Still open

1. Cleaning step 06 discards 45–47% of vowels through cascading word-level
   exclusion, and step 05's IQR fences are computed within vowel × corpus rather
   than within speaker or stress, which correlates the filter with the dependent
   variable. Replacement design in `alignment_confidence.md`.
2. The re-extraction (`7-extract/reextract/`) has not been run at scale. Until
   it is, f0 is stylised to 2 semitones and intensity is usable only at the
   midpoint.
3. Gemination, final lengthening, sentence type and the moraic questions all
   wait on that run.
