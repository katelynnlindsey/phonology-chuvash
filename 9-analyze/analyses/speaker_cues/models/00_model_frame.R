# speaker_cues/models/00_model_frame.R
# Column-subset export of the leveled vowel table for the per-speaker stress-cue models.
# Adds Kate's positional controls (syllable 1, syllable 2, word-final, utterance-final word,
# utterance-final syllable) and f0 in semitones re the speaker's median (f0_measure.R definition:
# f0_mid = mean(f0_step10, f0_step11); |st| > 12 dropped as octave errors).
# Speaker key `spk` is joined from the overnight sociophonetics cache (cv_<id> / chv_<voice cluster>).
# Run: LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 Rscript --vanilla 00_model_frame.R
suppressPackageStartupMessages({library(data.table); library(arrow)})
A   <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze"
OUT <- file.path(A, "output/speaker_cues_2026-10-02/models/cache")
v <- as.data.table(readRDS(file.path(A, "data/leveled/vowels_spoken_annotated.rds")))
stopifnot(nrow(v) == 574344)
rules <- grep("^stress_rule_(A[456]|B[456]|SON_[FAB])$", names(v), value = TRUE)
cat("rules:", rules, "\n")
keep <- c("file_name","corpus","word_id","word_label","word_token_idx","wN","widx","sidx","sN",
          "vowel_label","vowel_class","vowel_height","syllable_coda","phrase_position",
          "duration","log_duration","int_midpoint","f0_step10","f0_step11","iqr_outlier_any",
          "speech_rate","log_speech_rate", rules)
cat("missing:", setdiff(keep, names(v)), "\n")
v <- v[, intersect(keep, names(v)), with = FALSE]; gc()
for (cc in names(v)) if (is.factor(v[[cc]])) v[, (cc) := as.character(get(cc))]
spk <- as.data.table(read_parquet(file.path(A, "output/overnight_2026-10-01/sociophonetics/cache/vowels_socio.parquet"),
                                  col_select = c("file_name","spk")))
spk <- unique(spk); stopifnot(!anyDuplicated(spk$file_name))
v <- merge(v, spk, by = "file_name", all.x = TRUE)
cat("rows without spk:", v[is.na(spk), .N], "\n")
# positional controls
v[, last_tok := max(word_token_idx), by = file_name]
v[, `:=`(syl1 = as.integer(sidx == 1), syl2 = as.integer(sidx == 2),
         word_final = as.integer(sidx == sN),
         utt_final_word = as.integer(word_token_idx == last_tok))]
v[, utt_final_syl := word_final * utt_final_word]
# f0 in semitones re speaker median
v[, f0_mid := (f0_step10 + f0_step11) / 2]
v[f0_mid <= 0, f0_mid := NA_real_]
v[, f0_med_spk := median(f0_mid, na.rm = TRUE), by = spk]
v[, f0_st := 12 * log2(f0_mid / f0_med_spk)]
v[abs(f0_st) > 12, f0_st := NA_real_]
v[, int_c := int_midpoint - mean(int_midpoint, na.rm = TRUE), by = file_name]
v[, last_tok := NULL]
write_parquet(v, file.path(OUT, "model_frame.parquet"))
cat("written", nrow(v), "rows,", ncol(v), "cols; f0_st NA:", v[is.na(f0_st), .N],
    "; utt_final_word share:", round(mean(v$utt_final_word), 3), "\n")
print(v[, .N, by = .(corpus)])
