# =============================================================================
# data_profile.R
#
# Two deliverables, both descriptive, no modelling:
#
#   1. data_dictionary.csv — every column of the four analysis tables, with
#      the PIPELINE STAGE THAT CREATED IT derived rather than hand-written:
#      a column is attributed to the earliest stage whose output file already
#      contains it (loaded/ = 01, cleaned/ = 02, leveled/*_spoken = 03,
#      leveled/*_annotated = 04). Hand-written notes are attached only for
#      columns with a known defect or a non-obvious definition.
#
#   2. speaker_coverage.csv — what speaker metadata actually exists, which
#      decides whether a speaker random effect is supportable at all.
#
# OUTPUTS (9-analyze/output/)
#   data_dictionary.csv
#   data_dictionary.md
#   speaker_coverage.csv
#   speaker_clips.csv
# =============================================================================

source(here::here("9-analyze", "config", "phonology_params.R"))
source(here::here("9-analyze", "config", "paths.R"))
suppressPackageStartupMessages({ library(tidyverse) })

OUT_DIR <- here::here("9-analyze", "output")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ---- 1. Load the four analysis tables + the intermediates for attribution --

tbl <- list(
  vowels_spoken_annotated = readRDS(file.path(PATHS$leveled_dir, "vowels_spoken_annotated.rds")),
  words_spoken_annotated  = readRDS(file.path(PATHS$leveled_dir, "words_spoken_annotated.rds")),
  zheltov_annotated       = readRDS(file.path(PATHS$leveled_dir, "zheltov_annotated.rds")),
  mono_annotated          = readRDS(file.path(PATHS$leveled_dir, "mono_annotated.rds"))
)

# Earliest-stage attribution: read the intermediate outputs and record which
# columns each already had.
stage_cols <- list(
  "01_load_raw"     = c(names(readRDS(file.path(PATHS$loaded_dir,  "vowels_spoken_raw.rds"))),
                        names(readRDS(file.path(PATHS$loaded_dir,  "zheltov_raw.rds"))),
                        names(readRDS(file.path(PATHS$loaded_dir,  "mono_raw.rds")))),
  "02_clean"        = c(names(readRDS(file.path(PATHS$cleaned_dir, "vowels_spoken_clean.rds"))),
                        names(readRDS(file.path(PATHS$cleaned_dir, "zheltov_clean.rds"))),
                        names(readRDS(file.path(PATHS$cleaned_dir, "mono_clean.rds")))),
  "03_build_levels" = c(names(readRDS(file.path(PATHS$leveled_dir, "vowels_spoken.rds"))),
                        names(readRDS(file.path(PATHS$leveled_dir, "words_spoken.rds"))),
                        names(readRDS(file.path(PATHS$leveled_dir, "syllables_zheltov.rds"))),
                        names(readRDS(file.path(PATHS$leveled_dir, "syllables_mono.rds"))))
)
attribute_stage <- function(col) {
  for (s in names(stage_cols)) if (col %in% stage_cols[[s]]) return(s)
  "04_annotate"
}

# ---- 2. Hand-written notes: only where there is a defect or a subtlety -----

NOTES <- c(
  int_midpoint       = "ADOPTED intensity measure. Mean of intensity_step10 and step11, i.e. the vowel midpoint. Always exactly 2 samples at the same relative position, so no duration confound (r = -0.06 with duration). dB.",
  total_intensity    = "DO NOT USE. Sum of all 20 intensity steps including undefined-coded-as-zero cells; r = 0.909 with duration and 0.985 with n_valid_int_steps. It is a duration measure. Source of the '162 dB' figure in earlier drafts. Retained only to reproduce old results.",
  peak_intensity     = "DO NOT USE. Maximum over a VARIABLE number of samples, so biased upward for long vowels (peak minus midpoint grows 0 to 5.02 dB as valid steps go 2 to 16). Stressed vowels are longer, so it manufactures part of any stress effect.",
  intensity          = "new-FAVE single-point measurement, dB. Independent of the step series, but taken at ~13.8% of vowel duration (5th-95th pct 12.3-14.9%), i.e. on the onset ramp, not the steady state.",
  n_valid_int_steps  = "How many of the 20 intensity steps were actually defined. Median 6, range 2-18; 42% of vowels have only 2. Correlates with duration at r = 0.93. Exposes the stage-7 extraction defect in the data.",
  intensity_step1    = "One of 20 nominal readings across the vowel. 71% of cells across all 20 are literal 0.0 = Praat 'undefined', already 0 in the stage-7 CSV. Steps 1, 2, 19, 20 are 0 for EVERY vowel; only 10 and 11 are never 0. Treat 0 as missing.",
  time               = "The FAVE measurement time, in seconds. Together with file_name this is the vowel's unique key.",
  word_id            = "file_name + dense_rank(word_start). Unique per word token. NOT built from widx, which collides on 1.25% of tokens.",
  word_token_idx     = "The word's 1-based position in time within its recording. Unique within file_name.",
  widx               = "Position of the word in the ORTHOGRAPHIC sentence, INFERRED by string-matching the aligner label against sentence tokens. Collides on 1,758 word tokens (1.25%). Do not use as an identifier; phrase_position and rel_phrase_position inherit its error rate.",
  sidx_contour       = "The contour extraction's own vowel index within the word, kept so its agreement with sidx stays inspectable (100% in the cleaned data; 98.21% at the join).",
  sN_contour         = "The contour extraction's own vowel count for the word. 100% agreement with sN in the cleaned data; 97.23% at the join.",
  syllable_coda      = "open/closed. Depends on syllabification: exactly one consonant of each medial cluster goes to the following onset (NOT sonority-based onset maximisation, despite the docstring). /t-curl-c/ is treated as one segment as of 2026-09-25; before that it was split, mismarking 8,529 rows as closed.",
  vowel_class        = "full/reduced under ACTIVE_RULE's inventory. Renamed from vowel_strength; values were strong/weak.",
  speaker_id         = "Sparse. See speaker_coverage.csv before using it as a random effect or reporting a speaker count.",
  log_corpus_freq_smoothed = "log frequency in the monolingual corpus, smoothed for word types absent from it (see in_mono_corpus).",
  stress_rule_A6     = "Rightmost full vowel, else leftmost reduced; 6-vowel full inventory. The traditional description (Krueger 1961).",
  stress_rule_B5     = "Rightmost full vowel, else NO stress; 5-vowel full inventory. The draft's preferred rule (its 'Rule E').",
  stressed_sidx_B6   = "NA means this rule assigns the word no stress at all, not missing data. Same for B5 and B4."
)
note_for <- function(col) {
  if (col %in% names(NOTES)) return(NOTES[[col]])
  if (grepl("^intensity_step", col))        return(NOTES[["intensity_step1"]])
  if (grepl("^(f0|word|phrase)_.*step", col)) return("One of 20 readings across the interval. f0 steps are NOT affected by the zero-coding defect (0.00% zeros, 1.14% NA); the *_intensity_step series are.")
  if (grepl("^stress_rule_[AB][654]$", col))  return("Predicted stress under this rule. Never NA: under a B rule, a word with no full vowel has every syllable Unstressed.")
  if (grepl("^stressed_sidx_B", col))         return(NOTES[["stressed_sidx_B6"]])
  if (grepl("^vowel_cat_[654]$", col))        return("F/R/L under the 6-, 5- or 4-full-vowel inventory. L = loan-only vowel, excluded.")
  if (grepl("^word_cat_[654]$", col))         return("Per-word F/R string under the given inventory, loan vowels dropped.")
  ""
}

