# analyses/00_session_setup.R
# ================================================================
# SOURCE THIS AT THE START OF EVERY ANALYSIS SCRIPT
#
#   source(here::here("9-analyze", "analyses", "00_session_setup.R"))
#
# (here::here() rather than a relative path, so the script works whatever
#  the working directory is. File extensions are case-sensitive on Linux,
#  which is where the Binder build runs: every script in this project is
#  .R, never .r.)
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
#   zheltov     — Zheltov wordlist, word level (from cleaned/)
#   mono        — monolingual text corpus, word level (from cleaned/)
#   zheltov_ann — Zheltov, syllable level + annotations (from leveled/)
#   mono_ann    — monolingual, syllable level + annotations (from leveled/)
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

source(here::here("9-analyze", "config", "phonology_params.R"))
source(here::here("9-analyze", "config", "paths.R"))

suppressPackageStartupMessages({
  library(tidyverse)
  library(lme4)
  library(lmerTest)
  library(data.table)
})

# ── Load cleaned annotated data ──────────────────────────────────

# `dir` must be given explicitly: 02_clean.R writes to cleaned/, while
# 03_build_levels.R and 04_annotate.R write to leveled/. Defaulting it
# was how the four leveled/ files came to be looked up in cleaned/.
.load <- function(name, dir) {
  stopifnot(dir %in% c("loaded", "cleaned", "leveled"))
  path <- file.path(PATHS[[paste0(dir, "_dir")]], paste0(name, ".rds"))
  if (!file.exists(path)) {
    stop("File not found: ", path,
         "\nRun pipeline/run_pipeline.R first.")
  }
  readRDS(path)
}

# Spoken data — annotated levels, from 04_annotate.R / 03_build_levels.R
vowels    <- .load("vowels_spoken_annotated", "leveled")
syllables <- .load("syllables_spoken",        "leveled")
words     <- .load("words_spoken_annotated",  "leveled")
phrases   <- .load("phrases_spoken",          "leveled")

# Written data — word-level clean forms, from 02_clean.R
zheltov   <- .load("zheltov_clean", "cleaned")
mono      <- .load("mono_clean",    "cleaned")

# Written data — syllable-level annotated forms, from 04_annotate.R.
# These carry sidx / sN / vowel_label / syllable_coda / vowel_cat_* and are
# what the rule-comparison analyses need; zheltov/mono above are word-level
# only and have no syllable structure.
zheltov_ann <- .load("zheltov_annotated", "leveled")
mono_ann    <- .load("mono_annotated",    "leveled")

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