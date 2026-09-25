# pipeline/04_annotate.R
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
            ACTIVE_RULE,
            VOWEL_RULES[[ACTIVE_RULE]]$label))   # was $vowel_label — typo fixed
cat("══════════════════════════════════════════\n\n")


# ════════════════════════════════════════════════════════════════
# 0.  WORD-FREQUENCY LOOKUP  (from monolingual corpus)
# ════════════════════════════════════════════════════════════════
cat("── 0. Building word-frequency lookup ──\n")

mono_clean <- readRDS(file.path(PATHS$cleaned_dir, "mono_clean.rds"))

# mono_clean uses column name 'token' (the rename to word_label happens
# only in-memory in 03_build_levels.R — the .rds file keeps 'token')
word_freq_lookup <- mono_clean %>%
  select(token, corpus_freq, log_corpus_freq) %>%
  distinct()

cat(sprintf("  Frequency lookup: %d word types\n", nrow(word_freq_lookup)))
cat(sprintf("  Frequency range : %d – %d  (median %d)\n",
            min(word_freq_lookup$corpus_freq),
            max(word_freq_lookup$corpus_freq),
            median(word_freq_lookup$corpus_freq)))

# Joins word frequency to any table on `word_col`.
# Renames 'token' → word_col before joining so the key matches.
join_word_freq <- function(df, word_col = "word_label") {
  df %>%
    left_join(
      word_freq_lookup %>% rename(!!word_col := token),
      by = word_col
    ) %>%
    mutate(
      in_mono_corpus           = !is.na(corpus_freq),
      log_corpus_freq_smoothed = if_else(
        is.na(log_corpus_freq), log(1), log_corpus_freq
      )
    )
}

coverage_check <- function(df, label) {
  pct <- mean(df$in_mono_corpus, na.rm = TRUE) * 100
  cat(sprintf("  %-30s  %.1f%% of tokens found in mono corpus\n", label, pct))
}

# ── Shared helper: open / closed syllable structure ──────────────
# "open"   = syllable ends with a vowel nucleus
# "closed" = syllable ends with a consonant
# Works on any column produced by syllabify_ipa() / expand_to_syllables().
syl_coda_type <- function(syl_vec) {
  map_chr(syl_vec, \(syl) {
    if (is.na(syl)) return(NA_character_)
    segs <- tokenize_ipa(syl)
    if (!length(segs)) return(NA_character_)
    if (tail(segs, 1L) %in% IPA_VOWELS) "open" else "closed"
  })
}


# ════════════════════════════════════════════════════════════════
# A.  VOWEL-LEVEL ANNOTATION  (spoken)
# ════════════════════════════════════════════════════════════════
cat("\n── A. Annotating vowel level ──\n")

vowels <- readRDS(file.path(PATHS$leveled_dir, "vowels_spoken.rds"))

vowels_ann <- vowels %>%
  
  # ── A1. Vowel phonetic features ──────────────────────────────
mutate(
  vowel_height = case_when(
    vowel_label %in% VOWEL_HEIGHT$high ~ "high",
    vowel_label %in% VOWEL_HEIGHT$mid  ~ "mid",
    vowel_label %in% VOWEL_HEIGHT$low  ~ "low",
    TRUE                               ~ NA_character_
  ) %>% factor(levels = c("high", "mid", "low")),
  
  vowel_backness = case_when(
    vowel_label %in% VOWEL_BACKNESS$front   ~ "front",
    vowel_label %in% VOWEL_BACKNESS$central ~ "central",
    vowel_label %in% VOWEL_BACKNESS$back    ~ "back",
    TRUE                                    ~ NA_character_
  ) %>% factor(levels = c("front", "central", "back")),
  
  vowel_rounding = if_else(
    vowel_label %in% VOWEL_ROUND, "rounded", "unrounded"
  ) %>% factor(levels = c("unrounded", "rounded")),
  
  syllable_coda = factor(
    syl_coda_type(syllable_label),
    levels = c("open", "closed")
  )
) %>%
  
  # ── A2. All stress rules ─────────────────────────────────────
apply_all_stress_rules() %>%
  
  # ── A3. Strength and stress under active rule ─────────────────
mutate(
  vowel_strength = case_when(
    vowel_label %in% active_strong() ~ "strong",
    vowel_label %in% active_weak()   ~ "weak",
    TRUE                             ~ NA_character_
  ) %>% factor(levels = c("weak", "strong")),
  
  stress_cat = factor(
    .data[[paste0("stress_rule_", ACTIVE_RULE)]],
    levels = c("Unstressed", "Stressed")
  )
) %>%
  
  # ── A4. F0 slope type ────────────────────────────────────────
