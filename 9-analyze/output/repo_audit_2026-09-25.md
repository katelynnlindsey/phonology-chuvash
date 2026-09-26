# `phonology-chuvash` — reproducibility and consistency audit

Read-only review of the repository at `~/Documents/GitHub/phonology-chuvash`,
25 Sep 2026, against the current LaTeX draft. Nothing in the repo was modified.

Scope: `9-analyze/config/`, `9-analyze/pipeline/`, `9-analyze/analyses/`, the
directory layout of stages 1–8, git hygiene, and the draft's Methods and Results
sections. Not reviewed: the Python stages (2-load … 8-combine) beyond their file
layout, the forced-alignment output quality, `01_load_raw.R` and `03_build_levels.r`
in full.

---

## Summary

The design of this pipeline is sound and, in places, unusually careful. The
things that would embarrass you in review are not design failures — they are
five bugs that make the repo non-runnable as committed, several places where the
prose describes something the code does not do, and a draft whose numbers come
from an older run of the pipeline than the one that produced the current data.

Findings are ordered by how much they threaten a claim in the paper.

---

## 1. Blocking: the repo cannot be run start-to-finish as committed

> **STATUS: fixed 25 Sep 2026, staged but not committed.** All five items below
> were repaired in the working tree and verified (config sources cleanly, all
> eight `.rds` targets resolve, all seven scripts parse). See "Changes made" at
> the end of this document. Sections 2–5 are still open.

### 1.1 `00_session_setup.r` loads six files from the wrong directory

`analyses/00_session_setup.r` (lines 41–55) resolves every file against
`PATHS$cleaned_dir`. Four of the six live in `leveled/`:

| object loaded | script looks in | file actually in |
|---|---|---|
| `vowels_spoken_annotated` | `cleaned/` | `leveled/` |
| `syllables_spoken` | `cleaned/` | `leveled/` |
| `words_spoken_annotated` | `cleaned/` | `leveled/` |
| `phrases_spoken` | `cleaned/` | `leveled/` |
| `zheltov_clean` | `cleaned/` | `cleaned/` ✓ |
| `mono_clean` | `cleaned/` | `cleaned/` ✓ |

The script `stop()`s on the first one. So the file whose header says "SOURCE THIS
AT THE START OF EVERY ANALYSIS SCRIPT" currently cannot be sourced.

### 1.2 `run_pipeline.R` does not exist

`00_session_setup.r:45` directs the user to "Run `pipeline/run_pipeline.R` first."
`pipeline/` contains only `01_load_raw.R`, `02_clean.r`, `03_build_levels.r`,
`04_annotate.R`. There is no orchestration script, so the run order and the
"which stage do I re-run after changing X" question live only in your head.

### 1.3 Filename case will break on Linux, including your own Binder badge

Files on disk are `config/paths.r`, `config/phonology_params.r`,
`pipeline/02_clean.r`, `pipeline/03_build_levels.r`, `analyses/00_session_setup.r`
(lowercase `.r`); the rest are `.R`. Every `source()` call asks for `.R`:

```r
source(here::here("9-analyze", "config", "phonology_params.R"))   # file is .r
source(here::here("9-analyze", "config", "paths.R"))              # file is .r
```

This works on macOS and Windows (case-insensitive filesystems) and fails on
Linux. Your `README.md` advertises a Binder badge, which builds on Linux — so the
one-click reproducibility path in the README is currently broken. Pick one
extension, rename, and update the `source()` calls.

### 1.4 `stress_rule_comparison.R` is not self-contained

It uses `PATHS$leveled_dir` but has zero `source()` calls; it only runs if
something else defined `PATHS` first. Every other script in `pipeline/` sources
its config. Add the two `source()` lines.

### 1.5 A stale `.RData` is tracked and will auto-load

`.RData` (795 KB) and `.Rhistory` (20 KB) are committed at the repo root, and
`phonology-chuvash.Rproj` has `RestoreWorkspace: Default`. Opening the project
silently repopulates the global environment with objects from a September 23
session. If a script has a typo'd or renamed variable, it may resolve against a
stale object instead of erroring — and the result will differ between your
machine and a fresh clone. Set `RestoreWorkspace: No` and `SaveWorkspace: No`,
`git rm --cached .RData .Rhistory`, and add them to `.gitignore`.

