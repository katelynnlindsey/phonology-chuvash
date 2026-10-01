# =============================================================================
# position_cell_means.R                                           2026-10-01
#
# The within-word prominence profile, SATURATED: one free mean per
# (syllable index, word length) cell, for both duration and intensity.
#
# WHY SATURATED. factor(sidx) + factor(sN) entered ADDITIVELY cannot separate
# "second syllable" from "final syllable of a disyllable" -- in a disyllable
# they are the same thing, and 43.6% of rows are disyllables. Kate asked
# whether the syllable-2 intensity peak was an artefact of exactly that. A
# cell-means model answers it; the additive one cannot.
#
# NOTE on a data.table trap that produced a wrong first version: inside
# `DT[, x := if (dv == "...") ... ]` the name `dv` resolves to the COLUMN, not
# to the loop variable, so the condition has length > 1. Use a differently
# named local (this_dv).
#
# Output: output/position_cell_means.csv  (one row per cell per dv)
# =============================================================================
suppressMessages({library(data.table); library(lme4); library(broom.mixed)})
OUT <- "output"
v <- readRDS("/tmp/v2.rds")
COV <- "vowel_label + syllable_coda + z_freq + poly(rel_word,3) + is_utt_final"
base_ms <- median(exp(v$log_duration))

out <- rbindlist(lapply(c("int_c","dur_c"), function(this_dv) {
  m <- lmer(as.formula(paste(this_dv, "~", COV, "+ cell + (1|word_label)")),
            data = v, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  tt <- as.data.table(tidy(m, effects = "fixed"))[grepl("^cell", term)]
  tt[, term := sub("^cell", "", term)]
  tt <- rbind(data.table(term = "s1of2", estimate = 0,
                         std.error = NA_real_, statistic = NA_real_),
              tt[, .(term, estimate, std.error, statistic)], fill = TRUE)
  tt[, dv := this_dv]
  tt[, sidx := as.integer(sub("^s(\\d)of.*", "\\1", term))]
  tt[, sN   := as.integer(sub(".*of(\\d)$", "\\1", term))]
  tt[, is_final := sidx == sN]
  tt[, ms := if (this_dv == "dur_c") base_ms * (exp(estimate) - 1) else NA_real_]
  tt[, dB := if (this_dv == "int_c") estimate else NA_real_]
  tt[]
}))
out[, n := v[, .N, by = .(sidx, sN)][out, on = .(sidx, sN), x.N]]
setorder(out, dv, sN, sidx)
fwrite(out, file.path(OUT, "position_cell_means.csv"))

for (this_dv in c("int_c","dur_c")) {
  u <- out[dv == this_dv]
  cat(sprintf("\n== %s: syllable 2 minus syllable 1, per word length ==\n",
              ifelse(this_dv=="int_c","INTENSITY (dB)","DURATION (ms)")))
  for (k in 2:6) {
    a <- u[sN==k & sidx==1L]; b <- u[sN==k & sidx==2L]
    if (!nrow(a) || !nrow(b)) next
    val <- if (this_dv=="dur_c") b$ms - a$ms else b$dB - a$dB
    fin <- u[sN==k & is_final == TRUE]
    cat(sprintf("  sN=%d : %+7.3f   | final syllable %+7.3f  (syl 2 is %s)\n",
                k, val, if (this_dv=="dur_c") fin$ms else fin$dB,
                ifelse(k==2,"WORD-FINAL","word-internal")))
  }
}
cat("\n✓ position_cell_means.R complete\n")
