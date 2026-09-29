# The vowel space: rounding, and how many categories it supports

*Rewritten 2026-09-27 on the rebuilt dataset. `analyses/vowel_space.R` for the
normalisation and the chart; `analyses/vowel_features.py` for the rounding,
clustering and separability tables. Every figure below comes from a CSV in
this directory — see the Files section.*

**This note replaces an earlier version whose numbers came from the
outlier-filtered dataset (213,477 non-palatal vowels, 84 speakers) and which
asserted that ⟨ӑ⟩ is unrounded. Both are superseded; the second was wrong.
See `SUPERSEDED.md`.**

## Sample and normalisation

Lobanov within speaker. `speaker` is the Common Voice `client_id` where it
exists and the inferred Chuvash Voice `voice_label` otherwise (see
`methods_speaker_structure.md`).

| | |
|---|---|
| vowels with a full F1/F2/F3 triple | 574,344 |
| speakers before the token floor | 120 |
| after dropping speakers with <20 tokens | **574,186 vowels, 102 speakers** |
| of those, non-palatal | **447,719 (78.0%)** |

Speakers under 20 tokens are dropped because a z-score over fewer is noise.
Non-palatal excludes vowels adjacent to /j ɕ ʃ tɕ ʒ/, which front F2 enough to
smear the space; the request was to read the inventory off non-palatal
contexts.

One standing limitation applies to everything here: one speaker supplies about
69% of all vowels, so the normalised space is largely that speaker's.

## Rounding — and the control that decides what the test can say

> **Anchors corrected 29 Sep 2026.** This section previously used **one anchor
> per harmony series** — /i/ for the front vowels, /a/ for the back — and drew
> its control from **/u/ vs /a/**. That is wrong, because F3 varies with
> **height** as well as backness: /u/ against /a/ is high against low, and mid
> ⟨ӗ⟩ against high /i/ and mid ⟨ӑ⟩ against low /a/ have the same defect. The
> contrasts below are now **height-matched pairs** differing in rounding
> alone, which is what `analyses/vowel_space.R` computes. The conclusion about
> ⟨ӑ⟩ does not change; the reason for it does. Old table for reference:
> /y/ vs /i/ −0.567, /ø/ vs /i/ −0.396, /e/ vs /i/ −0.030, /u/ vs /a/ +0.0435,
> /ɵ/ vs /a/ +0.1175, /ʉ/ vs /a/ +0.2336 — do not quote these.

Rounding is identified within a **height-matched pair** as a difference in F3.
A global ordering on F3−F2 cannot do it, because that distance is also a
function of backness; nor can a regression conditioning on F2, because F2 is a
mediator of rounding and conditioning on it would absorb the effect being
measured.

From `rounding_contrasts.csv`:

| contrast | n (both members) | ΔF3 (z) | z on ΔF3 | ΔF2 (z) | z on ΔF2 | reading |
|---|---|---|---|---|---|---|
| /y/ ⟨ӳ⟩ vs /i/ ⟨и⟩ | 42,478 | **−0.483** | −21.2 | −0.457 | −21.4 | ⟨ӳ⟩ rounded |
| /ø/ ⟨ӗ⟩ vs /e/ ⟨е⟩ | 138,558 | **−0.334** | −32.5 | −0.537 | −36.5 | ⟨ӗ⟩ rounded |
| **/u/ ⟨у⟩ vs /ʉ/ ⟨ы⟩ — the control** | 43,065 | **−0.091** | −5.1 | −0.144 | −7.9 | predicted sign |
| /ɵ/ ⟨ӑ⟩ vs /a/ ⟨а⟩ | 223,618 | **+0.107** | +11.2 | −0.134 | −9.3 | **not determinable** |

**The control now behaves, so the earlier blanket claim is withdrawn.** With
/u/ compared against a height-matched unrounded partner rather than against
/a/, F3 moves in the direction rounding predicts (−0.091, z = −5.1), as does F2.
So it is **not** true that F3 has no sensitivity on the back series. What is
true is that the effect is small — a fifth of ⟨ӳ⟩'s and a third of ⟨ӗ⟩'s —
which is the expected asymmetry, F3 lowering being primarily a front-rounding
cue.

