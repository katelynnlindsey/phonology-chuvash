# speaker_cues/models/01d_pooled_loan_exclusion.R
# Pooled A6/B5/A5/B6 models under Kate's spec, and with vowel identity, excluding loan_combined words
# (lexicon + orthographic flag, speaker_cues_2026-10-02/loan_lexicon/loan_flags_by_word.csv).
suppressPackageStartupMessages({library(data.table); library(arrow); library(lme4); library(broom.mixed)})
A <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/speaker_cues_2026-10-02"
v <- as.data.table(read_parquet(file.path(A, "models/cache/model_frame.parquet")))[sN >= 2 & sN <= 6]
lf <- fread(file.path(A, "loan_lexicon/loan_flags_by_word.csv"), select = c("word_label","loan_combined"))
v <- merge(v, lf, by = "word_label", all.x = TRUE)
cat("loan rows dropped:", v[loan_combined %in% c(1, TRUE), .N], "of", nrow(v), "\n")
v <- v[!(loan_combined %in% c(1, TRUE))]
v[, dur_c := log_duration - mean(log_duration), by = file_name]
v[, f0_c := f0_st - mean(f0_st, na.rm = TRUE), by = file_name]
v <- v[!is.na(dur_c) & !is.na(int_c) & !is.na(f0_c)]
ctrl <- "syl1 + syl2 + word_final + utt_final_word + utt_final_syl"
out <- list()
for (sp in c("kate_noloans", "kate_vowel_noloans")) for (cn in c(duration = "dur_c", intensity = "int_c", f0 = "f0_c")) for (r in c("A6","A5","B6","B5")) {
  v[, R := as.integer(get(paste0("stress_rule_", r)) == "Stressed")]
  f <- paste(cn, "~ R +", ctrl, if (sp == "kate_vowel_noloans") "+ vowel_label" else "", "+ (1|word_label)")
  m <- lmer(as.formula(f), data = v, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  td <- as.data.table(tidy(m, effects = "fixed", conf.int = TRUE))[term == "R"]
  td[, `:=`(spec = sp, cue = cn, rule = r, AIC = AIC(m), n = nrow(v))]; out[[length(out) + 1]] <- td
}
res <- rbindlist(out); res[, dAIC := AIC - min(AIC), by = .(spec, cue)]
fwrite(res, file.path(A, "models/pooled_models_loan_exclusion.csv"))
print(res[, .(spec, cue, rule, est = round(estimate, 3), dAIC = round(dAIC))])
