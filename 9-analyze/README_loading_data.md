# Loading the current data in R

Everything below was run against the files on disk on 27 Sep 2026 and the
numbers are what you should see. If yours differ, see §3.

## 1. Quick start

Open `phonology-chuvash.Rproj` in RStudio, then:

```r
source(here::here("9-analyze", "analyses", "00_session_setup.R"))
```

That is the only line you need. It sources the config, loads every level of
every corpus, prints a summary, and builds a few convenience subsets. Takes
about 40 seconds, mostly reading the 296 MB vowel table.

Do **not** load the `.rds` files by hand. `00_session_setup.R` resolves each
one against the right directory — some live in `data/cleaned/`, some in
`data/leveled/` — and getting that wrong was a real bug in this repo once.

## 2. What you get

| object | rows | cols | what it is |
|---|---|---|---|
| `vowels` | 574,344 | 193 | one row per vowel token, all acoustics |
| `syllables` | 574,344 | 203 | same rows plus syllable-level columns |
| `words` | 303,139 | 42 | one row per word token |
| `phrases` | 46,336 | 11 | one row per utterance |
| `zheltov` | 19,009 | 3 | wordlist, word level, no acoustics |
| `mono` | 430,008 | 6 | monolingual corpus types + frequency |
| `zheltov_ann` | 52,171 | 21 | wordlist, **syllable** level + annotations |
| `mono_ann` | 1,543,531 | 20 | monolingual, **syllable** level + annotations |

Plus `vowels_stressed` / `vowels_unstressed` (filtered on `ACTIVE_RULE`, which
is `A6`), `valid_words`, `exclusion_log`, and everything from
`config/phonology_params.R` — `STRESS_RULES`, `SONORITY_TIERS`,
`assign_stress()`, `syllabify_ipa()`, `normalise_orthography()`.

Spoken data splits 440,768 vowels / 229,809 words / 29,551 utterances /
1 speaker for Chuvash Voice, and 133,576 / 73,330 / 16,785 / 109 for Common
Voice.

## 3. Checking you have the current data

```r
stopifnot(nrow(vowels) == 574344, ncol(vowels) == 193,
          nrow(words)  == 303139)
```

If `vowels` has 280,955 rows you are on the pre-27-September data, from before
cleaning steps 05 and 06 were changed from deleting rows to flagging them.
Re-run the pipeline (§8).

## 4. Five things that will bite you

**(a) Nothing is deleted any more — it is flagged.** Steps 05 and 06 used to
drop 45–47% of vowels. They now set flags, so `vowels` contains rows you may
not want:

```r
vowels %>% filter(word_complete, !iqr_outlier_any)   # 289,002 rows
```
`iqr_outlier_any` is TRUE for 11.1% of rows and `word_complete` for only 51.3%.
Reproducing the old behaviour is that one filter. **Do not filter by default** —
the flagged rows are disproportionately stressed vowels, which is why the
deletion was wrong.

**(b) The stress-rule columns are computed over the vowels that SURVIVED
cleaning, not over the dictionary word.** `words$vowel_sequence` holds only the
vowels present, so a token of шупашкар with `sN = 3` but only one surviving
vowel has `vowel_sequence == "a"` and `stressed_sidx_B5 == NA`. This is
internally consistent — `assign_stress()` on `vowel_sequence` reproduces the
stored `stressed_sidx_B5` on **100%** of word tokens where both are non-NA —
but it means a rule column can disagree with your intuition about the word.
For anything where the syllable count matters, filter on `word_complete`.

**(c) `vowel_cat_6/5/4` do not exist in `vowels`.** They are only in
`zheltov_ann` and `mono_ann`. The spoken equivalent is `vowel_class`, which
takes `full` (437,957) and `reduced` (136,387) — note this is the
**inventory-6** partition, matching `ACTIVE_RULE = "A6"`, so /ʉ/ counts as
full. For a different inventory, build it from `rule_full()` / `rule_reduced()`
rather than hardcoding:

```r
vowels %>% mutate(vclass5 = if_else(vowel_label %in% rule_full("B5"),
                                    "full", "reduced"))
```

**(d) Use `int_midpoint` for intensity.** `total_intensity` is a sum of 20
per-step dB readings and correlates with duration at r = 0.909 — it is a
duration measure. `peak_intensity` is extreme-value biased (stressed vowels
have more valid steps, so it manufactures part of the effect). The `intensity`
column is new-FAVE's point measure, taken at ~13.8% into the vowel, i.e. on
the onset ramp. `int_midpoint` is the mean of steps 10 and 11, the true
midpoint, available for 100% of rows. For f0 use `f0_mean` or `f0_slope`;
`f0_step1`–`f0_step20` are the raw contour, stylised to 2 semitones, so small
f0 differences in them are not interpretable.

**(e) Don't filter on typed IPA literals if your locale is not UTF-8.**
`config/phonology_params.R` stops the session if it isn't, but if you work
around that guard, `filter(vowel_label == "ø")` silently returns zero rows.

## 5. Which column for which question

| question | column |
|---|---|
| duration | `duration` (ms) |
| intensity | `int_midpoint` (dB) |
| pitch | `f0_mean`, `f0_slope` |
| vowel quality | `F1`, `F2`, `F3`; normalised in `output/vowels_normalised.csv` |
| syllable position | `sidx` of `sN` |
| open vs closed | `syllable_coda` (`open` / `closed`) |
| stress under a rule | `stress_rule_A6` … `stress_rule_B4` |
| utterance position | `phrase_position`, `vowel_position` |
| speaker | `speaker_id` (NA for Chuvash Voice — see §7) |
| word frequency | `corpus_freq`, `log_corpus_freq_smoothed`, `in_mono_corpus` |
| formant tracking error | `smooth_error` (new-FAVE; lower is better) |

