# =============================================================================
# stress_rule_comparison.R
#
# QUESTION: across the written and spoken Chuvash corpora, which candidate
# stress rule do the phonetic correlates (duration, intensity) and the
# phonological correlates (coda attraction, vowel-inventory breadth) point
# to most often as the one actually governing stress placement?
#
# Candidate rules -- nine in total, because "full vs. reduced" isn't a single
# fact about a vowel quality: it's defined three different ways (schemes 6,
# 5, 4), and each of Rule A and Rule B can be run against any of the three:
#   A6, A5, A4   rightmost full vowel (under scheme 6 / 5 / 4); else leftmost
#                reduced
#   B6, B5, B4   rightmost full vowel (under scheme 6 / 5 / 4); else no
#                stress at all
#   final        always stress the last syllable
#   initial      always stress the first syllable
#   weight       stress the rightmost closed (heavy) syllable; if none, falls
#                back to final stress (this fallback isn't fully determined
#                by the brief -- change predict_stress_weight() below for a
#                different default on all-open-syllable words)
#
# WHERE vowel_cat_6/5/4 COME FROM: they're a property of the vowel QUALITY
# (vowel_label), not of the corpus or the token -- the same 8 vowel labels
# and the same three-way full/reduced split appear in both zheltov_annotated
# and mono_annotated, and every vowel_label in the spoken data also appears
# in that lookup. So a single canonical vowel_label -> {6,5,4} lookup table
# built from the written corpora, joined onto the spoken vowel-level data by
# vowel_label, gives the spoken corpus the same three schemes -- confirmed
# by reapplying Rule A through that lookup and getting ~99.8% agreement with
# the pre-existing stressed_sidx_A6/B/C columns (which are exactly A6/A5/A4,
# just under their old letter names). That 99.8%-not-100% gap is presumably
# some edge case (diphthongs, ties) in however stressed_sidx_A6/B/C were
# originally computed; the pre-existing columns are treated as authoritative
# for A6/A5/A4 below rather than overwritten by the reimplementation, and
# B6/B5/B4 (not previously computed for the spoken corpus) are added via the
# same lookup + Rule B logic.
#
# DATA:
#   - zheltov_annotated.rds       written wordlist (52,171 syllable rows)
#   - mono_annotated.rds          written corpus, distinct word types drawn
#                                  from 2.9M sentences (1,466,800 syllable rows)
#   - words_spoken_annotated.rds  spoken corpus, one row per word TOKEN
#                                  (141,402 words; corpus = mfa / vox)
#   - vowels_spoken_annotated.rds spoken corpus, one row per vowel/syllable
#                                  nucleus TOKEN (287,418 rows)
#   Not used here (superseded by the four files above, which are strict
#   supersets of their columns): syllables_zheltov.rds, syllables_mono.rds,
#   syllables_spoken.rds, vowels_spoken.rds, words_spoken.rds,
#   phrases_spoken.rds.
#
# OTHER CORRECTIONS FROM THE PREVIOUS DRAFT, per your notes:
#   - phon_stress was assigned from whichever vowel-categorization rule was
#     active at the time plus stress_rule_A6 (confirmed empirically: it's
#     ~98% identical to stress_rule_A6, and stress_cat is 100% identical to
#     stress_rule_A6). Both are dropped rather than used as evidence.
#   - duration_matches_stress / intensity_matches_stress are themselves
#     rule-dependent, so they're dropped rather than used.
#   - Random effect uses file_name, not speaker_id, since speaker_id is
#     mostly unfilled (~1 distinct value, ~30% missing) whereas file_name is
#     complete and one-per-recording.
#   - phrase_position is categorical (initial/medial/final), not numeric;
#     the numeric position of a word within its phrase comes from widx/wN.
# =============================================================================

# This script previously relied on PATHS already existing in the global
# environment, so it only ran if config/paths.R had been sourced by hand
# first. Sourcing it here makes the script runnable on its own.
source(here::here("9-analyze", "config", "phonology_params.R"))
source(here::here("9-analyze", "config", "paths.R"))

library(tidyverse)
library(lme4)
library(lmerTest)
library(broom.mixed)
library(performance)

# ---- 0. Load ----------------------------------------------------------------

zheltov <- readRDS(file.path(PATHS$leveled_dir, "zheltov_annotated.rds"))
mono    <- readRDS(file.path(PATHS$leveled_dir, "mono_annotated.rds"))
words   <- readRDS(file.path(PATHS$leveled_dir, "words_spoken_annotated.rds"))
vowels  <- readRDS(file.path(PATHS$leveled_dir, "vowels_spoken_annotated.rds"))