Related: 15 `.DS_Store` / `.Rhistory` / `.Rapp.history` files are tracked. The
`.gitignore` uses Windows backslashes (`corpora\textgrids_commonvoice\*.mp3`);
git only treats `/` as a separator, so those three rules match nothing.

---

## 2. The code does not do what the prose says it does

### 2.1 Syllabification: onset maximisation is not implemented

This is the finding with the widest downstream reach, because `syllable_coda`
(open/closed) is a fixed effect in every acoustic model, the basis of the
`weight` candidate rule, and the evidence for the minimal-word claim in §3.2 of
the draft.

`config/phonology_params.r` defines:

```r
.max_onset_size <- function(cluster, sonority = IPA_SONORITY) {
  if (length(cluster) == 0L) 0L else 1L
}
```

The body ignores `sonority` and returns 1 for any non-empty cluster: exactly one
consonant goes to the onset, always. Consequences:

- The 60-line `IPA_SONORITY` table is dead code. Nothing reads it.
- The docstring directly above `syllabify_ipa()` claims "onset maximisation: the
  longest strictly-rising-sonority suffix … goes to the following onset," and
  its own worked examples are wrong under the shipped implementation:

  | input | docstring claims | code actually returns |
  |---|---|---|
  | `kastrul` | `kas.trul` | `kast.rul` |
  | `antrop` | `an.trop` | `ant.rop` |
  | `pɑrni` | `pɑr.ni` | `pɑr.ni` ✓ |

- The draft's Methods says syllables were built "according to onset maximization
  and sonority-sequencing principles." As written, that sentence is not accurate.

**How much does this actually matter?** Less than it sounds, for native
vocabulary: Chuvash does not permit complex onsets, so "one consonant to the
onset" gives the correct V.CV and VC.CV parses that cover almost everything. The
divergence only appears in medial clusters of three or more consonants. But you
currently do not know how many of those there are, and the claim in Methods is
unsupported either way. Two honest options: (a) quantify the 3+-cluster rate,
and if it is negligible, rewrite Methods to describe what the code does — "the
rightmost consonant of each medial cluster is assigned to the following onset" —
and delete `IPA_SONORITY`; or (b) implement the documented algorithm and re-run
from stage 3. Option (a) is defensible and much cheaper.

### 2.2 `ACTIVE_RULE` does not propagate everywhere

`config/phonology_params.r` states: "Edit this file to change phonological
assumptions… A change here propagates everywhere without touching analysis code."
It mostly does, but `04_annotate.R:228–231` hardcodes rule A:

```r
duration_matches_stress  = (longest_sidx  == stressed_sidx_A),
intensity_matches_stress = (loudest_sidx  == stressed_sidx_A)
```

Setting `ACTIVE_RULE <- "B"` leaves these two columns silently computed under A.
`stress_rule_comparison.R` is right to drop both as circular — but the file-level
promise is not currently true, and that is the kind of thing that bites six
months from now.

### 2.3 Three incompatible naming schemes for the same rules

The same objects are called different things in three places:

| config `VOWEL_RULES` | `stress_rule_comparison.R` | draft Table `tab:stress-rules` |
|---|---|---|
| `A` (ʉ strong, 6 full) | `A6` / `B6` | `A` / `D` |
| `B` (ʉ weak, 5 full) | `A5` / `B5` | `B` / `E` |
| `C` (y, ʉ weak, 4 full) | `A4` / `B4` | `C` / `F` |

To make it worse, the draft contains **two different tables both labelled
`tab:stress-rules`** — one with two rules (A, B) in §"Acoustics of stress" and
one with six (A–F) in §"Reanalysis of stress". LaTeX will resolve every
`\ref{tab:stress-rules}` to whichever comes last. `tab:harmony` is likewise used
twice (once on an empty gemination table, once on the vowel-harmony table).

Pick one naming scheme — I'd suggest the `A6/A5/A4/B6/B5/B4` form, since it makes
the two independent dimensions (default-to-opposite vs. stressless × which vowel
inventory) legible at a glance — and use it in config, code, and manuscript.

### 2.4 Latent trap: `classify_vowel()` is inconsistent on Cyrillic input

`VOWEL_CATEGORY_RULES` lists both Cyrillic and IPA symbols, but coverage differs
across rules:

