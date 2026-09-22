# pipeline/03_build_levels.R
# ================================================================
# BUILD ANALYSIS TABLES AT EACH LINGUISTIC LEVEL
# One script creates all four levels from the cleaned vowel table.
#
# Levels:
#   1. Vowel     — one row per vowel token (= base unit, already clean)
#   2. Syllable  — one row per syllable (here = vowel + position label)
#   3. Word      — one row per word token; vowel properties summarized
#   4. Phrase    — one row per utterance/file
# ================================================================

source("config/phonology_params.R")
source("config/paths.R")
library(tidyverse)

vowels <- readRDS(file.path(PATHS$cleaned_dir, "vowels_spoken_clean.rds"))

# ── Level 2: Syllable ────────────────────────────────────────────
# Adds explicit syl_position column; otherwise identical to vowel level.

syllables <- vowels %>%
  mutate(
    syl_position = case_when(
      sN == 1        ~ "only",
      sidx == 1      ~ "initial",
      sidx == sN     ~ "final",
      TRUE           ~ "medial"
    ) %>% factor(levels = c("only", "initial", "medial", "final"))
  )

saveRDS(syllables, file.path(PATHS$cleaned_dir, "syllables_spoken.rds"))
cat(sprintf("Level 2 syllables: %d rows saved\n", nrow(syllables)))

# ── Level 3: Word ────────────────────────────────────────────────
# One row per word token. All syllables of a word must be present
# (enforced by 02_clean.R step 6, so no additional filter needed).

words <- vowels %>%
  arrange(word_id, sidx) %>%
  group_by(word_id) %>%
  summarise(
    # Identifiers
    file_name       = first(file_name),
    corpus          = first(corpus),
    speaker_id      = first(speaker_id),
    word_label      = first(word_label),
    sN              = first(sN),
    word_category   = first(word_category),

    # Position in utterance
    widx            = first(widx),
    wN              = first(wN),
    phrase_position = first(phrase_position),

    # Duration: total and per-syllable
    total_duration  = sum(duration, na.rm = TRUE),
    dur_per_syl     = list(setNames(duration, paste0("v", sidx))),
    dur_ratio_v1    = duration[sidx == 1] / sum(duration, na.rm = TRUE),

    # Vowel sequence (for co-occurrence analyses)
    vowel_sequence  = paste(label, collapse = "-"),

    # F0 contour pattern
    slope_pattern   = paste(slope_type, collapse = "-"),

    # Amplitude
    total_intensity = list(setNames(total_intensity, paste0("v", sidx))),

    .groups = "drop"
  )

saveRDS(words, file.path(PATHS$cleaned_dir, "words_spoken.rds"))
cat(sprintf("Level 3 words:     %d rows saved\n", nrow(words)))

# ── Level 4: Phrase / Utterance ──────────────────────────────────
# One row per audio file. Join utterance durations for speech rate.

durations <- bind_rows(
  read_csv(PATHS$durations_mfa, show_col_types = FALSE),
  read_csv(PATHS$durations_vox, show_col_types = FALSE)
) %>%
  distinct(file_name, .keep_all = TRUE)

phrases <- vowels %>%
  group_by(file_name, corpus, speaker_id) %>%
  summarise(
    sentence        = first(sentence),
    n_vowels        = n(),
    n_words         = n_distinct(word_id),
    mean_duration   = mean(duration,    na.rm = TRUE),
    mean_F1         = mean(F1,          na.rm = TRUE),
    mean_F2         = mean(F2,          na.rm = TRUE),
    mean_f0         = mean(f0_step10,   na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(durations, by = "file_name") %>%
  mutate(
    speech_rate_vps = n_vowels / duration_seconds   # vowels per second
  )

saveRDS(phrases, file.path(PATHS$cleaned_dir, "phrases_spoken.rds"))
cat(sprintf("Level 4 phrases:   %d rows saved\n", nrow(phrases)))