# Are all the scripts up to date?

Audit of `9-analyze/` on 2026-09-29, after the stage-4 re-run wrote full-word
`stress_rule_*` columns for all ten rules.

## The end-to-end check

`stress_rules_full_word.R` now reads the pipeline's stored labels instead of
recomputing its own, and asserts the two agree. They do, for every rule:

```
stored stress_rule_A6     == full-word recomputation: 100.0000%
stored stress_rule_A5     == full-word recomputation: 100.0000%
stored stress_rule_A4     == full-word recomputation: 100.0000%
stored stress_rule_B6     == full-word recomputation: 100.0000%
stored stress_rule_B5     == full-word recomputation: 100.0000%
stored stress_rule_B4     == full-word recomputation: 100.0000%
stored stress_rule_SON_F  == full-word recomputation: 100.0000%
stored stress_rule_SON_A  == full-word recomputation: 100.0000%
stored stress_rule_SON_B  == full-word recomputation: 100.0000%
```

So the model comparison did **not** move when stage 4 was re-run: the
comparison had already been computing full-word targets locally. Every
coefficient and AIC in `full_word_rule_models.csv` is bit-identical to the
version computed before the re-run (checked: max |ΔAIC| = 0.0, max |Δβ| = 0.0
across all 72 rows). What the re-run buys is that every *other* script can now
read the labels rather than deriving them, which is what the fixes below do.

## Bugs found and fixed in this audit

### 1. The printed rule tables were duration and intensity interleaved
`stress_rules_full_word.R` filtered with `dv == get("dv")` inside a
`data.table` subset. Both resolve to the column, so the condition was
`dv == dv` — always TRUE — and every printed table contained all 18 rows for
that subset and control set rather than the 9 for that DV. **The CSV was never
affected** (`dAIC` and `rank` are computed `by = .(subset, dv, controls)`).

Consequence: the claim that the two control sets agree at **ρ = +1.000 in all
four subset × DV combinations was read off those broken tables and is wrong.**
Computed from the CSV:

| subset | duration | intensity |
|---|---|---|
| all words | +0.867 | +0.867 |
| conflict subset | **+0.083** | +0.883 |

The control-set instability is therefore **not** retired. It is concentrated in
the conflict-subset duration ranking — the one in which SON-A placed first.
Under `vowel_label` SON-A is 1st (ΔAIC 0) and SON-B 2nd (Δ6.5); under
`vowel_height` SON-A is 8th of 9 (Δ806) and B5 1st. Do not report that ranking
without the specification attached.

### 2. Three baselines were computed over surviving rows
`stress_rule_comparison.R`'s `derive_baselines()` set
`stress_rule_final = (sidx == max(sidx))` and
`stress_rule_initial = (sidx == min(sidx))`, where the max and min range over
the syllables that survived cleaning. In a word whose final syllable was not
measured, `final` designated the last *surviving* syllable — always an earlier
one. Now `sidx == sN` and `sidx == 1L`; `weight` falls back to `sN` rather
than to the last surviving syllable. `intensity_measure_comparison.R` had the
same three lines and the same fix.

### 3. `intensity_measure_comparison.R` re-derived all nine rules
It ran its own `predict_A`/`predict_B` over the surviving rows
(`max(sidx[is_full])`), which is the bug `stress_rules_full_word.R` documents.
It now reads `stress_rule_*` and derives only the three baselines. Its rule
list was also hardcoded to six and is now `setdiff(RULE_NAMES, "SON")`, so the
sonority rules are picked up automatically.

### 4. `monosyllable_default_test.R` re-derived the A rules
`any_A` — whether any A rule stresses anything in the word — came from
`assign_stress()` over the surviving vowels. It bit only the two polysyllabic
cells; a monosyllable is complete by construction. Now reads the stored
columns. The conclusion is unchanged and the numbers moved:

