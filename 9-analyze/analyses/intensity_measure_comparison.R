# =============================================================================
# intensity_measure_comparison.R
#
# QUESTION: which intensity measure should the paper use as its acoustic
# correlate of stress, and does the choice change which stress rule the
# acoustics favour?
#
# WHY THIS IS A QUESTION AT ALL -- a data-quality problem in stage 7
# -------------------------------------------------------------------
# intensity_step1..20 are supposed to be 20 equidistant intensity readings
# across each vowel. They are not all readings: 71% of the cells are exactly
# 0.0, and 0 dB is not a physically possible value in a recording (it is the
# threshold of hearing). The zeros are Praat "undefined" returns written out
# as 0 by the extraction, and they are already 0 in
# 7-extract/contours/.../contours_output.csv -- they are NOT introduced by
# the R pipeline.
#
# They are also not random. The pattern is exactly symmetric about the vowel
# midpoint: steps 1, 2, 19 and 20 are 0 for 100% of vowels, steps 10 and 11
# are never 0, and the number of valid steps is always even. This is the
# signature of Praat's intensity analysis window: intensity is undefined
# within half a window-length of each edge of the analysed interval, so
# short vowels get very few valid readings. 42% of vowels (121,179 of
# 287,418) have only TWO valid readings -- steps 10 and 11, the midpoint.
#
# The consequence: the count of valid steps correlates with duration at
# r = 0.93. Any measure computed over "the valid steps" therefore has
# duration smuggled into it, and since stressed vowels are longer, that
# leaks into the stress effect the paper wants to report.
#
# CANDIDATE MEASURES (all in dB except int_total)
#   int_point       `intensity` column -- FAVE single-point measurement.
#                   Independent of the step series entirely.
#   int_midpoint    mean of steps 10 and 11. Always exactly 2 samples at the
#                   same relative position, so no duration confound by
#                   construction. Available for 100% of rows.
#   int_mean_valid  mean of the non-zero steps. Window widens with duration
#                   and so pulls in lower-amplitude vowel edges -> biased
#                   DOWNWARD for long vowels.
#   int_peak        `peak_intensity` = max over the non-zero steps. A maximum
#                   over more samples is larger in expectation, so this is
#                   biased UPWARD for long vowels (extreme-value bias).
#                   This is what stress_rule_comparison.R currently uses.
#   int_total       `total_intensity` = sum of all 20 steps, zeros included.
#                   Retained only to document what it measures; it correlates
#                   with duration at r = 0.91 and with the valid-step count
#                   at r = 0.99. It is a duration measure. Do not use it.
#
#   log_duration    included as a reference DV, not an intensity measure, so
#                   the rule ranking under intensity can be compared with the
#                   rule ranking under duration.
#
# CANDIDATE RULES: the same nine as stress_rule_comparison.R (A6/A5/A4,
# B6/B5/B4, final, initial, weight), derived by the same logic.
#
# OUTPUTS (to 9-analyze/output/)
#   intensity_measure_diagnostics.csv  per-measure descriptives + confounds
#   intensity_step_bias.csv            peak-vs-midpoint gap by valid-step count
#   intensity_rule_models.csv          54 models: 9 rules x 6 DVs
#
# NOTE ON AIC: AIC is comparable only WITHIN a dependent variable, never
# across them -- different DVs are different response scales. The rank
# column is therefore computed within each DV.
# =============================================================================

source(here::here("9-analyze", "config", "phonology_params.R"))
source(here::here("9-analyze", "config", "paths.R"))

suppressPackageStartupMessages({
  library(tidyverse)
  library(lme4)
  library(lmerTest)
  library(broom.mixed)
})

OUT_DIR <- here::here("9-analyze", "output")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

RULES <- c("A6", "A5", "A4", "B6", "B5", "B4", "final", "initial", "weight")
IMEAS <- c("int_point", "int_midpoint", "int_mean_valid", "int_peak", "int_total")
DVS   <- c(IMEAS, "log_duration")

# ---- 1. Load ----------------------------------------------------------------

zheltov <- readRDS(file.path(PATHS$leveled_dir, "zheltov_annotated.rds"))
mono    <- readRDS(file.path(PATHS$leveled_dir, "mono_annotated.rds"))
vowels  <- readRDS(file.path(PATHS$leveled_dir, "vowels_spoken_annotated.rds"))

cat(sprintf("Loaded %d vowel tokens\n", nrow(vowels)))

# ---- 2. Build the candidate intensity measures ------------------------------
# S holds the step series with the undefined-coded-as-0 cells set to NA, so
# that rowMeans(na.rm = TRUE) averages over real readings only.

