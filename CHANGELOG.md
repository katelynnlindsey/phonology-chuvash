# Changelog

Notable changes to the analysis pipeline and to the assumptions it encodes.
Entries that change reported numbers are marked **[affects results]**.

## 2026-09-25

### Repository made runnable from a fresh clone

- `analyses/00_session_setup.R` resolved four of its six data files against
  `data/cleaned/` when they live in `data/leveled/`, so it failed on the first
  one. `.load()` now takes an explicit `dir` argument.
- Added `pipeline/run_pipeline.R`, the orchestrator `00_session_setup.R` was
  already telling users to run but which did not exist. Runs stages 1–4 with
  `from`/`to`/`stages` arguments, sources each stage into its own environment so
  no stage can inherit state from the previous one, and writes a provenance
  record to `data/run_log/` (git SHA, dirty-tree flag, `ACTIVE_RULE`, cleaning
  thresholds, per-stage timings, output file sizes, `sessionInfo()`).
- Renamed five scripts from `.r` to `.R`. Every `source()` call already asked
  for `.R`, which works on macOS and Windows but fails on Linux — including the
  Binder build advertised in the README. Project convention is now `.R` only.
- `stress_rule_comparison.R` depended on `PATHS` already existing in the global
  environment; it now sources its own config.
- `.Rproj`: `RestoreWorkspace`, `SaveWorkspace`, `AlwaysSaveHistory` set to
  `No`. A committed 795 KB `.RData` was auto-loading a stale global environment
  on project open.
- `.gitignore` rewritten with forward slashes — the previous Windows-backslash
  rules matched nothing — and extended to cover R session state, OS cruft, the
  3.2 GB of stage-7/8 extraction outputs, and the re-downloadable parquets.
- Untracked 15 files (`.RData`, `.Rhistory`, `.DS_Store`, `.Rapp.history`) with
  `git rm --cached`; all remain on disk.

### Intensity measure resolved **[affects results]**

Added `analyses/intensity_measure_comparison.R`, which fits all nine candidate
stress rules against six dependent variables (54 mixed-effects models, one row
set of 287,418 vowels so AIC is comparable within each DV).

Findings, with outputs in `9-analyze/output/`:

- `intensity_step1`–`20` code Praat "undefined" as literal `0.0` for 71% of
  cells. The zeros are already present in
  `7-extract/contours/*/contours_output.csv`, so they originate in stage 7, not
  in the R pipeline. The pattern is symmetric about the vowel midpoint (steps
  1, 2, 19, 20 are zero for every vowel; steps 10 and 11 never are), which is
  the signature of Praat's intensity analysis window. 42% of vowels have only
  two valid readings. `f0_step1`–`20` are unaffected.
- The valid-step count correlates with duration at r = 0.93, so any measure
  computed over "the valid steps" has duration built into it.
- **`total_intensity` must not be used.** It is the sum of all 20 steps
  including zeros, and correlates with duration at r = 0.909 and with the
  valid-step count at r = 0.985. It is a duration measure. It also reproduces
  the duration-based rule ranking exactly.
- **`peak_intensity` should not be used.** It is a maximum over a variable
  number of samples, so it is biased upward for long vowels: the gap between
  peak and midpoint intensity grows from 0 to 5.02 dB as valid steps go from 2
  to 16, and stressed vowels average 6.9 valid steps against 4.8 for
  unstressed.
- The `intensity` column (new-FAVE, `point_heuristic="fave"`) is measured at
  ~13.8% of vowel duration (5th–95th percentile 12.3–14.9%, 0% at the
  midpoint) — on the onset ramp, not the steady state.
- **Adopted measure: the mean of `intensity_step10` and `intensity_step11`**
  (vowel midpoint). Always exactly two samples at the same relative position,
  available for 100% of rows, no duration confound by construction.

Consequences for the manuscript:

- The draft's two figures for the stress effect on intensity — "+3.2 dB" and
  "162 dB" — are both wrong. The midpoint-intensity effect is **+0.44 dB**
  (SE 0.016), far below the 3 dB just-noticeable difference cited from Moore
  (2007). Intensity is statistically overwhelming and perceptually negligible.
- The rule ranking depends on which correlate is used. All four legitimate
  intensity measures rank **A6** best; `log_duration` ranks **B5** best
  (ΔAIC from A5 = 788.9).
- In polysyllabic all-reduced words (5,339 word tokens, 11,305 vowels) the
  initial syllable is +0.61 dB louder but 2.3 ms *shorter* and 1.6 Hz lower.
  This replicates Dobrovolsky (1999) — reduced vowels distinguished by
  amplitude, not duration — and explains why intensity favours rule A while
  duration favours rule B. Both differences are below their JNDs.

### Known non-obvious hazards

- This project's R sessions may run under a non-UTF-8 native encoding, in which
  typed IPA literals (`c("ø","ɵ")`) do **not** compare equal to stored
  `vowel_label` values and silently match nothing. Filter on the ASCII
  `vowel_cat_*` columns instead.
- `config/phonology_params.R`: `.max_onset_size()` returns 1 for any non-empty
  cluster and ignores its `sonority` argument, so onset maximization is not
  implemented and `IPA_SONORITY` is dead code. Unresolved as of this entry.
