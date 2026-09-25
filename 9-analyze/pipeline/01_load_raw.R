# pipeline/01_load_raw.R
# ================================================================
# LOAD RAW DATA FROM ALL FOUR CORPORA
# Reads outputs from 7-extract/ and 8-combine/.
# Joins acoustic data with speaker metadata.
# Saves one raw .rds per corpus level — no cleaning happens here.
#
# Outputs (saved to data/loaded/):
#   vowels_spoken_raw.rds     — one row per vowel token
#   contours_spoken_raw.rds   — f0/intensity time series (long)
#   words_raw.rds             — word-level contours
#   phrases_raw.rds           — phrase-level contours
#   zheltov_raw.rds           — Zheltov written corpus
#   mono_raw.rds              — monolingual text corpus tokens
#   n_counts_raw.csv          — initial N at every join step
# ================================================================

source(here::here("9-analyze", "config", "phonology_params.R"))
source(here::here("9-analyze", "config", "paths.R"))

suppressPackageStartupMessages({
  library(tidyverse)
  library(arrow)       # read_parquet()
  library(data.table)
})

cat("══════════════════════════════════════════\n")
cat("  01_load_raw.R  —  loading raw data\n")
cat("══════════════════════════════════════════\n\n")

# ── Tracking table: N at each join step ─────────────────────────
counts <- list()

note_n <- function(df, label) {
  counts[[length(counts) + 1]] <<- tibble(
    step       = label,
    n_rows     = nrow(df),
    n_files    = if ("file_name"   %in% names(df)) n_distinct(df$file_name)   else NA,
    n_speakers = if ("speaker_id"  %in% names(df)) n_distinct(df$speaker_id) else NA
  )
  cat(sprintf("  %-40s  %d rows\n", label, nrow(df)))
  invisible(df)
}


# ════════════════════════════════════════════════════════════════
# A.  SPOKEN CORPORA
# ════════════════════════════════════════════════════════════════

# ── A1. Formant / duration data (from 7-extract → 8-combine) ────
cat("\n── A. Spoken corpora ──\n")

raw_vowels <- read_csv(PATHS$vowel_points_csv,
                       locale = locale(encoding = "UTF-8"),
                       show_col_types = FALSE) %>%
  note_n("A1: raw vowel_points CSV loaded")

# ── A2. F0/intensity contours (from contour clustering app) ─────
cluster_data <- bind_rows(
  read_csv(PATHS$cluster_mfa_csv, na = c("", "NA", "--undefined--"),
           show_col_types = FALSE) %>% mutate(corpus = "mfa"),
  read_csv(PATHS$cluster_vox_csv, na = c("", "NA", "--undefined--"),
           show_col_types = FALSE) %>% mutate(corpus = "vox")
) %>%
  note_n("A2: cluster (contour) data loaded")

# Pivot contour data wide: one row per vowel token
contours_wide <- cluster_data %>%
  pivot_wider(
    id_cols     = c(filename, interval_label, start, end, duration,
                    jumpkilleffect, vowel_index, vowel_total,
                    vowel_category, word_category, word_label, corpus),
    names_from  = stepnumber,
    values_from = c(f0, intensity),
    names_glue  = "{.value}_step{stepnumber}"
  ) %>%
  note_n("A2b: contours pivoted wide")

# ── A3. Word and phrase contours (from get_contours_word_phrase.praat) ──
words_raw <- read_csv(
  PATHS$words_csv,
  na            = c("", "NA", "--undefined--"),
  show_col_types = FALSE
) %>%
  note_n("A3a: word contours loaded")
phrases_raw <- read_csv(
  PATHS$phrases_csv,
  na            = c("", "NA", "--undefined--"),   # ← treat Praat's undefined as NA
  show_col_types = FALSE
) %>%
  note_n("A3b: phrase contours loaded")

# ── A3c. Pivot word contours wide ────────────────────────────────
# Prefix all step columns with "word_" so they can't clash with
# the vowel-level step columns already in vowels_joined.
# Adjust the case_when() entries if your Praat script uses
# different column names (e.g. "text", "interval_label", etc.).

words_wide <- words_raw %>%
  rename_with(~ case_when(
    .x == "filename"       ~ "file_name",
    .x == "label"          ~ "word_label",
    .x == "interval_label" ~ "word_label",
    .x == "start"          ~ "word_start",
    .x == "end"            ~ "word_end",
    TRUE                   ~ .x
  )) %>%
  pivot_wider(
    id_cols     = any_of(c("file_name", "word_label",
                           "word_start", "word_end", "corpus")),
    names_from  = stepnumber,
    values_from = c(f0, intensity),
    names_glue  = "word_{.value}_step{stepnumber}"
  ) %>%
  note_n("A3c: word contours pivoted wide")