step_cols <- paste0("intensity_step", 1:20)
S <- as.matrix(vowels[, step_cols])
n_zero_cells <- sum(S == 0)
S[S == 0] <- NA_real_

cat(sprintf("Step series: %.1f%% of cells were 0 (undefined) and are now NA\n",
            100 * n_zero_cells / length(S)))

vowels <- vowels %>%
  mutate(
    n_valid_steps  = rowSums(!is.na(S)),
    int_midpoint   = rowMeans(S[, c(10, 11)], na.rm = TRUE),
    int_mean_valid = rowMeans(S, na.rm = TRUE),
    int_point      = intensity,
    int_peak       = peak_intensity,
    int_total      = total_intensity
  )

# ---- 3. Diagnostics: what does each measure actually track? -----------------

diagnostics <- map_dfr(IMEAS, function(m) {
  x <- vowels[[m]]
  tibble(
    measure          = m,
    n_finite         = sum(is.finite(x)),
    pct_missing      = round(100 * mean(!is.finite(x)), 2),
    min              = round(min(x, na.rm = TRUE), 1),
    median           = round(median(x, na.rm = TRUE), 1),
    max              = round(max(x, na.rm = TRUE), 1),
    sd               = round(sd(x, na.rm = TRUE), 2),
    # the two confound diagnostics that decide this question
    r_with_duration  = round(cor(x, vowels$duration,      use = "complete.obs"), 3),
    r_with_n_valid   = round(cor(x, vowels$n_valid_steps,  use = "complete.obs"), 3),
    r_with_midpoint  = round(cor(x, vowels$int_midpoint,   use = "complete.obs"), 3)
  )
})

write_csv(diagnostics, file.path(OUT_DIR, "intensity_measure_diagnostics.csv"))
cat("\n--- MEASURE DIAGNOSTICS ---\n"); print(diagnostics, width = Inf)

# Extreme-value bias made explicit: how far peak sits above the midpoint as a
# function of how many samples the maximum was taken over.
step_bias <- vowels %>%
  group_by(n_valid_steps) %>%
  summarise(
    n                = n(),
    median_duration  = round(median(duration), 1),
    mean_midpoint    = round(mean(int_midpoint,   na.rm = TRUE), 2),
    mean_mean_valid  = round(mean(int_mean_valid, na.rm = TRUE), 2),
    mean_peak        = round(mean(int_peak,       na.rm = TRUE), 2),
    peak_minus_mid   = round(mean(int_peak - int_midpoint, na.rm = TRUE), 2),
    .groups = "drop"
  )

write_csv(step_bias, file.path(OUT_DIR, "intensity_step_bias.csv"))
cat("\n--- EXTREME-VALUE BIAS IN peak_intensity ---\n"); print(step_bias, n = Inf)

# ---- 4. Derive the nine rules (same logic as stress_rule_comparison.R) ------

# vowel_cat_6/5/4 now come straight from 04_annotate.R under these
# names; the rename that used to live here is gone.

vowel_cat_lookup <- bind_rows(
  zheltov %>% distinct(vowel_label, vowel_cat_6, vowel_cat_5, vowel_cat_4),
  mono    %>% distinct(vowel_label, vowel_cat_6, vowel_cat_5, vowel_cat_4)
) %>% distinct()

stopifnot(
  "vowel_label -> cat lookup is not one row per phoneme" =
    n_distinct(vowel_cat_lookup$vowel_label) == nrow(vowel_cat_lookup),
  "a spoken vowel_label is missing from the written lookup" =
    all(unique(vowels$vowel_label) %in% vowel_cat_lookup$vowel_label)
)

vowels <- vowels %>% left_join(vowel_cat_lookup, by = "vowel_label")

predict_A <- function(is_full, sidx) if (any(is_full)) max(sidx[is_full]) else min(sidx)
predict_B <- function(is_full, sidx) if (any(is_full)) max(sidx[is_full]) else NA_integer_

stress_preds <- vowels %>%
  distinct(word_id, sidx, sN, syllable_coda,
           vowel_cat_6, vowel_cat_5, vowel_cat_4) %>%
  group_by(word_id) %>%
  arrange(sidx, .by_group = TRUE) %>%
  summarise(
    pred_final   = max(sidx),
    pred_initial = min(sidx),
    pred_weight  = if (any(syllable_coda == "closed"))
                     max(sidx[syllable_coda == "closed"]) else max(sidx),
    pred_A6 = predict_A(vowel_cat_6 == "F", sidx),
    pred_A5 = predict_A(vowel_cat_5 == "F", sidx),
    pred_A4 = predict_A(vowel_cat_4 == "F", sidx),
    pred_B6 = predict_B(vowel_cat_6 == "F", sidx),
    pred_B5 = predict_B(vowel_cat_5 == "F", sidx),
    pred_B4 = predict_B(vowel_cat_4 == "F", sidx),
    .groups = "drop"
  )

