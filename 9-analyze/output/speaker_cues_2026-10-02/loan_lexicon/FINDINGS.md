# Loan lexicon track — findings (2026-10-02)

Scripts: `9-analyze/analyses/speaker_cues/loan_lexicon/` (`00_export_leveled_words.R`, `lexicon_loan_flag.py`,
`01_build_and_validate.py`). Every number below is read from a file in this directory. Russian lexicon = **wordfreq 3.1.1**
(`large` Russian list, ё→е folded; 661,389 Cyrillic forms). Chuvash frequencies = overnight monolingual token table
(25.3 M tokens). Population = 35,420 spoken word types / 331,544 tokens (CH+CV, pre-cleaning; reconstructed exactly).

---

## Step 1. Build a lexicon-based loan flag

**Answer.** A word is flagged `loan_lexicon` when stripping a chain of listed Chuvash suffixes leaves a stem of at least 4 letters
that is (in one of 8 documented Chuvash spellings of an inflected Russian stem, e.g. машинӑ-на → машина, учител-ӗ → учитель,
кухньӑ-ра → кухня, пенси → пенсия) a Russian form with Zipf ≥ 3. Three evidence-derived vetoes remove native collisions:
**X1** the form is far more frequent in Chuvash text than in Russian (Zipf_cv − Zipf_ru > 1.23, the 99th percentile over known
letter-flagged loans); **X2** the match is a Russian oblique -е form of an a-stem noun; **X3** the word has a native
analysis as a Zheltov headword (not itself a loan spelling) + listed suffixes (ял-та, ан-не, кур-са, пул-ин, ватӑ). The vetoes
form the native-word exception list: 727 word types, 224 distinct Russian forms (`native_exception_list.csv`, with the rule and
evidence for each). `loan_combined` = `loan_full` OR `loan_lexicon`. In the leveled data, which already lack every letter-flagged
loan, the combined flag more than doubles the loan tokens. Most of the added tokens are Russian personal names (иван, петр,
анюта, татьяна) and native-letter loans (машина, культура, учитель, министр, техника).

**Key numbers**
- Leveled `vowels_spoken_annotated.rds` (31,103 word_label types, 303,139 word tokens; `loan_flags_by_word.csv`):
  `loan_full` 823 types / 3,986 tokens; `loan_lexicon` 1,487 / 7,089; `loan_combined` 1,839 / 8,690 (2.87% of word tokens).
  CH 1.21% → 2.65%, CV 1.65% → 3.54% of word tokens (`loan_share_by_speaker_id.csv`).
- Pre-cleaning spoken population (`loan_flags_spoken_preclean_types.csv`): loan_full 4,933 types / 18,840 tokens; lexicon adds
  1,029 types / 4,850 tokens → combined 5,962 / 23,690.
- Per speaker (26 speaker_ids with ≥ 200 leveled word tokens): combined loan share 2.1–5.0%, median 3.5%
  (`loan_share_by_speaker_id.csv`); per file in `loan_share_by_file.csv` (4,823 of 40,472 files have ≥ 10% loan tokens).
- Exception rules (`native_exception_list.csv`): X3 alone 440 types, X1 alone 82, X2 alone 15, combinations 190. Estimated cost
  on the Russian lexicon itself: X3 would veto 8.0% (532/6,612) and X1 0.4% (27) of Russian forms with Zipf ≥ 3 and ≥ 4 letters
  that are spelled with native letters only, so that is the most recall these vetoes can remove.

**Confidence:** medium. The procedure is transparent and every veto is rule-based. Residual collisions remain (Step 2).
**Caveats.**
- The REF list is IPA; I converted it to orthography with a fixed mapping and added the overnight invariant suffixes and 15 past-tense
  -т-/-ч- allomorphs (тӑм, тӗм, …), which REF lacks.
- wordfreq's Russian list contains Chuvash/Tatar web text for short strings (кун 3.65, кур 3.61), so frequency alone cannot
  guard short matches; the 4-letter stem floor and the vetoes do that work.
- Nativized loans spelled in Chuvash (сӗтел, салтак, шкул, пӑшал, вӑт) and 2–3-letter loans (ну) are out of reach by design.
- The vetoes resolve true homographs toward native: курса is the converb of кур- 'see', but it can also be the dative of the loan
  курс; likewise касса, карта (кар-та).
- The rule was revised after scoring (see Step 2).

**Files:** `loan_flags_by_word.csv` (required table; extra columns lexicon_variant, lexicon_suffix_chain, lexicon_zipf_ru/cv,
native_exception_rule/match, loan_lexicon_v1, in_handannotation), `loan_flags_spoken_preclean_types.csv`,
`native_exception_list.csv`, `loan_share_by_file.csv`, `loan_share_by_speaker_id.csv`.

---

## Step 2. Validate the lexicon flag

**Answer.** Against the 440 overnight hand labels, the lexicon flag on its own has perfect observed precision and moderate recall.
Combined with `loan_full`, it raises token-level recall from 0.63 to 0.91 with no loss of type precision. Token recall is the
quantity that matters for "loans hidden in the data". But the 440-sample contains only a handful of the cases the lexicon adds,
and four rule decisions were made after seeing validation errors. So the independent audit of the lexicon's new detections is the
better guide to precision: **about 0.90 by type and 0.85 by token**. Every error in that audit is a native Chuvash verb or noun
form whose string is also a Russian form (парам, персе, курсах, именни). The combined flag's overall precision is therefore
≈ 0.97 (type) / 0.96 (token), not 0.99.

