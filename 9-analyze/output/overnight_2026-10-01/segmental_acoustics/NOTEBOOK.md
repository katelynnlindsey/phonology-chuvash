# Segmental acoustics track — lab notebook (overnight 2026-10-01)

Scripts: `9-analyze/analyses/overnight/segmental_acoustics/`. Outputs: this directory.
Chronological. Every number here is read from a file in this directory.

## 15:00 Orientation
- Loaded skill chuvash-corpus-pipeline; read README_loading_data.md, SUPERSEDED.md, data_dictionary.csv.
- Existing consonant-duration work: `analyses/gemination_mora.R` -> `gemination_models.csv`,
  `gemination_final.csv`, `gemination_weight_model.csv`, `mora_evidence.csv`; methods in
  `methods_weight_prosody.md`. All of it is Chuvash Voice only (one dominant voice), from
  `7-extract/reextract/phones_chuvash_voice.csv` (pre-recode grids, 30 ms aligner floor, 10 ms quantised).
  SUPERSEDED.md 2026-09-27 entries: the "word-final rhyme" there is really the final CV sequence;
  the Cː+reduced vs C+full contrast is +22 ms (not ~7 ms).
- Common Voice: the only grids that keep geminates are `textgrids_VOX`, which methods_weight_prosody.md
  documents as a DIFFERENT third-party alignment (18.9% boundary agreement with the grids the
  vowel measurements come from). I use them anyway because they are the only CV grids with
  geminates; consequence: my CV consonant/vowel durations are not the same numbers as the
  leveled-data CV vowel durations. Declared.
