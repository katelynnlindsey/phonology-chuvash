# Broadcast-likeness score — findings (2026-10-02)

Track: `speaker_cues_2026-10-02/broadcast_score`. Scripts: `9-analyze/analyses/speaker_cues/broadcast_score/`
(`s1_file_metrics.py`, `s2_score.py`, `s2b_content_check.py`, `s3_figure.py`). Every number below is read from a CSV in this directory.
Main table: `broadcast_score_by_file.csv` (46,336 files; required columns first, then auxiliary columns).

**Headline.** The score does not isolate a "newscaster" style. (1) The nine metrics do not form one dimension. In particular,
a deep final fall *raises* file f0 SD/range, so two parts of Kate's description work against each other in the composite.
(2) Within voice_main, file-to-file score differences are not reliable: odd-word vs even-word split-half rho = -0.075
(95% CI -0.092 to -0.058, n = 13,214 files). What the score does capture is mostly variation **between speakers and channels**.
(3) On the composite, voice_main falls in the upper middle (rank 14 of 39). On single metrics it is extreme on two of them: it is the
**fastest speaker** of all 39 and has the **3rd-lowest utterance-final f0**. It is average on f0 variability and is
**strongly, not weakly, voiced**.

## Step 1 — Per-file style metrics
**Answer.** Computed nine metrics for every file in both corpora (`s1_metrics_full.csv`), plus auxiliary internal-pause boundary
metrics, HNR (CH only) and f0 variability without the final word. NA if < 6 retained vowels.
**Key numbers.**
- Scorable (>= 6 vowels): 90.2% of 29,551 CH files, 65.3% of 16,785 CV files.
- Median by group, voice_main / other CH voices / CV (`s2_metric_medians_by_group.csv`):
  - rate 3.99 / 3.20 / 3.06 vowels/s
  - nPVI-V 34.8 / 35.6 / 36.4
  - duration CV 0.374 / 0.383 / 0.364
  - f0 SD 2.12 / 2.40 / 1.97 st
  - f0 10–90 range 4.25 / 4.94 / 4.17 st
  - final-syllable f0 −5.01 / −3.50 / −2.73 st re file median
  - final-syllable intensity −5.84 / −2.65 / −7.63 dB
  - full-vowel voiced fraction 0.985 / 0.980 / 0.955
  - HNR 13.8 / 11.8 dB / NA
- Internal pauses (gap >= 150 ms between consecutive original words) occur at 8.2% of 221,537 adjacent-word boundaries
  (`s1_pause_audit.csv`). Only 30.6% of scorable CH files and 23.2% of scorable CV files have one, so the pause-boundary metrics
  are auxiliary columns and are not in the composite.
- Pause-adjacent word-final f0, voice_main / other CH / CV: −0.24 / +0.21 / +0.35 st.
- The reimplemented full-vowel voiced fraction reproduces the overnight `file_alignment_qc.csv` fullV_vf exactly (r = 1.000).

**Confidence.** High for the measurements as defined; medium for their interpretation (see caveats).

**Caveats.**
- Rate counts only vowels that survived cleaning, so it is biased low where cleaning dropped vowels (same definition as the
  overnight log_span_rate).
- final_f0_rel is NA for 23.8% of scorable files: the final word or syllable was dropped by cleaning, or its f0 was undefined or
  screened. This missingness is informative, because creaky finals are part of the hypothesised style.
- The CV voicing metric comes from the third-party VOX alignment, and 10.4% of CV words cannot be matched to leveled words.
- f0 is stylised to 2 st. Durations are 10 ms quantised with a 30 ms floor.

## Step 2 — Composite score and validation
**Answer.** broadcast_score = mean of 9 oriented, winsorised (1/99%) z-scores, requiring >= 6 metrics.
37,287 files were scored (CH 26,597; CV 10,690).
- **The composite is weakly structured.** PC1 explains only 24% of variance (eigenvalues 2.15, 1.78, 1.38). r(score, PC1) = 0.59.
  PC1 combines even rhythm with low f0 variability. The final-boundary metrics load against it (−0.26 f0, −0.33 intensity), and
  phonation does not load (−0.09, −0.06).
- **Mechanism.** Oriented final-f0 depth correlates −0.31 with oriented f0 SD (`s2_metric_intercorrelations.csv`).
  Measuring f0 variability without the final word removes most of the conflict: the final-f0 loading becomes +0.09
  (`s2_pc1_loadings_alt.csv`). That sensitivity score correlates 0.93 with the main score (`broadcast_score_alt`).
- **Corpus.** Means are CH −0.009 (95% CI −0.013 to −0.005) and CV +0.040 (0.030 to 0.050). Share above the pooled median
  (0.028): CH 50.3%, CV 49.2%.
