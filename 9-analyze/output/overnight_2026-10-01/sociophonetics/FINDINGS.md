# Sociophonetics — findings (overnight 2026-10-01)

Scripts: `9-analyze/analyses/overnight/sociophonetics/` (`00_extract.R`, `01_extract_f0.R`, `s*_*.py`, `s*_*.R`).
Outputs: this directory. Data: `data/leveled/vowels_spoken_annotated.rds` (574,344 vowels) exported column-subset to
`cache/vowels_socio.parquet`, joined to `output/speaker_structure.csv` (Chuvash Voice voice clusters) and the Mozilla TSV
(`cv_xpf_spkr17.tsv`: client_id, speaker_id, age, gender, accents). Speaker key `spk`: `cv_<TSV speaker_id>` for Common Voice (CV),
`chv_<voice cluster>` for Chuvash Voice (CH). Every number below is read from a CSV in this directory.

---

## Q1. Speaker profile; is Chuvash Voice `voice_main` plausibly female?

**Speaker table** (`s1_speaker_table.csv`, 120 rows = 109 CV speakers + 11 CH voice clusters). CV: 40 speakers have gender metadata
(30 male, 10 female), 40 have an age band (teens 9, twenties 17, thirties 8, forties 5, fifties 1), two have an accent
(`Верхний` = Upper/Viryal, `Без акцента` = no accent). CH `voice_main` carries 422,748 of the 574,344 vowel rows
(73.6%; the 69% figure in earlier notes was computed on the pre-27-Sep cleaned table); its metadata says `male_masculine` on the rows that carry metadata.

**Method.** Vocal-tract-length cue: per-token formant spacing ΔF = least-squares fit of F1–F3 to Fi = (i−0.5)·ΔF (uniform-tube
model), computed on non-outlier tokens of a, e, i, u, then median per vowel and averaged over the four vowels so that
vowel mix does not drive the comparison (speakers need ≥3 tokens of each vowel: 78 CV speakers, all 11 CH clusters). Same for F3.
new-FAVE was run without speaker gender (`7-extract/vowel_points/chuvash-fave.py`, `speakers="all"`, no sex-specific formant
ceiling), so the formants of voice_main are not biased by its `male` label.

**Answer. Yes. On vocal-tract cues, voice_main is very probably not an adult male, and most plausibly a woman.**
Its vowel-balanced ΔF is 1221 Hz (apparent tube length 14.3 cm) and its F3 is 3005 Hz. Both are higher than
**every** CV speaker labelled male (25 of 25; male median ΔF 995 Hz) and every CV speaker with median f0 < 175 Hz (41 of 41; median 999 Hz).
The cleanest comparison holds the recording channel constant. The four low-f0 CH clusters (f0 109–146 Hz) have ΔF 948–1047 Hz, against 1221 Hz for voice_main,
which is 23% higher than their median. voice_main sits at the 89th percentile of the 9 metadata-female CV speakers and of the 37 high-f0 CV speakers.
Its f0 is high (226.5 Hz) and its ΔF is high too, so the two cues agree. A high-pitched man would be expected to show male-range ΔF.
On robust-normal likelihoods the female-like group is favoured by log10 LR = 1.9 (metadata-gender benchmark, 9 vs 25 speakers)
to 10.4 (f0-defined groups, speakers with ≥200 tokens) (`s1_vtl_robust_likelihood.csv`).

**Confidence:** medium-high that voice_main is not an adult male. Medium that it is an adult woman rather than an adolescent; formants cannot separate those.
**Caveats.**
- The CV benchmark is weak. Metadata-female and metadata-male CV speakers differ by only ~4% in ΔF (1038 vs 995 Hz), much
  less than would be expected. Possible reasons: compressed formant estimates in phone-quality CV audio, noisy self-reported metadata (6 of 25
  metadata-male CV speakers have median f0 ≥ 175 Hz; two at 264 and 291 Hz with ΔF 604–725 Hz look like tracking failures), and small n
  (9 metadata-female speakers with formant data).
- F4 is not measured, so ΔF rests on F1–F3, which carry vowel-quality variance as well as length.
- The formant reading is an inference. Only Kate or the corpus documentation can settle the label. Until then, either treat the metadata as unknown or group voice_main with
  female voices for normalisation and sociophonetic grouping. Prosody that is normalised within speaker is unaffected.
