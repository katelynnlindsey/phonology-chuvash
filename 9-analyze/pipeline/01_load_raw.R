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

# sidx/sN are kept under CONTOUR-specific names. They used to be renamed to
# sidx/sN and used as join keys, which silently assumed the two extractions
# agreed about a vowel's index within its word. With the interval join they
# are no longer keys, so both sides survive and the assumption becomes
# testable — see the agreement check after A6.
contours_wide <- contours_wide %>%
  rename(
    file_name     = filename,
    sidx_contour  = vowel_index,
    sN_contour    = vowel_total,
    label_contour = interval_label
  ) %>%
  select(-duration) %>%      # ← not vowel duration; raw_vowels$dur is authoritative
  mutate(
    sidx_contour = as.integer(sidx_contour),
    sN_contour   = as.integer(sN_contour)
  )

# ── INTERVAL JOIN, not a key join ────────────────────────────────
#
# This used to join on (file_name, sidx, sN) with relationship =
# "many-to-many" and then de-duplicate with group_by/slice(1). That key is
# not unique on EITHER side: sidx/sN are the vowel's index and count WITHIN
# ITS WORD, so in a file containing several disyllabic words, every word's
# vowel 1 carries (sidx=1, sN=2) and matches every other word's vowel 1.
# Measured on the source files: the key identifies only 335,500 of 703,582
# point rows and 345,982 of 791,137 contour intervals. The slice(1) cleanup
# grouped by `time`, which does not separate two point rows belonging to the
# same word, so 3,998 (word_id, sidx) slots survived with 4,083 spurious extra
# rows — 66% of them disagreeing about which vowel it was.
#
# The correct relation is containment, not equality: each FAVE point has a
# measurement `time`, each contour row has a vowel interval, and the point
# belongs to the interval that contains its time. Verified on the source data:
#   (file_name, time)         is unique in the points file  (703,582/703,582)
#   (filename, start, end)    is unique in the contours     (791,137/791,137)
#   no two intervals within a file overlap                  (0 of 791,137)
# so the containment join is exactly 1:1 and needs no de-duplication.
#
# 87,948 point rows (12.50%) fall in no interval and are dropped here. They
# are not boundary-rounding cases — the median gap to the nearest preceding
# interval is 69 ms and only one row is within 5 ms of an edge. They are
# concentrated in Chuvash Voice (15.50% unmatched, vs 1.23% for Common
# Voice), which suggests the FAVE run and the contour run for that corpus
# used different TextGrids. Until that is resolved these vowels cannot be
# paired with a contour at all, so they are excluded and counted.
# Matched: 615,634 vowels.

.interval_join <- function(pts, iv, time_col = "time") {
  pt <- data.table::as.data.table(pts)
  iv <- data.table::as.data.table(iv)
  pt[, `:=`(.t1 = get(time_col), .t2 = get(time_col))]
  data.table::setkey(iv, file_name, start, end)
  out <- data.table::foverlaps(
    pt, iv,
    by.x   = c("file_name", ".t1", ".t2"),
    type   = "within",
    nomatch = NA
  )
  out[, c(".t1", ".t2") := NULL]
  dplyr::as_tibble(out)
}

.n_before <- nrow(raw_vowels)
vowels_joined <- .interval_join(raw_vowels, contours_wide) %>%
  note_n("A6: vowels joined with contours (interval join)")

.n_unmatched <- sum(is.na(vowels_joined$start))
cat(sprintf("  interval join: %d of %d point rows matched a contour interval (%.2f%% unmatched)\n",
            .n_before - .n_unmatched, .n_before, 100 * .n_unmatched / .n_before))
vowels_joined <- vowels_joined %>% filter(!is.na(start))

stopifnot(
  "interval join did not produce one row per point" =
    nrow(vowels_joined) == .n_before - .n_unmatched,
  "(file_name, time) is not unique after the interval join" =
    nrow(dplyr::distinct(vowels_joined, file_name, time)) == nrow(vowels_joined)
)
note_n(vowels_joined, "A6a: unmatched points dropped")

# Do the two extractions agree about where this vowel sits in its word?
# The old key join assumed they always did. Report rather than assert: a
# mismatch is informative about TextGrid provenance, not a reason to stop.
.agree <- vowels_joined %>%
  filter(!is.na(sidx), !is.na(sidx_contour)) %>%
  summarise(
    n         = dplyr::n(),
    sidx_same = mean(sidx == sidx_contour),
    sN_same   = mean(sN   == sN_contour)
  )
cat(sprintf("  FAVE vs contour vowel index agreement: sidx %.2f%%, sN %.2f%% (n=%d)\n",
            100 * .agree$sidx_same, 100 * .agree$sN_same, .agree$n))

# ── A6b. Join word-level contours ────────────────────────────────
# Join on (file_name, word_label) — both are already in vowels_joined
# after A6.  Because the same word_label can appear multiple times
# in a file, the many-to-many join may produce duplicates; the
# group/arrange/slice block keeps only the best match (the word
# interval whose midpoint is closest to the vowel measurement time,
# with preference for an exact time-overlap).

# Same containment logic as A6. Word intervals are also unique on
# (filename, start, end) (476,212/476,212) and non-overlapping within a file,
# so the join is 1:1. Joining on (file_name, word_label) was wrong for the
# same reason as A6: a word type can occur several times in one utterance.
vowels_joined <- vowels_joined %>%
  rename(vowel_start = start, vowel_end = end) %>%
  .interval_join(
    words_wide %>% rename(start = word_start, end = word_end)
  ) %>%
  rename(word_start = start, word_end = end,
         start = vowel_start, end = vowel_end) %>%
  note_n("A6b: word contours joined (interval join)")

stopifnot(
  "word interval join changed the row count" =
    nrow(dplyr::distinct(vowels_joined, file_name, time)) == nrow(vowels_joined)
)

# ── A6c. Join phrase-level contours ──────────────────────────────
# Phrases are joined on file_name alone (many utterances have a
# single phrase, but if yours have several the time-overlap logic
# below selects the containing phrase just as in A6 and A6b).

# Containment again. Phrase intervals are unique on (filename, start, end)
# (47,056/47,056) and there is a median and maximum of 1 per file, so joining
# on file_name alone happened to be nearly safe here — but the interval join
# is correct rather than nearly safe, and stays correct if multi-phrase
# utterances are added later.
vowels_joined <- vowels_joined %>%
  rename(vowel_start = start, vowel_end = end) %>%
  .interval_join(
    phrases_wide %>% rename(start = phrase_start, end = phrase_end)
  ) %>%
  rename(phrase_start = start, phrase_end = end,
         start = vowel_start, end = vowel_end) %>%
  note_n("A6c: phrase contours joined (interval join)")

stopifnot(
  "phrase interval join changed the row count" =
    nrow(dplyr::distinct(vowels_joined, file_name, time)) == nrow(vowels_joined)
)

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
