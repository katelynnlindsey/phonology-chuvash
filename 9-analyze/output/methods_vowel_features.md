# Rounding, and what the eight-way contrast is carried by

*2026-09-27. Revises parts of `methods_vowel_space.md`.*

## A correction to the separability figures

`methods_vowel_space.md` reported /i/~/y/ at 0.518 and /ʉ/~/ɵ/ at 0.527 and
described them as "at chance". Those were quadratic-discriminant accuracies,
which assume each vowel is a Gaussian ellipsoid. On the **same samples and the
same three formants**, a gradient-boosting classifier does considerably better:

*From `separability_classifier_comparison.csv`: 20,000-token subsets per pair.*

| pair | QDA | gradient boosting | gain |
|---|---|---|---|
| /i/ vs /y/ | 0.503 | **0.579** | +0.076 |
| /ʉ/ vs /ɵ/ | 0.518 | **0.626** | +0.108 |
| /e/ vs /ø/ | 0.631 | 0.705 | +0.074 |
| /u/ vs /ʉ/ | 0.501 | 0.603 | +0.102 |
| /a/ vs /e/ | 0.947 | 0.970 | +0.023 |

"At chance" was too strong: it was at chance *for that model class*. There is
real formant information in both pairs; the class distributions are simply not
Gaussian. The two model classes differ by up to 0.11 on identical samples, so
**any merger claim has to name its classifier**. **And the claim that the
/ʉ/~/ɵ/ merger gives independent acoustic support for inventory 5 has to come
down accordingly** — they are poorly separated, not unseparated, and the
minimal-word evidence carries more of the weight for inventory 5 than
previously stated.

*These figures are from the rebuilt, unfiltered data and are all lower than the
outlier-filtered estimates this document originally carried (0.672 and 0.690 for
the two crowded pairs), because the readmitted rows are noisier. The filtered
figures must not be reused.*

## Rounding, tested within harmony series — front row only

> **Revised 27 Sep 2026.** An earlier version of this section, computed on the
> outlier-filtered data, reported ⟨ӑ⟩ as **unrounded** and recommended dropping
> it from `VOWEL_ROUND`. **Both statements are withdrawn.** The test does not
> have the power to decide the back series, and the recommendation must not be
> acted on. This section now agrees with `methods_vowel_space.md`, which is the
> fuller treatment; numbers here come from `rounding_contrasts.csv` and
> `back_series_placement.csv`.

Rounding lowers F3, but F3 also varies with backness, so the comparison is made
within a harmony series against an unrounded anchor: /i/ for the front vowels,
/a/ for the back.

**The back-series test fails its positive control, so it cannot be run.** /u/ is
certainly rounded, yet against /a/ its ΔF3z is **+0.0435** — the wrong sign. F3
lowering is a *front*-rounding cue; on back vowels the acoustic consequence of
rounding lands in F2, where backness also lands, so the two cannot be separated
with these three formants. Every back-series row is therefore marked
`test_has_power = FALSE` and carries no verdict.

| vowel | series | ΔF3z vs anchor | z | verdict |
|---|---|---|---|---|
| /y/ ⟨ӳ⟩ | front | **−0.567** | −37.2 | rounded |
| /ø/ ⟨ӗ⟩ | front | **−0.396** | −66.0 | rounded |
| /e/ ⟨е⟩ | front | −0.030 | −5.5 | unrounded |
| /u/ ⟨у⟩ | back | +0.044 | +5.1 | *positive control fails* |
| /ɵ/ ⟨ӑ⟩ | back | +0.118 | +21.2 | not determinable |
| /ʉ/ ⟨ы⟩ | back | +0.234 | +18.5 | not determinable |

**What the front row establishes.** ⟨ӳ⟩ is front rounded and ⟨ӗ⟩ is front
rounded, both against an /i/ anchor on large samples. ⟨е⟩ is unrounded; its
−0.030 is significant only because n = 90,673 and is an order of magnitude
below the two rounded vowels. Krueger's (1961) front column is confirmed.

**What cannot be decided.** Whether ⟨ӑ⟩ and ⟨ы⟩ are rounded. Krueger's ŏ and
Róna-Tas's ɤ̆ differ precisely on this point, and these formants do not
adjudicate between them. The honest statement for the manuscript is that the
back series is not determinable from F3, not that it is unrounded.

**What the back series does carry** is placement, not rounding. Relative to /u/,
⟨ӑ⟩ sits ΔF1z +0.488 / ΔF2z +0.257 and ⟨ы⟩ ΔF1z −0.041 / ΔF2z +0.340, with /a/
at ΔF1z +1.547 / ΔF2z +0.478. Both reduced back vowels lie **between /u/ and
/a/ in F2** — central-back, fronter than /u/ — which matches the descriptions of
⟨ы⟩ as high central and of ⟨ӑ⟩ as a mid central-back reduced vowel.

