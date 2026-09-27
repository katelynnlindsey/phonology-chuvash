# Rounding, and what the eight-way contrast is carried by

*2026-09-27. Revises parts of `methods_vowel_space.md`.*

## A correction to the separability figures

`methods_vowel_space.md` reported /i/~/y/ at 0.518 and /ʉ/~/ɵ/ at 0.527 and
described them as "at chance". Those were quadratic-discriminant accuracies,
which assume each vowel is a Gaussian ellipsoid. On the **same samples and the
same three formants**, a gradient-boosting classifier does considerably better:

*From `separability_classifier_comparison.csv`: 20,000-token subsets per pair.*

| pair | QDA | gradient boosting |
|---|---|---|
| /i/ vs /y/ | 0.518 | **0.672** |
| /ʉ/ vs /ɵ/ | 0.527 | **0.690** |
| /e/ vs /ø/ | 0.693 | 0.735 |
| /u/ vs /ʉ/ | 0.582 | 0.590 |
| /a/ vs /e/ | 0.977 | 0.985 |

"At chance" was too strong: it was at chance *for that model class*. There is
real formant information in both pairs; the class distributions are simply not
Gaussian. **The claim that the /ʉ/~/ɵ/ merger gives independent acoustic support
for inventory 5 has to come down accordingly** — they are poorly separated, not
unseparated, and the minimal-word evidence carries more of the weight for
inventory 5 than previously stated.

## Rounding, tested within harmony series

Rounding lowers F3, but F3 also varies with backness, so the comparison has to be
made within a series against an unrounded anchor: /i/ for the front vowels, /a/
for the back.

| vowel | series | ΔF3 vs anchor | verdict |
|---|---|---|---|
| /y/ ⟨ӳ⟩ | front | **−0.855** | rounded |
| /ø/ ⟨ӗ⟩ | front | **−0.513** | rounded |
| /e/ ⟨е⟩ | front | −0.072 | unrounded |
| /u/ ⟨у⟩ | back | **−0.392** | rounded |
| /ɵ/ ⟨ӑ⟩ | back | +0.029 | **unrounded** |
| /ʉ/ ⟨ы⟩ | back | +0.122 | **unrounded** |

**Krueger's (1961) high row is confirmed exactly** — i front unrounded, y front
rounded, ɯ back unrounded, u back rounded. The 2×2 is the right
characterisation of the high vowels, and it should be kept.

**The lower row needs one change.** ⟨ӗ⟩ is front rounded, as Krueger has it. But
⟨ӑ⟩ shows no F3 lowering at all against /a/, which is what backness alone
predicts. It should be described as a back or central **unrounded** reduced
vowel, following Róna-Tas's ɤ̆ rather than Krueger's ŏ. `VOWEL_ROUND` in the
config should drop it.

On F2 both ⟨ы⟩ (−0.792) and ⟨ӑ⟩ (−0.800) sit between /a/ (−0.440) and /u/
(−1.362): central-back, fronter than /u/, which matches the descriptions of ⟨ы⟩
as high central.

### Reported lip rounding on ⟨ы⟩

These measurements do not show it in non-palatal contexts. Two caveats that keep
the question open: ⟨ы⟩ has only 3,306 tokens here, and visible lip protrusion can
exist without measurable F3 lowering if the labial constriction is slight. What
the acoustics establish is the absence of the *acoustic consequence* of rounding,
not the absence of the gesture.

### The grammars' claim that the reduced vowels round under stress

Half right. Under rule A6, which does assign stress to reduced vowels:

| vowel | ΔF3 stressed − unstressed | ΔF2 | z(F3) |
|---|---|---|---|
| /ø/ ⟨ӗ⟩ | **−0.270** | −0.261 | −26.3 |
| /ɵ/ ⟨ӑ⟩ | **+0.293** | −0.561 | +15.2 |
| /ʉ/ ⟨ы⟩ | −0.001 | −0.106 | −0.04 |

For ⟨ӗ⟩ both formants fall under stress: it does round, exactly as described. For
⟨ӑ⟩ F2 falls but F3 *rises* — that is backing, not rounding. ⟨ы⟩ does not move.

## What the eight-way contrast is carried by

The midpoint formant space resolves four to six categories, not eight. But there
are phonemic minimal pairs for eight qualities, so the question is where the
contrast lives rather than whether it exists.

Balanced accuracy of a gradient-boosting classifier, non-palatal contexts, from
`separability_with_context.csv` (40,000-token samples; the pairwise columns are
not the same runs as the classifier comparison above, so the two tables' shared
cells differ in the third decimal):

| features | all eight | /i/ vs /y/ | /ʉ/ vs /ɵ/ |
|---|---|---|---|
| formants only (F1 F2 F3) | 0.543 | 0.676 | 0.687 |
| + duration | 0.554 | 0.675 | 0.703 |
| + neighbouring segments | **0.753** | **0.861** | **0.940** |
| + word harmony class | 0.789 | 0.891 | 0.943 |

Chance is 0.125 for the eight-way problem and 0.500 for a pair.

Formants at the midpoint give 0.543. **The entire improvement comes from
phonological context, not from anything in the vowel itself**; duration adds
almost nothing. The two crowded pairs go from 0.676 and 0.687 to 0.861 and 0.940.

This is what a language with vowel harmony and pervasive consonant palatalisation
should look like: the vowel's identity is partly distributed onto its neighbours.
It reconciles the clustering result with the phonemic analysis, and it does so
without appealing to the orthography — which matters if one is unwilling to
assume the spelling still reflects the current system.

Caveat: harmony class is partly circular, since it is defined by the vowels of
the word including this one. The neighbouring-segment step is the one to rest on.

Files: `rounding_index.csv`, `rounding_by_stress.csv`,
`separability_with_context.csv`, `separability_classifier_comparison.csv`,
`fig_rounding_revised.png`, `fig_contrast_recovery.png`.
