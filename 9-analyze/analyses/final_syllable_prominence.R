# =============================================================================
# final_syllable_prominence.R                                    2026-09-29
#
# CAN A "STRESS IS WORD-FINAL" RULE BE TESTED AT ALL?
#
# THE PROBLEM. The `final` baseline's predictor is 1{sidx == sN}, which is
# bit-for-bit identical to the binary final-lengthening control `syl_final`
# (verified on all 574,344 rows; output/rule_final_collinearity.csv). In that
# specification it is unidentifiable: omit the control and `final` absorbs the
# whole +69% edge effect and "wins" for a reason unrelated to prominence;
# include it and no residual variation is left. No intermediate exists.
#
# THE SOLUTION (Kate's). Model declination as what it is -- a GRADIENT over
# position -- rather than as a binary endpoint flag. Intensity falls across an
# utterance (later words quieter) and across a word (later syllables quieter).
# Once position enters as a gradient, 1{sidx == sN} is a deterministic but
# NONLINEAR function of it, hence linearly independent, hence identified. The
# coefficient then answers a sharp question:
#
#       is the last syllable louder than the position trend predicts?
#
# Zero or negative => it is just the end of a declination ramp. Positive =>
# prominence counteracting the dampening. That is a discontinuity test, and it
# is the one test of final stress this corpus supports.
#
# WHY THE POSITION TREND IS NONPARAMETRIC. A polynomial in sidx/sN makes the
# answer depend on functional form: end-curvature the polynomial cannot follow
# is handed to the endpoint dummy, manufacturing the effect being looked for.
# factor(sidx) + factor(sN) entered ADDITIVELY imposes no shape -- a free mean
# per syllable position and per word length -- and the endpoint dummy then
# tests departure from ADDITIVITY on the diagonal of the sidx x sN table.
# This mattered: intensity RISES from syllable 1 to 2 (+0.52 dB) before
# falling, which a smooth trend would have flattened.
#
# MONOSYLLABLES EXCLUDED. In a one-syllable word there is no within-word trend
# to depart from, and the known structural confound applies (bearing lexical
# stress and being a whole prosodic word coincide there). sN capped at 6 =
# 91.8% of rows with intensity, every factor level >= 650 observations.
#
# WHICH POSITIONAL HYPOTHESES ARE TESTABLE THIS WAY. Only those whose
# predictor is NOT a function of the trend's own variables alone:
#   final    1{sidx == sN}  depends on sidx AND sN jointly (the diagonal),
#                           which additive main effects cannot express  -> YES
#   initial  1{sidx == 1}   depends on sidx alone, and is exactly the
#                           complement of the factor(sidx) dummies      -> NO
#   weight   rightmost closed syllable, carries coda information        -> YES
# lmer DROPS a collinear column silently rather than erroring, so every fit
# below is rank-checked first and `initial` is reported as NOT IDENTIFIED.
#
# WHY IT DOES NOT SOURCE 00_session_setup.R. The first version did and was
# killed twice by the OS with no R-level error after section 1: the session
# tables occupy ~4.8 GB before any fit, and each lmer fit on 527k rows with
# 45,861 file_name levels adds its own model frame. Reading only the needed
# columns gives a 0.09 GB frame.
#
# RANDOM EFFECTS, AND THEIR VALIDATION. Intensity is centred WITHIN RECORDING,
# which absorbs all between-recording and between-speaker level variation
# exactly (speaker is nested in recording), leaving within-recording contrasts
# -- which is what a position effect is. Checked on the headline coefficient:
#       centred + (1|word_label) : -0.7651 dB, t = -36.10,  21.6 s
#       three random effects     : -0.7780 dB, t = -35.50, 984.0 s
# a 1.7% difference at 1/45 the cost.
#
# WHAT THIS STILL CANNOT DO. A boundary-aligned prominence and a word-final
# lexical stress make the same prediction. This separates "prominence at the
# final syllable" from "smooth declination"; it does not separate "final
# stress" from "phrase-boundary marking". That needs non-acoustic evidence.
#
# Outputs
#   output/final_prominence_position_profile.csv   the declination gradients
#   output/final_prominence_test.csv               the endpoint departure
#   output/final_prominence_rule_ranking.csv       12 rules, same controls
# =============================================================================

suppressMessages({library(data.table); library(lme4); library(broom.mixed)})
OUT <- "output"
RULES <- c("A6","A5","A4","B6","B5","B4","SON_F","SON_A","SON_B")

need <- c("int_midpoint","log_duration","vowel_label","syllable_coda","log_speech_rate",
          "log_corpus_freq_smoothed","sidx","sN","widx","wN","word_id",
          "speaker_id","file_name","word_label", paste0("stress_rule_", RULES))
v <- as.data.table(readRDS("data/leveled/vowels_spoken_annotated.rds"))[, ..need]
v <- v[!is.na(vowel_label) & !is.na(sidx) & !is.na(sN) & !is.na(int_midpoint) &
        !is.na(log_duration) & !is.na(widx) & !is.na(wN) & !is.na(word_id)]
v <- v[sN >= 2L & sN <= 6L]
v[, is_final := sidx == sN][, is_utt_final := widx == wN][, rel_word := widx/wN]
v[, f_sidx := factor(sidx)][, f_sN := factor(sN)]
v[, z_freq := as.numeric(scale(log_corpus_freq_smoothed))][is.na(z_freq), z_freq := 0]
v[, b_final := as.integer(is_final)][, b_initial := as.integer(sidx == 1L)]
v[, wt := { z <- suppressWarnings(max(sidx[syllable_coda == "closed"], na.rm = TRUE))
            if (!is.finite(z)) sN[1] else z }, by = word_id]