| symbol | rule A | rule B | rule C |
|---|---|---|---|
| `ы` (Cyrillic) | **NA** | R | R |
| `э` | NA | NA | NA |
| `ĕ`, `ă` (Latin+breve, produced by `VOWEL_TO_IPA`) | NA | NA | NA |

**This is not currently biting you.** Every call site passes `vowel_label`, which
is IPA, and all eight IPA vowels are classified consistently under all three
rules. But the function's own docstring says it "classifies individual vowel
characters in Cyrillic/Latin orthography," so the next person to use it as
documented gets a silent asymmetry in exactly the A-vs-B comparison the paper
turns on. Either delete the orthographic entries or complete them.

---

## 3. One design issue in the stress-rule comparison

`analyses/stress_rule_comparison.R` is the strongest file in the repo — it drops
`phon_stress`, `stress_cat`, `duration_matches_stress` and
`intensity_matches_stress` on explicit circularity grounds, it validates the
reconstructed lookup against the pre-existing columns before trusting it, it
handles the Rule-B `NA` correctly so the B models are fit on the same rows (so
AIC really is comparable across all nine), and it uses `REML = FALSE`, which is
required for AIC comparison of models differing in fixed effects. That is all
correct and most people get at least one of those wrong.

The problem is in how the evidence is combined.

**`detected_accuracy` and the AIC ranks are not independent evidence.** Section 6
defines `detected_sidx` as the majority vote of the longest syllable, the loudest
syllable, and the largest-|f0 slope| syllable. Section 5 fits models whose
dependent variables are `log_duration` and `peak_intensity`. The master table
then scores each rule on both and the reading guide treats agreement between them
as convergence:

> the best-supported rule ranks high on detected_accuracy, has low
> duration_rank/intensity_rank … and shows significant, positive coda attraction

A rule that predicts the longest-and-loudest syllable will necessarily explain
duration and intensity well. These are one line of evidence measured twice, and
presenting them as two overstates the support. Worse, `detected_sidx` has no
controls, while the models control for `phrase_position`, `z_rel_phrase_position`
and `z_log_speech_rate` — so phrase-final lengthening and declination inflate
`detected_accuracy` for the `final` rule specifically. Your own comment
anticipates this, but `detected_accuracy` is still the primary sort key of
`master_comparison`.

The genuinely independent evidence is the phonological side: coda attraction and
inventory entropy, computed on Zheltov and mono, which never touch the acoustics.
That is the part that can adjudicate A-vs-B, and right now it is the thinnest
part of the script (a `glm` with `sN` as the only control, and entropy reported
descriptively with no test). If the paper's central claim is that Rule E/B5 wins,
the weight should rest there. Two suggestions:

- Demote `detected_accuracy` to a descriptive column; sort the master table by
  the AIC ranks, and say in the caption that the two are not independent.
- Strengthen the phonological side, where the independent leverage is. Candidates:
  the minimal-word asymmetry you already document in §3.2 of the draft
  (`/ø ɵ ʉ/` require a coda) is a direct test of the 6-vs-5-vs-4 split and does
  not use acoustics at all; likewise the non-initial `/ʉ/` distribution.

---

## 4. Reporting integrity: the draft's numbers are from an older run

The draft reports counts that no current file produces:

| draft says | current pipeline |
|---|---|
| 615,634 vowels extracted; 591,305 after loanword exclusion | — |
| N = 350,872 vowels (full model dataset) | `vowels_spoken_annotated.rds` header count: 287,418 rows |
| n = 11,711 (conflict subset) | not reproduced by the current script |
| `Num. obs. = 316,418`, `Num. groups: word = 17,739`, `speaker_id = 108` | script uses `file_name` as the random effect, not `speaker_id`, because `speaker_id` is ~1 distinct value and ~30% missing |
| 388,502 vowels in the Fig. `fig:vowels` text | 387,436 in the same figure's caption |

The `speaker_id` point is the serious one. The regression table in the draft
reports `Num. groups: speaker_id = 108` and a speaker random-effect variance,
but your own script header documents that `speaker_id` is mostly unfilled and
switches to `file_name`. Those two facts cannot both describe the same analysis.
A reviewer who asks "how many speakers?" needs one answer, and if the real answer
is that speaker identity is largely unrecoverable from these corpora, that is a
limitation to state plainly rather than a number to report.

### 4.1 The intensity effect size is reported in the wrong units, two ways

The draft gives two incompatible values for the same effect:

