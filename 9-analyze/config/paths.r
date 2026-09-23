# config/paths.R
# ================================================================
# CENTRALIZED PROJECT PATHS
#
# Uses here::here() so the same file works on Mac and Windows.
# The project root is the phonology-chuvash repository.
# ================================================================

# Install once if necessary:
# install.packages("here")

library(here)

# ── Project root ──────────────────────────────────────────────────
PROJECT_ROOT <- here::here()


# ── Inputs from upstream pipeline stages ─────────────────────────

PATHS <- list(
  
  vowel_points_csv = here::here(
    "8-combine",
    "all_chuvash_vowel_points.csv"
  ),
  
  cluster_mfa_csv = here::here(
    "7-extract", "contours", "vowels",
    "chuvash_voice", "contours_output.csv"
  ),
  
  cluster_vox_csv = here::here(
    "7-extract", "contours", "vowels",
    "common_voice_chuvash", "contours_output.csv"
  ),
  
  words_csv = here::here(
    "7-extract", "contours", "words_phrases",
    "output-words.csv"
  ),
  
  phrases_csv = here::here(
    "7-extract", "contours", "words_phrases",
    "output-phrases.csv"
  ),
  
  zheltov_csv = here::here(
    "6-annotate", "chuvash_wordlist",
    "zheltov_corpus.csv"
  ),
  
  zheltov_raw_csv = here::here(
    "1-raw_data", "chuvash_wordlist",
    "wordlist_just_words.csv"
  ),
  
  mono_parquet = here::here(
    "1-raw_data", "monolingual_chuvash",
    "train-00000-of-00001.parquet"
  ),
  
  cv_tsv = here::here(
    "1-raw_data", "common_voice_chuvash",
    "audio_metadata_Mozilla",
    "cv_xpf_spkr17.tsv"
  ),
  
  cv_parquet_files = c(
    here::here(
      "1-raw_data", "chuvash_voice",
      "audio_transcripts",
      "train-00000-of-00003.parquet"
    ),
    here::here(
      "1-raw_data", "chuvash_voice",
      "audio_transcripts",
      "train-00001-of-00003.parquet"
    ),
    here::here(
      "1-raw_data", "chuvash_voice",
      "audio_transcripts",
      "train-00002-of-00003.parquet"
    )
  ),
  
  durations_mfa = here::here(
    "7-extract", "utterance_duration",
    "chuvash_voice_utterance_durations.csv"
  ),
  
  durations_vox = here::here(
    "7-extract", "utterance_duration",
    "common_voice_chuvash_utterance_durations.csv"
  ),
  
  
  # ── Pipeline data folders ───────────────────────────────────────
  #
  # loaded/  : outputs of 01_load_raw.R
  # cleaned/ : outputs of 02_clean.R
  # leveled/ : outputs of 03_build_levels.R and 04_annotate.R
  
  loaded_dir = here::here(
    "9-analyze", "data", "loaded"
  ),
  
  cleaned_dir = here::here(
    "9-analyze", "data", "cleaned"
  ),
  
  leveled_dir = here::here(
    "9-analyze", "data", "leveled"
  )
)


# ── Create output folders if they don't exist ────────────────────

for (d in c(
  PATHS$loaded_dir,
  PATHS$cleaned_dir,
  PATHS$leveled_dir
)) {
  dir.create(
    d,
    recursive = TRUE,
    showWarnings = FALSE
  )
}


# ── Print project root when paths.R is sourced ───────────────────

cat("Project root:", PROJECT_ROOT, "\n")