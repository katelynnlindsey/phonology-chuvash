# ══════════════════════════════════════════════════════════════════════
# overnight/sociophonetics/00_extract.R
#
# Column-subset export of the leveled vowel table for the sociophonetics
# track. Reads data/leveled/vowels_spoken_annotated.rds (current as of the
# 2026-09-29 stage-4 re-run), keeps only the columns this track needs, joins
#   - the recording-level voice clusters (output/speaker_structure.csv)
#   - Common Voice accents / client_id from the Mozilla TSV
# and writes a parquet cache under output/overnight_2026-10-01/sociophonetics/cache/.
#
# Speaker key `spk`:
#   Common Voice  -> "cv_<speaker_id>"   (TSV speaker_id, 1:1 with client_id)
#   Chuvash Voice -> "chv_<voice_label>" (acoustic cluster; voice_main dominant)
#
# Run: LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 Rscript --vanilla 00_extract.R
# ══════════════════════════════════════════════════════════════════════
suppressPackageStartupMessages({library(data.table); library(arrow)})
ROOT <- "/Users/kate/Documents/GitHub/phonology-chuvash"
A    <- file.path(ROOT, "9-analyze")
OUT  <- file.path(A, "output/overnight_2026-10-01/sociophonetics")
dir.create(file.path(OUT, "cache"), recursive = TRUE, showWarnings = FALSE)

t0 <- Sys.time()
v <- readRDS(file.path(A, "data/leveled/vowels_spoken_annotated.rds"))
stopifnot(nrow(v) == 574344)
keep <- c("file_name","corpus","speaker_id","gender","age","word_id","word_label",
          "vowel_label","vowel_class","vowel_height","vowel_backness","vowel_rounding",
          "sidx","sN","wN","widx","word_token_idx","syllable_coda","vowel_position",
          "phrase_position","pre_seg","fol_seg","F1","F2","F3","duration","log_duration",
          "int_midpoint","f0_mean","f0_slope","smooth_error","iqr_outlier_any",
          "iqr_outlier_F1","iqr_outlier_F2","iqr_outlier_duration","word_complete",
          "speech_rate","log_speech_rate","duration_seconds","start","end","time",
          "word_start","word_end","phrase_start","phrase_end","n_syl_present",
          "log_corpus_freq","log_corpus_freq_smoothed",
          "stress_rule_A6","stress_rule_B5","stress_rule_A5","stress_rule_B6")
miss <- setdiff(keep, names(v)); if (length(miss)) cat("missing:", miss, "\n")
v <- as.data.table(v)[, intersect(keep, names(v)), with = FALSE]
gc()
for (cc in c("phrase_position","vowel_position","syllable_coda","vowel_class",
             "vowel_height","vowel_backness","vowel_rounding","stress_rule_A6",
             "stress_rule_B5","stress_rule_A5","stress_rule_B6"))
  if (is.factor(v[[cc]])) v[, (cc) := as.character(get(cc))]

spk <- fread(file.path(A, "output/speaker_structure.csv"))[, .(file_name, voice_label)]
stopifnot(!anyDuplicated(spk$file_name))
v <- merge(v, spk, by = "file_name", all.x = TRUE)

tsv <- fread(file.path(ROOT, "1-raw_data/common_voice_chuvash/audio_metadata_Mozilla/cv_xpf_spkr17.tsv"),
             sep = "\t", quote = "", encoding = "UTF-8")
tsv[, file_name := sub("\\.mp3$", "", path)]
cat("example file names: CV-vowels:", head(v[corpus != "chuvash_voice", file_name], 2),
    " TSV:", head(tsv$file_name, 2), "\n")
tsv <- tsv[, .(file_name, client_id, tsv_speaker_id = speaker_id, tsv_age = age,
               tsv_gender = gender, accents = trimws(accents))]
v <- merge(v, tsv, by = "file_name", all.x = TRUE)
cat("CV rows matched to TSV:", v[corpus != "chuvash_voice", mean(!is.na(client_id))], "\n")

v[, spk := fifelse(corpus == "chuvash_voice",
                   paste0("chv_", fifelse(is.na(voice_label), "unassigned", voice_label)),
                   paste0("cv_", tsv_speaker_id))]
cat("corpus x speaker_id(orig) check:\n"); print(v[, .(n = .N, n_spk_orig = uniqueN(speaker_id),
                                                     n_spk = uniqueN(spk)), by = corpus])
write_parquet(v, file.path(OUT, "cache/vowels_socio.parquet"))
cat(sprintf("wrote %d rows x %d cols in %.0f s\n", nrow(v), ncol(v),
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))