- CH minor clusters are acoustic clusters, not verified people. Five have f0 ≥ 200 Hz with ΔF 1065–1199 Hz (female-range), and four have low f0 with male-range ΔF.

**Files:** `s1_speaker_table.csv`, `s1_vtl_benchmark.csv`, `s1_vtl_robust_likelihood.csv`, `figures/s1_vtl_vs_f0.png`.

---

## Q2. Is the dominant voice representative? Which headline results survive without it?

**Design.** Subsets: (a) all speakers; (b) without voice_main (119 voices, 151,596 vowels); (c) CV only (109 speakers, 133,576 vowels); plus (d) voice_main alone (422,748 vowels).
Fixed effects as in `analyses/intensity_measure_comparison.R`: effect + vowel_label + syllable_coda + phrase_position + z_relpos + z_rate + z_freq.
**Fast spec** (all four subsets, `s2b_fast_models.R`): DV centred within file_name + (1|word_label).
**Full spec** (`s2_representativeness_models.R`): (1|word_label) + (1|file_name) + (1|spk). It finished for (b) and (c). For (a), only the three duration models finished in the time available (`s2_models_all.csv`).
Where both specs exist (b, c), they agree within 0.006 log units for duration, 0.016 dB for intensity stress terms (0.19 dB for the reduced-vs-full intensity term) and 0.033 st for f0.
For (a), the three finished full-spec duration fits agree too: B5 0.1719 vs 0.1711, A6 0.1476 vs 0.1468, reduced −0.1400 vs −0.1376 (`s2_models_all.csv`). The table below therefore uses the fast spec. Vowel quality: per-speaker Lobanov.

| effect (fast spec) | all | without voice_main | CV only | voice_main only |
|---|---|---|---|---|
| B5 stress, Δ log duration | 0.171 [0.169, 0.173] | 0.165 [0.161, 0.170] | 0.162 [0.158, 0.167] | 0.175 [0.173, 0.178] |
| A6 stress, Δ log duration | 0.147 [0.145, 0.149] | 0.153 [0.148, 0.157] | 0.152 [0.147, 0.156] | 0.147 [0.145, 0.149] |
| reduced vs full, Δ log duration | -0.138 [-0.140, -0.135] | -0.121 [-0.126, -0.116] | -0.130 [-0.135, -0.125] | -0.141 [-0.144, -0.138] |
| B5 stress, Δ int_midpoint (dB) | 0.34 [0.31, 0.37] | 0.53 [0.48, 0.59] | 0.59 [0.53, 0.65] | 0.28 [0.25, 0.32] |
| A6 stress, Δ int_midpoint (dB) | 0.45 [0.42, 0.48] | 0.69 [0.64, 0.74] | 0.75 [0.70, 0.80] | 0.39 [0.36, 0.43] |
| B5 stress, Δ f0 (st) | 0.18 [0.16, 0.19] | 0.57 [0.54, 0.59] | 0.61 [0.58, 0.64] | 0.04 [0.02, 0.05] |
| A6 stress, Δ f0 (st) | 0.20 [0.19, 0.21] | 0.55 [0.52, 0.57] | 0.58 [0.56, 0.61] | 0.08 [0.07, 0.10] |

**Answer.**
- **Duration survives fully.** The stress lengthening (A6 ≈ +16%, B5 ≈ +18%) and full/reduced lengthening are the same with or without voice_main. B5 > A6 on duration holds in every subset.
  At the speaker level, voice_main's full/reduced duration ratio (1.196) is at the 77th percentile of 79 CV speakers (median 1.089, IQR 1.028–1.170; `s2_full_reduced_ratio_by_speaker.csv`).
  It is typical, at the upper end.
- **Intensity survives in sign but is underestimated in the pooled data.** voice_main's A6 effect is 0.39 dB against 0.69–0.75 dB in the other voices, so the pooled estimate (0.45) is pulled down.
  The A6 > B5 ordering on intensity holds in every subset.
