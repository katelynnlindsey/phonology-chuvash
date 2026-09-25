# pipeline/03_build_levels.R
# ================================================================
# BUILD ANALYSIS TABLES AT EACH LINGUISTIC LEVEL
#
# Replaces the previous version; now also handles:
#   • Cyrillic → IPA transliteration  (spoken: word_label)
#   • IPA syllabification             (all three corpora)
#   • syllable_label extraction       (spoken: indexed via sidx;
#                                      written: via expand_to_syllables)
#   • Standard column naming          (word_label, word_label_IPA,
#                                      syllable_label, vowel_label,
#                                      sidx, sN, syl_position)
#
# Requires the syllabification block appended to:
#   config/phonology_params.R
#   (IPA_DIGRAPHS, IPA_VOWELS, IPA_SONORITY, tokenize_ipa,
#    syllabify_ipa, extract_syllable_vowel,
#    expand_to_syllables, add_syl_position)
#
# Input  (← data/cleaned/):
#   vowels_spoken_clean.rds   one row per vowel token
#   zheltov_clean.rds         one row per word type  (columns: word, IPA)
#   mono_clean.rds            one row per word type  (columns: token, IPA,
#                                                      corpus_freq, …)
#
# Output (→ data/leveled/):
#   vowels_spoken.rds         Level 1 — one row per vowel token
#   syllables_spoken.rds      Level 2 — + syl_position, syllable_label
#   words_spoken.rds          Level 3 — one row per word token
#   phrases_spoken.rds        Level 4 — one row per utterance/file
#   syllables_zheltov.rds     one row per syllable, vowel_label, syl_position
#   syllables_mono.rds        one row per syllable, vowel_label, corpus_freq
# ================================================================

source(here::here("9-analyze", "config", "phonology_params.R"))
source(here::here("9-analyze", "config", "paths.R"))

suppressPackageStartupMessages(library(tidyverse))

cat("══════════════════════════════════════════\n")
cat("  03_build_levels.R\n")
cat("══════════════════════════════════════════\n\n")


# ════════════════════════════════════════════════════════════════
# LOAD CLEANED DATA
# ════════════════════════════════════════════════════════════════

spoken  <- readRDS(file.path(PATHS$cleaned_dir, "vowels_spoken_clean.rds"))
zheltov <- readRDS(file.path(PATHS$cleaned_dir, "zheltov_clean.rds"))
mono    <- readRDS(file.path(PATHS$cleaned_dir, "mono_clean.rds"))

cat(sprintf("Loaded  spoken  : %d rows\n",   nrow(spoken)))
cat(sprintf("Loaded  zheltov : %d word types\n", nrow(zheltov)))
cat(sprintf("Loaded  mono    : %d word types\n\n", nrow(mono)))


# ════════════════════════════════════════════════════════════════
# SPOKEN CORPUS — TRANSLITERATE + SYLLABIFY
#
# spoken already has one row per vowel (= one per syllable).
# Steps:
#  (a) Transliterate Cyrillic word_label → word_label_IPA
#  (b) Syllabify → word_label_IPA_syllabified  (e.g. "ka.pak")
#  (c) Sanity-check: IPA syllable count must agree with MFA sN
#  (d) Index into syllabified string with sidx → syllable_label
#  (e) Rename `label` → `vowel_label` for cross-corpus consistency
#      (must be last: earlier steps still reference `label`)
# ════════════════════════════════════════════════════════════════
cat("── Spoken: transliterate + syllabify ──\n")

# (a) Transliterate
spoken <- spoken %>%
  mutate(word_label_IPA = map_chr(word_label, transliterate_word))

# (b) Syllabify
spoken <- spoken %>%
  mutate(word_label_IPA_syllabified = map_chr(word_label_IPA, syllabify_ipa))

# (c) Sanity check
sN_check <- spoken %>%
  mutate(sN_ipa = str_count(word_label_IPA_syllabified, fixed(".")) + 1L) %>%
  filter(!is.na(sN), !is.na(sN_ipa), sN != sN_ipa)

if (nrow(sN_check) > 0L) {
  cat(sprintf(
    "  ⚠  %d row(s) where MFA sN ≠ IPA sN  →  syllable_label = NA\n",
    nrow(sN_check)
  ))
  cat("  Sample mismatches:\n")
  sN_check %>%
    select(word_label, word_label_IPA,
           word_label_IPA_syllabified, sN, sN_ipa) %>%
    distinct() %>%
    slice_head(n = 8) %>%
    print()
} else {
  cat("  ✓  MFA sN matches IPA syllable count for all rows\n")
}

