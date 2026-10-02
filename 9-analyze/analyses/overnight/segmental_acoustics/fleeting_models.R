# Overnight 2026-10-01, segmental_acoustics: fleeting-vowel candidates.
# (1) P(reduced vowel at the 30-ms aligner floor) ~ flanking segments, position,
#     stress, speech rate, vowel (ӑ vs ӗ); (2) P(no voicing anywhere in the
#     C1-V-C2 span | word-internal T_V_T) ~ vowel class + position + stress + rate.
suppressPackageStartupMessages({library(data.table); library(lme4); library(broom.mixed)})
OUT <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/segmental_acoustics/"
d <- fread(cmd = paste0("gzip -dc ", OUT, "fleeting_tokens.csv.gz"))[!is.na(art_rate)]
d[, srate := (art_rate - mean(art_rate)) / sd(art_rate), by = corpus]; d[, word := paste0("w", word_ascii)]
coll <- function(x) fifelse(substr(x, 1, 1) == "#", "boundary", fifelse(x == "T", "vlessObs", fifelse(x == "R", "sonorant", fifelse(x == "D", "vcdObs", "vowel"))))
d[, Lc := factor(coll(Lf), levels = c("vlessObs", "sonorant", "boundary", "vcdObs", "vowel"))]
d[, Rc := factor(coll(Rf), levels = c("vlessObs", "sonorant", "boundary", "vcdObs", "vowel"))]
d[, vpos := factor(vpos, levels = c("initial", "medial", "final", "mono"))]
d[, vclass := factor(vclass, levels = c("full_nonhigh", "full_high", "reduced"))]
res <- list()
for (cp in c("chuvash_voice", "common_voice_chuvash")) {
  re <- if (cp == "chuvash_voice") "(1|word) + (1|file_name)" else "(1|speaker) + (1|word) + (1|file_name)"
  s <- d[corpus == cp & vclass == "reduced"]; if (cp == "chuvash_voice") s <- s[speaker == "ch_voice_main"]
  m <- glmer(as.formula(paste("floor ~ Lc + Rc + vpos + stressed + srate + V_ascii + utt_final_word +", re)),
             data = s, family = binomial, nAGQ = 0, control = glmerControl(optimizer = "bobyqa", calc.derivs = FALSE))
  t <- as.data.table(broom.mixed::tidy(m, effects = "fixed", conf.int = TRUE))
  t[, `:=`(model = "floor_reduced", corpus = cp, n = nrow(s), n_events = sum(s$floor), n_words = uniqueN(s$word), n_speakers = uniqueN(s$speaker))]
  res[[length(res) + 1]] <- t; cat(cp, "floor done\n")
  s <- d[corpus == cp & Lf == "T" & Rf == "T"]; if (cp == "chuvash_voice") s <- s[speaker == "ch_voice_main"]
  m <- glmer(as.formula(paste("absent_TVT ~ vclass + vpos + stressed + srate +", re)),
             data = s, family = binomial, nAGQ = 0, control = glmerControl(optimizer = "bobyqa", calc.derivs = FALSE))
  t <- as.data.table(broom.mixed::tidy(m, effects = "fixed", conf.int = TRUE))
  t[, `:=`(model = "absent_TVT_allvowels", corpus = cp, n = nrow(s), n_events = sum(s$absent_TVT), n_words = uniqueN(s$word), n_speakers = uniqueN(s$speaker))]
  res[[length(res) + 1]] <- t; cat(cp, "absent done\n")
}
r <- rbindlist(res); r[, `:=`(OR = exp(estimate), OR_lo = exp(conf.low), OR_hi = exp(conf.high))]
fwrite(r, paste0(OUT, "fleeting_models.csv")); cat("DONE\n")
