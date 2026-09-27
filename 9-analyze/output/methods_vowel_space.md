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

Rounding is identified *within* a harmony series, against an unrounded anchor
(/i/ for the front series, /a/ for the back), as a difference in F3. A global
ordering on F3−F2 cannot do it, because that distance is also a function of
backness; nor can a regression conditioning on F2, because F2 is a mediator of
rounding and conditioning on it would absorb the effect being measured.

From `rounding_contrasts.csv`:

| contrast | n | ΔF3 (z) | ΔF2 (z) | z on ΔF3 | reading |
|---|---|---|---|---|---|
| /y/ vs /i/ | 2,963 | **−0.567** | −0.543 | −37.2 | rounded |
| /ø/ vs /i/ | 47,885 | **−0.396** | −0.637 | −66.0 | rounded |
| /e/ vs /i/ | 90,673 | −0.030 | −0.104 | −5.5 | unrounded |
| **/u/ vs /a/ — the control** | 36,741 | **+0.0435** | −0.478 | +5.1 | rounded, yet no F3 drop |
| /ɵ/ vs /a/ | 53,021 | +0.1175 | −0.220 | +21.2 | **not determinable** |
| /ʉ/ vs /a/ | 6,324 | +0.2336 | −0.138 | +18.5 | **not determinable** |

**The back-series rows are uninformative, and the reason is the control.** /u/
is rounded in every description of Chuvash and in every Turkic language, and
its F3 is not lower than /a/'s. So F3 has no sensitivity on the back series,
and a *positive* ΔF3 for ⟨ӑ⟩ or ⟨ы⟩ is not evidence that they are unrounded —
it is what a rounded back vowel also looks like on this measure. The
underlying reason is phonetic, not a data problem: F3 lowering is primarily a
**front**-rounding cue; on back vowels the rounding gesture appears in F2,
which is also where backness appears, and these formants cannot separate the
two. No amount of additional data fixes it.

`rounding_contrasts.csv` carries a `test_has_power` column recording this. The
earlier recommendation to drop ⟨ӑ⟩ from `VOWEL_ROUND` is **withdrawn**, and
the config now carries a comment saying why.

**What the front series does establish:** Krueger's (1961) high row, exactly
as he has it — /i/ front unrounded, /y/ front rounded — and /ø/ front rounded
against /e/ unrounded in the mid row.

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