- §"Acoustics of stress": stressed vowels are "more intense (β = +3.2 dB, SE = 0.05)"
- §"Reanalysis of stress" + Table `tab:lmer_results`: `stress_rule_EStressed` on
  `Amp(Full)` = `161.90`, described in prose as "162 dB more intense in total
  amplitude"

161.90 is not decibels. It is the coefficient on your "total intensity" variable,
defined in the draft as the *sum of intensity measurements at 20 steps*. Summing
20 dB values is not a physical quantity — decibels are logarithmic, so their sum
does not correspond to energy, loudness, or anything else interpretable, and it
is not convertible to dB by any constant. (Energy would require converting each
step to linear intensity, integrating over the vowel, and converting back; that
quantity is largely redundant with duration × mean intensity, which may be why
you also have a 3.2 dB figure from somewhere else.)

Separately, the current script uses `peak_intensity` as the DV, not a 20-step sum
at all — so neither draft number is what the code now computes.

This needs resolving before submission: pick one intensity measure, define it in
Methods, and report it in real units. Mean or median intensity in dB is the
conventional and defensible choice, and it makes the 3 dB just-noticeable-
difference threshold you cite from Moore (2007) directly applicable.

---

## 5. Smaller items in the draft

- **Zheltov year.** `config/phonology_params.r` calls it the "Zheltov (1875)
  wordlist"; the draft cites `Zheltov2008` (31,403 words, modern literary
  Chuvash, 26 sources). One of these is wrong; the config comment looks like the
  error.
- **Backness features disagree.** Config has `VOWEL_BACKNESS` with
  `central = c("a")` and `back = c("u","ɵ","ʉ")`. The draft's §"General vowel
  acoustics" says central = `/ʉ ɵ a/` and back = `/u/`, and Table `tab:vowels`
  groups them a third way. These should be one statement.
- **Two gloss/transcription mismatches.** `кимĕ` is glossed 'chick' and
  transcribed `/t͡ɕøpø/` — but `кимĕ` is 'boat' (`/kimø/`); `/t͡ɕøpø/` is `чĕпĕ`.
  Separately `сула` is given for `/laʃa/` 'horse', which is `лаша`.
- **Table `tab:min` is mangled.** The header row contains a bare `%` mid-line
  (`Vowel & Open %& Closed`), which comments out the rest of that line; the
  column spec declares 7 columns for a 6-column table. It compiles but does not
  render what you intend.
- **`tab:harmony` is attached to an empty table** in §"Distribution of high and
  central vowels" before being reused for the real harmony table.

---

## Suggested order of work

1. Fix §1 (five blocking bugs). Half a day; makes the repo runnable by someone
   who is not you, which is the whole point of the folder structure you built.
2. Resolve the intensity measure (§4.1) and settle the `speaker_id` question
   (§4). These change reported results, so everything downstream waits on them.
3. Decide (a) or (b) on syllabification (§2.1) and make Methods match.
4. Unify rule naming across config, code, and manuscript (§2.3).
5. Restructure the evidence combination in `stress_rule_comparison.R` (§3).
6. Regenerate every number in the draft from the current data rather than
   typing it (see accompanying note on parameterised reporting).

---

## Changes made (§1 only) — staged, not committed

Nothing was deleted; no data file was touched; `data/leveled/` (10 files) and
`data/cleaned/` (6 files) are unchanged.

**Renamed for Linux case-sensitivity** (via `git mv`, so history follows):

```
9-analyze/config/paths.r            -> paths.R
9-analyze/config/phonology_params.r -> phonology_params.R
9-analyze/pipeline/02_clean.r       -> 02_clean.R
9-analyze/pipeline/03_build_levels.r-> 03_build_levels.R
9-analyze/analyses/00_session_setup.r -> 00_session_setup.R
```

Every `source()` call in the project already asked for `.R`, so no call sites
needed changing — verified by grep across all `.R`/`.py`/`.sh` files. No
lowercase `.r` files remain.

**`analyses/00_session_setup.R`**
- `.load()` now takes an explicit `dir` argument (`"loaded"`/`"cleaned"`/
  `"leveled"`) instead of hardcoding `cleaned_dir`, and validates it with
  `stopifnot()`. The four spoken objects load from `leveled/`; the two written
  clean objects from `cleaned/`.
