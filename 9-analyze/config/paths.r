# config/paths.R
# Edit paths here. Everything else uses PATHS$... only.

PATHS <- list(

  # ── Outputs from 8-combine/ ──────────────────────────────────────
  vowel_points_csv  = "~/GitHub/phonology-chuvash/extract/all_chuvash_vowel_points.csv",
  cluster_mfa_csv   = "~/GitHub/phonology-chuvash/contour-clustering/output-mfa.csv",
  cluster_vox_csv   = "~/GitHub/phonology-chuvash/contour-clustering/output-vox.csv",
  words_csv         = "~/GitHub/phonology-chuvash/contour-clustering/output-words.csv",
  phrases_csv       = "~/GitHub/phonology-chuvash/contour-clustering/output-phrases.csv",

  # ── Written corpora ───────────────────────────────────────────────
  zheltov_csv       = "~/GitHub/phonology-chuvash/wordlists/zheltov_corpus.csv",
  mono_parquet      = "C:/Users/profk/Downloads/train-00000-of-00001.parquet",

  # ── Speaker metadata ──────────────────────────────────────────────
  cv_tsv            = "~/GitHub/phonology-chuvash/corpora/textgrids_commonvoice/cv_xpf_spkr17.tsv",
  cv_parquet_files  = c(
    "C:/Users/profk/Downloads/train-00000-of-00003.parquet",
    "C:/Users/profk/Downloads/train-00001-of-00003.parquet",
    "C:/Users/profk/Downloads/train-00002-of-00003.parquet"
  ),

  # ── Utterance durations (from 7-extract/extract_durations.py) ────
  durations_mfa     = "~/GitHub/phonology-chuvash/scripts/extract file durations/utterance_durations_mfa.csv",
  durations_vox     = "~/GitHub/phonology-chuvash/scripts/extract file durations/utterance_durations_vox.csv",

  # ── Pipeline outputs (created by pipeline/; read by analyses/) ───
  cleaned_dir       = "~/GitHub/phonology-chuvash/9-analyze/data/cleaned"
)

if (!dir.exists(PATHS$cleaned_dir)) {
  dir.create(PATHS$cleaned_dir, recursive = TRUE)
}