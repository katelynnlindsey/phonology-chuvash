# analyses/00_session_setup.R
# ================================================================
# SOURCE THIS AT THE START OF EVERY ANALYSIS SCRIPT
#
#   source("analyses/00_session_setup.R")
#
# After sourcing you have:
#
#   SPOKEN DATA (acoustic measurements)
#   vowels    — vowel-level, cleaned, annotated with all stress rules
#   syllables — syllable-level (vowels + syl_position)
#   words     — word-level, one row per word token
#   phrases   — utterance-level
#
#   WRITTEN DATA (lexical only, no acoustics)
#   zheltov   — Zheltov (1875) wordlist
#   mono      — monolingual text corpus
#
#   CONFIGURATION
#   All VOWEL_RULES, CLEANING thresholds, label maps from
#   config/phonology_params.R are available directly.
#
#   CONVENIENCE OBJECTS (derived from ACTIVE_RULE)
#   vowels_stressed / vowels_unstressed — filtered subsets
#   valid_words        — word_ids with complete syllable sets
#   exclusion_log      — full N-tracking table from cleaning pipeline
# ================================================================

source("config/phonology_params.R")
source("config/paths.R")

suppressPackageStartupMessages({
  library(tidyverse)
  library(lme4)
  library(lmerTest)
  library(data.table)
})

# ── Load cleaned annotated data ──────────────────────────────────

.load <- function(name) {
  path <- file.path(PATHS$cleaned_dir, paste0(name, ".rds"))
  if (!file.exists(path)) {
    stop("File not found: ", path,
         "\nRun pipeline/run_pipeline.R first.")
  }
  readRDS(path)
}

vowels    <- .load("vowels_spoken_annotated")
syllables <- .load("syllables_spoken")
words     <- .load("words_spoken_annotated")
phrases   <- .load("phrases_spoken")
zheltov   <- .load("zheltov_clean")
mono      <- .load("mono_clean")

# ── Report data dimensions ───────────────────────────────────────

cat("\n══════════════════════════════════════════════════\n")
cat("  CHUVASH PHONOLOGY — ANALYSIS SESSION\n")
cat("══════════════════════════════════════════════════\n")
cat(sprintf("  Active stress rule : %s — %s\n",
            ACTIVE_RULE, VOWEL_RULES[[ACTIVE_RULE]]$label))
cat(sprintf("  Strong vowels      : %s\n",
            paste(active_strong(), collapse = " ")))
cat(sprintf("  Weak vowels        : %s\n",
            paste(active_weak(),   collapse = " ")))
cat("──────────────────────────────────────────────────\n")
cat("  SPOKEN DATA\n")
vowels %>%
  group_by(corpus) %>%
  summarise(
    vowels     = n(),
    words      = n_distinct(word_id),
    utterances = n_distinct(file_name),
    speakers   = n_distinct(speaker_id),
    .groups    = "drop"
  ) %>%
  print()
cat("  WRITTEN DATA\n")
cat(sprintf("  Zheltov  : %d word types\n",   n_distinct(zheltov$word)))
cat(sprintf("  Mono     : %d unique tokens\n", nrow(mono)))
cat("══════════════════════════════════════════════════\n\n")

# ── Convenience subsets ──────────────────────────────────────────

.stress_col <- paste0("stress_rule_", ACTIVE_RULE)

vowels_stressed   <- vowels %>% filter(.data[[.stress_col]] == "Stressed")
vowels_unstressed <- vowels %>% filter(.data[[.stress_col]] == "Unstressed")

valid_words <- words %>%
  filter(sN > 1) %>%
  pull(word_id)

# ── Exclusion log ────────────────────────────────────────────────

exclusion_log <- read_csv(
  file.path(PATHS$cleaned_dir, "exclusion_log.csv"),
  show_col_types = FALSE
)

cat("Cleaning pipeline summary (vowel counts):\n")
exclusion_log %>%
  select(step, corpus, n_vowels, vowels_excluded, pct_vowels_kept, reason) %>%
  print()