# Vowel shift, and where vowels may stand

*2026-09-26. Common Voice speaker metadata, lexical outliers, and the
positional distribution. Row data: `vowels_normalised.csv`.*

## A metadata problem that has to be stated first

Common Voice's own speakers separate cleanly by f0: median **125.5 Hz** for
`male_masculine`, **223.6 Hz** for `female_feminine`. The dominant Chuvash Voice
speaker sits at **225.7 Hz** and is labelled `male_masculine`. That is 100 Hz
from the male distribution and within 3 Hz of the female median.

The label covers **193,978 vowels, 69% of the analysed data**. Either the
metadata is wrong or this is a very high-pitched male voice; nothing in the
corpus settles it. Until it is settled, `gender` cannot be used as a predictor
across corpora, and every gender result below is Common Voice only.

## Apparent time: no effect

Speaker is the unit, since age is a speaker property. 19 Common Voice speakers
have both an age band and at least 25 tokens of a given vowel; F1 and F2 were
regressed on age-band midpoint with gender controlled, weighted by cell size.

**0 of 12 coefficients reach p < 0.05.** Point estimates are 0.001–0.011 z per
year, i.e. 0.01–0.11 z per decade, against within-vowel standard deviations near
1. The two largest — /ø/ on F2 (p = 0.094) and /ɵ/ on F1 (p = 0.078) — would need
replication on a real apparent-time sample before they meant anything.

This is a clean negative, and it is what the design can support: 19 speakers
with most of the mass in two adjacent bands (teens and twenties) cannot detect a
generational shift unless it is very large. Report it as "not detectable here",
not as "no change is taking place".

## Gender, within Common Voice

7 of 12 coefficients reach p < 0.05, with effects of 0.02–0.43 z. /u/ and /i/
move most on F2 (−0.43 and +0.35). These are residuals *after* Lobanov
normalisation within speaker, so they are differences the normalisation did not
remove — which is as likely to mean the normalisation is incomplete as that the
vowel systems differ. Worth one sentence, not a section.

## Words whose vowel sits in another phoneme's territory

For every word-and-syllable cell with at least 30 tokens (988 cells), the cell's
mean position in normalised F1/F2 was compared by Mahalanobis distance against
each phoneme's own distribution. **153 cells (15.5%) sit nearer a phoneme other
than the one they are written with.**

| word | syllable | written | measured nearer | n | margin |
|---|---|---|---|---|---|
| хыҫҫӑн | 2 | ɵ | ø | 325 | 1.28 |
| хӗветӗр | 1 | ø | i | 31 | 1.20 |
| петр | 1 | e | ø | 82 | 1.19 |
| иртсе | 2 | e | ø | 61 | 1.18 |
| икӗ | 2 | ø | i | 185 | 1.15 |
| аллине | 2 | i | ø | 50 | 1.15 |
| умӗн | 1 | u | ʉ | 49 | 1.03 |

Three kinds of thing are in this list and they should not be reported together.

1. **Russian names and loans** — `петр` (Пётр), `хӗветӗр` (Фёдор), `хӗлимун`
   (Филимон). Expected, and not evidence about Chuvash.
2. **The acoustically merged pairs.** The commonest substitutions are e↔ø (51
   cells), e↔i (29) and u↔ʉ (26) — exactly the pairs whose separability is
   0.58–0.72. For those, "nearer another phoneme" is weak evidence on its own.
3. **Genuine candidates**, where the token count is large and the pair is
   separable: `хыҫҫӑн` syllable 2 (n = 325, ɵ measured as ø — and this is a
   back-harmonic word, so a fronted ɵ there is notable) and `икӗ` syllable 2
   (n = 185, ø raising toward i).

`lexical_vowel_outliers.csv` carries all 153 with their margins; the two above
are the ones worth listening to before anything is claimed.

## Positional restriction

Observed/expected, spoken data, by syllable position:

| | initial | medial | final | monosyllable |
|---|---|---|---|---|
| a | 0.91 | 1.14 | 1.08 | 0.88 |
| e | 0.36 | 0.97 | 1.47 | 1.45 |
| i | 1.39 | 1.13 | 0.73 | 0.59 |
| u | 2.01 | 0.21 | **0.11** | 1.45 |
| y | 2.19 | 0.34 | **0.22** | 0.61 |
| ʉ | 2.37 | 0.10 | **0.05** | 0.83 |
| ø | 0.82 | 0.89 | 1.33 | 0.72 |
| ɵ | 0.80 | 1.54 | 1.01 | 0.96 |

Share of each vowel's polysyllabic tokens standing in syllable 1: **/ʉ/ 96.5%,
/u/ 91.2%, /y/ 86.0%**, /i/ 54.4%, /a/ 37.5%, /ɵ/ 33.1%, /ø/ 32.9%, /e/ 16.3%.

**This strengthens one part of the draft's argument and undercuts another.** The
claim that /ʉ/ is confined to the initial syllable is confirmed and strengthened
— 96.5% in the spoken data against the 89.5% reported from the wordlist. But
/u/ and /y/ behave almost identically, and they are full vowels under every
inventory. The restriction tracks vowel **height**, which is the familiar
Turkic pattern in which non-initial high vowels are largely suffixal, and it
therefore cannot by itself put /ʉ/ with the reduced vowels.

The minimal-word evidence does that work, and it should be allowed to: /ʉ/ is 0
of 37 in open monosyllables while /y/ is 8 of 52. Positional restriction is
corroboration for a claim about *height*, not about *weight*.

/e/ is the mirror image at 16.3% initial and an observed/expected of 1.47
word-finally — which is worth a line, since a stress rule looking for the
rightmost full vowel will land on /e/ disproportionately often.

## Files

- `vowel_shift_models.csv`, `lexical_vowel_outliers.csv`,
  `positional_restrictions.csv`
- `fig_vowel_shift.png`, `fig_positional.png`