| cell | n | types | duration | intensity |
|---|---|---|---|---|
| reduced vowel, monosyllable | 10,448 | 148 | **+7.45%** (t 3.75) | +1.62 dB |
| full vowel, monosyllable | 36,452 | 357 | +37.27% (t 5.80) | +3.08 dB |
| stressed full vowel, polysyllable-final | 158,463 | 20,624 | +24.39% (t 4.09) | +3.72 dB |

(reference = reduced vowel in the word-final syllable of a polysyllable no A
rule stresses; every cell is a word-final syllable, so final lengthening is
equalised). The monosyllabic reduced vowel sits with the unstressed reference,
not with the stressed cells — **supports B**, as before, at +7.45% rather than
the +9.45% reported earlier. Note the model drops one rank-deficient column:
`cell` is partly collinear with `vowel_label`, since vowel class is a function
of vowel identity.

### 5. The rule-neutral unstressed set named only six rules
`sonority_hierarchy.R` and `sonority_peripherality.R` intersected over the six
A/B rules, so tokens a sonority rule stresses stayed inside a set whose whole
purpose is to be free of stress-driven variation. This is now a documented
choice rather than a hardcoded list, and **both definitions are reported**,
because they pull against each other:

- `AB_only` — the six A/B rules. They partition the inventory into full and
  reduced and never refer to sonority tiers, so excluding what they stress
  cannot bias a measurement of the tiers *through the tiers*.
- `all_rules` — plus SON-F/SON-A/SON-B. Stricter, and the only set unstressed
  under every analysis on the table — but a SON rule stresses the most
  sonorous vowel in the word, so excluding its targets removes tokens in a way
  correlated with the hierarchy being measured. That circularity is one
  `AB_only` does not have.

It turns out not to matter. Both give peripherality recovered **8/8**, hull gap
**+66.7 points**, clean in **5/9 speakers**, tier ρ = **+0.970**. Only the
sample size differs (280,871 vs 244,277 tokens).

### 6. Two thresholds in the peripherality test were tuned to old labels
`sonority_peripherality.R` split peripheral from central at `pct_on_hull > 35`
and binned height at F1z breaks of `-0.55 / +0.30`. Both numbers had been
chosen against one particular labelling, so "recovery" was partly fitted — and
with re-run labels the F1z breaks mis-binned /u/ and /ʉ/, dropping the reported
tier recovery from 8/8 to 6/8 for reasons that were an artefact of the breaks.
Both are gone:

- the peripheral/central split is taken at the **largest gap** in the sorted
  `pct_on_hull` values (data-driven; lands at 44.4%)
- de Lacy predicts an **ordering** within each class, not membership in three
  named bins, so height is tested as an ordering — Spearman ρ between
  `son_tier` and F1z rank. No break points enter.

Threshold-free, the result is: peripherality class **8/8**, height ordering
ρ = **+0.894** within the peripheral class and **+0.866** within the central
class, whole-hierarchy ρ = **+0.970**. The earlier **ρ = +1.000** was
threshold-assisted and should not be quoted. Convex hull remains the only
peripherality measure that separates the classes at all: centroid distance
overlaps by −0.011 (`AB_only`) and backness deviation by −0.166, clean in 0/9
speakers.

Do not read the exact-tier-match count (3/8) as a score: `meas_tier` is built
from a continuous F1z and takes eight distinct values, while de Lacy's tiers
are tied (/i y u/ all tier 3, /ø ɵ/ both tier 4). A tied target cannot be
matched exactly by an untied reconstruction.

### 7. The data dictionary did not describe the sonority rules
`data_profile.R`'s fallback regex was `^stress_rule_[AB][654]$`, which does not
match `stress_rule_SON_F`, so the four new columns got an empty note. The
regex is now `^stress_rule_`, its text states that labels come from the whole
word, and SON-F/SON-A/SON-B/SON have explicit entries.

### 8. `RULE_NAMES` contains an alias, and scripts were fitting it twice
`STRESS_RULES` carries `SON` as a back-compatible alias of `SON_F`, so
`RULE_NAMES` has ten entries for nine distinct rules. Any script looping over
`RULE_NAMES` fits the same model twice and puts two identical rows in the
ranking. `stress_rule_comparison.R`, `intensity_measure_comparison.R` and both
sonority scripts now use `setdiff(RULE_NAMES, "SON")`.