# ── A3d. Pivot phrase contours wide ──────────────────────────────
# Prefix step columns with "phrase_".
# If the Praat script doesn't output a phrase label column, the
# id_cols below still works — file_name + boundaries is enough.

phrases_wide <- phrases_raw %>%
  rename_with(~ case_when(
    .x == "filename"       ~ "file_name",
    .x == "label"          ~ "phrase_label",
    .x == "interval_label" ~ "phrase_label",
    .x == "start"          ~ "phrase_start",
    .x == "end"            ~ "phrase_end",
    TRUE                   ~ .x
  )) %>%
  pivot_wider(
    id_cols     = any_of(c("file_name", "phrase_label",
                           "phrase_start", "phrase_end", "corpus")),
    names_from  = stepnumber,
    values_from = c(f0, intensity),
    names_glue  = "phrase_{.value}_step{stepnumber}"
  ) %>%
  note_n("A3d: phrase contours pivoted wide")

# ── A4. Speaker metadata ─────────────────────────────────────────

# Common Voice metadata (from TSV — has path → filename mapping)
meta_cv_tsv <- read_delim(PATHS$cv_tsv, delim = "\t",
                          show_col_types = FALSE) %>%
  mutate(file_name = str_remove(path, "\\.mp3$|\\.wav$")) %>%
  select(file_name, sentence = sentence, age, gender_tsv = gender,
         accents, variant)

note_n(meta_cv_tsv,"A4a: CV TSV metadata loaded")

# HuggingFace parquet metadata (client_id, sentence, etc.)
meta_cv_hf <- map_dfr(PATHS$cv_parquet_files, read_parquet) %>%
  mutate(
    file_name  = sprintf("utterance_%06d", row_number() - 1),
    speaker_id = na_if(as.character(client_id), "0"),
    gender     = if_else(speaker_id == "177", "male_masculine", NA_character_)
  ) %>%
  select(file_name, speaker_id, gender, sentence)

note_n(meta_cv_hf, "A4b: HuggingFace parquet metadata loaded")

# ── A5. Utterance durations (for speech rate) ────────────────────
utterance_durations <- bind_rows(
  read_csv(PATHS$durations_mfa, show_col_types = FALSE),
  read_csv(PATHS$durations_vox, show_col_types = FALSE)
) %>%
  distinct(file_name, .keep_all = TRUE)

note_n(utterance_durations, "A5: utterance durations loaded")

# ── A6. Join vowels + contours ───────────────────────────────────
# Duration in raw_vowels is in seconds — convert to ms here
# so all downstream code uses ms.

raw_vowels <- raw_vowels %>%
  mutate(
    dur       = dur * 1000,
    file_name = as.character(file_name)
  ) %>%
  mutate(
    sidx = as.integer(sidx),
    sN   = as.integer(sN)
  ) %>%
  select(-any_of("corpus"))

contours_wide <- contours_wide %>%
  rename(
    file_name     = filename,
    sidx          = vowel_index,
    sN            = vowel_total,
    label_contour = interval_label
  ) %>%
  select(-duration) %>%      # ← not vowel duration; raw_vowels$dur is authoritative
  mutate(
    sidx = as.integer(sidx),
    sN   = as.integer(sN)
  )

# Many-to-many join: disambiguate by time overlap
vowels_joined <- raw_vowels %>%
  left_join(
    contours_wide,
    by           = c("file_name", "sidx", "sN"),
    relationship = "many-to-many"
  ) %>%
  group_by(file_name, sidx, sN, label, time) %>%
  mutate(within = time >= start & time <= end) %>%
  arrange(desc(within), abs(time - start)) %>%
  slice(1) %>%
  ungroup() %>%
  select(-within) %>%
  note_n("A6: vowels joined with contours")

# ── A6b. Join word-level contours ────────────────────────────────
# Join on (file_name, word_label) — both are already in vowels_joined
# after A6.  Because the same word_label can appear multiple times
# in a file, the many-to-many join may produce duplicates; the
# group/arrange/slice block keeps only the best match (the word
# interval whose midpoint is closest to the vowel measurement time,
# with preference for an exact time-overlap).

vowels_joined <- vowels_joined %>%
  left_join(
    words_wide,
    by           = c("file_name", "word_label"),
    relationship = "many-to-many"
  ) %>%
  group_by(file_name, sidx, sN, label, time) %>%
  mutate(
    in_word = !is.na(word_start) &
      time >= word_start & time <= word_end
  ) %>%
  arrange(
    desc(in_word),
    abs(time - coalesce((word_start + word_end) / 2, time))
  ) %>%
  slice(1) %>%
  ungroup() %>%
  select(-in_word) %>%
  note_n("A6b: word contours joined")

# ── A6c. Join phrase-level contours ──────────────────────────────
# Phrases are joined on file_name alone (many utterances have a
# single phrase, but if yours have several the time-overlap logic
# below selects the containing phrase just as in A6 and A6b).