- Added `zheltov_ann` and `mono_ann` (the syllable-level annotated written
  data from `leveled/`). These are what the rule-comparison analyses need;
  `zheltov`/`mono` keep their previous word-level meaning, so no existing
  script changes behaviour.
- The two `source()` calls now use `here::here()` rather than paths relative
  to `9-analyze/`, so the script works from any working directory.
- Header documents the `.R`-not-`.r` convention and why.

**`analyses/stress_rule_comparison.R`**
- Added the two `source()` calls for config. It previously depended on `PATHS`
  already existing in the global environment.

**`pipeline/run_pipeline.R`** — new file, the orchestrator that
`00_session_setup.R` was already telling users to run. Provides:
- `run_pipeline()`, `run_pipeline(from = 3)`, `run_pipeline(stages = 4)`,
  `run_pipeline(from = 2, to = 3)`, with argument validation.
- Each stage sourced into `local = new.env()`, so no stage can silently
  inherit an object left behind by the one before it.
- A header table mapping "what you changed" to "which stage to re-run from"
  (e.g. editing `VOWEL_RULES` or `ACTIVE_RULE` -> `from = 4`; editing
  `syllabify_ipa()` -> `from = 3`).
- Per-run provenance log in `9-analyze/data/run_log/run_<timestamp>.txt`
  recording git SHA, whether the tree was dirty, `ACTIVE_RULE` and the
  strong/weak inventories, every `CLEANING` threshold, per-stage timings, the
  size and mtime of every output file, and `sessionInfo()` with package
  versions. Warns loudly if the tree is dirty, since such a run cannot be
  reproduced from its recorded SHA.

  These logs are intentionally *not* gitignored — they are the audit trail that
  ties a number in the manuscript to the run that produced it.

**`phonology-chuvash.Rproj`** — `RestoreWorkspace`, `SaveWorkspace` and
`AlwaysSaveHistory` changed from `Default` to `No`.

**`.gitignore`** — rewritten with forward slashes (the three backslash rules
matched nothing), and now covers `.RData`, `.Rhistory`, `.Rapp.history`,
`.Rproj.user/`, `.DS_Store`, audio, and the re-downloadable parquet files.

**Untracked, kept on disk** — 15 files via `git rm --cached` (10 `.DS_Store`,
3 `.Rhistory`, `.RData`, `.Rapp.history`). All still present in the working
tree; all now ignored.

### Verification performed

| check | result |
|---|---|
| config sources after renames | OK |
| all 8 `.rds` targets resolve | TRUE |
| all 7 project scripts parse | pass |
| `run_pipeline()` defined, stage order correct | pass |
| argument validation rejects `from=3,to=1` and `stages=9` | pass |
| files untracked but still on disk | 15/15 present |

Not verified: an end-to-end `run_pipeline()` execution (stage 1 re-reads the
full 27 GB of raw corpora), and the git-SHA capture, which returns `NA` in the
sandbox because git there cannot read `~/.gitconfig`. Both should be confirmed
with one `run_pipeline(stages = 4)` in RStudio — that stage is the cheapest and
will exercise the log writer and the SHA capture on your machine.

### To commit

```
git add 9-analyze/pipeline/run_pipeline.R
git commit -m "Fix blocking pipeline bugs: loader dirs, .R casing, orchestrator, session hygiene"
```

---

# Resolution — §§2–5, 2026-09-25

All ten planned steps complete. Commits `ac117a3114` … `afe0c6ed4a`.
Full narrative in `CHANGELOG.md`; numbers in `9-analyze/output/`.

## Status of the original findings

| § | finding | status |
|---|---|---|
| 1.1 | `00_session_setup.R` wrong load directory | fixed |
| 1.2 | `run_pipeline.R` missing | written, with per-run provenance log |
| 1.3 | `.R`/`.r` casing breaks on Linux | all renamed to `.R` |
| 1.4 | `stress_rule_comparison.R` not self-contained | sources its own config |
| 1.5 | stale `.RData` auto-loading | untracked, `.Rproj` set to `No` |
| 2.1 | onset maximization not implemented | **documentation error, not code error** — quantified at 20–26% divergence; the documented algorithm is wrong for Chuvash. Methods prose replaced |
| 2.2 | `ACTIVE_RULE` doesn't propagate | the two offending columns removed as circular |
| 2.3 | three naming schemes | unified on `A6 A5 A4 B6 B5 B4`; migration table saved |
| 2.4 | `classify_vowel` Cyrillic inconsistency | unreachable entries deleted; keyed by inventory |
| 3 | evidence combination circular | restructured into separate inventory and default questions |
| 4 | manuscript numbers stale | 54 macros + 33-row mapping table |
| 4.1 | intensity reported in wrong units | resolved: `int_midpoint`, 0.40 dB |
| 5 | smaller draft items | `manuscript_fixes.md` |