# !is.na(.x) & sidx == .x, not sidx == .x: under Rule B a word with no full
# vowel has predicted_sidx = NA, meaning "nothing in this word is stressed".
# Every syllable in it must read FALSE, not NA, or those rows drop out of the
# Rule-B models and AIC stops being comparable across rules.
vowels <- vowels %>%
  left_join(stress_preds, by = "word_id") %>%
  mutate(across(paste0("pred_", RULES),
                ~ !is.na(.x) & sidx == .x,
                .names = "is_stressed_{.col}")) %>%
  rename_with(~ str_remove(., "pred_"), starts_with("is_stressed_pred_")) %>%
  mutate(
    z_freq   = as.numeric(scale(log_corpus_freq_smoothed)),
    z_rate   = as.numeric(scale(log_speech_rate)),
    z_relpos = as.numeric(scale(widx / wN))
  )

# ---- 5. Model data ----------------------------------------------------------
# Single row set for all 54 models, so AIC is comparable within each DV.

need <- c("vowel_label", "syllable_coda", "phrase_position",
          "z_relpos", "z_rate", "z_freq", DVS)
model_data <- vowels %>% filter(if_all(all_of(need), ~ !is.na(.x)))

cat(sprintf("\nModel rows: %d of %d | %d word types | %d recordings\n",
            nrow(model_data), nrow(vowels),
            n_distinct(model_data$word_label), n_distinct(model_data$file_name)))

# vowel_label rather than height+backness+rounding: with 8 vowel qualities
# those three features jointly determine vowel identity and are exactly
# collinear, so lmer drops a column and which one it drops need not be the
# same across models -- making coefficients incomparable. Random effect is
# file_name, not speaker_id, because speaker_id is ~1 distinct value and
# ~30% missing in these corpora.
CONTROLS <- "vowel_label + syllable_coda + phrase_position + z_relpos + z_rate + z_freq"

fit_one <- function(dv, rule) {
  f <- as.formula(sprintf("%s ~ is_stressed_%s + %s + (1 | word_label) + (1 | file_name)",
                          dv, rule, CONTROLS))
  lmer(f, data = model_data, REML = FALSE)
}

# ---- 6. Fit all 9 rules x 6 DVs --------------------------------------------

grid <- expand_grid(dv = DVS, rule = RULES)
cat(sprintf("\nFitting %d models (~30 s each)...\n", nrow(grid)))

results <- pmap_dfr(grid, function(dv, rule) {
  t0 <- proc.time()[["elapsed"]]
  m  <- fit_one(dv, rule)
  co <- broom.mixed::tidy(m, effects = "fixed") %>%
    filter(term == paste0("is_stressed_", rule, "TRUE"))
  el <- proc.time()[["elapsed"]] - t0
  cat(sprintf("  %-15s %-8s beta=%9.4f  AIC=%12.1f  (%.0fs)\n",
              dv, rule,
              if (nrow(co)) co$estimate else NA_real_, AIC(m), el))
  tibble(
    dv       = dv,
    rule     = rule,
    estimate = if (nrow(co)) co$estimate  else NA_real_,
    se       = if (nrow(co)) co$std.error else NA_real_,
    p_value  = if (nrow(co)) co$p.value   else NA_real_,
    AIC      = AIC(m),
    n_obs    = nobs(m)
  )
})

results <- results %>%
  group_by(dv) %>%
  mutate(
    AIC_rank  = rank(AIC),                 # within DV only -- see header note
    dAIC_best = round(AIC - min(AIC), 1)
  ) %>%
  ungroup() %>%
  arrange(dv, AIC)

write_csv(results, file.path(OUT_DIR, "intensity_rule_models.csv"))

cat("\n--- RULE COMPARISON BY DEPENDENT VARIABLE ---\n")
results %>%
  mutate(across(c(estimate, se), ~ round(.x, 4)),
         AIC = round(AIC, 1), p_value = signif(p_value, 3)) %>%
  split(.$dv) %>%
  walk(~ { cat("\n", unique(.x$dv), "\n"); print(as.data.frame(.x), row.names = FALSE) })

cat("\n\nWrote 3 CSVs to", OUT_DIR, "\n")
