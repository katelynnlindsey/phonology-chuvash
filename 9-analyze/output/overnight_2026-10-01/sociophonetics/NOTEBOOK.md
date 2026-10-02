# Sociophonetics — lab notebook (overnight 2026-10-01)

## 23:40 Setup
- Loaded skill chuvash-corpus-pipeline; read README_loading_data.md, data_dictionary.csv (grep), SUPERSEDED.md (grep), segmental_acoustics/FINDINGS.md.
- Reused the stalled first attempt's cache `cache/vowels_socio.parquet` (574,344 × 60, written by `00_extract.R`); verified rows = 574,344,
  CV 133,576 rows / 109 speakers (100% matched to TSV client_id), CH 440,768 rows / 11 voice clusters.
- Lead's notes taken on board: do not source 00_session_setup.R; f0 measure = f0_mid (mean of f0_step10/11) in semitones re speaker median
  (analyses/f0_measure.R; it saves only diagnostics/distributions, no per-vowel table, so recomputed here from the steps);
  Kate's stress criterion = longer + louder + higher together; fast intensity models = int_midpoint centred within file + (1|word_label).
- `01_extract_f0.R`: exported word_id, sidx, start, f0_step10, f0_step11 → cache/f0_steps.parquet (key unique: 0 duplicates).

## 23:50 Step 1 — speakers and the gender label
- Built speaker table (s1_speaker_table.csv). CV gender metadata: 30 M / 10 F / 69 NA; age for 40.
- ΔF (uniform-tube LS fit over F1–F3), vowel-balanced over a e i u (≥3 tokens each, iqr_outlier_any excluded).
- First tried a logistic regression of metadata gender on ΔF: P(female | voice_main) ≈ 0.56. **Not used.** Two CV 'male' speakers with ΔF 604/725 Hz
  (tracking failures) flatten the slope. Replaced with rank/percentile comparisons and robust (median/MAD) likelihood ratios. Logged both.
- Checked chuvash-fave.py for a gender-dependent formant ceiling: none (speakers="all").
- Result: voice_main ΔF 1221 Hz > all 25 CV metadata males, > all 41 CV low-f0 speakers, > all 4 CH low-f0 clusters (948–1047).

## 00:00 Step 2 setup (models launched in background)
- cache/model_data.parquet: added f0_mid/f0_st (screening as analyses/f0_measure.R but normalised per `spk`, i.e. per CH voice cluster rather than one CH speaker),
  z_freq/z_rate/z_relpos as in analyses/intensity_measure_comparison.R. f0_ok: CH 99.4%, CV 94.1%.
- s2_representativeness_models.R (full spec: (1|word_label)+(1|file_name)+(1|spk)) launched for all / no_vm / cv_only.
  cv_only and no_vm finished in ~5 and ~20 min. `all` (574k rows) ran at 385 s for its first model, and the machine is shared (load ≈ 14 on 10 cores).
- Descriptives: per-vowel Lobanov means by subset (s2_vowel_means_by_subset.csv); per-speaker full/reduced duration ratio (s2_full_reduced_ratio_by_speaker.csv).

## 00:05 Step 3 — age
- Only 23 CV speakers have age plus all six core vowels (≥5 tokens, ≥100 clean), and 14 also have ⟨ы⟩. Ran a relaxed rule (≥3, ≥50) as sensitivity.
- First pass masked measures with a `.loc[...].assign` trick that turned the columns into object dtype. Caught when `.round` failed; redone with to_numeric. No numbers were affected.
- Token-count confound checked (teens contribute ~10× more vowels).

## 00:08 Step 4 — Viryal
- web_search found Savelyev 2020 (iling-ran PDF). DOI 10.1093/oso/9780198804628.003.0028 verified via api.crossref.org.
- cv_60 = 'Верхний': 12 files in leveled data (not 13), 53 vowels, 7 clean /u/.
- Dead end: `u_open_share` (share of /u/ tokens with F1 above the speaker's /e/ mean) is meaningless here because CV /u/ and /e/ have nearly equal mean Lobanov F1 (−0.68 vs −0.62). Dropped.
- Noticed that the IQR outlier filter removes 2 of the 9 /u/ tokens, one of them very open (ун, 533 Hz). Logged as a caveat.

## 00:10 Step 5 — cue weighting (s5_cue_weighting.py)
- Checked Praat pitch range (100–800 Hz) to rule out ceiling clipping as the cause of the small f0 slopes in high voices.

## 00:12 Step 6 — rate (s6_rate_compression.py)
- statsmodels warned about rank deficiency (vowel_label aliases `reduced`). Verified on two speakers that the rate_c and rate_c:reduced estimates are identical without the reduced main effect.
- Found that pipeline `speech_rate` = surviving vowels / whole clip duration (03_build_levels.R:360), which includes edge silence. Added `log_span_rate` and ran both.

## 00:17 Fast-spec models
- The full-spec `all` fit is slow on the loaded machine, so launched s2b_fast_models.R: file-centred DV + (1|word_label), as the lead advised, for all / no_vm / cv_only / vm_only.

## 00:25 Step 2 results and write-up
- The fast spec finished for all four subsets. The full spec finished for no_vm and cv_only; for `all` only 2 of 9 models finished (B5 dur 0.1719, A6 dur 0.1476), and they agree with the fast spec.
- Main result: the f0 stress effect is 0.18–0.20 st pooled, 0.55–0.61 st without voice_main, and 0.04–0.08 st in voice_main. Duration is invariant across subsets.
- Corrections before writing: (i) the claimed fast/full agreement was first written as '0.002 log / 0.03 dB'. Recomputing gave 0.006 log, 0.016 dB for stress terms, 0.19 dB for the reduced term and 0.033 st, and the text was fixed.
  (ii) 'within 0.15 SD of voice_main' was recomputed as 0.171 and fixed. (iii) The B5 three-cue count denominator is 71, not 74, and was fixed.
- Figures: s1_vtl_vs_f0, s2_headline_effects_by_subset, s2_vowel_space_voice_main_vs_cv, s5_stress_cue_slopes_by_voice. Overlaps were fixed by rendering and viewing the crops. In s5, the first draft clipped y-limits to the 2–98% range, which hid points; it was redone with the full range.

## 00:35 Wrap-up
- The full-spec `all` job (s2_representativeness_models.R all) had finished 3 of 9 models (all duration) when the session ended. It **could not be stopped** from the sandbox (`ps`/`pkill` are not permitted),
  so it keeps running in the background and appends to `s2_models_all.csv` in this directory. Rows it adds later are not reported in FINDINGS.
- `s6_rate_compression_summary.csv` and `s6_speaker_rate_slopes.csv` are from the first run, with the pipeline rate. They are identical to the `_log_speech_rate` versions and superseded by the suffixed files. I could not delete them (no rm in repo).
- The step 1–4 descriptive code (speaker table, ΔF/F3 benchmark, Lobanov means, speaker-level measures, age models, Viryal screen) and the figure code ran in the session's Python kernel.
  Their lineage is attached to the saved artifacts. Standalone scripts exist for the extraction (00, 01), the models (s2, s2b), step 5 (s5_cue_weighting.py) and step 6 (s6_rate_compression.py).