**⟨ӑ⟩ remains undecidable, for a different reason: the inventory.** To test
⟨ӑ⟩ you need a mid back unrounded vowel, and Chuvash has none. /a/ is the
nearest back unrounded vowel and it is *low*, so ⟨ӑ⟩ vs /a/ carries exactly the
height confound that invalidated the old control. Its ΔF3 of **+0.107** is
significant and in the wrong direction for rounding, but that is not
interpretable as evidence of unroundedness — it is the same kind of number the
discredited /u/-vs-/a/ comparison produced. `test_has_power = FALSE` should be
read as attaching to this one comparison, not to the back series as a whole.
The earlier recommendation to drop ⟨ӑ⟩ from `VOWEL_ROUND` stays **withdrawn**.

**What the front rows establish:** ⟨ӳ⟩ is rounded against /i/ and ⟨ӗ⟩ is
rounded against /e/ — each against its own height-matched unrounded partner,
with F2 and F3 agreeing in sign, on large samples. Krueger's (1961) front
column is confirmed.

### What the control does *not* establish — and it is worth being explicit

The /u/-vs-/ʉ/ row is a **control, not a result.** It presupposes the standard
description — /u/ ⟨у⟩ rounded, /ʉ/ ⟨ы⟩ unrounded (Krueger's ɯ/u pair) — and
asks only whether F3 detects a difference the literature already asserts.
**It therefore cannot be cited as evidence that ⟨ы⟩ is unrounded or that ⟨у⟩
is rounded.** Doing so would be circular, and an earlier version of this note
committed precisely that error: it reported "Krueger's high row is confirmed
exactly" from a ΔF3 that was itself computed against a mis-specified anchor on
outlier-filtered data, and that claim was withdrawn.

There is a further ambiguity the control cannot resolve. Its effect is small
(−0.091). That is consistent with *either* "F3 is a weak cue to back rounding"
*or* "these two vowels differ less in rounding than the descriptions say." The
measurement does not distinguish those readings. So the corpus establishes
rounding for the two **front** vowels and for neither **back** one: ⟨ӑ⟩ because
no valid anchor exists, ⟨ы⟩ because it *is* the anchor.

**What the data carries about the back series** (descriptive placement, not a
rounding verdict; `back_series_placement.csv`): against /u/, ⟨ы⟩ /ʉ/ is at the
same height (ΔF1 −0.04) but 0.34 fronter in F2; ⟨ӑ⟩ /ɵ/ is lower (ΔF1 +0.49)
and 0.26 fronter. Both sit between /u/ and /a/ in F2 — fronter than a plain
rounded back vowel. That is consistent with Krueger's ɯ/ŏ, with Róna-Tas's
ɤ̆, and with an impression of lip rounding; the acoustics do not choose.

### Rounding under stress

The grammars say the reduced vowels "may be somewhat rounded, especially when
stressed". Tested under rule A6, the only rule that stresses them
(`rounding_by_stress.csv`):

| vowel | series | ΔF3 (z) | ΔF2 (z) | rounding reading | F2 reading |
|---|---|---|---|---|---|
| /ø/ ⟨ӗ⟩ | front | −0.053 | −0.111 | **no rounding change** | lower F2 under stress |
| /ɵ/ ⟨ӑ⟩ | back | +0.265 | −0.299 | not determinable from F3 | lower F2 under stress |
| /ʉ/ ⟨ы⟩ | back | −0.038 | −0.078 | not determinable from F3 | no F2 change |

So the claim is **refuted for ⟨ӗ⟩** — the only vowel of the three where the
test is valid — and untestable for the other two. What is solid is that ⟨ӗ⟩ and
⟨ӑ⟩ both lower F2 under stress. On the filtered dataset ⟨ӗ⟩'s ΔF3 was −0.270
and this note previously reported that it rounds; readmitting the flagged rows
removed the effect.

## How many categories does the formant space support?

Gaussian mixtures on normalised F1/F2/F3, k = 2…12, 60,000-token samples, both
context sets (`clustering_comparison.csv`).

**BIC does not answer this question.** It falls monotonically to the largest k
tested in both context sets — the familiar failure mode where extra components
model within-category non-Gaussianity rather than new categories. It is
reported, not mined.

What is informative is agreement with the phonemic eight, which peaks *below*
eight:

| components | 2 | 3 | 4 | **5** | 6 | 7 | 8 | 10 | 12 |
|---|---|---|---|---|---|---|---|---|---|
| adjusted Rand, non-palatal | 0.331 | 0.331 | 0.415 | **0.416** | 0.398 | 0.296 | 0.286 | 0.235 | 0.215 |
| adjusted Rand, all contexts | 0.298 | 0.336 | 0.409 | 0.379 | 0.395 | 0.262 | 0.212 | 0.216 | 0.200 |

At the peak the clusters are not phoneme-shaped. They are
**harmony-class-shaped** (`clustering_confusion.csv`): one cluster takes all
four front vowels /i e y ø/ (0.62–0.86 of their tokens), one takes the back
non-low /ʉ u ɵ/ (0.51–0.70), and /a/ has its own (0.75).

This is **not** an argument that Chuvash has five vowels — there are phonemic
minimal pairs for eight qualities. It is an argument that a midpoint formant
measurement is the wrong instrument for reading an inventory off, which the
next section makes directly.

## Pairwise separability depends on the classifier

Balanced accuracy on F1/F2/F3, identical 20,000-token samples per pair,
5-fold cross-validated, non-palatal (`separability_classifier_comparison.csv`).
Chance is 0.500.

| pair | quadratic discriminant | gradient boosting | gain |
|---|---|---|---|
| /i/ ~ /y/ | 0.503 | 0.579 | +0.076 |
| /ʉ/ ~ /ɵ/ | 0.518 | 0.626 | +0.108 |
| /u/ ~ /ʉ/ | 0.501 | 0.603 | +0.102 |
| /e/ ~ /ø/ | 0.631 | 0.705 | +0.074 |
| /a/ ~ /e/ | 0.947 | 0.970 | +0.023 |

**Any "at chance" claim has to name the classifier.** A quadratic discriminant
asks whether two clouds are separable by a smooth quadratic boundary;
boosting asks whether *any* structure in the three formants separates them.
The second is systematically higher, by up to 0.11 on identical samples.

Consequence for the argument: /ʉ/ and /ɵ/ are **poorly separated, not
unseparated**, so their near-merger is weaker acoustic support for inventory 5
than a merger claim would imply. The case for treating ⟨ы⟩ as reduced rests on
the written-corpus distribution — /ʉ/ in 0 of 37 open monosyllables against
/y/ in 8 of 52 — and that is where it should be rested. The same applies to
/y/ ~ /i/ at 0.503/0.579: the Q1 argument calls /y/ full on distributional
grounds, and should not also claim it is a distinct acoustic target.

## The caveat that belongs in the same paragraph

Separability tracks duration. The reduced vowels are the short ones, and a
single formant measurement on a 70 ms vowel is noisier than on a 90 ms vowel,
so some of the merging is measurement rather than phonology and this design
cannot separate the two. (The r = 0.70 correlation reported in the earlier
version of this note has not been re-estimated on the rebuilt data; treat it
as indicative only.)

What the design *can* say is that whatever distinguishes /ʉ/ from /ɵ/, or /y/
from /i/, is not recoverable from a point measurement of F1–F3 — and that it
*is* recoverable from phonological context. See `methods_vowel_features.md`:
on the eight-way problem, formants alone give 0.469 and adding the
neighbouring segments gives 0.643, with folds grouped by word type so the
gain cannot be word memorisation.

## Files

- `vowel_space_means.csv` — per vowel and context set: n, normalised means and SDs, Hz means
- `rounding_contrasts.csv` — the table above, with `test_has_power`
- `rounding_by_stress.csv`, `back_series_placement.csv`
- `clustering_comparison.csv` — BIC and adjusted Rand by k, both context sets
- `clustering_confusion.csv` — cluster membership at the peak k
- `separability_classifier_comparison.csv` — two learners, identical samples
- `vowels_normalised.csv` — row-level export the shift and outlier analyses read
- `fig_vowel_chart.png`, `fig_vowel_clustering.png`, `fig_rounding_revised.png`