# (d) Extract syllable_label by indexing with sidx
spoken <- spoken %>%
  mutate(
    syllable_label = map2_chr(
      word_label_IPA_syllabified, sidx,
      \(w, idx) {
        if (is.na(w) || is.na(idx)) return(NA_character_)
        parts <- strsplit(w, ".", fixed = TRUE)[[1L]]
        i     <- as.integer(idx)
        if (i < 1L || i > length(parts)) NA_character_ else parts[[i]]
      }
    )
  )

# (e) Rename — keep until last
spoken <- spoken %>% rename(vowel_label = label)

cat(sprintf(
  "  syllable_label : %d present  |  %d NA\n\n",
  sum(!is.na(spoken$syllable_label)),
  sum( is.na(spoken$syllable_label))
))


# ════════════════════════════════════════════════════════════════
# ZHELTOV — STANDARDISE NAMES + SYLLABIFY + EXPAND
#
# zheltov_clean has one row per word type.
# Columns from 02_clean.R: `word` (cleaned Cyrillic), `IPA` (transliterated).
# The rename guards accept data in either naming convention so the script
# is robust if 02_clean is later updated to use standard names.
# ════════════════════════════════════════════════════════════════
cat("── Zheltov: syllabify + expand to syllable rows ──\n")

if ("word" %in% names(zheltov) && !"word_label"     %in% names(zheltov))
  zheltov <- rename(zheltov, word_label     = word)
if ("IPA"  %in% names(zheltov) && !"word_label_IPA" %in% names(zheltov))
  zheltov <- rename(zheltov, word_label_IPA = IPA)

zheltov <- zheltov %>%
  mutate(word_label_IPA_syllabified = map_chr(word_label_IPA, syllabify_ipa))

zheltov_syl <- zheltov %>%
  expand_to_syllables() %>%
  add_syl_position()

cat(sprintf(
  "  %d word types  →  %d syllable rows  (%d unique vowel labels)\n\n",
  nrow(zheltov),
  nrow(zheltov_syl),
  n_distinct(zheltov_syl$vowel_label, na.rm = TRUE)
))


# ════════════════════════════════════════════════════════════════
# MONO — STANDARDISE NAMES + SYLLABIFY + EXPAND
#
# mono_clean has one row per word type.
# Columns from 02_clean.R: `token`, `IPA`, `corpus_freq`,
#                           `log_corpus_freq`, `corpus`.
# corpus_freq propagates automatically to every syllable row.
# ════════════════════════════════════════════════════════════════
cat("── Mono: syllabify + expand to syllable rows ──\n")

if ("token" %in% names(mono) && !"word_label"     %in% names(mono))
  mono <- rename(mono, word_label     = token)
if ("IPA"   %in% names(mono) && !"word_label_IPA" %in% names(mono))
  mono <- rename(mono, word_label_IPA = IPA)

mono <- mono %>%
  mutate(word_label_IPA_syllabified = map_chr(word_label_IPA, syllabify_ipa))

mono_syl <- mono %>%
  expand_to_syllables() %>%
  add_syl_position()

cat(sprintf(
  "  %d word types  →  %d syllable rows  (%d unique vowel labels)\n\n",
  nrow(mono),
  nrow(mono_syl),
  n_distinct(mono_syl$vowel_label, na.rm = TRUE)
))


# ════════════════════════════════════════════════════════════════
# LEVEL 1 — VOWEL (spoken)
# Base table; all transliteration and syllabification complete.
# ════════════════════════════════════════════════════════════════
saveRDS(spoken, file.path(PATHS$leveled_dir, "vowels_spoken.rds"))
cat(sprintf("Level 1  vowels    : %d rows saved\n", nrow(spoken)))


# ════════════════════════════════════════════════════════════════
# LEVEL 2 — SYLLABLE (spoken)
# Adds syl_position factor. syllable_label already present from above.
# ════════════════════════════════════════════════════════════════
syllables <- spoken %>% add_syl_position()

saveRDS(syllables, file.path(PATHS$leveled_dir, "syllables_spoken.rds"))
cat(sprintf("Level 2  syllables : %d rows saved\n", nrow(syllables)))


