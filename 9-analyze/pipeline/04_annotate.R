# pipeline/04_annotate.R
# ================================================================
# ANNOTATION PIPELINE
# Reads from data/leveled/  →  writes back to data/leveled/
#
# Adds to EVERY annotated table:
#   - Phonological stress under Rules A, B, C
#   - Vowel features (height, backness, rounding)
#   - Vowel strength under active rule
#   - Slope type (Rising / Stable / Falling)
#   - Word frequency from monolingual Chuvash corpus
#
# To change stress rule: edit ACTIVE_RULE in phonology_params.R
# and re-run this script only. No other file needs to change.
# ================================================================

source(here::here("9-analyze", "config", "phonology_params.R"))
source(here::here("9-analyze", "config", "paths.R"))

suppressPackageStartupMessages({
  library(tidyverse)
  library(data.table)
})

cat("══════════════════════════════════════════\n")
cat("  04_annotate.R\n")
cat(sprintf("  Active stress rule : %s — %s\n",
            ACTIVE_RULE, VOWEL_RULES[[ACTIVE_RULE]]$label))
cat("══════════════════════════════════════════\n\n")


# ════════════════════════════════════════════════════════════════
# 0.  BUILD WORD-FREQUENCY TABLE FROM MONOLINGUAL CORPUS
#     mono_clean.rds already has corpus_freq per word type
#     (frequency was counted in 02_clean.R before distinct()).
#
#     We build a lookup table keyed on the orthographic word form
#     so it can be joined to spoken-corpus vowel and word tables.
# ════════════════════════════════════════════════════════════════
cat("── 0. Building word-frequency lookup ──\n")

mono_clean <- readRDS(file.path(PATHS$cleaned_dir, "mono_clean.rds"))

word_freq_lookup <- mono_clean %>%
  select(token, corpus_freq, log_corpus_freq) %>%
  distinct()

cat(sprintf("  Frequency lookup: %d word types\n",
            nrow(word_freq_lookup)))
cat(sprintf("  Frequency range : %d – %d  (median %d)\n",
            min(word_freq_lookup$corpus_freq),
            max(word_freq_lookup$corpus_freq),
            median(word_freq_lookup$corpus_freq)))


# Helper: join frequency to any table that has a word_label column.
# Words absent from the monolingual corpus receive corpus_freq = NA
# so that the user can decide downstream whether to drop or impute.
# A boolean column 'in_mono_corpus' makes the coverage transparent.

join_word_freq <- function(df, word_col = "word_label") {
  df %>%
    left_join(
      word_freq_lookup %>%
        rename(!!word_col := token),
      by = word_col
    ) %>%
    mutate(
      in_mono_corpus  = !is.na(corpus_freq),
      # log(1) = 0 used as floor for words not found in corpus.
      # Keep NA version as well so models can choose how to handle.
      log_corpus_freq_smoothed = if_else(
        is.na(log_corpus_freq), log(1), log_corpus_freq
      )
    )
}

# Coverage report — run once so it appears in the console log
coverage_check <- function(df, label) {
  pct <- mean(df$in_mono_corpus, na.rm = TRUE) * 100
  cat(sprintf("  %-30s  %.1f%% of word tokens found in mono corpus\n",
              label, pct))
}


# ════════════════════════════════════════════════════════════════
# A.  VOWEL-LEVEL ANNOTATION  (spoken)
# ════════════════════════════════════════════════════════════════
cat("\n── A. Annotating vowel level ──\n")

vowels <- readRDS(file.path(PATHS$leveled_dir, "vowels_level.rds"))

vowels_ann <- vowels %>%
  
  # ── A1. Vowel phonetic features ───────────────────────────────
mutate(
  vowel_height = case_when(
    label %in% VOWEL_HEIGHT$high ~ "high",
    label %in% VOWEL_HEIGHT$mid  ~ "mid",
    label %in% VOWEL_HEIGHT$low  ~ "low",
    TRUE                         ~ NA_character_
  ) %>% factor(levels = c("high", "mid", "low")),
  
  vowel_backness = case_when(
    label %in% VOWEL_BACKNESS$front   ~ "front",
    label %in% VOWEL_BACKNESS$central ~ "central",
    label %in% VOWEL_BACKNESS$back    ~ "back",
    TRUE                              ~ NA_character_
  ) %>% factor(levels = c("front", "central", "back")),
  
  vowel_rounding = if_else(
    label %in% VOWEL_ROUND, "rounded", "unrounded"
  ) %>% factor(levels = c("unrounded", "rounded"))
) %>%
  
  # ── A2. All stress rules ──────────────────────────────────────