## Retired

These three compute targets from the surviving vowels and are superseded in
full by `stress_rules_full_word.R`, which covers the same ground (9 rules × 2
DVs × 2 control sets × {all words, conflict subset}) on the pipeline's labels.
Each now carries a `⚠⚠ SUPERSEDED IN FULL` header naming its dead outputs.

| script | dead outputs |
|---|---|
| `rule_conflict_models.R` | `rule_conflict_models.csv`, `rule_conflict_profile.csv`, `rule_conflict_pairwise.csv` |
| `rule_conflict_robustness.R` | `rule_conflict_robustness.csv`, `rule_conflict_singular.csv` |
| `rule_conflict_extended.R` | `rule_conflict_extended.csv` |

`rule_conflict_robustness.R` deserves a note of its own: its headline finding
was that the ranking flips between control sets at ρ = +0.217. That number was
computed on surviving-row labels, so it does not stand — but the *phenomenon*
does, at ρ = +0.083 on the conflict-subset duration ranking (item 1 above). The
script was right about the instability and wrong about its size.

## Unaffected by the stress labels

These read the leveled data but not `stress_rule_*`, so the re-run does not
touch them: `geminating_stems.R`, `gemination_mora.R`, `minimal_word_internal.R`,
`inventory_phonotactics.R`, `syllabification_audit.R`, `wordhood_internal.py`,
`pbase_comparison.py`, `geminating_stems.py` (already marked superseded by the
R port), `gemination_cross_corpus.py`.

`coda_sonority.R` reads the stored columns and was already correct. Its
acoustic-prominence rows are unchanged to three decimals (`prom_dur_adj`:
has_coda 0.653, is_a 1.348, is_nonhigh 1.166). Its rule-based rows now read
has_coda 0.838 (A6) and 0.848 (B5) — both below 1, so still no coda
attraction. Its secondary-stress frame grew from 154,504 to 169,896
non-primary syllables, and the pattern holds: the syllable after the primary is
longer (dur_z +0.347) *and* quieter (int_z −0.215), which is final lengthening
rather than secondary stress.

`son_default_test.R` filtered `word_complete == TRUE` before computing
anything, so surviving == full by construction. Its numbers are unchanged:
placement null (+0.42 ms, t 0.75), presence +13.88% but structurally
confounded. Verdict still SON-B on placement.

## Still stale

| output | why |
|---|---|
| `results_macros.tex` | headline duration figures come from the superseded comparison; regenerate with `make_macros.R` **after** the re-runs below land |
| `draft_number_mapping.csv` | 41 rows, pre-rebuild |
| `jnd_contrasts.csv` | produced by `intensity_measure_comparison.R`, pending its re-run |
| `master_rule_comparison.csv`, `rule_acoustic_models.csv`, `rule_detected_descriptive.csv`, `rule_coda_attraction.csv`, `rule_default_evidence.csv`, `rule_inventory_evidence.csv`, `rule_minimal_word.csv`, `rule_positional.csv` | produced by `stress_rule_comparison.R`, pending its re-run |
| `intensity_rule_models.csv` | same, from `intensity_measure_comparison.R` |
| `chuvash_findings_slides.html` | no slides for SON/SON-A/SON-B, the conflict-subset ranking, cross-corpus gemination, peripherality, the full-word fix or the internal minimal-word filter; slide 7 still states the retracted mora conclusion |

`align_confidence.py` and `vowel_features.py` read `stress_rule_*` out of
exported CSVs rather than the leveled data, so they need their input re-exported
before they are re-run. Neither feeds a stress claim — the confidence composite
uses stress only as a stratifying column — so this is low priority.

## One design choice left open

`coda_sonority.R` tests rule-based coda attraction for `A6` and `B5` only, as
two representative rules. Adding `SON_B` would say whether a sonority rule's
stressed syllables attract codas differently. That is a scope addition rather
than a currency problem, so it has not been made.