v[, b_weight := as.integer(sidx == wt)]
for (r in RULES) v[, (paste0("is_", r)) := get(paste0("stress_rule_", r)) == "Stressed"]
v[, file_name := factor(file_name)][, word_label := factor(word_label)]
v[, int_c := int_midpoint - mean(int_midpoint), by = file_name]
v[, dur_c := log_duration  - mean(log_duration),  by = file_name]
cat(sprintf("\nframe: %s vowels | %s word tokens | %s types\n",
            format(nrow(v), big.mark=","), format(uniqueN(v$word_id), big.mark=","),
            format(uniqueN(v$word_label), big.mark=",")))

POS  <- "f_sidx + f_sN + poly(rel_word,3) + is_utt_final"
COV  <- "vowel_label + syllable_coda + z_freq"
BASE <- paste(COV, POS, "(1|word_label)", sep = " + ")
fit <- function(rhs, dv = "int_c")
  lmer(as.formula(paste(dv, "~", rhs)), data = v, REML = FALSE,
       control = lmerControl(calc.derivs = FALSE))
base_ms <- median(exp(v$log_duration))

cat("\n=== 1. the declination profile (no stress term in the model) ===\n")
m0 <- fit(BASE)
prof <- as.data.table(tidy(m0, effects = "fixed"))[
  grepl("^f_sidx|^f_sN|rel_word|is_utt_final", term),
  .(term, estimate = round(estimate,4), se = round(std.error,4), t = round(statistic,2))]
fwrite(prof, file.path(OUT, "final_prominence_position_profile.csv")); print(prof)

cat("\n=== 2. does the FINAL syllable depart from that trend? ===\n")
res <- rbindlist(lapply(c("int_c","dur_c"), function(dv) {
  n0 <- fit(BASE, dv); ma <- fit(paste(BASE,"+ b_final"), dv)
  mb <- fit(paste(BASE,"+ b_final * is_utt_final"), dv)
  g <- function(m, lab) { t <- as.data.table(tidy(m, effects="fixed"))[grepl("b_final", term)]
    data.table(dv=dv, model=lab, term=t$term, estimate=t$estimate, se=t$std.error, t=t$statistic,
      dB  = if (dv=="int_c") t$estimate else NA_real_,
      pct = if (dv=="dur_c") 100*(exp(t$estimate)-1) else NA_real_,
      ms  = if (dv=="dur_c") base_ms*(exp(t$estimate)-1) else NA_real_,
      dAIC_vs_position_only = AIC(m) - AIC(n0)) }
  rbind(g(ma,"additive"), g(mb,"with utt-final interaction"))
}))
fwrite(res, file.path(OUT, "final_prominence_test.csv"))
print(res[, .(dv, model, term, est=round(estimate,4), t=round(t,2), dB=round(dB,3),
              pct=round(pct,2), ms=round(ms,2), dAIC=round(dAIC_vs_position_only,1))])
cat("\nJND: intensity 3 dB (Moore 2007), duration 10 ms (Hirsh 1959).\n")
cat("POSITIVE intensity = louder than trend, i.e. prominence counteracting\n")
cat("declination. NEGATIVE = quieter than trend, i.e. boundary lowering.\n")

cat("\n=== 3. twelve rules, identical nonparametric position controls ===\n")
PRED <- c(setNames(paste0("is_",RULES), RULES),
          final="b_final", initial="b_initial", weight="b_weight")
aic0 <- AIC(m0)
rk <- rbindlist(lapply(names(PRED), function(nm) {
  p <- PRED[[nm]]
  X <- model.matrix(as.formula(paste("~", POS, "+", p)), data = v)
  if (qr(X)$rank < ncol(X)) {
    cat(sprintf("  %-8s NOT IDENTIFIED against the position controls (rank %d of %d)\n",
                nm, qr(X)$rank, ncol(X)))
    return(data.table(rule=nm, effect_dB=NA_real_, se=NA_real_, t=NA_real_,
                      AIC=NA_real_, dAIC_vs_position_only=NA_real_, identified=FALSE))
  }
  m <- fit(paste(BASE, "+", p))
  tt <- as.data.table(tidy(m, effects="fixed"))[term %in% c(p, paste0(p,"TRUE"))]
  cat(sprintf("  %-8s dB=%+7.4f  t=%7.2f  AIC=%11.1f\n", nm, tt$estimate, tt$statistic, AIC(m)))
  data.table(rule=nm, effect_dB=tt$estimate, se=tt$std.error, t=tt$statistic,
             AIC=AIC(m), dAIC_vs_position_only=AIC(m)-aic0, identified=TRUE)
}))
rk[identified==TRUE, dAIC := round(AIC-min(AIC,na.rm=TRUE),1)]
rk[identified==TRUE, rank := frank(AIC, ties.method="min")]
fwrite(rk, file.path(OUT, "final_prominence_rule_ranking.csv"))
print(rk[order(rank, na.last=TRUE), .(rank, rule, effect_dB=round(effect_dB,4),
        t=round(t,2), dAIC, improves_on_position_only=round(dAIC_vs_position_only,1), identified)])
cat("\nREAD THE SIGN, NOT ONLY THE AIC RANK. AIC rewards any informative\n")
cat("predictor regardless of direction, so `final` outranks three SON rules\n")
cat("while predicting the OPPOSITE of prominence. Every named rule is\n")
cat("positive; `final` is the only negative one.\n")
cat("\n✓ final_syllable_prominence.R complete\n")