apply_all_stress_rules() %>%
  
  # ── A3. Strength and stress under active rule ─────────────────
mutate(
  vowel_strength = case_when(
    label %in% active_strong() ~ "strong",
    label %in% active_weak()   ~ "weak",
    TRUE                       ~ NA_character_
  ) %>% factor(levels = c("weak", "strong")),
  
  stress_cat = factor(
    .data[[paste0("stress_rule_", ACTIVE_RULE)]],
    levels = c("Unstressed", "Stressed")
  )
) %>%
  
  # ── A4. F0 slope type ─────────────────────────────────────────
mutate(
  slope_type = case_when(
    f0_slope >  1        ~ "Rising",
    f0_slope < -1        ~ "Falling",
    !is.na(f0_slope)     ~ "Stable",
    TRUE                 ~ NA_character_
  ) %>% factor(levels = c("Falling", "Stable", "Rising"))
) %>%
  
  # ── A5. Positional labels ─────────────────────────────────────
mutate(
  vowel_position = case_when(
    sN == 1    ~ "only",
    sidx == 1  ~ "initial",
    sidx == sN ~ "final",
    TRUE       ~ "internal"
  ) %>% factor(levels = c("only", "initial", "internal", "final")),
  
  phrase_position = factor(
    phrase_position,
    levels = c("initial", "medial", "final")
  )
) %>%
  
  # ── A6. Word frequency from monolingual corpus ────────────────
# corpus_freq          : raw count in running-text corpus
# log_corpus_freq      : log(corpus_freq); NA if word not found
# log_corpus_freq_smoothed : log(1) = 0 floor for absent words
# in_mono_corpus       : logical flag for coverage transparency
join_word_freq(word_col = "word_label")

coverage_check(vowels_ann, "vowels_ann")
cat(sprintf("  Annotated: %d rows\n", nrow(vowels_ann)))