# ---- 1. Clean up naming and drop non-informative / circular columns --------

# vowel_cat_6/5/4 and word_cat_6/5/4 now arrive under these names from
# 04_annotate.R, and stressed_sidx_A6/A5/A4 plus B6/B5/B4 are all
# computed there, so the renaming and reconstruction that used to
# happen here is gone. The circular columns this script used to drop
# (duration_matches_stress, intensity_matches_stress, phon_stress,
# stress_cat) are removed at source in 04_annotate.R.
words <- words %>%
  rename(given_A6 = stressed_sidx_A6,
         given_A5 = stressed_sidx_A5,
         given_A4 = stressed_sidx_A4)

RULES <- c("A6", "A5", "A4", "B6", "B5", "B4", "final", "initial", "weight")

# ---- 2. Rule functions -------------------------------------------------------
# Operate on one word's syllables, ordered by sidx 1..sN.

predict_stress_A <- function(is_full, sidx) if (any(is_full)) max(sidx[is_full]) else min(sidx)
predict_stress_B <- function(is_full, sidx) if (any(is_full)) max(sidx[is_full]) else NA_integer_
predict_stress_final   <- function(sidx) max(sidx)
predict_stress_initial <- function(sidx) min(sidx)
predict_stress_weight  <- function(is_closed, sidx) if (any(is_closed)) max(sidx[is_closed]) else max(sidx)

# One rule-derivation function used identically for every corpus: it only
# needs sidx, sN, syllable_coda, and the three vowel_cat_* columns per token.

derive_rules <- function(df, id_col) {
  df %>%
    group_by(across(all_of(id_col))) %>%
    arrange(sidx, .by_group = TRUE) %>%
    summarise(
      sN = dplyr::first(sN),
      pred_final   = predict_stress_final(sidx),
      pred_initial = predict_stress_initial(sidx),
      pred_weight  = predict_stress_weight(syllable_coda == "closed", sidx),
      pred_A6 = predict_stress_A(vowel_cat_6 == "F", sidx),
      pred_A5 = predict_stress_A(vowel_cat_5 == "F", sidx),
      pred_A4 = predict_stress_A(vowel_cat_4 == "F", sidx),
      pred_B6 = predict_stress_B(vowel_cat_6 == "F", sidx),
      pred_B5 = predict_stress_B(vowel_cat_5 == "F", sidx),
      pred_B4 = predict_stress_B(vowel_cat_4 == "F", sidx),
      .groups = "drop"
    )
}

# ---- 3. Written corpora: straightforward, they already carry vowel_cat_6/5/4

zheltov_rules <- derive_rules(zheltov, "word_label")
mono_rules    <- derive_rules(mono,    "word_label")

# ---- 4. Spoken corpus: build the canonical vowel_label -> {6,5,4} lookup
#         from the written corpora, join it onto the spoken vowel tokens by
#         vowel_label, then run the SAME derive_rules() function -----------

vowel_cat_lookup <- bind_rows(
  zheltov %>% distinct(vowel_label, vowel_cat_6, vowel_cat_5, vowel_cat_4),
  mono    %>% distinct(vowel_label, vowel_cat_6, vowel_cat_5, vowel_cat_4)
) %>% distinct()

stopifnot(
  "vowel_label -> vowel_cat_6/5/4 isn't a consistent per-phoneme lookup -- zheltov and mono disagree somewhere" =
    n_distinct(vowel_cat_lookup$vowel_label) == nrow(vowel_cat_lookup),
  "some spoken vowel_label isn't covered by the written lookup" =
    all(unique(vowels$vowel_label) %in% vowel_cat_lookup$vowel_label)
)

vowels <- vowels %>% left_join(vowel_cat_lookup, by = "vowel_label")

spoken_rules_token <- derive_rules(
  vowels %>% distinct(word_id, sidx, sN, syllable_coda, vowel_cat_6, vowel_cat_5, vowel_cat_4),
  "word_id"
)

# Validate the lookup-based A6/A5/A4 against the pre-existing given_A6/A5/A4
# before trusting the freshly-derived B6/B5/B4 alongside them.
validation <- words %>%
  select(word_id, given_A6, given_A5, given_A4) %>%
  left_join(spoken_rules_token %>% select(word_id, pred_A6, pred_A5, pred_A4), by = "word_id") %>%
  summarise(
    A6_agree = mean(given_A6 == pred_A6, na.rm = TRUE),
    A5_agree = mean(given_A5 == pred_A5, na.rm = TRUE),
    A4_agree = mean(given_A4 == pred_A4, na.rm = TRUE)
  )
