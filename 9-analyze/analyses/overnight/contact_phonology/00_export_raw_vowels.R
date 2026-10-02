# Export a compact copy of data/loaded/vowels_spoken_raw.rds (pre-cleaning, so it
# still contains the words is_loan() removes at 02_clean step 02).
# Output: output/overnight_2026-10-01/contact_phonology/intermediate/raw_vowels_compact.csv
suppressPackageStartupMessages(library(data.table))
root <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze"
d <- readRDS(file.path(root, "data/loaded/vowels_spoken_raw.rds"))
keep <- c("file_name","corpus","speaker_id","gender","age","accents","word_label",
          "word_start","word_end","start","end","duration","time","label",
          "sidx","sN","sidx_contour","sN_contour","F1","F2","F3",
          "intensity_step10","intensity_step11","f0_mean","phrase_start","phrase_end",
          "syl_open_closed","context","pre_seg","fol_seg","smooth_error","word")
d <- as.data.table(d)[, ..keep]
gc()
d[, int_midpoint := (intensity_step10 + intensity_step11)/2]
d[, c("intensity_step10","intensity_step11") := NULL]
fwrite(d, file.path(root, "output/overnight_2026-10-01/contact_phonology/intermediate/raw_vowels_compact.csv"))
cat(nrow(d), ncol(d), "\n")