# Frequency coverage summary by corpus
vowels_ann %>%
  group_by(corpus) %>%
  summarise(
    n_tokens        = n(),
    n_found         = sum(in_mono_corpus),
    pct_found       = round(mean(in_mono_corpus) * 100, 1),
    median_freq     = median(corpus_freq, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  print()

saveRDS(vowels_ann,
        file.path(PATHS$leveled_dir, "vowels_spoken_annotated.rds"))
cat("✓ vowels_spoken_annotated.rds saved\n")


# ════════════════════════════════════════════════════════════════
# B.  WORD-LEVEL ANNOTATION  (spoken)
# ════════════════════════════════════════════════════════════════
cat("\n── B. Annotating word level ──\n")

words <- readRDS(file.path(PATHS$leveled_dir, "words_level.rds"))

# Pull per-vowel stress annotations from the annotated vowel table
word_stress <- vowels_ann %>%
  group_by(word_id) %>%
  summarise(
    stressed_sidx_A = sidx[stress_rule_A == "Stressed"][1],
    stressed_sidx_B = sidx[stress_rule_B == "Stressed"][1],
    stressed_sidx_C = sidx[stress_rule_C == "Stressed"][1],
    
    stressed_position = {
      s <- .data[[paste0("stressed_sidx_", ACTIVE_RULE)]][1]
      n <- first(sN)
      case_when(
        n == 1  ~ "only",
        s == 1  ~ "initial",
        s == n  ~ "final",
        s == n - 1 ~ "penultimate",
        TRUE    ~ "medial"
      )
    } %>%
      factor(levels = c("only","initial","medial","penultimate","final")),
    
    stressed_slope = slope_type[
      .data[[paste0("stress_rule_", ACTIVE_RULE)]] == "Stressed"
    ][1],
    
    .groups = "drop"
  )

# Word-category strings under each rule
word_categories <- vowels_ann %>%
  arrange(word_id, sidx) %>%
  group_by(word_id) %>%
  summarise(
    word_cat_A = word_category_string(label, "A"),
    word_cat_B = word_category_string(label, "B"),
    word_cat_C = word_category_string(label, "C"),
    .groups    = "drop"
  )

words_ann <- words %>%
  left_join(word_stress,     by = "word_id") %>%
  left_join(word_categories, by = "word_id") %>%
  
  # ── Does the longest/loudest syllable match predicted stress? ──
  mutate(
    duration_matches_stress  = (longest_sidx == stressed_sidx_A),
    intensity_matches_stress = (loudest_sidx == stressed_sidx_A),
    
    disyl_slope_cat = if_else(sN == 2, f0_slope_pattern, NA_character_)
  ) %>%
  
  # ── Word frequency from monolingual corpus ────────────────────
# One frequency value per word type, joined on word_label.
# word_label is the orthographic form from the words TextGrid tier.
join_word_freq(word_col = "word_label")

coverage_check(words_ann, "words_ann")
cat(sprintf("  Annotated: %d rows\n", nrow(words_ann)))

saveRDS(words_ann,
        file.path(PATHS$leveled_dir, "words_spoken_annotated.rds"))
cat("✓ words_spoken_annotated.rds saved\n")


# ════════════════════════════════════════════════════════════════
# C.  WRITTEN CORPUS ANNOTATION  (Zheltov)
# ════════════════════════════════════════════════════════════════
cat("\n── C. Annotating Zheltov corpus ──\n")

zheltov <- readRDS(file.path(PATHS$cleaned_dir, "zheltov_clean.rds"))

zheltov_ann <- zheltov %>%
  mutate(
    vowel_cat_A = classify_vowel(label, "A"),
    vowel_cat_B = classify_vowel(label, "B"),
    vowel_cat_C = classify_vowel(label, "C"),
    vowel_cat   = classify_vowel(label, ACTIVE_RULE),
    
    position3 = case_when(
      syl_pos %in% c("initial_final", "initial") ~ "initial",
      str_detect(syl_pos, "final")               ~ "final",
      TRUE                                       ~ "medial"
    ) %>% factor(levels = c("initial", "medial", "final")),
    
    syl_structure = factor(syl_open_closed, levels = c("open","closed"))
  ) %>%
  group_by(word) %>%
  mutate(
    word_cat_A = word_category_string(label[order(sidx)], "A"),
    word_cat_B = word_category_string(label[order(sidx)], "B"),
    word_cat_C = word_category_string(label[order(sidx)], "C")
  ) %>%
  ungroup() %>%
  
  # ── Frequency: look up orthographic word in mono corpus ───────
left_join(
  word_freq_lookup %>% rename(word = token),
  by = "word"
) %>%
  mutate(
    in_mono_corpus          = !is.na(corpus_freq),
    log_corpus_freq_smoothed = if_else(
      is.na(log_corpus_freq), log(1), log_corpus_freq
    )
  )

coverage_check(zheltov_ann %>% distinct(word, .keep_all = TRUE),
               "zheltov_ann (word types)")
cat(sprintf("  Annotated: %d rows | %d word types\n",
            nrow(zheltov_ann), n_distinct(zheltov_ann$word)))

saveRDS(zheltov_ann,
        file.path(PATHS$leveled_dir, "zheltov_annotated.rds"))
cat("✓ zheltov_annotated.rds saved\n")


# ════════════════════════════════════════════════════════════════
# D.  WRITTEN CORPUS ANNOTATION  (monolingual)
# ════════════════════════════════════════════════════════════════
cat("\n── D. Annotating monolingual corpus ──\n")

mono_ann <- mono_clean %>%
  mutate(
    vowel_seq_cat_A = map_chr(vowels,
                              ~ paste(sapply(.x, classify_vowel, rule = "A"), collapse = "")),
    vowel_seq_cat_B = map_chr(vowels,
                              ~ paste(sapply(.x, classify_vowel, rule = "B"), collapse = "")),
    vowel_seq_cat_C = map_chr(vowels,
                              ~ paste(sapply(.x, classify_vowel, rule = "C"), collapse = "")),
    word_cat_A = str_remove_all(vowel_seq_cat_A, "L|NA"),
    word_cat_B = str_remove_all(vowel_seq_cat_B, "L|NA"),
    word_cat_C = str_remove_all(vowel_seq_cat_C, "L|NA"),
    n_vowels   = as.integer(n_vowels)
  ) %>%
  filter(str_detect(word_cat_A, "[FR]"))

cat(sprintf("  Annotated: %d unique tokens\n", nrow(mono_ann)))

saveRDS(mono_ann,
        file.path(PATHS$leveled_dir, "mono_annotated.rds"))
cat("✓ mono_annotated.rds saved\n")

cat(sprintf("\n✓ 04_annotate.R complete\n"))
cat(sprintf("  Active rule : %s — %s\n",
            ACTIVE_RULE, VOWEL_RULES[[ACTIVE_RULE]]$label))
cat("  To re-annotate with a different rule:\n")
cat("    1. Edit ACTIVE_RULE in config/phonology_params.R\n")
cat("    2. Rerun: source('pipeline/04_annotate.R')\n")