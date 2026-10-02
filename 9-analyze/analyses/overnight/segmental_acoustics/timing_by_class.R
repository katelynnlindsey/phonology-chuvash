# Overnight 2026-10-01, segmental_acoustics: V1 (before singleton / geminate /
# cluster) and V2 (after singleton / geminate) fitted separately for obstruent
# and sonorant C1, so each effect has its own CI. Same controls as v1_context.R
# and geminate_timing.R.
suppressPackageStartupMessages({library(data.table); library(lme4); library(lmerTest); library(broom.mixed)})
OUT <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/segmental_acoustics/"
v <- fread(cmd = paste0("gzip -dc ", OUT, "v1_context_tokens.csv.gz"))[!is.na(art_rate)]
v[, next_type := factor(next_type, levels = c("singleton", "geminate", "cluster"))]
v[, srate := (art_rate - mean(art_rate)) / sd(art_rate), by = corpus]; v[, word := paste0("w", word_ascii)]
g <- fread(cmd = paste0("gzip -dc ", OUT, "geminate_timing_tokens.csv.gz"))
g <- g[!is.na(V2_dur) & !is.na(art_rate) & V1_ascii != "o" & V2_ascii != "o"]
g[, srate := (art_rate - mean(art_rate)) / sd(art_rate), by = corpus]; g[, word := paste0("w", word_ascii)]
g[, cls := ifelse(klass == "O", "obstruent", "sonorant")]
res <- list()
for (cp in c("common_voice_chuvash", "chuvash_voice")) for (cl in c("obstruent", "sonorant")) {
  re <- if (cp == "chuvash_voice") "(1|word) + (1|file_name)" else "(1|speaker) + (1|word) + (1|file_name)"
  s <- v[corpus == cp & C1_cls == cl]; if (cp == "chuvash_voice") s <- s[speaker == "ch_voice_main"]
  m <- lmer(as.formula(paste("log(dur_ms) ~ next_type + C1_ascii + V_ascii + V_stressed + V_first + word_nphone + utt_final_word + srate +", re)),
            data = s, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  t <- as.data.table(broom.mixed::tidy(m, effects = "fixed", conf.int = TRUE))[grepl("next_type", term)]
  t[, `:=`(outcome = "V1", corpus = cp, cls = cl, n = nrow(s), n_words = uniqueN(s$word), n_speakers = uniqueN(s$speaker))]
  res[[length(res) + 1]] <- t
  s <- g[corpus == cp & cls == cl]; if (cp == "chuvash_voice") s <- s[speaker == "ch_voice_main"]
  m <- lmer(as.formula(paste("log(V2_dur) ~ long + C_ascii + V2_ascii + V2_stressed + V2_word_final*utt_final_word + V1_ascii + word_nphone + srate +", re)),
            data = s, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  t <- as.data.table(broom.mixed::tidy(m, effects = "fixed", conf.int = TRUE))[term == "long"]
  t[, `:=`(outcome = "V2", corpus = cp, cls = cl, n = nrow(s), n_words = uniqueN(s$word), n_speakers = uniqueN(s$speaker))]
  res[[length(res) + 1]] <- t; cat(cp, cl, "\n")
}
r <- rbindlist(res)
r[, `:=`(pct = 100 * (exp(estimate) - 1), pct_lo = 100 * (exp(conf.low) - 1), pct_hi = 100 * (exp(conf.high) - 1))]
fwrite(r, paste0(OUT, "timing_by_class_models.csv")); cat("DONE\n")
