# Broadcast-likeness score — lab notebook (2026-10-02)

Scripts: `9-analyze/analyses/speaker_cues/broadcast_score/`. Outputs: this directory. Chronological.

## Orientation
- Loaded skill chuvash-corpus-pipeline (int_midpoint only; durations in ms; widx/sidx have gaps from cleaning).
- Reused overnight caches, read-only: `sociophonetics/cache/vowels_socio.parquet` (574,344 vowels, `spk` key),
  `cache/model_data.parquet` (f0_st = f0_mid in st re `spk` median, octave/step-disagreement screened; row-aligned
  with vowels_socio: file_name, sidx, int_midpoint identical in 100% of rows), `cache/f0_steps.parquet` (raw steps 10/11,
  NOT row-aligned -> merged on word_id+sidx+start), `segmental_acoustics/vowel_tokens.csv.gz` (803,733 grid vowels,
  Praat AC voicing), `segmental_acoustics/file_alignment_qc.csv` (per-file full-vowel voiced fraction, qc_pass),
  `output/speaker_structure.csv` (CH per-file HNR).
- Data structure facts checked: every file is ONE phrase (phrase_start/phrase_end constant per file), so internal pauses
  must be derived from word timing. `widx` = original word index (1..wN, gaps where cleaning dropped words);
  `word_token_idx` = consecutive renumbering of retained words. Utterance-final syllable = widx==wN & sidx==sN.
- `vowel_tokens` widx does NOT equal leveled widx (47% label agreement on file+widx). Joined words instead by
  (file_name, word_label, occurrence rank in time order): matches 100.0% of CH leveled words, 89.6% of CV
  (CV grids are the third-party VOX alignment).

## Step 1 — per-file metrics (`s1_file_metrics.py`, ~40 s)
- Outputs: `s1_metrics_full.csv` (46,336 files), `s1_metrics_odd.csv`, `s1_metrics_even.csv` (even = split-half diagnostic only),
  `s1_pause_audit.csv`.
- Files with >= 6 retained vowels: CH 90.2%, CV 65.3% of files (CV clips are short and lose vowels in cleaning).
- Reimplemented full-vowel voiced fraction reproduces overnight `file_alignment_qc.csv` fullV_vf exactly (r = 1.000).
- Internal pause = gap >= 150 ms between consecutive original words (widx, widx+1). 8.2% of 221,537 adjacent-word
  boundaries qualify (10.6% at 100 ms; 17.9% have any gap). Only 30.6% of CH / 23.2% of CV scorable files have one, so
  pause-adjacent boundary metrics are auxiliary (not in the composite).
- Missingness among scorable files: final_f0_rel 23.8% NA (final word/syllable dropped by cleaning, or final f0 undefined/screened),
  final_int_rel 17.7%, npvi_v 3.2%, f0 SD 1.6%. f0_undef_share is zero-inflated (median 0).
- Added f0_sd_nonfinal_st / f0_range_nonfinal_st (f0 variability without the utterance-final word) after step 2 showed
  that a deep final fall inflates file f0 SD (see below). Re-ran s1 (outputs regenerated, same file count).

## Step 2 — composite (`s2_score.py`, `s2b_content_check.py`, `s3_figure.py`)
- Orientation as specified; metrics winsorised at 1st/99th pct of scorable files before z (heavy tails; declared).
  Score = mean of available oriented z, needs >= 6 of 9 metrics: 37,287 of 46,336 files scored (CH 26,597; CV 10,690).
- PCA (complete cases n = 27,894): eigenvalues 2.15 / 1.78 / 1.38 (24% / 20% / 15%) — no dominant dimension.
  PC1 = rhythm evenness + low f0 variability; the two final-boundary metrics load NEGATIVELY (-0.26, -0.33) and phonation ~0.
  Score vs PC1 r = 0.59. Mechanism: oriented final_f0_rel vs oriented f0_sd r = -0.31 (a deeper final fall raises the file f0 SD).
  Sensitivity score with non-final f0 variability: final_f0 loading turns +0.09, r(score, score_alt) = 0.93, r(score_alt, pc1_alt) = 0.67.
- Split-half (odd vs even words): composite Spearman rho = -0.017 overall, -0.075 within voice_main (n = 13,214),
  +0.28 CH other voices, +0.15 CV. Per-metric within voice_main all |rho| <= 0.14. => no reliable file-level style
  variation within voice_main; between-speaker variation is what the score picks up.
- Speaker eta^2 of score: 0.112 all, 0.206 within CV, 0.024 within CH; corpus eta^2 0.003 (but rate 0.154, voicing 0.104,
  undefined-f0 0.118 by corpus -> channel/alignment).
- voice_main: median 0.037 vs pooled median 0.028; 51.4% of files above pooled median; rank 14 / 39 speakers (>= 20 files).
  Per metric: fastest of 39 speakers (3.99 vowels/s vs speaker median-of-medians 3.08), 3rd-lowest final f0 (-5.0 st re file median),
  but mid-pack on f0 SD/range, and among the most strongly voiced (rank 32/39; HNR 13.8 vs 11.8 dB for other CH voices).
- Least-broadcast listening candidates were full of numerals / names. Files whose transcript contains a digit score 0.455 lower
  (95% CI -0.483 to -0.428; n = 918; voice_main -0.451, n = 746) -> likely aligner mismatch on unspelled numerals. Excluded
  digit files from listening-list eligibility (pool = 19,559 qc_pass files with >= 10 vowels, all 9 metrics, no digits).
- Figure: fig_broadcast_score_by_speaker.png/pdf (39 speakers with >= 20 scored files).

## Step 3 — cross-fitted score
- broadcast_score_odd from odd word_token_idx words only (rate = within-word vowels/s over odd words; nPVI within-word pairs only;
  final boundary only when the utterance-final word is odd: 46.6% of odd-scored files have final f0).
  23,021 files scored (CH 18,347; CV 4,674); 14,266 full-scored files have < 6 odd-word vowels.
  r(full, odd) = 0.70 Pearson / 0.65 Spearman (all); 0.66 / 0.62 voice_main. Overlap of words makes this an upper bound.
