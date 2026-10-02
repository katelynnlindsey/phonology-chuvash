# speaker_cues/models/01b_broadcast_decomposition.R
# Splits the pooled rule x broadcast-score interaction into a within-speaker part (file score minus the
# speaker's mean score) and a between-speaker part (the speaker's mean score), for A6 and B5.
# DV centred within file ~ rule*(bs_within + bs_between) + Kate's controls + (1|word_label).
suppressPackageStartupMessages({library(data.table); library(arrow); library(lme4); library(broom.mixed)})
A <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/speaker_cues_2026-10-02"
v <- as.data.table(read_parquet(file.path(A, "models/cache/model_frame.parquet")))[sN >= 2 & sN <= 6]
bs <- fread(file.path(A, "broadcast_score/broadcast_score_by_file.csv"), select = c("file_name","broadcast_score"))
v <- merge(v, bs, by = "file_name")
v[, dur_c := log_duration - mean(log_duration), by = file_name]
v[, f0_c := f0_st - mean(f0_st, na.rm = TRUE), by = file_name]
v <- v[!is.na(dur_c) & !is.na(int_c) & !is.na(f0_c) & !is.na(broadcast_score)]
fs <- unique(v[, .(file_name, spk, broadcast_score)])
fs[, bs_between := mean(broadcast_score), by = spk]
fs[, bs_within := broadcast_score - bs_between]
fs[, bs_between := bs_between - mean(bs_between)]
v <- merge(v, fs[, .(file_name, bs_within, bs_between)], by = "file_name")
ctrl <- "syl1 + syl2 + word_final + utt_final_word + utt_final_syl"
out <- list()
for (r in c("A6","B5")) {
  v[, R := as.integer(get(paste0("stress_rule_", r)) == "Stressed")]
  for (cn in c(duration = "dur_c", intensity = "int_c", f0 = "f0_c")) {
    m <- lmer(as.formula(paste(cn, "~ R*(bs_within + bs_between) +", ctrl, "+ (1|word_label)")), data = v, REML = FALSE,
              control = lmerControl(calc.derivs = FALSE))
    td <- as.data.table(tidy(m, effects = "fixed", conf.int = TRUE))[grepl("^R", term)]
    td[, `:=`(rule = r, cue = cn, n = nrow(v))]; out[[length(out) + 1]] <- td
  }
}
res <- rbindlist(out); fwrite(res, file.path(A, "models/pooled_broadcast_decomposition.csv")); print(res[, .(rule, cue, term, estimate = round(estimate, 3), conf.low = round(conf.low, 3), conf.high = round(conf.high, 3))])