cat("\nValidation -- lookup-based Rule A vs. pre-existing given_A6/A5/A4:\n")
print(validation)
cat("(expect ~99.8% -- if it's much lower, the vowel_label -> scheme lookup",
    "isn't matching what was originally used and the B6/B5/B4 below shouldn't be trusted.)\n")

# given_A6/A5/A4 (pre-existing, authoritative) + freshly-derived B6/B5/B4 and
# final/initial/weight (not previously computed for the spoken corpus).
words <- words %>%
  left_join(
    spoken_rules_token %>% select(word_id, pred_B6, pred_B5, pred_B4,
                                   pred_final, pred_initial, pred_weight),
    by = "word_id"
  ) %>%
  rename(pred_A6 = given_A6, pred_A5 = given_A5, pred_A4 = given_A4)

spoken_rule_cols <- paste0("pred_", RULES)

# ---- 5. PHONETIC EVIDENCE (spoken only): duration & intensity by rule ------

vowels <- vowels %>%
  left_join(words %>% select(word_id, all_of(spoken_rule_cols)), by = "word_id") %>%
  # !is.na(.x) & ... rather than sidx == .x: for B6/B5/B4, a word with no
  # full vowel gets predicted_sidx = NA (Rule B assigns no stress at all in
  # that word), and every syllable in it should read as unstressed (FALSE)
  # under Rule B, not as missing data. Plain `sidx == .x` would propagate
  # the NA and silently drop those syllables from the Rule-B models below.
  mutate(across(all_of(spoken_rule_cols), ~ !is.na(.x) & sidx == .x, .names = "is_stressed_{.col}")) %>%
  rename_with(~ str_remove(., "pred_"), starts_with("is_stressed_pred_")) %>%
  mutate(
    z_log_corpus_freq_smoothed = as.numeric(scale(log_corpus_freq_smoothed)),
    z_log_speech_rate          = as.numeric(scale(log_speech_rate)),
    # phrase_position is categorical (initial/medial/final), not numeric --
    # the numeric position of this word within its phrase comes from
    # widx/wN instead (word index over total words in the phrase).
    rel_phrase_position = widx / wN,
    z_rel_phrase_position = as.numeric(scale(rel_phrase_position))
  )
# (is_stressed_pred_A6 etc. get renamed to is_stressed_A6 / is_stressed_B6 / ...)

phon_model_data <- vowels %>%
  filter(!is.na(vowel_height), !is.na(vowel_backness), !is.na(vowel_rounding),
         !is.na(syllable_coda), !is.na(phrase_position), !is.na(z_rel_phrase_position),
         !is.na(z_log_speech_rate),
         !is.na(z_log_corpus_freq_smoothed), !is.na(log_duration), !is.na(peak_intensity))

cat("Rows available for duration/intensity models:", nrow(phon_model_data),
    "of", nrow(vowels), "\n")
# is_stressed_B6/B5/B4 is FALSE (not NA) for every vowel in a word that Rule
# B assigns no stress to at all under that scheme -- Rule B's prediction for
# those words IS "nothing here is stressed", so those syllables stay in the
# model as unstressed data points rather than being dropped. This means the
# B models are fit on the same full set of rows as A6/A5/A4/final/initial/
# weight (no NA-driven row loss), so AIC is directly comparable across all
# nine rules.

controls <- "vowel_label + syllable_coda +
             phrase_position + z_rel_phrase_position + z_log_speech_rate +
             z_log_corpus_freq_smoothed"

# vowel_height + vowel_backness + vowel_rounding were dropped in favor of
# vowel_label: with only 8 vowel qualities in the inventory, those three
# features jointly define vowel identity, and not every combination of
# their levels is attested -- entered as separate factors they produce
# exact linear dependencies, which is what "fixed-effect model matrix is
# rank deficient" is reporting. lmer handles it by dropping a column, but
# WHICH column gets dropped isn't guaranteed to be the same one across all
# nine rule-specific models, which would make the coefficients hard to
# compare. vowel_label (8 levels) is a strictly more complete, non-redundant
# stand-in -- it controls for the vowel's identity outright rather than
# reconstructing it from three collinear pieces.

fit_model <- function(dv, rule) {
  f <- as.formula(paste0(
    dv, " ~ is_stressed_", rule, " + ", controls,
    " + (1 | word_label) + (1 | file_name)"
  ))
  lmer(f, data = phon_model_data, REML = FALSE)
}

duration_models  <- setNames(lapply(RULES, fit_model, dv = "log_duration"),   RULES)
intensity_models <- setNames(lapply(RULES, fit_model, dv = "peak_intensity"), RULES)