# ════════════════════════════════════════════════════════════════
# LEVEL 3 — WORD (spoken)
# One row per word token; per-syllable properties summarised.
# ════════════════════════════════════════════════════════════════
words <- spoken %>%
  arrange(word_id, sidx) %>%
  group_by(word_id) %>%
  summarise(
    # ── Identifiers ────────────────────────────────────────────
    file_name                  = first(file_name),
    corpus                     = first(corpus),
    speaker_id                 = first(speaker_id),
    word_label                 = first(word_label),
    word_label_IPA             = first(word_label_IPA),
    word_label_IPA_syllabified = first(word_label_IPA_syllabified),
    sN                         = first(sN),
    word_category              = first(word_category),
    
    # ── Position in utterance ──────────────────────────────────
    widx                       = first(widx),
    wN                         = first(wN),
    phrase_position            = first(phrase_position),
    
    # ── Duration ───────────────────────────────────────────────
    total_duration             = sum(duration, na.rm = TRUE),
    dur_per_syl                = list(setNames(duration, paste0("v", sidx))),
    dur_ratio_v1               = first(duration[sidx == 1L]) /
      sum(duration, na.rm = TRUE),
    
    # ── Sequences (vowel_label replaces old `label`) ───────────
    vowel_sequence             = paste(vowel_label,    collapse = "-"),
    syllable_sequence          = paste(syllable_label, collapse = "-"),
    
    # ── Prosodic pattern ───────────────────────────────────────
    slope_pattern              = paste(slope_type,     collapse = "-"),
    
    # ── Amplitude ──────────────────────────────────────────────
    total_intensity            = list(setNames(total_intensity,
                                               paste0("v", sidx))),
    .groups = "drop"
  )

saveRDS(words, file.path(PATHS$leveled_dir, "words_spoken.rds"))
cat(sprintf("Level 3  words     : %d rows saved\n", nrow(words)))


# ════════════════════════════════════════════════════════════════
# LEVEL 4 — PHRASE / UTTERANCE (spoken)
# One row per audio file; speech rate from file-level duration.
# ════════════════════════════════════════════════════════════════
durations <- bind_rows(
  read_csv(PATHS$durations_mfa, show_col_types = FALSE),
  read_csv(PATHS$durations_vox, show_col_types = FALSE)
) %>%
  distinct(file_name, .keep_all = TRUE)

phrases <- spoken %>%
  group_by(file_name, corpus, speaker_id) %>%
  summarise(
    sentence      = first(sentence),
    n_vowels      = n(),
    n_words       = n_distinct(word_id),
    mean_duration = mean(duration,   na.rm = TRUE),
    mean_F1       = mean(F1,         na.rm = TRUE),
    mean_F2       = mean(F2,         na.rm = TRUE),
    mean_f0       = mean(f0_step10,  na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(durations, by = "file_name") %>%
  mutate(speech_rate_vps = n_vowels / duration_seconds)

saveRDS(phrases, file.path(PATHS$leveled_dir, "phrases_spoken.rds"))
cat(sprintf("Level 4  phrases   : %d rows saved\n", nrow(phrases)))


# ════════════════════════════════════════════════════════════════
# WRITTEN CORPUS SYLLABLE TABLES
# ════════════════════════════════════════════════════════════════
saveRDS(zheltov_syl, file.path(PATHS$leveled_dir, "syllables_zheltov.rds"))
cat(sprintf("Zheltov syllables  : %d rows saved\n", nrow(zheltov_syl)))

saveRDS(mono_syl,    file.path(PATHS$leveled_dir, "syllables_mono.rds"))
cat(sprintf("Mono    syllables  : %d rows saved\n", nrow(mono_syl)))


# ════════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════════
cat("\n── Column inventory check ──\n")
expected_cols <- c("word_label", "word_label_IPA",
                   "word_label_IPA_syllabified",
                   "syllable_label", "vowel_label",
                   "sidx", "sN", "syl_position")

for (nm in c("syllables_spoken", "syllables_zheltov", "syllables_mono")) {
  obj  <- switch(nm,
                 syllables_spoken  = syllables,
                 syllables_zheltov = zheltov_syl,
                 syllables_mono    = mono_syl
  )
  miss <- setdiff(expected_cols, names(obj))
  if (length(miss) == 0L) {
    cat(sprintf("  ✓  %-22s  all expected columns present\n", nm))
  } else {
    cat(sprintf("  ✗  %-22s  MISSING: %s\n", nm, paste(miss, collapse = ", ")))
  }
}

cat("\n✓ 03_build_levels.R complete\n")