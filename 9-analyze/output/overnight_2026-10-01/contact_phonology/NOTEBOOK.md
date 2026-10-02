# Contact phonology — lab notebook (overnight 2026-10-01/02)

Scripts: `9-analyze/analyses/overnight/contact_phonology/`. Outputs: this directory. Session-kernel code
(Python, env `python`) that is not in a script file is described here step by step.

## 00 Setup (≈03:45 UTC)
- Read the `chuvash-corpus-pipeline` skill, `README_loading_data.md`, `SUPERSEDED.md`, the Segmental track's
  FINDINGS.md, `pbase_relevance.md` §P3/P6, `pbase_comparison.py` (source of the 73.0% / 36.5% figures).
- **Key structural fact:** `pipeline/02_clean.R:188` drops every word for which `is_loan()` is TRUE, so
  `data/cleaned` and `data/leveled` contain *no* words with б г д о ж ц ф з ё щ (or any Latin letter). Loan analyses
  must use pre-cleaning data: `data/loaded/vowels_spoken_raw.rds` (exported by the stalled first attempt to
  `intermediate/raw_vowels_compact.csv`, 615,634 vowel rows; reused, not regenerated), the Python phone table
  `7-extract/reextract/phones_chuvash_voice.csv` (CH only, 1,424,952 phones, includes /o/), and
  `data/loaded/zheltov_raw.rds` (23,608 words, includes loans such as абажур, аббат).
- `vowels_spoken_raw` has **no OW rows** (labels AA EY EH AH UW IY IX UX only): /o/ was dropped at load.
  OW rows with formants exist in `8-combine/all_chuvash_vowel_points.csv` (8,681 rows) — used in step 3.
- `01_export_written.R`: zheltov_raw and mono_raw (2,917,415 sentences) → `cache/*.parquet`.
- `02_mono_token_freq.py`: 25,251,810 tokens, 703,346 forms → `cache/mono_token_freq.parquet`.

## 01 Loan classifier
- **Dead end:** `03_russian_sentence_freq.py` tried to derive a Russian-attestation feature from Russian
  passages in the monolingual corpus (sentences without ӑ ӗ ӳ ҫ and with ≥2 Russian function words). Only
  1,955 sentences qualify and they are polluted by Chuvash sentences without Chuvash-only letters (тата 93,
  пур 23 hits, машина 0). Abandoned; not used.
- Wrote `loan_classifier.py` (8 named regex features; labels `loan_full`, `loan_vowelblind`, `loan_crude`,
  `loan_pipeline`). First pass showed false positives from the clitic -ҫке (INIT_CC), single-letter parts
  (шӑпӑр-р → INIT_R), native expressives (хашш, чӑрр → FINAL_GEM), medial -ика- (никам) and ӑ/ӗ hiatus
  (иӗм); patterns tightened before annotation of the final sample (FINAL_GEM → -сс/-лл in words without
  ӑӗӳҫ; HIATUS → full-vowel letters only; -ика only word-final/before ӑ; clitics skipped for INIT_*).
  The clitic fix was made AFTER the SRS sample was drawn, so S3 strata sizes are from the pre-fix
  version; predictions in the evaluation are from the final version.
- Population: 35,420 spoken word types (CH+CV, pre-cleaning, Cyrillic-only labels), 331,544 word tokens.
- Strata (from features): S1 consonant letter 2,280 types; S2 о/ё only 1,812; S3 other feature only 898;
  S4 unflagged ≥20 tokens 2,367; S5 unflagged rare 28,063. SRS 50/50/50/50/80 + token-PPS draws
  100 (S4) and 60 (S5), seed 20261001 / 7. 440 draws, 420 distinct types.
- Annotation by the agent from lexical knowledge (not a native speaker); each label has a confidence
  (c/p/u) and note → `loan_handannotation.csv`. Nativized Russian loans (шкул, хресчен, сӗтел, салтак, ретре)
  and Russian-form names count as Russian; older Turkic/Persian/Arabic loans (хуҫа, хурал, патша) as non-Russian.
