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
            RULE_LABELS[[ACTIVE_RULE]]))   # was $vowel_label — typo fixed
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
  
  # ── A3. Vowel class and stress under the active rule ──────────
mutate(
  vowel_class = case_when(
    vowel_label %in% rule_full()    ~ "full",
    vowel_label %in% rule_reduced() ~ "reduced",
    TRUE                            ~ NA_character_
  ) %>% factor(levels = c("reduced", "full")),
  
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
# All six rules get a stressed_sidx column. For the B rules, a word
# with no full vowel has no stressed syllable at all, so every
# stress_rule_B* value is "Unstressed" and sidx[...][1L] correctly
# yields NA — that NA means "this rule assigns this word no stress",
# not "missing data". Analyses must read it that way: see
# analyses/stress_rule_comparison.R, which converts it to FALSE per
# syllable rather than dropping the rows.
word_stress <- vowels_ann %>%
  group_by(word_id) %>%
  summarise(
    stressed_sidx_A6 = sidx[stress_rule_A6 == "Stressed"][1L],
    stressed_sidx_A5 = sidx[stress_rule_A5 == "Stressed"][1L],
    stressed_sidx_A4 = sidx[stress_rule_A4 == "Stressed"][1L],
    stressed_sidx_B6 = sidx[stress_rule_B6 == "Stressed"][1L],
    stressed_sidx_B5 = sidx[stress_rule_B5 == "Stressed"][1L],
    stressed_sidx_B4 = sidx[stress_rule_B4 == "Stressed"][1L],
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
    word_cat_6 = word_category_string(vowel_label, "6"),
    word_cat_5 = word_category_string(vowel_label, "5"),
    word_cat_4 = word_category_string(vowel_label, "4"),
    .groups    = "drop"
  )

words_ann <- words %>%
  left_join(word_stress,     by = "word_id") %>%
  left_join(word_categories, by = "word_id") %>%
  mutate(
    duration_matches_stress  = (longest_sidx  == stressed_sidx_A6),
    intensity_matches_stress = if ("loudest_sidx" %in% names(.))
      (loudest_sidx == stressed_sidx_A6)
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
    vowel_cat_6 = classify_vowel(vowel_label, "6"),
    vowel_cat_5 = classify_vowel(vowel_label, "5"),
    vowel_cat_4 = classify_vowel(vowel_label, "4"),
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
    word_cat_6 = word_category_string(vowel_label[order(sidx)], "6"),
    word_cat_5 = word_category_string(vowel_label[order(sidx)], "5"),
    word_cat_4 = word_category_string(vowel_label[order(sidx)], "4")
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
  vowel_cat_6 = classify_vowel(vowel_label, "6"),
  vowel_cat_5 = classify_vowel(vowel_label, "5"),
  vowel_cat_4 = classify_vowel(vowel_label, "4"),
  vowel_cat   = classify_vowel(vowel_label, ACTIVE_RULE),
  syllable_coda = factor(             
    syl_coda_type(syllable_label),
    levels = c("open", "closed")
  )
) %>%
  
  # ── Word-level category strings ────────────────────────────
group_by(word_label) %>%
  mutate(
    word_cat_6 = word_category_string(vowel_label[order(sidx)], "6"),
    word_cat_5 = word_category_string(vowel_label[order(sidx)], "5"),
    word_cat_4 = word_category_string(vowel_label[order(sidx)], "4")
  ) %>%
  ungroup() %>%
  
  # ── Keep only words with at least one F or R vowel ─────────
filter(str_detect(word_cat_6, "[FR]"))

cat(sprintf("  Annotated: %d syllable rows | %d word types\n",
            nrow(mono_ann), n_distinct(mono_ann$word_label)))

# ════════════════════════════════════════════════════════════════
# E.  FINALISE — drop redundant columns, standardise column order
#
# All four annotated objects are re-saved here, overwriting the
# intermediate saves in sections A–D.
# any_of() silently skips columns that don't exist, so this block
# is safe to run even if upstream optional steps were skipped.
# ════════════════════════════════════════════════════════════════
cat("\n── E. Finalising column layout ──\n")

# ── Columns to drop from the spoken dataset ───────────────────────
# Each entry is justified in the comment.
SPOKEN_DROP <- c(
  # fave extraction parameters / internal IDs — not linguistic data
  "B1", "B2", "B3",        # formant bandwidths
  "max_formant",            # fave setting, not a measurement
  "smooth_error",           # fave tracking quality flag
  "id",                     # internal fave row counter
  "group",                  # unclear provenance
  "speaker_num",            # redundant with speaker_id
  "point_heuristic",        # fave setting
  "optimized",              # fave flag
  # contour clustering artefact
  "jumpkilleffect",
  # superseded by vowel_label (pre-recode form of the same label)
  "label_contour",
  "vowel_category",
  # superseded by syllable_coda (added in 04_annotate §A1 / §C / §D)
  "syl_open_closed",
  # superseded by context + vowel_position
  "syl_pos_raw",
  # superseded by word_label
  "word",
  # superseded by gender (consolidated from both metadata sources)
  "gender_tsv",
  # Common Voice crowdsourcing metadata — not relevant to phonology
  "accents", "variant",
  # redundant timing columns (time is kept)
  "rel_time", "prop_time"
)

# ── E1.  vowels_ann ───────────────────────────────────────────────
vowels_ann <- vowels_ann %>%
  select(-any_of(SPOKEN_DROP)) %>%
  select(
    # IDENTIFIERS
    any_of(c("file_name", "corpus", "speaker_id", "word_id")),
    # UTTERANCE METADATA
    any_of(c("sentence", "gender", "age",
             "duration_seconds", "speech_rate", "log_speech_rate")),
    # WORD — orthographic, IPA, category
    any_of(c("word_label", "word_label_IPA", "word_label_IPA_syllabified",
             "word_category",
             "word_cat_6", "word_cat_5", "word_cat_4")),
    # WORD POSITION IN SENTENCE
    any_of(c("widx", "wN", "phrase_position")),
    # SYLLABLE
    any_of(c("sidx", "sN", "syllable_label", "syllable_coda")),
    # VOWEL — label, position, features, strength
    any_of(c("vowel_label", "context", "vowel_position",
             "vowel_height", "vowel_backness", "vowel_rounding",
             "vowel_class")),
    # PHONOLOGICAL CONTEXT
    any_of(c("pre_seg", "fol_seg", "abs_pre_seg", "abs_fol_seg")),
    # STRESS — observed (phon_stress from forced alignment) +
    #          predicted under each rule
    any_of(c("phon_stress",
             "stress_rule_A6", "stress_rule_A5", "stress_rule_A4",
             "stress_rule_B6", "stress_rule_B5", "stress_rule_B4",
             "stress_cat")),
    # TIMING
    any_of(c("start", "end", "duration", "log_duration", "time")),
    # FORMANTS
    any_of(c("F1", "F2", "F3")),
    # INTENSITY — summary columns first, then 20-step series
    any_of(c("intensity", "total_intensity", "peak_intensity")),
    starts_with("intensity_step"),
    # F0 — summary first, then 20-step series
    any_of(c("f0_mean", "f0_slope", "slope_type")),
    starts_with("f0_step"),
    # WORD-LEVEL CONTOURS
    any_of(c("word_start", "word_end")),
    starts_with("word_f0_step"),
    starts_with("word_intensity_step"),
    # PHRASE-LEVEL CONTOURS
    any_of(c("phrase_label", "phrase_start", "phrase_end")),
    starts_with("phrase_f0_step"),
    starts_with("phrase_intensity_step"),
    # CORPUS FREQUENCY
    any_of(c("corpus_freq", "log_corpus_freq",
             "log_corpus_freq_smoothed", "in_mono_corpus"))
  )

saveRDS(vowels_ann,
        file.path(PATHS$leveled_dir, "vowels_spoken_annotated.rds"))
cat(sprintf("  vowels_ann     : %d rows × %d cols\n",
            nrow(vowels_ann), ncol(vowels_ann)))


# ── E2.  words_ann ────────────────────────────────────────────────
words_ann <- words_ann %>%
  select(
    # IDENTIFIERS
    any_of(c("word_id", "file_name", "corpus", "speaker_id")),
    # WORD
    any_of(c("word_label", "word_label_IPA", "word_label_IPA_syllabified",
             "sN", "word_category",
             "word_cat_6", "word_cat_5", "word_cat_4")),
    # WORD POSITION
    any_of(c("widx", "wN", "phrase_position")),
    # VOWEL/SYLLABLE SEQUENCES (what vowels / syllables make up the word)
    any_of(c("vowel_sequence", "syllable_sequence")),
    # PREDICTED STRESS under each rule
    any_of(c("stressed_sidx_A6", "stressed_sidx_A5", "stressed_sidx_A4",
             "stressed_sidx_B6", "stressed_sidx_B5", "stressed_sidx_B4",
             "stressed_position", "stressed_slope")),
    # DOES THE ACOUSTIC WINNER MATCH PREDICTED STRESS?
    any_of(c("duration_matches_stress", "intensity_matches_stress")),
    # DURATION
    any_of(c("total_duration", "dur_ratio_v1",
             "longest_sidx", "log_duration_mean", "dur_per_syl")),
    # F0 SLOPE PATTERN
    any_of(c("slope_pattern", "f0_slope_mean")),
    # AMPLITUDE
    any_of(c("loudest_sidx", "intensity_per_syl")),
    # SPEECH RATE
    any_of("log_speech_rate"),
    # CORPUS FREQUENCY
    any_of(c("corpus_freq", "log_corpus_freq",
             "log_corpus_freq_smoothed", "in_mono_corpus"))
  )

saveRDS(words_ann,
        file.path(PATHS$leveled_dir, "words_spoken_annotated.rds"))
cat(sprintf("  words_ann      : %d rows × %d cols\n",
            nrow(words_ann), ncol(words_ann)))


# ── E3.  zheltov_ann ──────────────────────────────────────────────
zheltov_ann <- zheltov_ann %>%
  select(
    # WORD
    any_of(c("word_label", "word_label_IPA", "word_label_IPA_syllabified")),
    any_of(c("word_cat_6", "word_cat_5", "word_cat_4")),
    # SYLLABLE
    any_of(c("sidx", "sN", "syllable_label", "syllable_coda",
             "syl_position", "position3")),
    # VOWEL
    any_of(c("vowel_label",
             "vowel_cat", "vowel_cat_6", "vowel_cat_5", "vowel_cat_4")),
    # CORPUS FREQUENCY
    any_of(c("corpus_freq", "log_corpus_freq",
             "log_corpus_freq_smoothed", "in_mono_corpus"))
  )

saveRDS(zheltov_ann,
        file.path(PATHS$leveled_dir, "zheltov_annotated.rds"))
cat(sprintf("  zheltov_ann    : %d rows × %d cols\n",
            nrow(zheltov_ann), ncol(zheltov_ann)))


# ── E4.  mono_ann ─────────────────────────────────────────────────
# mono IS the reference corpus, so in_mono_corpus / _smoothed are
# uninformative and not added.
mono_ann <- mono_ann %>%
  select(
    # WORD
    any_of(c("word_label", "word_label_IPA", "word_label_IPA_syllabified")),
    # FREQUENCY (the primary property of this corpus)
    any_of(c("corpus", "corpus_freq", "log_corpus_freq")),
    any_of(c("word_cat_6", "word_cat_5", "word_cat_4")),
    # SYLLABLE
    any_of(c("sidx", "sN", "syllable_label", "syllable_coda",
             "syl_position")),
    # VOWEL
    any_of(c("vowel_label",
             "vowel_cat", "vowel_cat_6", "vowel_cat_5", "vowel_cat_4"))
  )

saveRDS(mono_ann,
        file.path(PATHS$leveled_dir, "mono_annotated.rds"))
cat(sprintf("  mono_ann       : %d rows × %d cols\n",
            nrow(mono_ann), ncol(mono_ann)))


cat(sprintf("\n✓ 04_annotate.R complete\n"))
cat(sprintf("  Active rule : %s — %s\n",
            ACTIVE_RULE, RULE_LABELS[[ACTIVE_RULE]]))
cat("  To re-annotate with a different rule:\n")
cat("    1. Edit ACTIVE_RULE in config/phonology_params.R\n")
cat("    2. Rerun: source('pipeline/04_annotate.R')\n")