- **f0 does not survive pooling.** Other speakers show +0.55 to +0.61 st under both rules. voice_main shows +0.04 to +0.08 st, which is below the 2-st stylisation resolution, and the pooled estimate is +0.18 to +0.20 st.
  The B5-vs-A6 ordering on f0 also **flips**: B5 ≥ A6 without voice_main, A6 > B5 with it. Any claim that f0 participates in stress, or any rule comparison that uses f0, must be made on speaker-level or
  voice_main-excluded data. (Kate's three-cue criterion depends on this.) Note that `master_rule_comparison.csv` reports f0 estimates of 0.46–0.52 st on all data with a different
  position control (nonparametric sidx/sN/poly(rel_word)), and that figure has not been reconciled with the 0.18–0.20 here (see questions for Kate).
- **Vowel quality: the configuration survives, the scale does not.** In token-pooled Lobanov means, voice_main differs from CV by up to 0.45 SD in F1 and 0.56 SD in F2 (`s2_vowel_means_by_subset.csv`):
  - /a/ is lower: F1 1.13 vs 0.68.
  - /u/ and ⟨ӑ⟩ are further back: F2 −1.30 vs −0.74 and −0.80 vs −0.44.
  - ⟨ы⟩ sits at F2 −0.23 vs +0.28.

  On scale-free speaker-level measures voice_main is typical (`s2_voice_main_vs_cv_speaker_measures.csv`): ⟨ы⟩ relative backness 0.44 (CV median 0.47, 39th percentile), reduced-vowel
  centralisation 0.51 (median 0.52), reduced dispersion ratio 1.07 (median 1.16). Its vowel-space area (2.72) is at the 81st percentile.
  So voice_main has a more expanded, cleaner vowel space, which fits studio read speech and less tracking noise than CV phone audio. The relative placement of the eight vowels is
  the same. Token-pooled "Chuvash vowel" means are essentially voice_main's means: the all-data values are within 0.17 SD of voice_main on every vowel.

**Confidence:** high for duration and for the f0 dilution. Medium for intensity (spec-dependent magnitudes). Medium for the vowel-scale interpretation (CV channel noise and voice_main's style cannot be separated).
**Caveats.**
- (a) with the full random-effect spec is incomplete: the 574k-row fits ran at 6–20 min each on a shared, loaded machine. The fast spec stands in, and it matched the full spec wherever both exist.
- CV "speakers" include many with <100 vowels.
- Without voice_main, the remaining CH clusters (18k vowels) are not verified individuals.

**Files:** `s2_headline_effects_by_subset.csv`, `s2b_fast_models.csv`, `s2_models_*.csv`, `s2_vowel_means_by_subset.csv`, `s2_voice_main_vs_cv_speaker_measures.csv`,
`s2_full_reduced_ratio_by_speaker.csv`, `figures/s2_headline_effects_by_subset.png`, `figures/s2_vowel_space_voice_main_vs_cv.png`.

---

## Q3. Apparent-time age effects on the vowel space

**Design.** Speaker-level measures from per-speaker Lobanov F1/F2 (`s3_speaker_vowel_measures.csv`):
- ⟨ы⟩ relative backness `y_F2_rel` = (ʉ−u)/(i−u) on F2 (0 = at /u/, 1 = at /i/) and relative height `y_F1_rel`.
- Reduced-vowel centralisation: mean distance of ø, ɵ from the a-e-i-u centroid, divided by the mean corner distance.
- Reduced-vowel dispersion: within-category RMS spread of ø and ɵ, divided by that of a e i u.
- i-e-a-u polygon area.
- ø−ɵ F2 separation.

Only CV speakers have age metadata. Of the 40 who do, **23** meet the main inclusion rule (≥5 tokens of each of a e i u ø ɵ, ≥100 clean vowels) and only **14** have enough ⟨ы⟩.
Age is the CV decade band (teens = 1 … fifties = 5; 9/17/8/5/1 speakers). Each model is an OLS of the measure on age decade plus a
high-f0 indicator, with HC3 SEs. A younger (teens + twenties) vs older (30+) contrast and Spearman ρ are reported alongside.

**Answer. Inconclusive. Two dispersion-type measures show a positive age slope that is suggestive but not established, and the targeted ⟨ы⟩ and reduced-vowel
positions show no age trend.**
- Reduced-vowel dispersion ratio: +0.101 per decade [-0.004, 0.205], n = 23 speakers.
  Older minus younger = +0.26 [0.04, 0.49], Spearman ρ = 0.55 (p = 0.007).
  With the relaxed inclusion rule (n = 32) the slope is +0.094 [0.006, 0.182]. Controlling log token count
  leaves it at +0.095 to +0.101 per decade with the CI touching 0 (`s3_age_effects_tokencount_control.csv`).
- Vowel-space area: +0.21/decade [-0.04, 0.46] (main) and +0.23 [0.03, 0.43] (relaxed).
- ⟨ы⟩ relative backness: -0.022/decade [-0.109, 0.065], n = 14 (only 3 speakers aged 30+).
  Reduced centralisation: +0.007 [-0.039, 0.053].
- **Power.** With 15 younger and 8 older speakers, the minimum detectable group difference (80% power, α = .05) is 1.23 between-speaker SDs, and for ⟨ы⟩ it is 1.8 SD
  (`mde80_in_sd`). Only large generational shifts could be detected. The null results for ⟨ы⟩ and reduced-vowel position are therefore "not detected at this power",
  not evidence of stability.
- Six measures × two inclusion rules were tested. None of the OLS slopes survives a Holm correction over the six main-spec measures.

**Loan /o/.** Not assessed. The OW label is excluded from the cleaned/leveled vowels by design, so there is no loan-/o/ row to measure
in `data/leveled`. It would need the pre-cleaning FAVE point tables.

**Confidence:** low.
**Caveats.** Age bands are self-reported CV metadata. Age is confounded with recording amount: teens contribute a median 1,397 vowels against
~120 for the other bands, and token count correlates with age at ρ ≈ −0.23 to −0.30 among included speakers. Age is also partly confounded with device and recording conditions, which
cannot be separated here. Lobanov normalisation depends on each speaker's vowel mix, which follows the prompt sentences.

**Files:** `s3_speaker_vowel_measures.csv`, `s3_age_effects.csv`, `s3_age_effects_tokencount_control.csv`, `figures/s3_s4_age_and_viryal.png` (a).

---

## Q4. Viryal (Upper) dialect evidence

**Literature (retrieved).** Savelyev (2020), *Chuvash and the Bulgharic languages*, in Robbeets & Savelyev (eds.),
*The Oxford Guide to the Transeurasian Languages*, doi:10.1093/oso/9780198804628.003.0028 (DOI verified on CrossRef). The basic dialect split is Viryal (Upper, NW Chuvashia) vs Anatri (Lower, SE).
Viryal has /o/ where Anatri and the standard have /u/, so Anatri's *o > u merger is an innovation. Both dialects also keep a tense /ụ/. Viryal and many Anatri varieties keep rounded vs unrounded reduced vowels.
The same chapter mentions a traditional attribution of some Viryal features to a Mari substrate (Ašmarin 1898); the snippet did not say which features, so this is not verified.
**Prediction.** For a Viryal speaker, a subset of literary ⟨у⟩ words should surface as [o]. Relative to the speaker's own i–a range, /u/ F1 should be higher (more open), and its F1 distribution may be wider.

**Measure.** `u_F1_rel` = (F1ᵤ − F1ᵢ)/(F1ₐ − F1ᵢ) on per-speaker Lobanov values: 0 = /u/ as close as /i/, 1 = as open as /a/. It is computed for the `Верхний` speaker (cv_60) and for 48 CV
speakers with ≥10 /u/, ≥5 a/e/i, and ≥50 clean vowels.

**Answer. Direction as predicted, but the evidence is too thin to support a dialect claim. Inconclusive.**
- cv_60 has **12 recordings (the task brief said 13 clips), 53 vowels, 7 clean /u/ tokens (9 including IQR-flagged), and only 4 /i/**.
- Its `u_F1_rel` = 0.295: rank 5 of 49, above the reference 90th percentile (0.271), against a median of 0.137.
  A full token bootstrap (resampling u, i and a) gives 95% CI [0.198, 0.383], above the reference median in 99.98% of resamples.
  This CI covers token sampling only, not the speaker-to-speaker spread: four unlabelled speakers score higher.
- Two of cv_60's /u/ tokens are excluded by `iqr_outlier_any`. One of them is ун with F1 = 533 Hz, more open than the speaker's /e/. Its /u/ flag rate (22%) is at the 88th percentile.
  **The IQR outlier filter may be removing exactly the o-like realisations a dialect analysis would want.**
- Unsupervised screen (robust MCD Mahalanobis distance on u_F1_rel and u_F2_rel, `s4_u_lowering_screen.csv`): cv_60 is not an outlier (χ²₂ p = 0.07).
  The most extreme speakers (cv_51, cv_86, cv_83) are extreme on F2 or show formant-tracking failures, not /u/ lowering. On u_F1_rel alone the
  top speakers are cv_76 (0.57, 25 /u/), cv_108 (0.33, 2,676 /u/), cv_68 and cv_77, all without accent metadata. These are candidates for listening, not findings.
- CV is read speech from standard-orthography prompts, which should suppress dialect vowels. This works against detection.

**Confidence:** low.
**Caveats.** Seven tokens. The words (вуннӑ, кун, пулин, пулӑшасса, пултарать, юрать, чухне) were not checked against an etymological
list of Viryal-/o/ items, and that check is the decisive test. Lobanov scaling based on 46 clean vowels is itself noisy.

**Files:** `s4_viryal_speaker_u.csv`, `s4_viryal_speaker_summary.csv`, `s4_u_lowering_screen.csv`, `figures/s3_s4_age_and_viryal.png` (b; cv_51 at −3.9 is off scale and marked).

---

## Q5. Individual differences in stress-cue weighting

**Design.** Per speaker (≥30 stressed and ≥30 unstressed vowels, ≥5 files), an OLS of each DV, centred within recording, on predicted stress
(A6, and B5 as a check), with vowel_label, syllable_coda, phrase_position and relative word position as controls (HC1 SEs).
The DVs are log duration, int_midpoint, and f0_st: f0_mid (mean of steps 10–11, as in `analyses/f0_measure.R`) in semitones re the speaker's median, with the same octave screening.
f0 is in the leveled data (`f0_step10/11`). Slopes are pooled by DerSimonian–Laird random effects, and a meta-regression is run on voice group (median f0 ≥ 175 Hz) and age decade.
74 speakers under A6 (63 CV + 11 CH clusters).

**Answer. Yes, there is large between-speaker variation, and it is structured. Duration is a consistent stress cue for everyone; intensity and especially f0 are not.**
- **Duration (A6):** RE mean +0.167 log units [0.154, 0.181] (≈ +18%), τ = 0.043. 55/74 speakers
  are individually significantly positive and none negative.
- **Intensity:** +0.58 dB [0.43, 0.74], τ = 0.53 dB, i.e. about as large as the mean.
  33 speakers are significantly positive and 2 significantly negative. Under B5 the mean is only +0.36 dB.
- **f0:** +0.63 st [0.52, 0.75], τ = 0.41 st. It is **-0.51 st smaller in high-f0 voices** [-0.72, -0.30],
  p < .001 (medians 0.86 vs 0.30 st, `s5_slopes_by_voice_group.csv`). The same holds under B5 (−0.57 st) and among CV speakers alone (−0.47 st).
  Duration goes the other way: high-f0 voices have a +0.039 larger duration slope (p = .04). That pattern is consistent with **cue trading by voice group**.
- **voice_main:** duration +0.159, intensity +0.52 dB, **f0 +0.14 st** (A6), and under B5 +0.192 / +0.28 dB / +0.07 st. That f0 slope is far below the low-f0 CV median and near the
  2-st stylisation resolution. Pooled f0-as-stress-cue estimates are therefore driven by CV speakers, not by the dominant voice.
- **Kate's three-cue criterion** (longer, louder and higher together): 56 of 74 speakers have all three point estimates positive under A6, and **17 of 74**
  have all three individually significant (B5: 49 of 71 and 17 of 71). Cross-speaker correlations between cue slopes are weak
  (Spearman: f0–intensity 0.35, f0–duration 0.16, intensity–duration 0.03), so speakers do not divide into "strong-stress" and "weak-stress" talkers.
- **Age:** no detectable age gradient on any cue (n = 33 speakers with age; f0 +0.05 st/decade [−0.09, 0.19]).

**Confidence:** high that duration is the speaker-general cue and that f0 and intensity weighting vary. Medium for the voice-group f0 difference.
**Caveats.** "High-f0 voice" stands in for sex. Metadata gender is available for only 38 speakers; there the female median f0 slope is 0.45 st against 0.63 st for males (A6), in the same direction.
The f0 stylisation (2 st) and the midpoint measure limit what small differences mean, and a later pitch peak would be missed by a midpoint measure.
The Praat pitch range is 100–800 Hz for all voices (`7-extract/contours/vowels/time-series_f0-int.praat`), so high voices are not clipped.
Predicted stress (A6/B5) is a rule label, not perceived stress, so a speaker whose stress falls elsewhere would show a small slope.
CH minor clusters are not verified individuals.

**Files:** `s5_speaker_slopes.csv`, `s5_speaker_slopes_wide_A6.csv`, `s5_speaker_slopes_wide_B5.csv`, `s5_cue_heterogeneity.csv`, `s5_slopes_by_voice_group.csv`, `figures/s5_stress_cue_slopes_by_voice.png`.

---

## Q6. Speech rate and reduced-vowel compression

**Design.** Per speaker (56 speakers: ≥30 reduced, ≥60 full, ≥8 files): OLS of log duration on vowel_label + rate_c × reduced + A6 stress + phrase
position + coda + relative position. rate_c is log rate centred within speaker, so the slopes come from tempo variation within each talker.
Two rate measures were used:
- `log_span_rate` (main): vowels per second between the first and last vowel of the clip. Added here because the pipeline's `speech_rate` divides surviving vowels by the *whole
  clip* duration, including leading and trailing silence, which is large in CV. The two correlate at r = 0.83.
- The pipeline `log_speech_rate`.

Results are pooled by random effects. The interaction is meta-regressed on voice group, age and corpus.

**Answer. Yes. Reduced vowels compress about four times more than full vowels as within-speaker tempo increases, and the difference holds across speakers.
Group differences are not established.**
- Span rate, all speakers: full-vowel elasticity -0.021 [-0.032, -0.011], reduced -0.087
  [-0.107, -0.067], interaction **-0.066 [-0.085, -0.047]**, τ = 0.030, I² = 0.41.
  13 speakers are individually significant in the predicted direction and 1 in the opposite direction.
  CV only: -0.080 [-0.109, -0.050]. Excluding voice_main: -0.068.
  voice_main itself: −0.063.
- Pipeline rate gives the same picture: interaction -0.063 [-0.082, -0.044].
- **Groups:**
  - Voice group (high f0): -0.018 [-0.062, 0.026].
  - Age (n = 24): +0.017/decade [-0.017, 0.050] with span rate. With pipeline rate it is +0.031 [0.001, 0.061], i.e. older speakers compress reduced vowels slightly less.
  - Corpus (CH vs CV): +0.032 [-0.014, 0.078] (span) against +0.054 [0.008, 0.100] (pipeline).
  
  The age and corpus effects depend on which rate measure is used, so they are **inconclusive**.

**Confidence:** high for the compression asymmetry. Low for the group effects.
**Caveats.** Both rate measures still include utterance-internal pauses, and in read CV prompts the within-speaker tempo range is narrow. That attenuates all
elasticities: they are tiny in absolute terms, with full vowels nearly rate-invariant. The asymmetry is the robust quantity, not the elasticities.
Rate is counted in vowels, so it is not mechanically computed from the durations being modelled, but faster utterances may also differ in prosodic phrasing.
Reduced vowels are shorter to begin with, so a floor effect (the 30-ms alignment floor) would push toward *less* compression of reduced vowels. The observed asymmetry is therefore conservative with respect to that floor.

**Files:** `s6_speaker_rate_slopes_log_span_rate.csv`, `s6_speaker_rate_slopes_log_speech_rate.csv`, `s6_rate_compression_summary_log_span_rate.csv`, `s6_rate_compression_summary_log_speech_rate.csv`.

---

## Bearing on the overarching hypothesis (Turkic base + Volga-Kama areal overlay)

This track bears on the hypothesis only indirectly. (i) The retrieved dialect literature (Savelyev 2020) treats Viryal as the archaic variety (it keeps /o/ where Anatri has /u/).
It also reports a traditional attribution of some Viryal features to a Mari substrate (Ašmarin 1898). That attribution was not verified feature by feature, and the corpora contain one self-declared Viryal speaker with 53 vowels, so the speech data cannot test it.
(ii) Apparent-time change in the reduced vowels, which are the putative Mari-type feature, was not detected, but the analysis was only powered for shifts larger than one between-speaker SD.
(iii) Duration is the speaker-general stress cue, f0 participates in most voices, and intensity varies. This cue profile is a speaker-level fact that any typological comparison of Chuvash
stress with Mari or Turkic should use, rather than the voice_main-dominated pooled estimates.

## Questions for Kate
1. Who recorded Chuvash Voice voice_main? Its vocal-tract cues (ΔF 1,221 Hz, F3 3,005 Hz) are above every CV male and every low-f0 voice. Is the `male_masculine` label wrong (likely female), and can the corpus documentation confirm it?
2. voice_main shows almost no f0 rise on predicted-stressed vowels (+0.04 to +0.14 st, against +0.55 to +0.86 st in other voices). Should f0-based stress claims and rule comparisons be reported on voice_main-excluded or speaker-level data by default?
3. master_rule_comparison.csv gives f0 stress estimates of 0.46–0.52 st on all data, but this track gets 0.18–0.20 st on all data (different position controls, and f0 normalised per voice cluster rather than one CH speaker). Which f0 spec is canonical? Should the master table be rerun with voice_main excluded?
4. The IQR outlier filter removes 2 of the Viryal speaker's 9 /u/ tokens, including an [o]-like ун (F1 533 Hz). For dialect work, should iqr_outlier_any be relaxed per speaker?
5. Is there an etymological list of Viryal-/o/ ~ standard-/u/ items (Proto-Chuvash *o)? With one, the 'Верхний' speaker's /u/ tokens could be tested word by word instead of averaged. It would also allow eliciting Viryal speakers.
6. Could the CV clips of cv_60 (Верхний) and of the high u_F1_rel speakers cv_76, cv_108, cv_68 and cv_77 be listened to for [o] in ⟨у⟩ words?
7. The pipeline's speech_rate divides surviving vowels by whole-clip duration, including edge silence. Should 03_build_levels.R use the vowel span (first to last vowel) instead? The corpus effect on reduced-vowel compression depends on this choice.
8. Loan /o/ (OW) is excluded before the leveled data, so apparent-time change in loan /o/ could not be assessed. Is it worth carrying OW rows into a side table?

## New questions raised
1. Cue trading by voice group: high-f0 (probably female) voices use less f0 and slightly more duration for stress. Is this a sex difference in Chuvash prosody, a style effect (studio vs phone), or an f0-measurement artefact? It needs metadata-verified gender and more female CV speakers.
2. Is voice_main's weak f0 cue a property of read audiobook-style prosody (phrase-level intonation overriding word stress)? Compare its f0 slope in phrase-medial words only.
3. Older CV speakers may have more dispersed reduced vowels and a larger vowel space (+0.10 dispersion ratio per decade, CI touching 0, n = 23). Does a larger age-balanced sample confirm it?
4. Only 17 of 74 voices meet Kate's three-cue stress criterion individually under A6. Is that a power issue (small per-speaker n) or evidence that intensity and f0 are optional cues?

## Reference (retrieved and verified)
- Savelyev, Alexander. 2020. Chuvash and the Bulgharic languages. In Martine Robbeets & Alexander Savelyev (eds.), *The Oxford Guide to the Transeurasian Languages*. Oxford University Press.
  doi:10.1093/oso/9780198804628.003.0028 (CrossRef-verified). Supports: the Viryal/Anatri split; Viryal /o/ vs Anatri/standard /u/; the tense /ụ/; rounded reduced vowels in Viryal; the cited Mari-substrate attribution (Ašmarin 1898).