summarize_effect <- function(models, dv_label) {
  map_dfr(names(models), function(r) {
    m <- models[[r]]
    coef_name <- paste0("is_stressed_", r, "TRUE")
    row <- broom.mixed::tidy(m, effects = "fixed") %>% filter(term == coef_name)
    tibble(
      dv = dv_label, rule = r,
      estimate = if (nrow(row)) row$estimate else NA_real_,
      se       = if (nrow(row)) row$std.error else NA_real_,
      p_value  = if (nrow(row)) row$p.value else NA_real_,
      AIC = AIC(m),
      marginal_R2 = tryCatch(performance::r2_nakagawa(m)$R2_marginal, error = function(e) NA_real_)
    )
  })
}

phonetic_comparison <- bind_rows(
  summarize_effect(duration_models,  "log_duration"),
  summarize_effect(intensity_models, "peak_intensity")
) %>% arrange(dv, AIC)

cat("\n--- PHONETIC EVIDENCE: duration & intensity effect of predicted stress, by rule ---\n")
print(phonetic_comparison, n = Inf)

# ---- 6. BOTTOM-UP DETECTED STRESS (spoken, rule-agnostic) -------------------
# longest_sidx (duration-based) and loudest_sidx (intensity-based) are
# computed directly from the raw phonetics, independent of any rule. Added
# here: an f0-based vote -- the syllable with the largest |f0_slope|,
# computed fresh from vowels (also raw-phonetics-based, not rule-dependent).

