# pipeline/02_clean.R
# ================================================================
# CLEANING PIPELINE — SPOKEN CORPORA
# Runs once; saves cleaned data and a full exclusion audit log.
#
# Every exclusion step is logged with N vowels / N words / N files
# so you always know the sample size at each decision point.
#
# Inputs:  data/cleaned/vowels_spoken_raw.rds  (from 01_load_raw.R)
# Outputs: data/cleaned/vowels_spoken_clean.rds
#          data/cleaned/exclusion_log.csv
# ================================================================

source("config/phonology_params.R")
source("config/paths.R")
library(tidyverse)
library(data.table)

# ── Exclusion log infrastructure ────────────────────────────────

.log <- list()

snapshot <- function(step, df, reason = "") {
  entry <- df %>%
    group_by(corpus) %>%
    summarise(
      n_vowels     = n(),
      n_words      = n_distinct(word_id,  na.rm = TRUE),
      n_utterances = n_distinct(file_name, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(step = step, reason = reason) %>%
    select(step, corpus, n_vowels, n_words, n_utterances, reason)
  .log[[length(.log) + 1]] <<- entry
  invisible(df)   # pass through so steps can be piped
}

save_log <- function(path) {
  log_df <- bind_rows(.log) %>%
    arrange(corpus, step) %>%
    group_by(corpus) %>%
    mutate(
      vowels_excluded  = lag(n_vowels,  default = first(n_vowels)) - n_vowels,
      words_excluded   = lag(n_words,   default = first(n_words))  - n_words,
      pct_vowels_kept  = round(n_vowels / first(n_vowels) * 100, 1)
    ) %>%
    ungroup()
  fwrite(log_df, path)
  cat("\n── Exclusion summary ───────────────────────────────────\n")
  print(log_df %>% select(step, corpus, n_vowels, vowels_excluded,
                           pct_vowels_kept, reason))
}

# ── Step 0: Load ─────────────────────────────────────────────────

cat("Step 0: Loading raw data...\n")
d <- readRDS(file.path(PATHS$cleaned_dir, "vowels_spoken_raw.rds"))
snapshot("00_raw", d, "all data loaded from 8-combine outputs")
cat(sprintf("  %d vowel rows | %d unique files\n",
            nrow(d), n_distinct(d$file_name)))

# ── Step 1: Target vowel labels only ────────────────────────────

cat("Step 1: Keeping only target vowel labels...\n")
d <- d %>%
  filter(label %in% TARGET_VOWELS_ARPABET) %>%
  mutate(label = recode(label, !!!ARPABET_TO_IPA))

snapshot("01_target_labels", d,
         paste("kept:", paste(TARGET_VOWELS_ARPABET, collapse = " ")))
cat(sprintf("  %d rows remain\n", nrow(d)))

# ── Step 2: Russian loanwords ────────────────────────────────────

cat("Step 2: Removing Russian loanwords...\n")
d <- d %>% filter(!is_russian_loan(word))

snapshot("02_loanwords", d, "Russian loanword pattern in word form")
cat(sprintf("  %d rows remain\n", nrow(d)))

# ── Step 3: Absolute duration bounds ────────────────────────────
# Rationale: durations outside [20, 400] ms are acoustically
# implausible for Chuvash vowels and most likely reflect MFA
# boundary errors (phone spanning a pause, or collapsed interval).

cat("Step 3: Duration bounds (MFA misalignment filter)...\n")
d <- d %>%
  filter(
    duration >= CLEANING$min_duration_ms,
    duration <= CLEANING$max_duration_ms
  )

snapshot("03_duration_bounds", d,
         sprintf("duration outside [%d, %d] ms removed",
                 CLEANING$min_duration_ms, CLEANING$max_duration_ms))
cat(sprintf("  %d rows remain\n", nrow(d)))

# ── Step 4: Absolute formant bounds ─────────────────────────────
# Values outside these ranges are acoustically impossible for
# human adult speech and indicate fave extraction errors.

cat("Step 4: Absolute formant bounds...\n")
d <- d %>%
  filter(
    is.na(F1) | between(F1, CLEANING$min_F1_hz, CLEANING$max_F1_hz),
    is.na(F2) | between(F2, CLEANING$min_F2_hz, CLEANING$max_F2_hz)
  )

snapshot("04_formant_bounds", d,
         sprintf("F1 [%d–%d Hz] or F2 [%d–%d Hz] violated",
                 CLEANING$min_F1_hz, CLEANING$max_F1_hz,
                 CLEANING$min_F2_hz, CLEANING$max_F2_hz))
cat(sprintf("  %d rows remain\n", nrow(d)))

# ── Step 5: IQR outlier removal (within vowel × stress × corpus) ─
# Removes statistical outliers within each cell.
# Groups with fewer than min_cell_n tokens are dropped entirely
# (not enough data to compute reliable quartiles).

cat("Step 5: IQR outlier removal within vowel × stress × corpus...\n")

remove_iqr <- function(df, col,
                       groups = c("label", "phon_stress", "corpus"),
                       k      = CLEANING$iqr_multiplier,
                       min_n  = CLEANING$min_cell_n) {
  if (!col %in% names(df)) {
    message("  Column '", col, "' not found — skipping.")
    return(df)
  }
  df %>%
    group_by(across(all_of(groups))) %>%
    filter(n() >= min_n) %>%
    mutate(
      .q1    = quantile(.data[[col]], 0.25, na.rm = TRUE),
      .q3    = quantile(.data[[col]], 0.75, na.rm = TRUE),
      .iqr   = .q3 - .q1,
      .lower = .q1 - k * .iqr,
      .upper = .q3 + k * .iqr
    ) %>%
    filter(is.na(.data[[col]]) |
           (.data[[col]] >= .lower & .data[[col]] <= .upper)) %>%
    select(!starts_with(".")) %>%
    ungroup()
}

for (col in CLEANING$iqr_cols) {
  before <- nrow(d)
  d      <- remove_iqr(d, col)
  cat(sprintf("  IQR on %-12s: removed %d rows\n", col, before - nrow(d)))
}

snapshot("05_iqr_outliers", d,
         paste("IQR outliers removed for:",
               paste(CLEANING$iqr_cols, collapse = ", ")))

# ── Step 6: Complete words only ──────────────────────────────────
# Remove polysyllabic words where at least one syllable has no
# measurement. These are unreliable for any word-level analysis
# and are a strong signal of alignment failure.

cat("Step 6: Removing polysyllabic words with missing syllables...\n")

complete_ids <- d %>%
  filter(sN > 1) %>%
  group_by(word_id) %>%
  filter(n_distinct(sidx) == first(sN)) %>%
  pull(word_id) %>%
  unique()

d <- d %>% filter(sN == 1 | word_id %in% complete_ids)

snapshot("06_complete_words", d,
         "polysyllabic words with ≥1 missing syllable removed")
cat(sprintf("  %d rows remain\n", nrow(d)))

# ── Step 7: Consistent word_category per word_id ─────────────────
# Removes artefacts from many-to-many joins in 8-combine where
# the same word_id was matched to multiple word_category values.

cat("Step 7: Removing words with conflicting word_category...\n")

consistent_ids <- d %>%
  group_by(word_id) %>%
  filter(n_distinct(word_category) == 1) %>%
  pull(word_id) %>%
  unique()

d <- d %>% filter(word_id %in% consistent_ids)

snapshot("07_consistent_word_cat", d,
         "word_id matched to >1 distinct word_category removed")
cat(sprintf("  %d rows remain\n", nrow(d)))

# ── Save outputs ─────────────────────────────────────────────────

out_rds <- file.path(PATHS$cleaned_dir, "vowels_spoken_clean.rds")
out_log <- file.path(PATHS$cleaned_dir, "exclusion_log.csv")

saveRDS(d, out_rds)
save_log(out_log)

cat(sprintf("\n✓ Clean data saved:    %s\n", out_rds))
cat(sprintf("✓ Exclusion log saved: %s\n",  out_log))
cat(sprintf("\nFinal: %d vowels | %d words | %d utterances\n",
            nrow(d), n_distinct(d$word_id), n_distinct(d$file_name)))