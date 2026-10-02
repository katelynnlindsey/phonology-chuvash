# Loan lexicon track — lab notebook (2026-10-02)

Scripts: `9-analyze/analyses/speaker_cues/loan_lexicon/`. Outputs: this directory.

## 00 Setup
- Read the `chuvash-corpus-pipeline` skill and the overnight contact-phonology FINDINGS/NOTEBOOK and `loan_classifier.py`.
- Installed **wordfreq 3.1.1** (pip, env `python`; approved by Kate). Russian list `large`: 713,447 forms; after
  lower-casing, ё→е folding (frequencies summed) and Cyrillic-only filter, 661,389 forms, of which 60,262 have Zipf >= 3.
  NB wordfreq's Russian list is contaminated by Chuvash/Tatar web text for short strings (e.g. кун 3.65, пур 2.52,
  хула 2.71, кур 3.61), which is why frequency alone cannot guard short matches.
- `00_export_leveled_words.R` (Rscript --vanilla, UTF-8): distinct word tokens from `data/leveled/vowels_spoken_annotated.rds`
  → `cache/leveled_word_tokens.parquet` (303,139 tokens, word_id unique, 31,103 word_label types).
- Pre-cleaning spoken population reconstructed exactly as overnight: CH word tokens from
  `7-extract/reextract/phones_chuvash_voice.csv` (distinct file_name × widx; includes /o/ words), CV from
  `contact_phonology/intermediate/raw_vowels_compact.csv` (distinct file_name × word_start × label); Cyrillic-only labels after
  `loan_classifier.normalise`. 35,420 types / 331,544 tokens; n_ch and n_cv equal the annotation file for 100% of annotated types.
- Overnight sampling strata reconstructed exactly (S1 2,280; S2 1,812; S3 898 with the *pre-fix* INIT_* behaviour; S4 2,367;
  S5 28,063); all 440 draws fall in their recorded stratum. The overnight `loan_full` estimates are reproduced to all printed
  digits by `estimates()` (type P 0.9853 / R 0.9238; token P 0.9908 / R 0.6339), so the estimator is the same.

## 01 Lexicon flag — design (fixed BEFORE scoring against the hand labels)
- Normalisation: `loan_classifier.normalise` (homoglyph fold, lower-case) + ё→е. Hyphenated words: each part evaluated.
- Suffixes: `REF` from `analyses/morph_validation.R` (67 IPA strings) converted to orthography (tɕ→ч ɕ→ҫ ʃ→ш ɵ→ӑ ø→ӗ, other
  letters 1:1) + the overnight invariant-suffix list (рӗ чӗ сем сен сене не ӗ ри ти хи ки ҫҫӗ рӗҫ ӗн ни асси ччӗ) + 15 allomorphs of
  the listed past suffix (-т-/-ч- for -р-: тӑм тӗм тӑмӑр тӗмӗр тӑр тӗр тӑн тӗн чӑм чӗм чӑр чӗр чӗҫ тӗҫ тӑҫ), added after a first look
  showed куртӑм 'I saw' unparsable. Single-letter suffixes are allowed because every strip is verified by the lexicon.
- Stripping: every split word = stem + chain where chain is segmentable into <= 4 listed suffixes and stem >= 3 letters
  (right-to-left, i.e. stems from longest to shortest).
- Lookup forms per stem (orthographic adaptation of Russian stems in Chuvash inflection): stem itself; final ӑ→а, ӗ→е, й→я;
  stem+ь, stem+а, stem+я (машинӑ-на→машина, учител-е→учитель, пенсий-ӗ→пенсия).
- Guards: Chuvash stem >= 4 letters (MINLEX) and Russian Zipf >= 3.0 (>= 1 per million; Z0). Chosen candidate = longest stem,
  then identity lookup before adapted lookups, then highest Zipf.
- Native-collision vetoes (a vetoed candidate falls through to shorter stems):
  - X1 Chuvash-dominant form: Zipf_cv(match) − Zipf_ru(match) > δ, Zipf_cv from the overnight monolingual token table
    (25,251,810 tokens). δ = 1.23 = 99th percentile of the same difference over 1,402 distinct lexicon matches of
    letter-flagged (loan_crude) words outside the annotation sample (median −0.23, 95th pct 0.84). I.e. no more Chuvash-dominant
    than 99% of known loans.
  - X2 Russian oblique form: match ends in -е and Russian has the -а/-я form with higher frequency (dative/prepositional of an
    a-stem; Chuvash borrows the nominative, cf. машина/машинӑ-). Fall-through recovers учителе → учител-е → учитель.
  - X3 Native dictionary parse: the word part = h + segmentable chain with h a Zheltov headword (22,180 forms), h not flagged by
    `loan_full`, and h either not a Russian form at Zipf >= 3, or (len(h) <= 3 and Zipf_cv(h) > Zipf_ru(h)); and h ≠ the match.
    (ял-та, ан-не, кур-са, пул-ин, ватӑ, шурӑ.) Its false-native rate was estimated on the Russian lexicon itself: of 6,612 Russian
    forms (Zipf >= 3, >= 4 letters) spellable with native letters and not flagged by loan_full, the **v1** X3 vetoes 565 (8.5%), mostly short
    oblique forms (анну, ирину, атаки) — an upper bound on what X3 can cost in recall. X1 vetoes 27 (0.4%). (The FINAL X3 of §02,
    with the loan-spelling and headword-frequency tests, vetoes 532 of the same 6,612 = 8.0%; that is the figure in FINDINGS.)
