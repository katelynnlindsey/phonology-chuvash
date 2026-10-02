# Overnight 2026-10-01, segmental_acoustics: V1 duration before a singleton,
# a geminate and a heterosyllabic cluster (word-internal V1 C(ː)/C1C2 V).
# Tests whether a geminate "closes" V1's syllable the way a cluster does.
suppressPackageStartupMessages({library(data.table); library(lme4); library(lmerTest); library(broom.mixed)})
OUT <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/segmental_acoustics/"
d <- fread(cmd = paste0("gzip -dc ", OUT, "v1_context_tokens.csv.gz"))
d <- d[!is.na(art_rate)]
d[, next_type := factor(next_type, levels = c("singleton", "geminate", "cluster"))]
d[, srate := (art_rate - mean(art_rate)) / sd(art_rate), by = corpus]
d[, word := paste0("w", word_ascii)]
res <- list()
for (cp in c("common_voice_chuvash", "chuvash_voice")) for (vr in c("all", "full", "reduced")) {
  s <- d[corpus == cp]
  if (cp == "chuvash_voice") s <- s[speaker == "ch_voice_main"]
  if (vr == "full") s <- s[V_red == 0]; if (vr == "reduced") s <- s[V_red == 1]
  re <- if (cp == "chuvash_voice") "(1|word) + (1|file_name)" else "(1|speaker) + (1|word) + (1|file_name)"
  f <- as.formula(paste("log(dur_ms) ~ next_type*C1_cls + C1_ascii + V_ascii + V_stressed + V_first +",
                        "word_nphone + utt_final_word + srate +", re))
  m <- lmer(f, data = s, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  t <- as.data.table(broom.mixed::tidy(m, effects = "fixed", conf.int = TRUE))[grepl("next_type", term)]
  t[, `:=`(corpus = cp, V1_subset = vr, n = nrow(s), n_words = uniqueN(s$word), n_speakers = uniqueN(s$speaker),
           pct = 100 * (exp(estimate) - 1), pct_lo = 100 * (exp(conf.low) - 1), pct_hi = 100 * (exp(conf.high) - 1))]
  res[[length(res) + 1]] <- t; cat(cp, vr, "\n")
}
fwrite(rbindlist(res), paste0(OUT, "v1_context_models.csv")); cat("DONE\n")
