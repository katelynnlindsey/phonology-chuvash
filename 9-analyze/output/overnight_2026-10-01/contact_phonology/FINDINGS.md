# Contact phonology — findings (overnight 2026-10-01/02)

Track: contact phonology (Russian loans). Scripts in `9-analyze/analyses/overnight/contact_phonology/`;
every number below is read from a file in this directory. CH = Chuvash Voice (one dominant reader),
CV = Common Voice (client IDs as speakers).

**Structural caveat for every loan analysis in the repo:** `pipeline/02_clean.R` (line 188) removes every
word for which `is_loan()` is TRUE, so `data/cleaned/` and `data/leveled/` contain no word spelled with
б г д о ж ц ф з ё щ. All loan/native comparisons here use pre-cleaning data (`data/loaded/`, the Python
phone table, `8-combine/all_chuvash_vowel_points.csv`). Loans that `is_loan()` misses (машина, учитель,
класс …) *are* in the leveled data.

---

## Q1. Classify Russian loans transparently

**Answer.** Precision is not the problem; recall is. On a stratified hand-annotated sample, words spelled
with any of о ё ф ц щ ъ б г д ж з are essentially all Russian loans (0 native words among 100 sampled
flagged types; the premise that native words often carry these letters is not supported in the spoken
corpora). What the letter flag misses is the large set of loans spelled with native letters only
(машина, учитель, класс, министр, шкул, Илья, пенсия, кухня, эксперт). Adding six phonotactic /
morphological features (word-initial cluster, initial р-, final -сс/-лл, vowel hiatus, non-initial э,
Russian derivational endings) raises type-level recall from 0.78 to 0.92 at a precision cost of 1.5 points.
Token-level recall stays low (≈0.63) because frequent nativized loans and names (сӗтел, салтак, вӑт, ну,
Иван, Марийка, Якур) carry no orthographic signal at all.

**Key numbers** (`loan_classifier_eval.csv`; population 35,420 spoken word types / 331,544 tokens, CH+CV
pre-cleaning; 440 annotation draws, 420 distinct types; 95% stratified bootstrap CIs):

| classifier | type precision | type recall | token precision | token recall |
|---|---|---|---|---|
| `loan_full` (8 features) | 0.985 [0.971, 0.996] | 0.924 [0.807, 1.000] | 0.991 [0.978, 0.999] | 0.634 [0.454, 0.880] |
| `loan_vowelblind` (no vowel-letter features) | 0.989 [0.972, 1.000] | 0.609 [0.512, 0.686] | 0.994 [0.984, 1.000] | 0.396 [0.260, 0.585] |
| `loan_crude` (Segmental track) | 1.000 | 0.783 [0.678, 0.855] | 1.000 | 0.471 [0.325, 0.679] |
| `loan_pipeline` (`is_loan()` replica) | 1.000 | 0.783 [0.678, 0.855] | 1.000 | 0.471 [0.325, 0.679] |

- Cross-check of token recall for `loan_full` by census of the 400 most frequent unflagged types
  (45% of unflagged tokens) plus the PPS draws for the remainder: 0.63 [0.50, 0.86]
  (`loan_classifier_token_recall_census_plus_pps.csv`, `loan_census_top400_unflagged.csv`).