# ---- 3. Build the dictionary ----------------------------------------------

# imap() passes (value, name) in that order.
profile_one <- function(d, nm) {
  tibble(
    table     = nm,
    column    = names(d),
    type      = map_chr(d, ~ class(.x)[1]),
    n_rows    = nrow(d),
    pct_missing = map_dbl(d, ~ round(100 * mean(is.na(.x)), 2)),
    n_distinct  = map_int(d, ~ dplyr::n_distinct(.x)),
    example     = map_chr(d, function(x) {
      v <- x[!is.na(x)]
      if (!length(v)) return("")
      v <- v[1]
      if (is.list(v)) return("<list>")
      substr(paste(format(v, digits = 4), collapse = ""), 1, 28)
    })
  ) %>%
    mutate(created_by = map_chr(column, attribute_stage),
           note       = map_chr(column, note_for))
}

dict <- imap_dfr(tbl, profile_one) %>%
  select(table, column, type, created_by, pct_missing, n_distinct, example, note)

write_csv(dict, file.path(OUT_DIR, "data_dictionary.csv"))
cat(sprintf("data_dictionary.csv: %d column entries across %d tables\n",
            nrow(dict), n_distinct(dict$table)))
print(dict %>% count(table, created_by) %>% pivot_wider(names_from = created_by,
      values_from = n, values_fill = 0))

# ---- 4. Speaker coverage ---------------------------------------------------

v <- tbl$vowels_spoken_annotated

spk <- v %>%
  group_by(corpus) %>%
  summarise(
    vowel_tokens      = n(),
    recordings        = n_distinct(file_name),
    speaker_id_values = n_distinct(speaker_id, na.rm = TRUE),
    pct_speaker_na    = round(100 * mean(is.na(speaker_id)), 2),
    gender_values     = n_distinct(gender, na.rm = TRUE),
    pct_gender_na     = round(100 * mean(is.na(gender)), 2),
    age_values        = n_distinct(age, na.rm = TRUE),
    pct_age_na        = round(100 * mean(is.na(age)), 2),
    .groups = "drop"
  )
write_csv(spk, file.path(OUT_DIR, "speaker_coverage.csv"))
cat("\n--- SPEAKER METADATA COVERAGE ---\n"); print(as.data.frame(spk), row.names = FALSE)

clips <- v %>%
  filter(!is.na(speaker_id)) %>%
  group_by(corpus, speaker_id) %>%
  summarise(recordings = n_distinct(file_name), vowels = n(), .groups = "drop") %>%
  arrange(desc(recordings))
write_csv(clips, file.path(OUT_DIR, "speaker_clips.csv"))
cat("\n--- CLIPS PER IDENTIFIED SPEAKER ---\n")
print(as.data.frame(clips %>% slice_head(n = 12)), row.names = FALSE)
cat(sprintf("\n  identified speakers: %d | recordings they cover: %d of %d (%.1f%%)\n",
            nrow(clips), sum(clips$recordings), n_distinct(v$file_name),
            100 * sum(clips$recordings) / n_distinct(v$file_name)))
cat(sprintf("  vowels with a speaker_id: %d of %d (%.1f%%)\n",
            sum(clips$vowels), nrow(v), 100 * sum(clips$vowels) / nrow(v)))

cat("\nWrote 4 files to ", OUT_DIR, "\n", sep = "")