- loan_combined = loan_full OR loan_lexicon.
- Development look (guard/veto design) used only words OUTSIDE the 420 annotated types; the annotation sample was not inspected
  before scoring.

## 02 First scoring (v1, pre-registered) and revisions
- v1 vs the 440 hand labels: lexicon type P 1.000 / R 0.656, token P 0.906 / R 0.591; combined type P 0.986 / R 0.991,
  token P 0.922 / R 0.786 (`loan_lexicon_validation.csv`, rows "…v1 (pre-registered)").
- **Post-hoc revision after looking at three validation errors** (така FP via така+я → такая; пенсие and кухньӑна FN):
  (a) `+я` only after и (Russian -ия nouns; -ая is adjectival); `+а` only after a consonant; new `ьӑ→я` (кухньӑ-);
  (b) X3 headword test: Zheltov spells some loans in Chuvash form (пенси, интереслӗ), so a headword only counts as native
  evidence if it is not itself a loan spelling (Russian stem >= 4 letters at Zipf >= 3 + listed suffixes, or -и < -ия).
- Further revision from the NON-annotated development list (самай, какай → самая/какая; самант → саманта; шарламасӑр → шарль;
  миллиметр/литература lost): `й→я` only for -ий/-ей stems; loan-spelling test uses identity readings only; a >= 4-letter
  headword spelled as a Russian word (Zipf >= 2) is not native evidence.
- That last change created one validation FP (никама → ника-ма, because никам has Russian Zipf 2.06); fixed by reusing the X1
  criterion (headword exempt if Chuvash-dominant, Zipf_cv − Zipf_ru > δ; никам 5.58 vs 2.06). **Four decisions in total were
  informed by validation-set errors**, so the final validation figures are optimistic; v1 is the clean reference.
- Final rules are in `analyses/speaker_cues/loan_lexicon/lexicon_loan_flag.py`; `01_build_and_validate.py` rebuilds
  `loan_flags_by_word.csv` identically (all columns equal to the session output, checked) and re-scores
  (`loan_lexicon_validation_rerun.csv`; point estimates identical, CIs differ in the 3rd decimal from bootstrap RNG order).
  `cache/session_copy/` holds the pre-rerun session files used for that comparison.

## 03 Validation of the final rule
- Estimator: stratified (overnight design strata), type-level from SRS draws, token-level from SRS (S1–S3) + Hansen–Hurwitz on the
  token-PPS draws (S4, S5); 2,000 stratified bootstrap reps, percentile 95% CIs. Gold R = loan; U (2 draws) as non-loan, with an
  R+U sensitivity row. Reproduces the overnight loan_full estimates exactly.
- Because the 440-sample contains only ~7 draws where the lexicon adds something, I drew an **independent audit** of the final flag's
  new detections (lexicon & not loan_full, outside the annotated types; 1,023 types / 4,771 tokens): 80 SRS types + 60 token-PPS
  draws (seed 20261002), labelled by the agent from lexical knowledge (R/N/U with confidence, `lexicon_newflag_audit.csv`).
  Precision 0.90 [0.84, 0.96] (type), 0.85 [0.75, 0.93] (token). All 16 native false positives are Chuvash verb or noun forms whose
  stem+suffix string is a Russian form: парам, персе, курсах, салатаҫҫӗ, саланчӗҫ, именни, именмесӗр, вилле/вилли/виллине,
  сентре/сентри, купине, чашкӑрса. These were NOT used to change the rule.
- Independent check on the overnight census of the 400 most frequent unflagged types (8 loans, all loan_full-negative): the lexicon
  flags 1 (иван, correct) and none of the 392 native types; it misses марийка, васса, сӗтел, салтак, вӑт, якур, ну (nativized
  spellings, a name not in the Russian list, and a 2-letter particle).
- Sensitivity grid (`loan_lexicon_sensitivity_grid.csv`, post hoc): without vetoes 12 of the 440 draws are false positives and
  lexicon token precision is 0.50; X1+X3 alone give 0 false positives. Raising Z0 to 3.5 costs recall (lexicon type R 0.56).