**Always control the utterance edge** in any duration or f0 model. Final
lengthening is 15.6× the size of the stress effect: word-final syllable
+12.3%, and +51.6% in interaction with utterance-final position. An
uncontrolled initial-vs-final comparison is measuring the edge, not stress.

## 6. Adding rule SON

`SON` is in `RULE_NAMES` and `assign_stress()` handles it, but it is not yet a
column in the `.rds` files — that needs a stage-4 re-run. Until then:

```r
library(data.table)
w <- as.data.table(words)
w[, son_sidx := vapply(strsplit(vowel_sequence, "-", fixed = TRUE),
                       function(vs) assign_stress(vs, "SON"), numeric(1))]
v <- merge(as.data.table(vowels), w[, .(word_id, son_sidx)], by = "word_id")
v[, stress_rule_SON := fifelse(sidx == son_sidx, "Stressed", "Unstressed")]
```

Verified output: SON marks 42.16% of vowels as stressed and agrees with A6 on
89.82%, A5 on 89.87%, B5 on 89.14%. Compute it from `words$vowel_sequence` as
above, **not** from the surviving `vowels` rows — doing the latter gives a
different answer on incomplete words, for the reason in §4(b).

## 7. Speakers

`speaker_id` is NA throughout Chuvash Voice, which is essentially one speaker:
93.4% of its recordings fall in a single acoustic voice cluster against 78
clusters in a comparable Common Voice sample. Ten minor clusters account for
6.6% and at least three or four of them are other people. Per-recording
cluster assignments are in `output/speaker_structure.csv`; use `file_name` as
the grouping variable for Chuvash Voice and `speaker_id` for Common Voice.
Random effects throughout this project are
`(1 | speaker_id) + (1 | file_name) + (1 | word_label)`.

Chuvash Voice's gender metadata is wrong — the dominant voice has median f0
225.7 Hz and is labelled `male_masculine` — so don't use gender as a
cross-corpus predictor.

## 8. Re-running the pipeline

```r
source(here::here("9-analyze", "pipeline", "run_pipeline.R"))
run_pipeline()                       # all stages, ~35 min
run_pipeline(from = 4)               # just re-annotate, ~18 min
```

Which stage to start from: raw inputs → 1; cleaning thresholds or `is_loan`
→ 2; `syllabify_ipa()` or the `IPA_*` maps → 3; `VOWEL_RULES`, `ACTIVE_RULE`,
`classify_vowel()`, or a new stress rule → 4. It writes a provenance log to
`data/run_log/run_<timestamp>.txt` and warns loudly if the git tree is dirty,
because such a run cannot be reproduced from its recorded SHA. **Commit before
any run whose numbers go into the paper.**

## 9. The Python-side tables

Two things live outside the R pipeline because they need segment-level data the
R levels don't carry. Read them with `data.table::fread()`:

```r
ph  <- fread(here::here("7-extract","reextract","phones_chuvash_voice.csv"))
utt <- fread(here::here("7-extract","reextract","utterances_sentence_type.csv"))
```

`phones_chuvash_voice.csv` is 1,424,952 rows, every phone of Chuvash Voice
including **consonants and geminates**, read from the pre-recode TextGrids. Use
it for anything about consonant length; the R levels are vowels only. Two
traps: `duration` is in **milliseconds** here, and `pos_in_word` is the
**phone's** position in the word, so a vowel counts as `initial` only when it
is the word's first segment. For syllable position, index the vowels within
the word. Its phone labels are already translated to the config's IPA via
`ALIGNER_IPA_TO_CONFIG` — if you write your own TextGrid reader, translate
first: the aligner writes ⟨ӗ⟩ as `ɛ` and ⟨е⟩ as `e`, and conflating them cost
me two wrong results.

`utterances_sentence_type.csv` is 47,195 recordings classified by final
punctuation, with `question_subtype` ∈ content / clitic_final / no_marking.

## 10. Results you can read instead of recomputing

`output/` holds about 80 files. The ones most likely to save you a model run:

| file | what |
|---|---|
| `master_rule_comparison.csv` | all rules × all DVs, full data, 499,357 rows |
| `rule_conflict_models.csv` | the same on the 18.9% conflict subset — the informative comparison |
| `default_adjudication.csv` | the A-vs-B test with the utterance edge controlled |
| `final_lengthening_models.csv` | the position effects |
| `coda_sonority_models.csv` | within-word coda and sonority odds |
| `vowels_normalised.csv` | Lobanov-normalised formants, 574,186 × 38 |
| `geminating_stems.csv` | the пулӑ ~ пулли class, with the evidence for each |
| `align_confidence_strata.csv` | per-vowel alignment confidence |
| `results_macros.tex` | 109 `\newcommand` macros — every manuscript number |
| `data_dictionary.csv` | every column of every table, described |
| `SUPERSEDED.md` | **read this first** — every withdrawn or corrected result |

`results_macros.tex` is regenerated by `analyses/make_macros.R`, which reads
from the CSVs, so the manuscript cannot disagree with the tables. Run it last,
after the pipeline and after any analysis that writes to `output/`.
