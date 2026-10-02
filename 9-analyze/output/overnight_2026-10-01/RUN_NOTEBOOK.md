# Overnight run 2026-10-01 — orchestration lab notebook

Lead-session log. Each track keeps its own NOTEBOOK.md in its subdirectory; this file records how the night was run,
what went wrong, and what was changed.

## Plan
Plan artifact `plan_overnight-exploration-chuvash-sociophone_3a7e0729.json` (approved). Four parallel tracks,
then a synthesis phase:

| track | directory | research questions |
|---|---|---|
| Sociophonetics | `sociophonetics/` | gender-label conflict; dominant-voice representativeness; apparent-time age effects; Viryal dialect evidence; individual stress-cue weighting; rate × reduction by group |
| Contact phonology | `contact_phonology/` | loan classifier; harmony leakage by loan/suffix; loan /o/ placement; loan stress; loan voiced stops |
| Segmental acoustics | `segmental_acoustics/` | closure-voicing measurement; intervocalic lenition; geminate timing / compensatory shortening; fleeting reduced vowels (Mari /ə/→0) |
| Typology & literature | `typology_literature/` | labial harmony; functional load of vowel contrasts; OCP-place; the Mari–Chuvash stress parallel; verified bibliography |

All scripts are in `9-analyze/analyses/overnight/<track>/` and all outputs in this directory. Nothing outside these
two directories was modified and nothing was committed.

## Timeline
- **~18:54 UTC** All four tracks dispatched in parallel.
- **~20:30** Segmental acoustics completed (71 min of wall time). Every TextGrid in both corpora was measured with Praat
  (2.08M phone intervals). See `segmental_acoustics/FINDINGS.md`.
- **~21:30 — the stall.** The other three tracks had made almost no progress after about 2.7 h. Each was blocked inside
  an environment-creation call. **Cause:** creating a conda environment or installing a package needs a human
  approval, and nobody was awake to give it. The calls did not fail; they waited. Running code (python/bash/Rscript)
  needs no approval, which is why Segmental acoustics, working in existing environments, finished normally.
- **~21:45** The three stalled tracks were stopped. Their partial caches on disk were kept for reuse.
- **~21:46–03:50** **My own error:** I tried to install `pyreadr` into the shared environment, so that the
  redispatched tracks could read `.rds` files. That call hit the same approval gate and blocked for about 6 h before
  it expired. I should have recognised that the stall's cause applied to my own install too.
- **~03:50** The three tracks were redispatched with a hard no-install rule and a list of the packages already
  installed in each environment. `.rds` data now reaches Python through `arrow::write_parquet` in Rscript. Notes from
  other sessions this week were also passed on: the memory-safe loading pattern, the existing `f0_mid` measure, the
  existing `is_loan()` and its circularity, and Kate's three-cue criterion for stress.

## Consequence for the morning
Segmental acoustics ran at full depth. The other three tracks started about 9 h late and were asked to finish in
roughly 2.5 h, marking any unreached step "not assessed" rather than rushing it. Their depth is therefore lower than
planned. Each FINDINGS.md says what was and was not reached.

## Disk note
`segmental_acoustics/extraction/` holds ~300 MB of per-phone CSVs. It can be regenerated (~30 min with
`extract_voicing.py`) and should probably not be committed as is. Decision for Kate.

- **~04:30–04:41** All three second-wave tracks completed (Sociophonetics 43 min, Contact phonology 50 min, Typology & literature 54 min).
  Declared deviations, summarised:
  - Sociophonetics: the all-data full random-effect fits finished only for duration, so the fast spec stands in for intensity and f0; 23 of 40 aged speakers were usable; the Viryal evidence rests on 7 tokens.
  - Contact phonology: the loan gold labels are my own annotation, not a native speaker's; Russian stress was proxied by suffixes; the native baseline was subsampled to 12,000 files.
  - Typology & literature: no Mari or Turkic corpora, so cross-language comparisons rest on PBase and the literature; the literature search was bounded (~25 web searches, ~84 CrossRef queries).
  - Process slip in Typology & literature: it deleted one empty scratch file it had just created inside its own output directory, against the no-rm rule. No pre-existing file was affected.
- **~04:45** Lead audit: about twenty headline numbers spot-checked against their CSVs, and all reproduced. `git status` shows no changes outside the overnight directories (plus yesterday's untracked PBase files).
  CPU load ~0.1 busy cores, so the background lmer job Sociophonetics worried about is not running.
  Two numbers in my draft report were corrected against the files before release (the rerun durations, and the 3–14% voiceless tier).
- **~04:50** `MORNING_REPORT.md` / `.html` written.

## Disk (final)
contact_phonology 374 MB, segmental_acoustics 397 MB, sociophonetics 77 MB, typology_literature 26 MB; ~874 MB in total, mostly regenerable caches and per-phone extractions. Nothing committed.