- Raw grids: tiers `words`, `phones`; IPA labels (ɑ e ʌ=⟨ӑ⟩ ɛ=⟨ӗ⟩ i u ɯ=⟨ы⟩ y o; tʃ=⟨ч⟩ (config tɕ);
  χ=⟨х⟩; v=⟨в⟩; geminates as `tː` etc.; `sil`, `spn` (OOV/noise, frequent in CV: ~6% of intervals in an 800-file sample).

## 15:05 Voicing-measure design and synthetic validation
- Praat AC pitch on the WHOLE utterance (no excision), 5 ms step, 75-600 Hz.
- Synthetic test (vowel–silence–vowel, f0 180 Hz): AC voices 12% of frames in a 40 ms silent gap,
  8% at 60 ms, 6% at 80 ms (≈1 frame of edge bleed); CC (cross-correlation) bleeds much more
  (38/33/19%) -> AC chosen.
- Sensitivity to a weak voicing bar (80 ms gap, harmonic bar attenuated): defaults (silence 0.03,
  voicing 0.45) detect it at −10/−20 dB (100%) but not at −30 dB (6%). Sensitive setting
  (silence 0.01, voicing 0.30) only partially at −30 dB. So `def` = Praat default and `sen` = sensitive
  are both extracted, plus a threshold-free low-band (60–400 Hz) energy measure.
- Middle-50% voiced fraction (`vf_*_mid`) is the primary measure: least exposed to edge bleed and
  to the ±10 ms MFA boundary error.

## 15:10 Literature check for the lenition description (before modelling)
- Savelyev (2020) 'Chuvash and the Bulgharic languages', Oxford Guide to the Transeurasian Languages,
  doi:10.1093/oso/9780198804628.003.0028 (draft PDF on iling-ran.ru): no voiced/voiceless stop
  opposition; ALL non-sonorant consonants have semi-voiced vs voiceless allophones; semi-voiced
  between vowels or after a sonorant before a vowel; voiceless elsewhere (word-initially, before a
  sonorant, before/after a non-sonorant); geminates voiceless; and — directly relevant to the
  overnight hypothesis — he says a similar voiced/voiceless distribution was historically present in
  neighbouring Mari (citing Kangasmaa-Minn 1998: 222) and that Chuvash likely lost the
  original contrast under Mari substratum influence.
- So the predictions are: V_V and R_V (R = sonorant) -> semi-voiced; #_, _#, V_R, V_O, O_V -> voiceless;
  geminates -> voiceless. Applies to fricatives too, so s ʃ ɕ χ are in scope.

## 15:12 Full extraction launched
- `extract_voicing.py`, 4 processes (2 per corpus), every phone interval of every grid:
  Common Voice 17,023 grids, Chuvash Voice 29,727 grids. Partial CSVs append per file
  (`extraction/phones_*.csv`), restartable. No subsampling at the extraction stage.

## 15:20 Extraction finished
- 46,750 grids, 0 errors; 2,084,544 phone intervals (`extraction/phones_{cv,ch}_part0{0,1}.csv`).
  Rate ≈ 8 files/s/process.
- `build_tokens.py` -> `obstruent_tokens.csv.gz` (564,179 obstruents), `vowel_tokens.csv.gz` (803,733 vowels).
  Speaker: CV from cv_xpf_spkr17.tsv `speaker_id` (0.9% of CV obstruent tokens have no TSV row -> dropped);
  CH from speaker_structure.csv voice clusters (models use `voice_main` only).
- Aligner floor: 30 ms in BOTH corpora (min observed; 10-ms quantisation in both). The VOX grids have the
  same floor as the Chuvash Voice grids.

## 15:25 Validation (`validation_by_class.csv`, `handcheck/`)
- % of intervals voiced at mid-interval (vf_def_mid ≥ 0.5), CH / CV: vowels 97.3 / 90.1; sonorants 93.6 / 87.2;
  post-pause sibilants 2.3 / 4.8; post-pause word-initial stops 6.1 / 16.2; `sil` 15.4 / 22.6;
  loan /b d g/ intervocalic 87.0 / 84.6. The measure separates voiced from voiceless classes.
- Hand check of 8 rendered tokens (waveform + spectrogram + pitch, `handcheck/handcheck_grid.png`): 7/8 agree
  with what is visible (e.g. ӳстерессипе /p/ = full voicing bar, 100%; хваттер /tː/ = silent closure, 0%;
  ыттисене /tː/ in CV = voicing decays half-way, measured 0.5). The 8th (CV кам, cv_23964683) is aligned
  into DIGITAL SILENCE at the start of the clip -> alignment error, not a measurement error.
- That prompted an alignment check. Shift scan (TextGrid shifted −150..+150 ms; score = vowel voicing −
  voiceless-segment voicing): best shift +10–20 ms in both corpora (systematic, small; consistent with MFA
  boundaries slightly early or aspirated vowel onsets), but ~15% of CV files score < 0.3 at zero shift and
  ~10% have best |shift| ≥ 100 ms, vs 3% / 0% in CH.
- QC rule adopted (`file_alignment_qc.csv`): keep a file only if its full vowels (/a e i u y ɯ/, ≥ 50 ms)
  are voiced at mid-interval on average ≥ 0.8. This uses only full vowels, so it is not circular for the
  obstruent-voicing or reduced-vowel analyses. Excludes 12.4% of CV files and 1.0% of CH files.
  (Caveat: it will also remove speakers with heavy creak/whisper.)

## 15:30 Step 2 — lenition
- Positions (word tier + utterance neighbours; R = sonorant m n l r j v; O = obstruent):
  V_V, R_V, geminate V_ːV, O_V, V_R, V_O within the word; cross-word V#_V, R#_V, O#_V, post-pause;
  word-final V_#V, V_#C, pre-pause. Neighbours labelled `spn` -> excluded.
- Descriptives `voicing_by_position.csv`; models `lenition_models.R` -> `lenition_lmm.csv`
  (A: position + segment; B: + standardised log duration + articulation rate),
  `lenition_glmm.csv` (logistic, voiced ≥ 0.5, ≤ 4,000 tokens per position subsample, nAGQ = 0),
  `lenition_emm.csv`, `lenition_dur_models.csv`, `lenition_speaker_level.csv`.
  RE: CV (1|speaker)+(1|word)+(1|file); CH voice_main only, (1|word)+(1|file).
- Result: three tiers. Adjusted mid-closure voiced fraction (stops CH/CV): V_V 0.60/0.63, R_V 0.51/0.61;
  intermediate: V#_V 0.32/0.43, R#_V 0.31/0.39, V_#V 0.30/0.39, V_#C 0.15/0.34, V_O 0.22/0.34, V_R 0.16/0.28;
  voiceless: geminate 0.06/0.10, O_V 0.06/0.03, O#_V −0.04/−0.06, post-pause 0.07/0.14, pre-pause 0.09/0.10.
- Speaker level (CV, speakers with ≥5 tokens in both cells): V_V > post-pause in 53/53 speakers
  (mean diff 0.465, 95% CI 0.414–0.516); V_V > geminate 20/20 (0.489, 0.419–0.559); V_V > O_V 46/46;
  R_V > V_R 35/39; V#_V > post-pause 50/52; V_V > V#_V 49/56.
- Rate: articulation-rate coefficient ≈ 0 (CH stops +0.023/SD, CV stops −0.004/SD). Duration: −0.10/SD.
- Geminates at matched duration: in V_V-vs-geminate models with duration in, geminates still −0.45 to −0.57
  (vf_all) and have 25–39 ms LESS voicing into closure than singletons of the same duration (model E) ->
  geminate voicelessness is not just a by-product of length.
- Place gradient (`voicing_by_segment.csv`), % voiced, V_V, CH: p 75.7 > t 65.2 > k 56.3 > tʃ 31.8.
- Distribution shape (`lenition_mixture_test.csv`, low-band energy re next vowel): word-internal V_V sits at
  −9.9 dB vs voiced-loan reference −6.2 and O_V reference −38.6 (CH); a voiced/voiceless mixture and a shifted
  unimodal fit V_V equally (dLL/token −0.03). Cross-word V#_V and pre-consonantal V_R, V_O are fit much better
  by a single intermediate distribution than by a mixture of the two references (dLL/token −0.50, −0.78,
  −0.81 for CH) -> intermediate, gradient values there, not a mix of voiced and voiceless tokens.
- Figure `figures/fig_lenition.png` (a: adjusted means by position; b: low-band energy densities, CH voice_main
  stops vs loan /b d g/; c: voicing-into-closure vs duration, singleton vs geminate).
- Dead end / correction: first R run died (fread cannot read .gz without R.utils) -> read via `gzip -dc` pipe;
  second died because 3 rows had NA vf_def_mid (predict length mismatch) -> NA rows filtered.

## 15:45 Lexical exceptions -> loans
- Word-level V_V stop voicing (`lenition_word_level_VV_stops.csv`, words with ≥15 tokens, CH voice_main):
  35 of 355 words are <10% voiced, 39 are >90%. The near-voiceless ones (0–4.2% voiced; only some at exactly 0%) are Russian loans and names
  (учитель, капитан, Анюта, председатель, секретарь, литература, батальон, Степан, Яков, Вероника);
  the fully voiced ones are native (ята, апачӗ, витене, ятарлӑ, атӑл, апата, Шупашкара).
- Crude loan flag (word contains any of о ё ф ц щ ъ б г д ж з): `lenition_loan_vs_native.csv`,
  `lenition_loan_models.csv` (lenition_loans.R). V_V stops voiced: native 65.2% vs loan-spelled 22.3% (CH,
  6,584 vs 932 words); 73.6% vs 41.3% (CV). LMM loan effect on vf_mid: −0.373 [−0.394, −0.351] CH,
  −0.294 [−0.322, −0.266] CV; at matched duration −0.316 / −0.234. Loan stops are also longer (median 90 vs 70 ms CH).
- Note: one low-voicing native-looking item, хутшӑннӑ /tʃ/, is probably т+ш merged by the aligner as tʃ —
  i.e. a cluster, not a V_V affricate. Not corrected.

## 15:50 Step 3 — geminate timing
- Existing outputs read first: gemination_models.csv (CH only: long/short ratio 1.11–1.71 by place, mː vː
  floor-clipped), gemination_weight_model.csv (final CV 2×2, additive), mora_evidence.csv (alternating vs
  non-alternating final vowels: null), methods_weight_prosody.md, SUPERSEDED.md 09-27 entries.
  None of them measures the vowel BEFORE a geminate; that is new here, and CV is new.
- pbase_gemination_typology.csv has only rule statements (Estonian 'X → long / V__# under stress', Eastern
  Khanty 'X → long / V__V'), no durations -> the Estonian/Khanty comparison has to come from phonetic
  literature; nothing durational was retrievable for Khanty tonight.
- Tokens: word-internal V1 C(ː) V2 (`geminate_timing_tokens.csv.gz`, 269,964; mː/vː geminates and loan-only
  consonants dropped) and V1 + {singleton, geminate, heterosyllabic cluster} (`v1_context_tokens.csv.gz`).
- Models (log duration; controls: consonant identity, vowel identity, A6 stress, first syllable, word length,
  utterance-final word, articulation rate; RE as before): `geminate_timing.R`, `v1_context.R`,
  `timing_by_class.R`. One CH model in geminate_timing.R warned 'failed to converge, 1 negative eigenvalue';
  the per-class refits in timing_by_class.R converged and are the ones reported.
- Results (`timing_by_class_models.csv`), % change vs singleton:
  V1 before obstruent geminate +5.7 [4.6, 6.9] CH, +3.3 [0.7, 6.0] CV; before sonorant geminate +13.9 [12.9, 14.9]
  CH, +11.7 [9.5, 14.0] CV. V1 before an obstruent-initial cluster −13.2 [−13.7, −12.7] CH, −9.1 [−10.3, −7.8] CV;
  sonorant-initial cluster −1.5 / −2.4. V2 after geminate: +2.4 [1.1, 3.8] / +4.6 [1.5, 7.8] (obstruent),
  +3.5 [2.3, 4.6] / +7.5 [4.9, 10.0] (sonorant). Reduced V1 before obstruent geminates: −0.2% [−3.6, 3.2] CH,
  −3.3% [−12.4, 6.8] CV (geminate_timing_models.csv) -> no lengthening there either.
- So: no compensatory (closed-syllable) shortening before geminates, while clusters do shorten V1; and no
  foot-isochrony shortening of V2. Not Finnic/Estonian-like; closer to the Japanese / Sakha V1 pattern.

## 16:05 Step 4 — fleeting vowels
- Floor: 30 ms in both corpora (minimum observed duration; MFA's 3 × 10 ms frame minimum). Floor-length
  vowels: reduced 9.1% (CH all voices) / 11.8% (CV); full 3.4% / 7.5% (QC-passed files).
- Acoustic presence test: for word-internal vowels between two voiceless obstruents, sum the voiced ms over
  C1+V+C2 (alignment-robust); 'absent' = ≤ 5 ms (≤ 1 frame) of voicing in the whole span.
  `fleeting_TVT_by_vowel.csv`: CH voice_main ӑ 55/11,631 = 0.47% [0.36, 0.62], i 38/6,569 = 0.58%, ӗ 0.17%,
  u 0.12%, a 0.08%, e 0.02%. CV: 2.3–6.0% for EVERY vowel including /a/ 5.7% -> CV is at alignment-noise level
  and cannot carry this test.
- Hand check of 5 'absent' and 3 floor-but-voiced CH tokens (`handcheck/fleeting_handcheck_grid.png`):
  кӑшкӑрса, кӗтсе, пӑхма, кӑштӑртаттарса, вӑхӑтра show no periodicity between the consonants (burst/aspiration
  noise runs into the fricative) -> devoiced or deleted, which the voicing measure cannot tell apart.
- GLMMs (`fleeting_models.R` -> `fleeting_models.csv`, nAGQ = 0):
  absent | T_V_T, CH (145 events / 76,288): reduced vs non-high full OR 4.51 [2.37, 8.57], high full OR 3.33
  [1.76, 6.29], stressed OR 0.17 [0.07, 0.42], +1 SD rate OR 1.33 [1.13, 1.57]. CV: no vowel-class effect
  (OR 1.28 [0.91, 1.79]) — consistent with noise.
  Floor | reduced vowel: CH 13,432 / 157,923; CV 4,947 / 41,968. Rate OR 1.49 / 1.33 per SD; stressed 0.22 / 0.54;
  after sonorant 1.35 / 1.76; before sonorant 1.35 / 1.05 (n.s. CV); word-final 0.35 / 0.45; ӗ vs ӑ 0.84 / 0.94 (n.s. CV).
- Sonorant contexts: intensity peak vs flanking sonorants is NOT diagnostic (`fleeting_RVR_intensity.csv`):
  24% of above-floor full non-high vowels already show no peak at 32-ms window resolution. Dead end.
- PBase P8 (Mari /e, ə/ → 0 next to /a/): word-final reduced vowels before a vowel-initial word are at the
  floor 9.4% (before #a) and 10.3% (before other #V) vs 3.4% before #C (CH; `fleeting_hiatus_P8.csv`).
  Hiatus favours floor-length vowels, but /a/ is not special, and the V–V boundary is where an aligner is least reliable.

## 16:20 Write-up and a correction
- First FINDINGS draft said Chuvash "matches none of the Finnic signatures". Corrected: the retrieved Sakha paper's
  review (Li & Kuang 2022) lists FINNISH among languages that lengthen V1 before geminates, so V1 lengthening is not
  diagnostic. The diagnostic retained is Estonian foot isochrony (V2 shortening after a long S1), which Chuvash lacks.
- Figures: `figures/fig_lenition.png|pdf`, `figures/fig_geminate_timing.png|pdf`, `figures/fig_fleeting.png|pdf`
  (figure-style rules; bbox overlap check flagged only figure-legend text boxes, visually clean on inspection).
- Disk: this directory is ~415 MB, almost all in `extraction/phones_*.csv` (per-phone measures, regenerable in
  ~30 min with extract_voicing.py). Not compressed, because compressing in place would delete the originals. Flagged for Kate before any commit.


## Correction (lead, 2026-10-02)
- 'Fully voiceless' was too strong for the word list above. учитель, капитан, Анюта, секретарь and батальон are at 0% voiced, but председатель 1.4%, Яков 2.0%, Степан 2.7%, Вероника 3.1% and литература 4.2% are not. The conclusion (loans resist lenition) is unaffected.
- Figure title (fig_lenition.png panel a, 'word-internal V_V and R_V only'): read it as 'strongest in'. Cross-word and pre-consonantal positions reach 0.3–0.43, i.e. intermediate, not zero (FINDINGS Q2 says so).
- Savelyev (2020) content (allophone distribution, geminates voiceless, Mari substratum via Kangasmaa-Minn 1998: 222) was read in a draft PDF whose text is not preserved in the transcript. The DOI is CrossRef-verified, and the Sociophonetics and Typology tracks independently retrieved consistent Savelyev content on dialects and harmony. The lenition description and the Kangasmaa-Minn sub-citation should still be checked against the published chapter before citation.