**Key numbers** (`loan_lexicon_validation.csv`; stratified estimators reproducing the overnight loan_full figures exactly;
440 draws / 420 types; 2,000 stratified bootstrap reps; gold U counted as non-loan):

| classifier | type precision | type recall | token precision | token recall |
|---|---|---|---|---|
| lexicon (final) | 1.000 [1.000, 1.000] | 0.665 [0.570, 0.751] | 1.000 [1.000, 1.000] | 0.713 [0.528, 0.849] |
| loan_full (overnight) | 0.985 [0.971, 0.996] | 0.924 [0.802, 1.000] | 0.991 [0.978, 0.999] | 0.634 [0.451, 0.880] |
| combined (final) | 0.986 [0.972, 0.997] | 1.000 [1.000, 1.000]* | 0.994 [0.984, 0.999] | 0.909 [0.737, 1.000] |
| lexicon v1 (pre-registered) | 1.000 | 0.656 [0.561, 0.742] | 0.906 [0.710, 1.000] | 0.591 [0.404, 0.773] |
| combined v1 (pre-registered) | 0.986 [0.971, 0.997] | 0.991 [0.971, 1.000] | 0.922 [0.771, 0.998] | 0.786 [0.589, 1.000] |

\* Degenerate bootstrap: the S4/S5 SRS draws contain only 1 loan each and no misses. One-sided 95% Clopper–Pearson bounds on
the miss rate in those strata (5.8%, 3.7%) put a conservative lower bound of **0.82** on combined type recall
(`combined_recall_stratum_bounds.csv`, `combined_derived_estimates.csv`).

- **Independent audit** of the final flag's new detections (lexicon & not loan_full, outside the annotated types; 1,023 types /
  4,771 tokens; `lexicon_newflag_audit.csv`, `lexicon_newflag_audit_summary.csv`): type precision 0.90 [0.84, 0.96]
  (80 SRS draws: 7 native, 1 unsure); token precision 0.85 [0.75, 0.93] (60 token-PPS draws: 9 native).
  Audit-weighted precision of `loan_combined` over the population: 0.971 (type) / 0.962 (token) (`combined_derived_estimates.csv`).
- Errors in the 440-sample (final rules). False positives of combined: хистенипе, асаилӳ (both loan_full; native), and чпун,
  пратьякас (loan_full; gold "unsure"). The lexicon flag itself has no false positives there. False negative of combined: пӑшал
  (old nativized loan < пищаль, gold "probable"). New true detections by the lexicon: эксперт-сене, илья, чапаев, пенси-е,
  кухньӑ-на, интерес-лӗ.
- v1 errors that motivated the revision: така (FP, → такая), пенсие and кухньӑна (FN). The revision then created and removed
  one more (никама → ника), so four decisions were informed by validation errors (NOTEBOOK §02).
- Census of the 400 most frequent unflagged types (overnight, 140,699 tokens): lexicon flags 1 (иван, a loan) and 0 of 392 native
  types.
- Sensitivity (`loan_lexicon_sensitivity_grid.csv`): without vetoes, lexicon token precision is 0.504 (12 FP draws). With X1+X3 it
  is 1.000 (0 FP draws). Z0 = 3.5 → lexicon type recall 0.561; MINLEX = 3 → 13 FP draws.

**Confidence:** medium for the gain in token recall (the direction is large and consistent across the 440-sample and the census);
medium–low for the exact precision of the new flags (agent-labelled audit, n = 80/60).
**Caveats.**
- Both the gold labels and the audit labels are the agent's lexical judgement, not a native speaker's. The audit labeller knew the
  words were flagged.
- Names count as loans (overnight policy). Names are a large share of the new flags, so a different decision on names changes
  every recall figure.
- Validation is on spoken types only; precision on Zheltov/monolingual types was not assessed.
- The final validation numbers are optimistic (post-hoc revisions); v1 figures are the unbiased reference for the procedure.

**Use as a sensitivity check.** Re-fit the stress-rule/cue models with `loan_combined` words removed, or with a loan × rule
interaction. Expect a small effect overall: loans are ~3% of leveled word tokens, and their share varies little across speakers
(2.1–5.0%). Speaker-level "different rule" claims should still be checked on the 4,823 files where loans are ≥ 10% of tokens.
About 10–15% of the new flags are native verb forms. If removing them matters, use `loan_full` + names-only as a tighter variant.

**Files:** `loan_lexicon_validation.csv`, `loan_lexicon_validation_rerun.csv`, `lexicon_newflag_audit.csv`,
`lexicon_newflag_audit_summary.csv`, `combined_recall_stratum_bounds.csv`, `combined_derived_estimates.csv`,
`loan_lexicon_sensitivity_grid.csv`, `fig_loan_lexicon_validation.png`.

## Questions for Kate
1. Should Russian personal names (Иван, Петр, Анюта, Татьяна …) count as loans for the stress analyses? They are the largest
   block of new flags. Removing them, or keeping them as a separate stratum, would change the sensitivity check.
2. The residual false positives are native verb forms (парам, персе, именни, салатаҫҫӗ). Adding a verb-root list (Zheltov verbs
   with their native conjugation endings, e.g. -ам, -аҫҫӗ, -нчӗҫ) would remove most of them. Is there a POS-tagged Chuvash
   lexicon in the project I could use instead of the bare Zheltov headwords?
3. Could a Chuvash speaker check `lexicon_newflag_audit.csv` (140 rows) and the top of `native_exception_list.csv`? Both were
   labelled by the agent.
