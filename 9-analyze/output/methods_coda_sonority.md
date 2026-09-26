# Coda, sonority, and secondary stress

*2026-09-26. 240,509 vowels in 100,772 polysyllabic word tokens.*

## The design

Both questions are asked **within each word token**, so word identity, speaker,
recording and speech rate are all conditioned out: the comparison is between the
syllables of one word as spoken once. Odds ratios are pooled across word tokens
Mantel-Haenszel style over discordant pairs. Prominence is defined acoustically
— the longest or the most intense syllable of the word — and so is independent
of any stress rule, which the rule-based labels are not.

**The control that decides both results.** /a/ is intrinsically longer (90 ms
median against 70 ms for the high vowels) and more intense (80.0 dB against
76.8) than a high vowel whether or not it is stressed. So "the longest syllable
tends to contain /a/" is true by construction. Duration and intensity are
therefore z-scored **within vowel quality and within speaker** before the test is
repeated. The difference between the two rows is the whole finding.

## Are stressed syllables more likely to have codas?

**No — and this is the cleanest negative in the set.**

| prominence measure | odds ratio of a coda |
|---|---|
| longest syllable, raw | 0.764 |
| longest syllable, intrinsic removed | 0.782 |
| loudest syllable, raw | 1.049 |
| loudest syllable, intrinsic removed | 1.021 |
| rule B5 stressed | 0.847 |
| rule A6 stressed | 0.818 |

Every value sits at or below 1. Under no measure and no rule is the prominent
syllable more likely to be closed; on duration it is slightly *less* likely,
which is what one expects if a closed syllable's coda takes time that the vowel
would otherwise have.

This is worth stating plainly in the paper, because it removes the main
alternative to a sonority account. Chuvash stress is not attracted to closed
syllables, so it is not weight-sensitive in the coda-mora sense, and the
`weight` baseline's poor showing (0.63 accuracy) is not an artifact of how that
baseline was coded.

## Are stressed syllables more sonorous?

**Yes on duration, no on intensity, and much smaller than it first appears.**

| prominence measure | contains /a/ | contains a non-high vowel |
|---|---|---|
| longest, raw | 3.167 | 1.744 |
| longest, intrinsic removed | **1.479** | **1.308** |
| loudest, raw | 2.313 | 2.252 |
| loudest, intrinsic removed | **1.190** | 0.951 |

Raw, the effect looks decisive: the longest syllable is three times more likely
to contain /a/. Once intrinsic vowel duration is removed, two thirds of that
disappears and an odds ratio of 1.48 remains. On intensity essentially nothing
survives — 1.19 for /a/ and 0.95 for non-high vowels, i.e. no association at
all.

So the draft's claim that rightmost stress in Chuvash is sonority-sensitive is
**supported, in the duration dimension, at about a 1.3–1.5 odds ratio** — not at
the 2–3 that the uncontrolled numbers would suggest. A reviewer will ask for
exactly this control, and the honest version of the claim is stronger for
surviving it.

## Is there secondary stress?

**No evidence for it.**

Words of three or more syllables (32,164 tokens, 71,893 non-primary syllables),
with the rule-B5 primary removed. If secondary stress existed we would expect
the remaining syllables to be non-uniform, and specifically to alternate.

Prominence of non-primary syllables by distance from the primary:

| syllables from primary | −3 | −2 | −1 | +1 | +2 |
|---|---|---|---|---|---|
| duration (z) | −0.325 | −0.352 | −0.329 | +0.143 | +0.402 |
| intensity (z) | −0.059 | +0.008 | +0.010 | −0.190 | −0.213 |
| n | 4,618 | 25,151 | 29,653 | 7,231 | 1,884 |

Everything before the primary is flat at about −0.33 — no alternation, no
distance effect. The only departure is *after* the primary, where syllables are
longer (+0.14, +0.40) but simultaneously **quieter** (−0.19, −0.21).

Long and quiet is word-final lengthening, not stress. Under B5 anything to the
right of the primary is a word-final reduced syllable, so this is the final
lengthening effect showing up as a positional artifact — and the intensity
moving in the opposite direction is what distinguishes the two.

A mixture fit on the residual prominence distribution prefers three components
to two and two to one for both measures, which is the same monotonic-BIC
behaviour seen in the vowel clustering and is not evidence for two prominence
levels.

This negative supports the stresslessness analysis: in a language where some
words are phonologically stressless, one does not expect a rhythmic secondary
layer, and none is found.

## Files

- `coda_sonority_models.csv`, `secondary_stress_models.csv`,
  `secondary_stress_by_position.csv`
- `fig_coda_sonority.png`