f0_vote <- vowels %>%
  filter(!is.na(f0_slope)) %>%
  group_by(word_id) %>%
  slice_max(abs(f0_slope), n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(word_id, f0_vote_sidx = sidx)

words <- words %>% left_join(f0_vote, by = "word_id")

detect_majority <- function(a, b, c) {
  pmap_int(list(a, b, c), function(x, y, z) {
    v <- c(x, y, z); v <- v[!is.na(v)]
    if (length(v) == 0) return(NA_integer_)
    tab <- table(v)
    top <- tab[tab == max(tab)]
    if (length(top) == 1) as.integer(names(top)) else NA_integer_  # unresolved tie
  })
}

words <- words %>%
  mutate(detected_sidx = detect_majority(longest_sidx, loudest_sidx, f0_vote_sidx))

cat("\nDetected-stress resolved for",
    round(mean(!is.na(words$detected_sidx)) * 100, 1),
    "% of tokens; duration/intensity/f0-slope 3-way agreement rate:",
    round(mean(words$longest_sidx == words$loudest_sidx &
               words$loudest_sidx == words$f0_vote_sidx, na.rm = TRUE), 3), "\n")

rule_vs_detected <- words %>%
  filter(!is.na(detected_sidx)) %>%
  select(word_id, detected_sidx, all_of(spoken_rule_cols)) %>%
  pivot_longer(all_of(spoken_rule_cols), names_to = "rule", names_prefix = "pred_",
               values_to = "predicted_sidx") %>%
  group_by(rule) %>%
  summarise(
    n = sum(!is.na(predicted_sidx)),
    accuracy = mean(predicted_sidx == detected_sidx, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(accuracy))

cat("\n--- BOTTOM-UP EVIDENCE: rule accuracy against detected stress (token level) ---\n")
print(rule_vs_detected, n = Inf)

# ---- 7. PHONOLOGICAL EVIDENCE (all three corpora, same 9 rules everywhere) -

build_syllable_table <- function(rules_df, syll_info, corpus_name) {
  syll_info %>%
    distinct(word_label, sidx, sN, syllable_coda, vowel_label) %>%
    left_join(rules_df %>% select(-sN), by = "word_label") %>%
    pivot_longer(starts_with("pred_"), names_to = "rule", names_prefix = "pred_",
                 values_to = "predicted_sidx") %>%
    mutate(
      is_predicted_stressed = !is.na(predicted_sidx) & sidx == predicted_sidx,
      has_coda = syllable_coda == "closed",
      corpus_source = corpus_name
    )
}

zheltov_syll <- build_syllable_table(zheltov_rules, zheltov, "zheltov")
mono_syll    <- build_syllable_table(mono_rules,    mono,    "mono")

# Predicted stress under any of these rules depends only on syllable
# structure and vowel quality, both constant across tokens of the same word
# type, so it should be constant across tokens too; group_by + first()
# collapses to one row per type (rather than distinct(), which would
# silently duplicate rows if any token disagreed).
spoken_type_rules <- words %>%
  group_by(word_label) %>%
  summarise(sN = dplyr::first(sN), across(all_of(spoken_rule_cols), dplyr::first), .groups = "drop")

spoken_syll_types <- vowels %>% distinct(word_label, sidx, sN, syllable_coda, vowel_label)
spoken_syll_long  <- build_syllable_table(spoken_type_rules, spoken_syll_types, "spoken")

all_syllables <- bind_rows(zheltov_syll, mono_syll, spoken_syll_long)

# -- 7a. Coda attraction: logistic regression, has_coda ~ predicted stress --

coda_results <- all_syllables %>%
  group_by(corpus_source, rule) %>%
  group_modify(~ {
    if (nrow(.x) < 20 || n_distinct(.x$has_coda) < 2) return(tibble())
    m <- glm(has_coda ~ is_predicted_stressed + sN, data = .x, family = binomial())
    s <- summary(m)$coefficients
    if (!"is_predicted_stressedTRUE" %in% rownames(s)) return(tibble())
    tibble(
      log_odds = s["is_predicted_stressedTRUE", "Estimate"],
      p_value  = s["is_predicted_stressedTRUE", "Pr(>|z|)"],
      n = nrow(.x)
    )
  }) %>% ungroup()

cat("\n--- PHONOLOGICAL EVIDENCE: coda attraction to predicted-stressed syllable ---\n")
cat("(positive log-odds = codas attracted to the predicted-stressed syllable)\n")
print(coda_results %>% arrange(corpus_source, p_value), n = Inf)

# -- 7b. Vowel inventory breadth: entropy of vowel_label distribution -------

shannon_entropy <- function(x) { p <- table(x) / length(x); -sum(p * log2(p)) }

inventory_results <- all_syllables %>%
  filter(!is.na(vowel_label)) %>%
  group_by(corpus_source, rule, is_predicted_stressed) %>%
  summarise(
    n_tokens = n(), n_distinct_qualities = n_distinct(vowel_label),
    entropy = shannon_entropy(vowel_label), .groups = "drop"
  ) %>%
  arrange(corpus_source, rule, is_predicted_stressed)

cat("\n--- PHONOLOGICAL EVIDENCE: vowel inventory breadth by predicted stress status ---\n")
print(inventory_results, n = Inf)

# ---- 8. MASTER COMPARISON TABLE ---------------------------------------------
# All nine rules scored on: (a) phonetic AIC rank for duration and intensity
# (spoken), (b) accuracy against the bottom-up detected stress (spoken), (c)
# coda-attraction direction/significance in the spoken corpus. See
# coda_results / inventory_results above for the written-corpus (zheltov,
# mono) phonological evidence on the same nine rules, which is the part of
# the evidence that lets A6/A5/A4 and B6/B5/B4 be told apart from each
# other, since only one scheme's worth of the given A predictions actually
# exists as ground truth in the spoken data.

aic_rank <- function(models, label) {
  tibble(rule = names(models), AIC = map_dbl(models, AIC)) %>%
    mutate("{label}_rank" := rank(AIC)) %>%
    rename("{label}_AIC" := AIC)
}

master_comparison <- rule_vs_detected %>%
  rename(detected_accuracy = accuracy, detected_n = n) %>%
  left_join(aic_rank(duration_models, "duration"), by = "rule") %>%
  left_join(aic_rank(intensity_models, "intensity"), by = "rule") %>%
  left_join(
    coda_results %>% filter(corpus_source == "spoken") %>%
      select(rule, spoken_coda_log_odds = log_odds, spoken_coda_p = p_value),
    by = "rule"
  ) %>%
  arrange(desc(detected_accuracy))

cat("\n================ MASTER RULE COMPARISON (spoken evidence) ================\n")
print(master_comparison, n = Inf, width = Inf)
cat("============================================================================\n")
cat("\nReading guide: the best-supported rule ranks high on detected_accuracy,\n",
    "has low duration_rank/intensity_rank (its stress predictor best explains\n",
    "the acoustics once controls are in), and shows significant, positive\n",
    "coda attraction (spoken_coda_p < .05, spoken_coda_log_odds > 0) in BOTH\n",
    "the spoken row here and the written-corpus rows in coda_results. A rule\n",
    "that wins on accuracy alone but loses on the AIC ranks is likely matching\n",
    "surface position for a reason unrelated to genuine phonetic prominence\n",
    "(e.g. final position via independent phrase-final lengthening) rather\n",
    "than because it's the real stress rule. Among A6/A5/A4 (and B6/B5/B4),\n",
    "whichever scheme shows the strongest and most consistent effect across\n",
    "ALL of these tables -- not just detected_accuracy -- is the best\n",
    "candidate for which full/reduced split is the phonologically real one.\n")