### Reported lip rounding on ⟨ы⟩

Not testable here, for the reason above: the measurement that would show it is
the one whose positive control fails. Two further caveats keep the question
open even in principle — ⟨ы⟩ has 6,324 tokens against tens of thousands for the
other vowels, and visible lip protrusion can exist without measurable F3
lowering when the labial constriction is slight. Settling it needs articulatory
data (lip video or ultrasound), not these formants.

### The grammars' claim that the reduced vowels round under stress

> **Revised 27 Sep 2026.** The earlier version of this table read ⟨ӗ⟩ as
> **rounding under stress** (ΔF3z −0.270) on the outlier-filtered data. On the
> full data the effect is −0.053, a fifth the size, and **that reading is
> withdrawn**. Numbers from `rounding_by_stress.csv`.

Under rule A6, which does assign stress to reduced vowels:

| vowel | ΔF3z stressed − unstressed | z(F3) | ΔF2z | F3 reading |
|---|---|---|---|---|
| /ø/ ⟨ӗ⟩ | −0.053 | −5.8 | **−0.111** | no rounding change |
| /ɵ/ ⟨ӑ⟩ | +0.265 | +21.9 | **−0.299** | not determinable from F3 |
| /ʉ/ ⟨ы⟩ | −0.038 | −1.5 | −0.078 | not determinable from F3 |

**The claim is not supported on F3 for any of the three.** ⟨ӗ⟩ moves by 0.05 z,
which is negligible beside the 0.40 z that separates it from unrounded /i/ in
the first place; ⟨ӑ⟩ moves in the *opposite* direction; ⟨ы⟩ does not move at
all, and with 2,971 stressed tokens its z of −1.5 is not distinguishable from
zero. And for ⟨ӑ⟩ and ⟨ы⟩ the F3 test has no power regardless, for the
positive-control reason above.

**What does hold is an F2 effect.** Both ⟨ӗ⟩ (−0.111) and ⟨ӑ⟩ (−0.299) lower F2
under stress; ⟨ы⟩ does not. Lower F2 is consistent with rounding *or* with
backing, and these formants do not separate the two — but it does mean the
grammars are describing something real: the reduced vowels are not
articulatorily identical under stress and without it. The safe statement is that
stressed ⟨ӗ⟩ and ⟨ӑ⟩ are backer, more peripheral, or both, and that whether
lip rounding is involved needs articulatory data.

## What the eight-way contrast is carried by

The midpoint formant space resolves four to six categories, not eight. But there
are phonemic minimal pairs for eight qualities, so the question is where the
contrast lives rather than whether it exists.

Balanced accuracy of a gradient-boosting classifier, non-palatal contexts, from
`separability_with_context.csv` (40,000-token samples; the pairwise columns are
not the same runs as the classifier comparison above, so the two tables' shared
cells differ in the third decimal). Folds are **grouped by word type**, so the
context features cannot succeed by memorising particular words; the
random-fold figures are in the CSV alongside and differ by at most 0.04, so the
context gain is not leakage:

| features | all eight | /i/ vs /y/ | /ʉ/ vs /ɵ/ |
|---|---|---|---|
| formants only (F1 F2 F3) | 0.469 | 0.606 | 0.588 |
| + duration | 0.491 | 0.611 | 0.613 |
| + neighbouring segments | **0.643** | **0.713** | **0.833** |
| + word harmony class | 0.675 | 0.757 | 0.833 |

Chance is 0.125 for the eight-way problem and 0.500 for a pair.

Formants at the midpoint give 0.469 on the eight-way problem. **Almost the
entire improvement comes from phonological context, not from anything in the
vowel itself**; duration adds 0.022. The two crowded pairs go from 0.606 and
0.588 to 0.713 and 0.833.

The harmony-class row is partly circular — a word's harmony class is close to a
restatement of which vowels it contains — so the argument should rest on the
neighbouring-segment step, which is not.

This is what a language with vowel harmony and pervasive consonant palatalisation
should look like: the vowel's identity is partly distributed onto its neighbours.
It reconciles the clustering result with the phonemic analysis, and it does so
without appealing to the orthography — which matters if one is unwilling to
assume the spelling still reflects the current system.

Files: `rounding_contrasts.csv`, `back_series_placement.csv`,
`rounding_by_stress.csv`, `separability_with_context.csv`,
`separability_classifier_comparison.csv`, `fig_rounding_revised.png`,
`fig_contrast_recovery.png`. The fuller treatment of the vowel space is
`methods_vowel_space.md`; where the two documents touch the same result they now
agree, and `methods_vowel_space.md` is authoritative.