# slope_type is already present from 03_build_levels.R;
# re-factor here so the levels are guaranteed consistent.
mutate(
  slope_type = if ("f0_slope" %in% names(.)) {
    case_when(
      f0_slope >  1    ~ "Rising",
      f0_slope < -1    ~ "Falling",
      !is.na(f0_slope) ~ "Stable",
      TRUE             ~ NA_character_
    ) %>% factor(levels = c("Falling", "Stable", "Rising"))
  } else {
    factor(slope_type, levels = c("Falling", "Stable", "Rising"))
  }
) %>%
  
  # ── A5. Positional labels ─────────────────────────────────────
mutate(
  vowel_position = factor(
    context,
    levels = c("only", "initial", "internal", "final")
  ),
  phrase_position = factor(
    phrase_position,
    levels = c("initial", "medial", "final")
  )
) %>%
  
  # ── A6. Word frequency ────────────────────────────────────────
join_word_freq(word_col = "word_label")

coverage_check(vowels_ann, "vowels_ann")
cat(sprintf("  Annotated: %d rows\n", nrow(vowels_ann)))

vowels_ann %>%
  group_by(corpus) %>%
  summarise(n = n(), n_found = sum(in_mono_corpus),
            pct = round(mean(in_mono_corpus) * 100, 1),
            med_freq = median(corpus_freq, na.rm = TRUE),
            .groups = "drop") %>%
  print()

saveRDS(vowels_ann, file.path(PATHS$leveled_dir, "vowels_spoken_annotated.rds"))
cat("✓ vowels_spoken_annotated.rds saved\n")


# ════════════════════════════════════════════════════════════════
# B.  WORD-LEVEL ANNOTATION  (spoken)
# ════════════════════════════════════════════════════════════════
cat("\n── B. Annotating word level ──\n")

words <- readRDS(file.path(PATHS$leveled_dir, "words_spoken.rds"))

# Pull per-vowel stress + slope from annotated vowel table.
# stressed_position must go in a SEPARATE mutate() because it
# references stressed_sidx_* columns created in the same summarise.
word_stress <- vowels_ann %>%
  group_by(word_id) %>%
  summarise(
    stressed_sidx_A = sidx[stress_rule_A == "Stressed"][1L],
    stressed_sidx_B = sidx[stress_rule_B == "Stressed"][1L],
    stressed_sidx_C = sidx[stress_rule_C == "Stressed"][1L],
    stressed_slope  = if ("slope_type" %in% names(vowels_ann))
      slope_type[.data[[paste0("stress_rule_", ACTIVE_RULE)]]
                 == "Stressed"][1L]
    else NA_character_,
    sN_word = first(sN),
    .groups = "drop"
  ) %>%
  mutate(
    # Now stressed_sidx_* exist and can be safely referenced
    .stressed_sidx = .data[[paste0("stressed_sidx_", ACTIVE_RULE)]],
    stressed_position = case_when(
      sN_word == 1                        ~ "only",
      .stressed_sidx == 1                 ~ "initial",
      .stressed_sidx == sN_word           ~ "final",
      .stressed_sidx == sN_word - 1L      ~ "penultimate",
      TRUE                                ~ "medial"
    ) %>% factor(levels = c("only", "initial", "medial", "penultimate", "final"))
  ) %>%
  select(-.stressed_sidx, -sN_word)

# Word-category strings
word_categories <- vowels_ann %>%
  arrange(word_id, sidx) %>%
  group_by(word_id) %>%
  summarise(
    word_cat_A = word_category_string(vowel_label, "A"),
    word_cat_B = word_category_string(vowel_label, "B"),
    word_cat_C = word_category_string(vowel_label, "C"),
    .groups    = "drop"
  )

words_ann <- words %>%
  left_join(word_stress,     by = "word_id") %>%
  left_join(word_categories, by = "word_id") %>%
  mutate(
    duration_matches_stress  = (longest_sidx  == stressed_sidx_A),
    intensity_matches_stress = if ("loudest_sidx" %in% names(.))
      (loudest_sidx == stressed_sidx_A)
    else NA
  ) %>%
  join_word_freq(word_col = "word_label")

coverage_check(words_ann, "words_ann")
cat(sprintf("  Annotated: %d rows\n", nrow(words_ann)))

saveRDS(words_ann, file.path(PATHS$leveled_dir, "words_spoken_annotated.rds"))
cat("✓ words_spoken_annotated.rds saved\n")


# ════════════════════════════════════════════════════════════════
# C.  WRITTEN CORPUS ANNOTATION  (Zheltov)
#
# Read syllables_zheltov.rds (from 03_build_levels.R), NOT
# zheltov_clean.rds.  The clean file is word-level and has no
# vowel_label / sidx / sN columns.
# ════════════════════════════════════════════════════════════════
cat("\n── C. Annotating Zheltov corpus ──\n")

