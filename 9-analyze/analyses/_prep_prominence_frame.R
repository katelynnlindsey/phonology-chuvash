suppressMessages(library(data.table))
RULES <- c("A6","B5","SON_B")
need <- c("int_midpoint","log_duration","vowel_label","syllable_coda","sidx","sN",
          "widx","wN","word_id","file_name","word_label","log_corpus_freq_smoothed",
          paste0("stress_rule_", RULES))
v <- as.data.table(readRDS("data/leveled/vowels_spoken_annotated.rds"))[, ..need]
v <- v[!is.na(vowel_label) & !is.na(sidx) & !is.na(sN) & !is.na(int_midpoint) &
        !is.na(log_duration) & !is.na(widx) & !is.na(wN) & !is.na(word_id)]
v <- v[sN >= 2L & sN <= 6L]
v[, is_final := sidx == sN][, is_utt_final := widx == wN][, rel_word := widx/wN]
v[, cell := factor(paste0("s", sidx, "of", sN))]
v[, cell := relevel(cell, ref = "s1of2")]
v[, z_freq := as.numeric(scale(log_corpus_freq_smoothed))][is.na(z_freq), z_freq := 0]
v[, file_name := factor(file_name)][, word_label := factor(word_label)]
v[, int_c := int_midpoint - mean(int_midpoint), by = file_name]
v[, dur_c := log_duration  - mean(log_duration),  by = file_name]
for (r in RULES) v[, (paste0("is_",r)) := get(paste0("stress_rule_",r)) == "Stressed"]
v[, (paste0("stress_rule_", RULES)) := NULL][, log_corpus_freq_smoothed := NULL]
saveRDS(v, "/tmp/v2.rds"); cat(sprintf("prepped %s rows\n", format(nrow(v), big.mark=",")))