vowels_joined <- vowels_joined %>%
  left_join(
    phrases_wide,
    by           = "file_name",
    relationship = "many-to-many"
  ) %>%
  group_by(file_name, sidx, sN, label, time) %>%
  mutate(
    in_phrase = !is.na(phrase_start) &
      time >= phrase_start & time <= phrase_end
  ) %>%
  arrange(
    desc(in_phrase),
    abs(time - coalesce((phrase_start + phrase_end) / 2, time))
  ) %>%
  slice(1) %>%
  ungroup() %>%
  select(-in_phrase) %>%
  note_n("A6c: phrase contours joined")

# ── A7. Join speaker metadata ────────────────────────────────────
vowels_joined <- vowels_joined %>%
  
  left_join(
    meta_cv_tsv %>%
      rename(sentence_tsv = sentence),      
    by = "file_name"
  ) %>%
  
  left_join(
    meta_cv_hf %>%
      rename(
        sentence_hf  = sentence,            
        gender_hf    = gender,              
        speaker_id   = speaker_id           
      ),
    by = "file_name"
  ) %>%
  
  mutate(
    sentence   = coalesce(sentence_tsv, sentence_hf),
    speaker_id = as.character(speaker_id),  # only from meta_cv_hf, no conflict
    gender     = coalesce(gender_tsv, gender_hf)
  ) %>%
  
  select(-sentence_tsv, -sentence_hf, -gender_hf) %>%  # drop the renamed helpers
  
  note_n("A7: speaker metadata joined")

# ── A8. Join utterance durations ─────────────────────────────────
vowels_joined <- vowels_joined %>%
  left_join(utterance_durations, by = "file_name") %>%
  note_n("A8: utterance durations joined")

# ── A9. Rename for pipeline consistency ──────────────────────────
vowels_spoken_raw <- vowels_joined %>%
  rename_with(~ case_when(
    .x == "dur"             ~ "duration",
    .x == "f0"              ~ "f0_mean",
    .x == "phon_stress"     ~ "phon_stress",
    .x == "syl_pos"         ~ "syl_pos_raw",
    .x == "syl_open_closed" ~ "syl_open_closed",
    TRUE                    ~ .x
  )) %>%
  # Derive corpus name from filename prefix — always override any
  # upstream corpus column because the old mfa/vox tags were misleading.
  mutate(
    corpus = if_else(
      str_starts(file_name, "utterance_"),
      "chuvash_voice",
      "common_voice_chuvash"
    )
  )


# ════════════════════════════════════════════════════════════════
# B.  WRITTEN CORPORA
# ════════════════════════════════════════════════════════════════
cat("\n── B. Written corpora ──\n")

# ── B1. Zheltov wordlist ──────────────────────────────────
# Expected columns: word, label (IPA vowel), sidx, sN,
#                   syl_pos, syl_open_closed, phon_stress, corpus
zheltov_raw <- read_csv(PATHS$zheltov_csv,
                        locale = locale(encoding = "UTF-8"),
                        show_col_types = FALSE) %>%
  mutate(corpus = "zheltov") %>%
  note_n("B1: Zheltov raw loaded")


# Expected columns: word
zheltov_raw_true <- read_csv(PATHS$zheltov_raw_csv,
                        locale = locale(encoding = "UTF-8"),
                        show_col_types = FALSE)

# ── B2. Chuvash monolingual text corpus ──────────────────────────
# Parquet file has column 'chv' with raw sentences.
mono_raw <- read_parquet(PATHS$mono_parquet) %>%
  mutate(corpus = "mono") %>%
  note_n("B2: monolingual corpus loaded")


# ════════════════════════════════════════════════════════════════
# C.  SAVE
# ════════════════════════════════════════════════════════════════
cat("\n── C. Saving raw .rds files ──\n")

saveRDS(vowels_spoken_raw, file.path(PATHS$loaded_dir, "vowels_spoken_raw.rds"))
saveRDS(contours_wide,     file.path(PATHS$loaded_dir, "contours_raw.rds"))
saveRDS(words_raw,         file.path(PATHS$loaded_dir, "words_contours_raw.rds"))
saveRDS(phrases_raw,       file.path(PATHS$loaded_dir, "phrases_contours_raw.rds"))
saveRDS(zheltov_raw_true,       file.path(PATHS$loaded_dir, "zheltov_raw.rds"))
saveRDS(mono_raw,          file.path(PATHS$loaded_dir, "mono_raw.rds"))

# Save N-tracking table
bind_rows(counts) %>%
  write_csv(file.path(PATHS$cleaned_dir, "n_counts_raw.csv"))

cat("\n✓ 01_load_raw.R complete\n")
cat(sprintf("  %d vowel rows loaded across %d files\n",
            nrow(vowels_spoken_raw),
            n_distinct(vowels_spoken_raw$file_name)))
