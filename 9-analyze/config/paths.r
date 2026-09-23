# config/paths.R

PATHS <- list(
  
  # ── Inputs from upstream pipeline stages ─────────────────────
  vowel_points_csv  = "~/GitHub/phonology-chuvash/8-combine/all_chuvash_vowel_points.csv",
  cluster_mfa_csv   = "~/GitHub/phonology-chuvash/7-extract/contours/vowels/chuvash_voice/contours_output.csv",
  cluster_vox_csv   = "~/GitHub/phonology-chuvash/7-extract/contours/vowels/common_voice_chuvash/contours_output.csv",
  words_csv         = "~/GitHub/phonology-chuvash/7-extract/contours/words_phrases/output-words.csv",
  phrases_csv       = "~/GitHub/phonology-chuvash/7-extract/contours/words_phrases/output-phrases.csv",
  zheltov_csv       = "~/GitHub/phonology-chuvash/6-annotate/chuvash_wordlist/zheltov_corpus.csv",
  zheltov_raw_csv   = "~/GitHub/phonology-chuvash/1-raw_data/chuvash_wordlist/wordlist_just_words.csv",
  mono_parquet      = "~/GitHub/phonology-chuvash/1-raw_data/monolingual_chuvash/train-00000-of-00001.parquet",
  cv_tsv            = "~/GitHub/phonology-chuvash/1-raw_data/common_voice_chuvash/audio_metadata_Mozilla/cv_xpf_spkr17.tsv",
  cv_parquet_files  = c(
    "~/GitHub/phonology-chuvash/1-raw_data/chuvash_voice/audio_transcripts/train-00000-of-00003.parquet",
    "~/GitHub/phonology-chuvash/1-raw_data/chuvash_voice/audio_transcripts/train-00001-of-00003.parquet",
    "~/GitHub/phonology-chuvash/1-raw_data/chuvash_voice/audio_transcripts/train-00002-of-00003.parquet"
  ),
  durations_mfa     = "~/GitHub/phonology-chuvash/7-extract/utterance_duration/chuvash_voice_utterance_durations.csv",
  durations_vox     = "~/GitHub/phonology-chuvash/7-extract/utterance_duration/common_voice_chuvash_utterance_durations.csv",
  
  # ── Pipeline data folders ─────────────────────────────────────
  # loaded/  : outputs of 01_load_raw.R
  #            joined from source files, nothing removed yet
  # cleaned/ : outputs of 02_clean.R
  #            rows removed, exclusion log and report stored here
  # leveled/ : outputs of 03_build_levels.R and 04_annotate.R
  #            reshaped into linguistic levels, phonological labels applied
  
  loaded_dir  = "~/GitHub/phonology-chuvash/9-analyze/data/loaded",
  cleaned_dir = "~/GitHub/phonology-chuvash/9-analyze/data/cleaned",
  leveled_dir = "~/GitHub/phonology-chuvash/9-analyze/data/leveled"
)

# Create folders if they do not exist
for (d in c(PATHS$loaded_dir, PATHS$cleaned_dir, PATHS$leveled_dir)) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
}