zheltov_syl <- readRDS(file.path(PATHS$leveled_dir, "syllables_zheltov.rds"))

# Compute syl_open_closed from syllable_label
# (not in the syllabified file; derived here from the IPA structure)
zheltov_ann <- zheltov_syl %>%
  mutate(
    # ── Vowel categories under each rule ──────────────────────
    vowel_cat_A = classify_vowel(vowel_label, "A"),
    vowel_cat_B = classify_vowel(vowel_label, "B"),
    vowel_cat_C = classify_vowel(vowel_label, "C"),
    vowel_cat   = classify_vowel(vowel_label, ACTIVE_RULE),
    
    # ── Three-way position label ───────────────────────────────
    # syl_position is "only" / "initial" / "medial" / "final"
    position3 = case_when(
      syl_position %in% c("only", "initial") ~ "initial",
      syl_position == "final"                ~ "final",
      TRUE                                   ~ "medial"
    ) %>% factor(levels = c("initial", "medial", "final")),
    
    # ── Open / closed syllable ─────────────────────────────────
    syllable_coda = map_chr(syllable_label, \(syl) {
      if (is.na(syl)) return(NA_character_)
      segs <- tokenize_ipa(syl)
      if (!length(segs)) return(NA_character_)
      if (tail(segs, 1L) %in% IPA_VOWELS) "open" else "closed"
    }) %>% factor(levels = c("open", "closed"))
    
  ) %>%
  
  # ── Word-level category strings ────────────────────────────
group_by(word_label) %>%
  mutate(
    word_cat_A = word_category_string(vowel_label[order(sidx)], "A"),
    word_cat_B = word_category_string(vowel_label[order(sidx)], "B"),
    word_cat_C = word_category_string(vowel_label[order(sidx)], "C")
  ) %>%
  ungroup() %>%
  
  # ── Word frequency from monolingual corpus ─────────────────
join_word_freq(word_col = "word_label")

coverage_check(
  zheltov_ann %>% distinct(word_label, .keep_all = TRUE),
  "zheltov_ann (word types)"
)
cat(sprintf("  Annotated: %d rows | %d word types\n",
            nrow(zheltov_ann), n_distinct(zheltov_ann$word_label)))

saveRDS(zheltov_ann, file.path(PATHS$leveled_dir, "zheltov_annotated.rds"))
cat("✓ zheltov_annotated.rds saved\n")


# ════════════════════════════════════════════════════════════════
# D.  WRITTEN CORPUS ANNOTATION  (monolingual)
#
# Read syllables_mono.rds (from 03_build_levels.R).
# mono_clean.rds is word-level only; the 'vowels' list-column
# was dropped by count() in 02_clean.R.
# corpus_freq propagates from the word-level join inside
# expand_to_syllables(), so it is already present here.
# ════════════════════════════════════════════════════════════════
cat("\n── D. Annotating monolingual corpus ──\n")

mono_syl <- readRDS(file.path(PATHS$leveled_dir, "syllables_mono.rds"))

mono_ann <- mono_syl %>%
  
  # ── Per-syllable vowel categories ─────────────────────────
mutate(
  vowel_cat_A = classify_vowel(vowel_label, "A"),
  vowel_cat_B = classify_vowel(vowel_label, "B"),
  vowel_cat_C = classify_vowel(vowel_label, "C"),
  vowel_cat   = classify_vowel(vowel_label, ACTIVE_RULE),
  syllable_coda = factor(             
    syl_coda_type(syllable_label),
    levels = c("open", "closed")
  )
) %>%
  
  # ── Word-level category strings ────────────────────────────
group_by(word_label) %>%
  mutate(
    word_cat_A = word_category_string(vowel_label[order(sidx)], "A"),
    word_cat_B = word_category_string(vowel_label[order(sidx)], "B"),
    word_cat_C = word_category_string(vowel_label[order(sidx)], "C")
  ) %>%
  ungroup() %>%
  
  # ── Keep only words with at least one F or R vowel ─────────
filter(str_detect(word_cat_A, "[FR]"))

cat(sprintf("  Annotated: %d syllable rows | %d word types\n",
            nrow(mono_ann), n_distinct(mono_ann$word_label)))

saveRDS(mono_ann, file.path(PATHS$leveled_dir, "mono_annotated.rds"))
cat("✓ mono_annotated.rds saved\n")


cat(sprintf("\n✓ 04_annotate.R complete\n"))
cat(sprintf("  Active rule : %s — %s\n",
            ACTIVE_RULE, VOWEL_RULES[[ACTIVE_RULE]]$label))
cat("  To re-annotate with a different rule:\n")
cat("    1. Edit ACTIVE_RULE in config/phonology_params.R\n")
cat("    2. Rerun: source('pipeline/04_annotate.R')\n")