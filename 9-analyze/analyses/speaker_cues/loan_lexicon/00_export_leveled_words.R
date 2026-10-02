# Export distinct word tokens (word_label, corpus, file, word_id) from the leveled spoken vowels.
suppressPackageStartupMessages({library(data.table); library(arrow)})
root <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze"
out  <- file.path(root, "output/speaker_cues_2026-10-02/loan_lexicon/cache")
d <- as.data.table(readRDS(file.path(root, "data/leveled/vowels_spoken_annotated.rds")))
cat("rows", nrow(d), "\n"); print(intersect(c("word_id","word_label","corpus","file_name","word_start","speaker_id"), names(d)))
keep <- intersect(c("word_id","word_label","corpus","file_name","word_start","speaker_id"), names(d))
w <- unique(d[, ..keep])
cat("word tokens", nrow(w), " types", uniqueN(w$word_label), "\n")
write_parquet(w, file.path(out, "leveled_word_tokens.parquet"))