- Census of the 400 most frequent still-unflagged spoken types (45% of unflagged tokens): 8 loans,
  1,495 tokens (васса uncertain) → `loan_census_top400_unflagged.csv`.

## 02 Harmony decomposition (session kernel, env `python`)
- Reproduced 73.0% (CH phone table, V8 vowels, /o/ excluded) exactly before splitting.
- CV vowel strings from `raw_vowels_compact.csv` (ARPAbet → config IPA via ARPABET_TO_IPA), word = (file_name, word_start).
- First suffix pass used raw orthographic tails after the last back vowel (too granular: `harmony_disharmonic_raw_endings.csv`);
  replaced by 14 ordered end-of-word regex categories (`CATS`, in session code; listed in the CSV category names).
- Initial bug: a column named `tail` collided with the pandas method; renamed `ending`.
- Zheltov types: orthographic vowel mapping а/я→a ӑ→ɵ у/ю→u ы→ʉ е/э→e и→i ӗ→ø ӳ→y о/ё→o (o excluded), consistent with
  `transliterate_word()`; monolingual frequency joined by exact lower-cased form (`in_wordlist` = in Zheltov).

## 03 Loan /o/ (session kernel)
- OW rows only in `8-combine/all_chuvash_vowel_points.csv` (8,681). Joined to word labels via raw vowels on (file_name, ARPAbet `word`) with
  time inside [word_start, word_end]: 7,151 labelled, 1,520 unlabelled (OW-only words such as monosyllables).
- Speaker: CV = speaker_id from raw vowels; CH = `voice_label` from `speaker_structure.csv`.
- First run crashed on a speaker whose 9-class CV confusion matrix lacked an ɵ column; fixed with a guarded getter.
- Russian-stress proxy for o: monosyllabic word (sN == 1). Durations in this table are in seconds (`dur`).

## 04 Loan stress (session kernel + `04_loan_stress_models.R`)
- First proxy (bare forms ending in the suffix, complete words only) gave just ~190 loan tokens; -ика also caught Russian
  genitives with penultimate stress (шарика, лесника). Rebuilt: the suffix may be followed by Chuvash suffix material
  (stress index counted from the word start), syllables missing only because they are /o/ are allowed, and -ика stems
  must be attested in Zheltov as X-ика. Checked by hand on 10 forms (учитель→2, учительсем→2, федерацийӗн→3, техникӑпа→1, республикинче→2).
- Orthographic vowel count must equal sN (drops words whose syllabification disagrees).
- R fit: native baseline subsampled to 12,000 files (seed 20261002). Two singular fits are recorded in `logs_04_loan_stress.txt`.

## 05 Lenition re-run (`05_lenition_loans_reclassified.R`)
- Word flags exported from the session kernel (33,834 word labels in `voicing_tokens.csv.gz`). The crude flag is recomputed in R
  verbatim from the Segmental script, and the crude no-duration estimates reproduce `lenition_loan_models.csv` exactly
  (CH −0.3725, CV −0.2943).

## 06 Figure + wrap-up
- `figures/fig_contact_overview.png` = first draft (panel c labels overlapped); fixed in
  `fig_contact_phonology_overview.png` / `_v3.png` (identical bytes; v3 is the cited one).
- Code provenance: steps 01–03 and the data prep for 04/05 ran in the session Python kernel (env `python`); the saved
  artifacts carry that code as lineage. Scripts on disk: `loan_classifier.py`, `01_export_written.R`,
  `02_mono_token_freq.py`, `03_russian_sentence_freq.py` (dead end), `04_loan_stress_models.R`,
  `05_lenition_loans_reclassified.R`. The stalled attempt's `00_export_raw_vowels.R` was reused for its output only.
- No `update_step_status` tool was available in this session; step completion is recorded here.
