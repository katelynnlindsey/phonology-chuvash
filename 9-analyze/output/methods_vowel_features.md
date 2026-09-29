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

## Rounding, tested within height-matched pairs

> **Revised 27 Sep 2026, corrected again 29 Sep 2026.** An earlier version of
> this section, computed on the outlier-filtered data, reported ⟨ӑ⟩ as
> **unrounded** and recommended dropping it from `VOWEL_ROUND`. **Both
> statements remain withdrawn** and the recommendation must not be acted on.
>
> What the 29 Sep pass changed is the *reason*. The 27 Sep version said the
> test has no power on the back series at all. That rested on a mis-specified
> control (/u/ against /a/, which is not height-matched); with the correct
> control the back-series test does have power, and it is the absence of a
> height-matched anchor for ⟨ӑ⟩ — not a limitation of F3 — that leaves ⟨ӑ⟩
> undecided. Every number in the table now comes from
> **`rounding_contrasts.csv`** alone, the height-matched pairs computed by
> `analyses/vowel_space.R`. `back_series_placement.csv` sourced the previous
> table's back-series column as each-vowel-minus-/a/ and is no longer used
> here; it remains valid for what it is, a description of where ⟨ӑ⟩ and ⟨ы⟩ sit
> relative to /u/, which is not a rounding test.
>
> This section agrees with `methods_vowel_space.md`, the fuller treatment,
> which needs the same anchor correction applied to it.

Rounding lowers F3, but F3 also varies with backness **and with height**, so the
comparison is only identified within a pair matched on both, differing in
rounding alone.

**Correction, 2026-09-29 — the control was mis-specified, and the reason the
back-series test cannot be run is different from what this note used to say.**
The earlier text anchored the back series on **/a/** and reported /u/ vs /a/ at
ΔF3z **+0.0435**, the wrong sign, concluding that F3 lowering is a front-rounding
cue with no back-series power at all. But /u/ and /a/ are not height-matched —
high against low — so that contrast confounds rounding with height and is not a
valid control in either direction.

The height-matched control is **/u/ vs /ʉ/ ⟨ы⟩**: both high, differing in
rounding, which is the pair `analyses/vowel_space.R` actually uses. It gives
ΔF3z **−0.091 (z = −5.1)** and ΔF2z **−0.144 (z = −7.9)** — both the sign
rounding predicts. **So the back-series F3 test does have power**, modest but
real, and the blanket claim that it does not is withdrawn.

That does not rescue the ⟨ӑ⟩ verdict, because the same defect applies to it.
⟨ӑ⟩ /ɵ/ is mid; the only back unrounded vowel available to anchor it is /a/,
which is low. Its measured ΔF3z against /a/ is **+0.107 (z = +11.2)** —
significantly the *wrong* sign for rounding, and significantly non-zero — but
so was the discredited /u/-vs-/a/ figure, and for the same structural reason.
Chuvash has no mid back unrounded vowel, so **no height-matched anchor for ⟨ӑ⟩
exists in this inventory and its rounding is not determinable from F3.** What
changes is that this is now a fact about the *inventory* rather than about F3:
the ⟨ӑ⟩ row carries no verdict because no valid anchor exists for it, not
because F3 is blind to back rounding. `test_has_power = FALSE` should be read
as attaching to the **⟨ӑ⟩-vs-/a/ comparison specifically**, not to the back
series as a whole — /u/ vs /ʉ/ is a back-series comparison and it has power.

A designed elicitation with lip video, or a articulatory measure, is the way to
settle ⟨ӑ⟩. The corpus cannot.

**The table below was replaced on 2026-09-29 and the previous one should not be
quoted.** It listed one row per vowel against a single anchor per harmony
series — /i/ for the front vowels, /a/ for the back — and so carried the same
height confound throughout, not only in the /u/ control: it compared mid ⟨ӗ⟩
against high /i/ and mid ⟨ӑ⟩ against low /a/. It also predated the re-run, so
its numbers (/y/ −0.567, /ø/ −0.396, ⟨ӑ⟩ +0.118, ⟨ы⟩ +0.234) are stale as well
as mis-anchored. The replacement is the set of **height-matched pairs** that
`analyses/vowel_space.R` computes, read from `rounding_contrasts.csv`.

| pair | ΔF2z | z | ΔF3z | z | reading |
|---|---|---|---|---|---|
| /y/ ⟨ӳ⟩ vs /i/ ⟨и⟩ | **−0.457** | −21.4 | **−0.483** | −21.2 | ⟨ӳ⟩ rounded |
| /ø/ ⟨ӗ⟩ vs /e/ ⟨е⟩ | **−0.537** | −36.5 | **−0.334** | −32.5 | ⟨ӗ⟩ rounded |
| /u/ ⟨у⟩ vs /ʉ/ ⟨ы⟩ | **−0.144** | −7.9 | **−0.091** | −5.1 | positive control **passes** |
| /ɵ/ ⟨ӑ⟩ vs /a/ ⟨а⟩ | −0.134 | −9.3 | **+0.107** | +11.2 | not determinable |

Because each pair is height-matched, the unrounded member *is* the anchor, so
/e/ and /ʉ/ have no rows of their own — /e/ anchors ⟨ӗ⟩ and /ʉ/ anchors /u/.
The earlier table's separate "/e/ ⟨е⟩ unrounded, −0.030" row is therefore gone
by construction, not by retraction.

**What the front rows establish.** ⟨ӳ⟩ and ⟨ӗ⟩ are both rounded, each against
its own height-matched unrounded partner, on large samples and with F2 and F3
agreeing in sign. Krueger's (1961) front column is confirmed.

**What the /u/ row establishes — and what it does not.** The positive control
passes, so F3 does carry back-series rounding information in this corpus. The
effect is small (−0.091 against −0.334 and −0.483 for the front pairs), which
is the expected pattern: F3 lowering is a stronger cue to front rounding than
to back rounding.

But that row is a **control, not a result.** It presupposes the standard
description of the two high back vowels — /u/ ⟨у⟩ rounded, /ʉ/ ⟨ы⟩ unrounded
(Krueger's ɯ/u pair) — and asks only whether F3 detects a difference the
literature already asserts. **It cannot be cited as evidence that ⟨ы⟩ is
unrounded or that ⟨у⟩ is rounded.** That would be circular, and a much earlier
version of this note did exactly that: it reported "Krueger's high row is
confirmed exactly" on the strength of a ΔF3 computed against a mis-specified
anchor on outlier-filtered data, and the claim was withdrawn when the filter
came off.

There is also an ambiguity the control cannot resolve. A small effect is
consistent with *either* "F3 is a weak cue to back rounding" *or* "these two
vowels differ less in rounding than the descriptions say". Nothing here
distinguishes them. So the corpus establishes rounding for the two **front**
vowels and for neither **back** one — ⟨ӑ⟩ because no valid anchor exists for
it, ⟨ы⟩ because it *is* the anchor.

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
random-fold figures are in the CSV alongside and are higher by at most **0.054**
(the two /ʉ/~/ɵ/ context rows; 0.037 for the eight-way problem, 0.023 for
/i/~/y/, and under 0.01 in every row without context features). The grouped
figures are the conservative ones and the context gain survives in them, so it
is not word memorisation:

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