- **voice_main.** Median 0.037; 51.4% of files above the pooled median (Wilson CI 50.7–52.0%; n = 25,313).
  - The other CH voices are clearly lower: median −0.220, 29.7% above the pooled median (27.2–32.2%), n = 1,284.
  - Rank 14 of 39 speakers with >= 20 scored files (`s2_score_by_speaker.csv`; figure panel a).
  - Per-metric rank among 39 speakers, 1 = most broadcast-like (`s2_voice_main_metric_ranks.csv`; panel b):
    - rate 1
    - final f0 3
    - nPVI 15
    - f0 range 18
    - f0 SD 20
    - final intensity 22
    - undefined-f0 share 24 (tied with 29 speakers at median 0)
    - duration CV 26
    - voicing 32
- **The score is mostly a speaker and channel measure.** Speaker η² = 0.112 overall, 0.206 within CV and 0.024 within CH.
  Corpus η² is 0.003 for the score, but large for individual metrics: rate 0.154, undefined-f0 share 0.118, voicing 0.104
  (`s2_variance_shares.csv`). These metrics carry recording-channel and aligner differences, not only style.
- **No reliable within-speaker file variation.**
  - Composite odd vs even split-half rho (`s2_split_half_reliability.csv`): −0.075 within voice_main (n = 13,214),
    +0.278 among other CH voices (n = 428), +0.151 in CV (n = 2,158).
  - The positive values outside voice_main reflect differences between speakers.
  - Single metrics within voice_main: |rho| <= 0.14 (undefined-f0 share 0.14, rate 0.06, f0 SD −0.06).
- **Content confound.** Transcripts with numerals score 0.455 lower (95% CI −0.483 to −0.428; n = 918 files).
  The effect is the same within voice_main (−0.451, n = 746). The most likely cause is aligner mismatch on unspelled numerals.
  Text length is unrelated to the score (Spearman −0.005; `s2b_content_check.csv`).
- **Listening list** (`listening_list.csv`): the 15 highest- and 15 lowest-scoring files from an eligible pool of 19,559.
  Eligible files pass alignment QC, have >= 10 vowels, have all 9 metrics, and have no numerals in the transcript.
  - Most broadcast-like: 5 voice_main files, 5 cv_107, 3 cv_106, 1 cv_108, 1 cv_109.
  - Least broadcast-like: 8 voice_main, 2 voice_4, 2 cv_104, 2 cv_109, 1 voice_2.

**Confidence.** High that the composite is not unidimensional and that file-level variation within voice_main is unreliable.
Medium for the speaker ranking: it depends on channel, and speakers with few files are noisy.

**Caveats.**
- The score partly measures **speaker and recording channel** (CV crowd microphones vs CH studio; the VOX alignment for CV
  voicing), not only speaking style.
- Weights are equal by construction. They are not tuned to any external "broadcast" judgement; Kate's listening is the
  first validation.
- Winsorisation and the >= 6-metric rule are analyst choices (stated here).
- HNR is excluded from the composite because it exists for CH only. Within CH it is unrelated to the score
  (Spearman 0.054).

## Step 3 — Cross-fitted score
**Answer.** broadcast_score_odd uses only odd-numbered words (word_token_idx), so stress can be tested on even-numbered words
without circularity. It was scored for 23,021 files (CH 18,347; CV 4,674). 14,266 files with a full score have fewer than
6 vowels in their odd words.

**Key numbers.**
- r(full, odd) = 0.699 Pearson / 0.654 Spearman (n = 23,021); voice_main 0.658 / 0.616 (n = 17,676). These are upper bounds,
  because the full score contains the odd words.
- Only 46.6% of odd-scored files have a final-boundary f0 term, because the utterance-final word is odd in roughly half of files.

**Confidence.** High for the computation. Low for its usefulness as a style covariate within voice_main: its split-half
reliability there is about 0, so even-word stress tests conditioned on it will mostly condition on noise.

**Caveats.**
- The odd-word rate is a within-word rate (vowels per second of word duration). It cannot be the span rate, because even words
  are interleaved.
- nPVI uses within-word pairs only. z-scores are recomputed within the odd set.
- Even if the score were reliable, a test that conditions on it would be confounded by speaker. Do any style comparison
  within speaker (e.g. within voice_main) using `broadcast_score_within_spk` or the odd score centred by speaker.

## Files
- `broadcast_score_by_file.csv`: required table plus auxiliary columns (alt score, even-half score, within-speaker-centred score,
  pause metrics, HNR, qc_pass, has_digit).
- `listening_list.csv`
- `fig_broadcast_score_by_speaker.png` / `.pdf`
- `s1_metrics_{full,odd,even}.csv`
- `s1_pause_audit.csv`
- `s2_*.csv`
- `s2b_content_check.csv`