- `is_loan()` and the crude flag are identical on this population (the only difference, ъ, never decides).
- **Circularity (lead's note confirmed):** `is_loan()` and the crude flag both fire on the vowel letters
  о/ё. 1,812 of the 4,092 letter-flagged spoken types (44%) are flagged *only* by о/ё (stratum S2). Any
  analysis of the vowel /o/ or of harmony that uses those flags conditions on the vowel inventory it is
  measuring. `loan_vowelblind` (consonant letters б г д ж з ф ц щ ъ, initial cluster, initial р-, final
  -сс/-лл) is the non-circular variant; it costs recall (0.61 type).
- Full-classifier false positives in the sample: хистенипе (-ист- in native хисте-), асаилӳ (compound
  hiatus), and two unclassifiable fragments (чпун, пратьякас).

**Confidence:** high for precision; medium for type recall; low for the exact token recall (5 loan draws among
91 PPS draws drive it).
**Caveats.** The gold labels are the agent's lexical judgement, not a native speaker's (23 "probable",
3 "unsure" of 440). Nativized loans and Russian-form names are counted as Russian; a different decision
about names (≈ a third of S2) would change token recall. Older Turkic/Tatar/Persian loans are counted as
native. The annotation is on spoken types; recall on Zheltov/monolingual types was not separately estimated.
**Files:** `9-analyze/analyses/overnight/contact_phonology/loan_classifier.py`, `loan_handannotation.csv`,
`loan_classifier_eval.csv`, `loan_census_top400_unflagged.csv`, `loan_classifier_token_recall_census_plus_pps.csv`.

---

## Q2. Decompose harmony leakage into loans and suffixes

**Answer.** Loans are a small part of the leak; invariant inflectional suffixes are most of it. Using the
non-circular loan flag (`loan_vowelblind`), loan tokens are 4–10% of disharmonic tokens and native words
alone are still only 74.6% (CH) / 78.6% (CV) one-backness. About two thirds of native disharmony is a back
stem followed by one of a short list of front-vowel suffixes that do not alternate: past 3sg -рӗ/-чӗ,
plural -сем/-сен(е), dative -не after a possessive/pronoun, possessive 3sg -ӗ, attributive -ри/-ти/-хи/-ки,
-ҫҫӗ, -рӗҫ, -ӗн, -ни, -асси, -ччӗ. Exempting those suffixes lifts native harmony to ≈92–93%. The 36.5% leak of
⟨ӗ⟩ after a back vowel at the word end is almost wholly suffixal: 98% of those tokens end in an invariant
inflection (CH), and at the stem level the back-context final reduced vowel is ⟨ӑ⟩ in 99.0% (CH) /
95.6% (CV) of tokens and 97.4% of native Zheltov citation forms. So the backness-conditioned final reduced
vowel (the Mari-like P6 pattern) is near-categorical in stems; what leaks is morphology.

**Key numbers**
- Reproduction: 73.0% one-backness polysyllabic tokens in the CH phone table (same code as
  `pbase_comparison.py`). CV: 78.0% (49,305 tokens).
- By loan status (`harmony_by_loan_status_spoken.csv`), tokens one-backness:
  CH native 74.6% (200,391 tokens / 29,560 types) vs loan 38.3% (9,033 / 2,770); CV native 78.6%
  (48,452 / 6,072) vs loan 43.8% (853 / 169). Loans' share of all disharmonic tokens: CH 9.9%, CV 4.4%
  (`loan_full`: 13.8% / 9.4%; crude: 11.4% / 5.0%).
- Written (`harmony_by_loan_status_written.csv`): Zheltov native types 85.0% one-backness (18,368 types) vs
  loans 32.5% (3,410); weighted by monolingual-corpus token frequency of those dictionary types (i.e. only
  `in_wordlist` forms): native 87.0%, loan 34.7%.
- Native disharmony structure (`harmony_native_disharmony_by_suffix.csv`, `harmony_native_summary.csv`):
  back→front (BF) 87.4% CH / 87.2% CV; front→back 6.8 / 7.0%; multi-switch 5.8 / 5.8%. Largest CH
  categories as % of native disharmonic tokens: -рӗ/-чӗ 15.4, plural -сем/-сен 14.3, dative -не 12.8,
  final -е (пурте, ҫуркунне …) 7.7, possessive -ӗ 6.5, attributive -ри/-ти… 4.5. Exempting the 12 invariant
  categories → 92.2% (CH) / 92.9% (CV) harmonic.
- Back-context final ⟨ӗ⟩ (`final_reduced_back_context_by_ending.csv`, `..._stem_level.csv`): native-only
  rate unchanged at 36.5% (CH, 42,775 tokens) and 29.9% (CV, 9,435), so loans contribute nothing to it.
  CH: -рӗ/-чӗ 50.5%, poss. -ӗ 20.8%, -рӗҫ/-чӗҫ 10.3%, -ҫҫӗ 9.9%, -ӗн 5.7%; residue 1.0% of stem-level
  tokens. CV: poss. -ӗ 32.6%, -ҫҫӗ 20.5%, -рӗ/-чӗ 15.6%; residue 4.4%. Zheltov native citation forms:
  113/4,328 = 2.6% (mostly lexicalised possessives амӑшӗ, ашшӗ, ordinals -мӗш, compounds).

**Confidence:** high for the direction (both corpora, both written sources); medium for exact category
shares — they come from orthographic end-of-word regexes, not a morphological parser.
**Caveats.** -чӗ is ambiguous (past 3sg vs possessive after т: ҫурчӗ, вӑхӑчӗ); "dative -не" includes
pronominal/postpositional forms (патне, ҫине-type). Loan recall is ≈0.61 types for the vowel-blind flag (Q1), so
some "native" disharmony is unflagged loans (Иван, Марийка, техника …). The FB residue (front stem → back
suffix/vowel, 7%) is dominated by names and lexical items (Иван, никам, нихҫан, хӗрарӑм). /o/ is excluded from the
vowel string (as in the original code), so loans are scored only on their other vowels. CH is one reader.
**Files:** `harmony_by_loan_status_spoken.csv`, `harmony_by_loan_status_written.csv`,
`harmony_native_disharmony_by_suffix.csv`, `harmony_native_summary.csv`, `harmony_disharmonic_raw_endings.csv`,
`final_reduced_back_context_by_ending.csv`, `final_reduced_back_context_stem_level.csv`.

**Bearing on the hypothesis.** It sharpens the P6 parallel with Mari: the stem-level conditioning of the
final reduced vowel by preceding backness is near-categorical (97–99%), and the "leak" is the
Turkic-style agglutinative inventory of non-harmonising suffixes. That part needs no contact explanation.

---

## Q3. Where is the loan vowel /o/ in the Chuvash vowel space?

**Answer.** In F1/F2 it falls on ⟨ӑ⟩ /ɵ/, not on /u/ or /a/, for every speaker with enough data
(18 of 18: 5 CH voices, 13 CV speakers). Within-speaker Lobanov distance o–ɵ is 0.01–0.44 SD against
0.38–1.10 SD for o–u. It is not simply merged, though. o is slightly lower and longer than ӑ (median 80 vs
70 ms, voice_main), and in **monosyllabic** loans (Russian-stressed by definition; the specific words were not recoverable, because monosyllabic OW tokens have no word label in the join) it is a distinct back rounded
mid vowel: lower F2 than /u/ and F1 between u and ɵ, 100 ms. Best reading: stressed loan /o/ is kept as a
separate back mid rounded vowel, and the bulk of loan /o/ tokens (polysyllables, where most о are
Russian-unstressed) sit on ⟨ӑ⟩. That is consistent both with Chuvash ⟨ӑ⟩ being itself a short rounded [ŏ]-type vowel
(its F2 is low in these data) and with Russian-style reduction of unstressed о. Tonight's data cannot separate those two
accounts (see Q4 on the missing stress lexicon).

**Key numbers** (`loan_o_vowel_space_by_speaker.csv`, `loan_o_mono_vs_poly.csv`; source
`8-combine/all_chuvash_vowel_points.csv` OW rows, 8,681 tokens, F1 200–1100 / F2 500–3500 Hz, Lobanov per speaker over all 9 vowels):
- Nearest native centroid: ɵ in 18/18 speakers (≥20 tokens each of o, u, ɵ, a). voice_main (n_o = 6,319): d(o,ɵ) 0.21
  [0.20, 0.23], d(o,u) 0.63, d(o,a) 1.2. o vs ɵ: F1 higher in 13/18 speakers, F2 lower in 13/18; median duration o > ɵ in 13/18.
- An LDA trained on the native vowels assigns voice_main o tokens 43% ɵ, 27% u, 22% a. In a 9-class cross-validated LDA,
  o is recovered 38.5% for voice_main and 0% for the 17 smaller speakers, where ɵ itself is recovered only 0–48%:
  ⟨ӑ⟩ and o occupy the same region.
- voice_main monosyllables (n = 262): zF1 −0.20, zF2 −1.15, 100 ms; polysyllables (n = 6,057): zF1 0.00, zF2 −0.85,
  80 ms; ɵ −0.14 / −0.69, 70 ms; u −0.64 / −0.90. CV pooled monosyllables only n = 20 (7 speakers): not assessed at that depth.
- Speaker variation: d(o,ɵ) ranges 0.01 (cv_105) to 0.44 (ch_voice_3). No speaker places o nearer u than ɵ. With
  ≤ 400 tokens for most speakers, the variation is not interpretable as sociolinguistic.

**Confidence:** medium-high that polysyllabic loan /o/ ≈ ⟨ӑ⟩ in quality. Medium that stressed (monosyllabic) /o/ is
distinct: one dominant reader, and the monosyllables are confounded with longer duration (less undershoot) and with
utterance position.
**Caveats.** OW rows are excluded from `data/loaded` and later stages, so this uses the raw combined FAVE table.
Checked: new-FAVE measured OW with the same `fave` point heuristic as every other label, at a median of 33.0% of the vowel (`loan_o_fave_point_heuristic_check.csv`), so the o placement is not a measurement-point artefact.
Monosyllabic OW words have no orthographic label in the join (their only vowel is o), so the word list behind them was not
inspected. F1/F2 only, so rounding (F3, lip) is not assessed. 1,520 OW tokens could not be joined to a word label.
**Files:** `loan_o_vowel_space_by_speaker.csv`, `loan_o_mono_vs_poly.csv`, `figures/fig_contact_phonology_overview_v3.png` panel c.

---

## Q4. Does loan stress follow the Chuvash rule?

**Answer (provisional).** Neither fully. The syllable that carries Russian stress (by a suffix proxy) is about
10% longer than the same position in native words or other loans, but it is not louder and its pitch is slightly *lower*.
By Kate's criterion (longer AND louder AND higher), that is not stress in the Chuvash acoustic sense. It looks more like a retained
Russian durational correlate. The loan's final syllable, which is where rule A6 places stress in 94% of these
loans, is 13% *shorter* than a native all-full final syllable but 0.2–0.3 st higher in pitch. Its intensity excess
(+0.55 dB) does not survive restriction to voice_main. So loans lack part of the native final lengthening. The Chuvash rule and the final
syllable cannot be separated in loans (collinear), so the "Chuvash rule" side of the question is
**not assessed** beyond that final-syllable contrast.

**Key numbers** (`loan_stress_models.csv`; LMM, (1|word)+(1|file), position (i of n) × utterance-final + vowel + corpus;
59,918 syllables = 1,741 loan syllables from 265 loan types / 35 speakers + a 12,000-file random subsample of native all-full words):
- Russian-stressed syllable: log duration +0.095 [0.062, 0.128] (≈ +10%); int_midpoint +0.11 dB [−0.32, 0.55];
  f0 −0.24 st [−0.42, −0.06].
- Loan word-final syllable vs native all-full final: log duration −0.135 [−0.169, −0.100] (≈ −13%), intensity +0.55 dB
  [0.10, 1.01], f0 +0.20 st [0.01, 0.39].
- Proxy coverage: 638 complete loan word tokens with a proxy class: Russian-final (-ист/-изм/-ент/-ант) 354 tokens,
  penult (-тель, -ци(я)) 217, antepenult (-ика, Zheltov-attested stems only) 67.
- Rule A6 ≠ final syllable in only 6.1% of these loan rows, so A6 and "final" are not separable in loans.
- Robustness (`loan_stress_models_robustness.csv`, `04b_loan_stress_robustness.R`). Russian-stressed duration effect: +0.106
  [0.069, 0.143] in voice_main only (1,325 loan syllables) and +0.109 [0.075, 0.142] in non-utterance-final words only. Intensity stays
  null in both, and f0 stays ≤ 0 (−0.19 [−0.39, 0.01]; −0.24 [−0.42, −0.06]). The loan-final intensity excess is *not*
  robust in voice_main only (+0.25 [−0.32, 0.82]). The final shortening (−0.12 / −0.13) and the final f0 excess (+0.31 / +0.19) are robust.

**Confidence:** low–medium. The duration effect is clear of zero. Intensity is null. The f0 effect is small and rests on stylised f0.
**Caveats.** **No Russian stress lexicon was available tonight** (none installable offline). The proxy covers only a few
fixed-stress suffixes, which biases the loan sample toward internationalisms and names of professions. Vowel letters
о/ё are missing from the raw vowel table (OW excluded at load), so loans containing о are analysed only if the o
syllable is not the one being measured. Native baseline subsampled (12,000 of the native files) for speed. Two of
the three fits were singular (a random-effect variance at zero). CH dominates the loan rows (519 of 638 tokens). Russian word
stress is itself realised mainly by duration and vowel quality, not by f0, so "longer but not higher" is what transfer
of Russian stress would predict. That makes the result suggestive of transfer, not evidence against stress.
**Files:** `9-analyze/analyses/overnight/contact_phonology/04_loan_stress_models.R`, `cache/loan_stress_syllables.csv`,
`loan_stress_models.csv`, `loan_stress_profiles.csv`, `logs_04_loan_stress.txt`.

---

## Q5. Voicing in loan stops, with the better classifier

**Answer.** The Segmental track's loan effect is robust to the classifier and gets slightly larger. The loans the crude flag
missed (machine-spelled loans such as учитель, класс, машина) are just as unlenited as the flagged ones: 21.8% vs
22.7% of V_V stops voiced in CH, 44.5% vs 41.3% in CV, against 66.4% / 74.6% in native words. Reclassifying them
moves the LMM loan effect from −0.373 to −0.380 (CH) and from −0.294 to −0.311 (CV): 2–6% larger in magnitude, with
overlapping CIs. Loan exemption from intervocalic lenition is therefore a property of the Russian stratum as a whole,
not of the voiced-letter spelling (the crude flag partly defines loans by б д г, the letters for the stops being measured).

**Key numbers** (`lenition_loan_reclassified_models.csv`, `lenition_loan_reclassified_descriptive.csv`; same token table
`segmental_acoustics/voicing_tokens.csv.gz` and same model as `lenition_loans.R`: vf_def_mid ~ loan + segment
(+ scaled log duration) + (1|word)+(1|file) [+ (1|speaker) in CV]; CH = voice_main only):

| corpus | loan definition | loan effect, no duration | with duration | loan tokens / words |
|---|---|---|---|---|
| CH | crude (Segmental) | −0.373 [−0.394, −0.351] | −0.316 [−0.337, −0.295] | 3,258 / 932 |
| CH | `loan_full` | −0.380 [−0.400, −0.361] | −0.326 [−0.346, −0.307] | 3,730 / 1,101 |
| CH | `loan_vowelblind` | −0.346 [−0.372, −0.319] | −0.292 [−0.318, −0.266] | 1,961 / 627 |
| CV | crude | −0.294 [−0.322, −0.266] | −0.234 [−0.259, −0.208] | 1,716 / 264 |
| CV | `loan_full` | −0.311 [−0.337, −0.286] | −0.249 [−0.272, −0.226] | 2,008 / 307 |
| CV | `loan_vowelblind` | −0.272 [−0.305, −0.239] | −0.220 [−0.250, −0.191] | 1,332 / 198 |

- Three-way stratum model (native / crude-flagged loan / newly-detected loan): CH −0.383 vs −0.364; CV −0.309 vs −0.324.
  The newly detected loans are indistinguishable from the crude-flagged ones.
- `loan_vowelblind` gives a *smaller* effect because it returns the о-only loans (Николай, район, совет …) to the
  "native" group. For consonant voicing, vowel letters are not circular, so `loan_full` is the right flag here.

**Confidence:** high (the comparison is a re-labelling of the same tokens; both corpora agree).
**Caveats.** Remaining unflagged loans (token recall ≈0.63, Q1) still sit in the native group, so the native rate is still
slightly understated. The CH descriptive table pools all CH voices (11), but the models use voice_main only.
**Files:** `9-analyze/analyses/overnight/contact_phonology/05_lenition_loans_reclassified.R`, `cache/voicing_word_loan_flags.csv`,
`lenition_loan_reclassified_models.csv`, `lenition_loan_reclassified_descriptive.csv`, `logs_05_lenition.txt`.

---

## Figure

`figures/fig_contact_phonology_overview_v3.png`: (a) one-backness rate for loans, natives, and natives with
invariant suffixes exempt; (b) endings behind back-context final ⟨ӗ⟩; (c) loan /o/ in voice_main's F1/F2 space
(ellipses = ±1 SD); (d) V_V stop voicing for native words, letter-flagged loans and newly detected loans.
(`fig_contact_overview.png` is an earlier draft with overlapping labels. Do not use it.)

## Questions for Kate

1. **Names and nativized loans.** Should Russian-form personal names (Иван, Николаевич, Петров) and old nativized loans
   (шкул, хресчен, сӗтел, салтак, ретре, пӑшал) count as "loans" for the phonology? Tonight they do. Token recall and the
   harmony/lenition loan shares move with this choice.
2. **`is_loan()` in `02_clean.R` removes every о-word before cleaning.** That makes all leveled-data analyses native-only by
   letter, but loans spelled with native letters (машина, учитель, класс) stay in. Do you want the stress-rule analyses
   re-run with `loan_full` exclusion, or loans kept as a flagged stratum?
3. **Elicitation target:** do speakers distinguish stressed loan /o/ from ⟨ӑ⟩ (e.g. *том* vs a ⟨ӑ⟩ monosyllable) and
   reduce unstressed loan о to ⟨ӑ⟩/[a]? The acoustics suggest yes (Q3), but one reader carries it.
4. **Elicitation target:** Russian stress in loans with Chuvash suffixes (учи́тель-сем vs учитель-се́м). Tonight's proxy
   says the Russian syllable keeps extra duration but not pitch or intensity (Q4).
5. A Russian stress dictionary (e.g. a Zaliznyak-derived list) would replace the suffix proxy. Can one be added to the
   project environment?
6. The annotation sample is the agent's judgement, not a native speaker's. Could a speaker re-check
   `loan_handannotation.csv` (440 rows; 26 marked probable/unsure)?

## Not assessed tonight
- Loan-classifier recall on written (Zheltov / monolingual) types separately from spoken types.
- The Chuvash rule (A6) in loans independently of the final syllable (collinear in 94% of loan rows).
- F3/rounding of loan /o/.