## Additional defects found while fixing the above

None of these were in the original audit. Each changed reported numbers.

1. **`/tɕ/` was not a digraph.** `CONSONANT_TO_IPA` maps ⟨ч⟩ to `tɕ`, absent
   from `IPA_DIGRAPHS`, so the affricate was split across syllable boundaries.
   8,529 vowel rows (2.97%) were marked `closed` with half an affricate as the
   coda. `syllable_coda` changed for 2,864 rows.
2. **The contour joins used a non-unique key.** `(file_name, sidx, sN)`
   identified only 335,500 of 703,582 point rows. Replaced with an interval
   join, verified 1:1. Reproduces the draft's 615,634.
3. **`word_id` collided across different words**, because it was built from
   `widx`, which is *inferred* by string-matching and collides on 1.25% of
   word tokens. Now built from `dense_rank(word_start)`.
4. **`loudest_sidx` came from `total_intensity`**, a duration measure, so the
   three-way bottom-up vote was duration counted twice — agreement with
   `longest_sidx` was 0.863, now 0.458.
5. **Speaker ids were being discarded, not missing.** `01_load_raw.R` selected
   five columns from the Common Voice TSV and dropped `client_id` and
   `speaker_id`. Recovered: 105 talkers, 93.7% of vowels.
6. **The monolingual corpus contains vowel-stripped non-words** (`/jtmrø/`,
   `/ʋkɕø/`) that the syllabifier reads as open monosyllables, putting /ø/ at
   28.1% open — the highest of any vowel, against the wordlist's 0 of 90.

## Verification performed

| check | result |
|---|---|
| all 13 scripts parse | pass |
| `00_session_setup.R` from `--vanilla`, no `.RData` | pass, 11 objects |
| `(file_name, time)` unique | pass |
| `(word_id, sidx)` unique | pass |
| one `word_label` per `word_id` | pass |
| `duration` == `(end − start)` | 100.000% (was 98.70%) |
| no `NA` in the six `stress_rule_*` columns | pass |
| `vowel_class` populated | 212,061 full / 68,894 reduced |
| no `.RData`/`.Rhistory`/`.DS_Store` tracked | pass |
| provenance logs written | 5 runs |

## Open items, in priority order

1. **12.50% of FAVE vowel points match no contour interval**, and the rate is
   lopsided — 15.50% in Chuvash Voice against 1.23% in Common Voice. That
   asymmetry points at the two extractions for Chuvash Voice having used
   different TextGrids. 86,129 vowels of that corpus are currently dropped.
   Worth tracking down; it is the single largest recoverable data loss.
2. **Step 06 of cleaning drops 45–47% of vowels** — 162,689 from Chuvash Voice
   and 55,273 from Common Voice — because a polysyllabic word is excluded
   entirely if any one of its vowels failed an earlier filter. This is by far
   the largest filter, and it is a *cascading* one: the IQR step (step 05)
   removes 20% of vowels, and each of those can take a whole word with it.
   Worth checking whether word-level exclusion is necessary for every analysis
   or only those needing complete words.
3. **Pitch floor and ceiling are still unspecified** (`[specify]` in the
   draft's Table 2). These determine Praat's intensity analysis window and
   therefore the undefined-step problem, so the value is needed both for
   Methods and to decide whether re-extraction would fix the 20-step contours.
4. **The written corpora don't carry `stress_rule_*` columns** —
   `04_annotate.R` applies the rules only to spoken data, so
   `stress_rule_comparison.R` derives them locally. Worth moving into the
   pipeline so every corpus carries the same columns.
5. **`widx` collides on 1.25% of word tokens**, which `phrase_position` and
   `rel_phrase_position` inherit. Both are model predictors.
6. **The `weight` rule's fallback is arbitrary** — all-open-syllable words
   fall back to final stress. Undetermined by the brief; documented in the
   script but not justified.
