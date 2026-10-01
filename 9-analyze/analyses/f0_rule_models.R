# =============================================================================
# f0_rule_models.R                                                  2026-10-01
#
# f0 IN THE RULE COMPARISON.  Until now every rule comparison in this project
# has been run on duration and intensity only, so Kate's three-cue criterion
# for stress -- longer duration, HIGHER intensity, HIGHER PITCH -- has never
# been tested on its third cue.  This script supplies the missing column.
#
# Specification is copied from final_syllable_prominence.R without change, so
# the f0 numbers are directly comparable to the intensity ones already
# reported there:
#   DV        f0_st, semitones from the speaker's own median (f0_measure.R)
#   position  f_sidx + f_sN + poly(rel_word,3) + is_utt_final  -- NONPARAMETRIC,
#             which is what makes `final` identified at all (its predicate is a
#             deterministic but NONLINEAR function of position)
#   controls  vowel_label (or vowel_height) + syllable_coda + z_freq
#   random    (1|word_label); the DV is already centred within recording, which
#             absorbs between-recording and between-speaker level exactly
# Monosyllables excluded, sN capped 2-6.  Every rule's design matrix is
# rank-checked against the position controls before fitting: `initial` is NOT
# identified (1{sidx==1} is the complement of the f_sidx dummies) and is
# reported as such rather than silently dropped by lmer.
#
# INTRINSIC f0 is the reason both control sets matter here.  f0 rises with
# vowel height independently of prominence, and the full/reduced distinction in
# Chuvash is partly a height distinction, so vowel_label and vowel_height can
# disagree about how much of a rule's apparent effect is intrinsic.
#
# JND for reference: Gandour (1978) gives about 1 Hz; at the pooled median of
# 215 Hz, 1 Hz is roughly 0.08 semitones, so f0 effects clear audibility far
# more easily than the 3 dB intensity JND -- a 0.5 st effect is about 6 Hz.
#
# Outputs
#   output/f0_rule_models.csv       12 rules x 2 control sets
#   output/f0_endpoint_test.csv     does the final syllable depart from trend?
# =============================================================================
suppressMessages({library(data.table); library(lme4); library(broom.mixed)})
OUT <- "output"
RULES <- c("A6","A5","A4","B6","B5","B4","SON_F","SON_A","SON_B")

v <- as.data.table(readRDS("/tmp/f0v.rds"))
v <- v[f0_ok == TRUE & !is.na(vowel_label) & !is.na(vowel_height) &
       !is.na(sidx) & !is.na(sN) & !is.na(widx) & !is.na(wN) & !is.na(word_id)]
v <- v[sN >= 2L & sN <= 6L]
v[, f_sidx := factor(sidx)][, f_sN := factor(sN)]
v[, b_final := as.integer(sidx == sN)][, b_initial := as.integer(sidx == 1L)]
v[, wt := { z <- suppressWarnings(max(sidx[syllable_coda == "closed"], na.rm = TRUE))
            if (!is.finite(z)) sN[1] else z }, by = word_id]
v[, b_weight := as.integer(sidx == wt)]
for (r in RULES) v[, (paste0("is_", r)) := get(paste0("stress_rule_", r)) == "Stressed"]
v[, file_name := factor(file_name)][, word_label := factor(word_label)]
v[, f0_c := f0_st - mean(f0_st), by = file_name]
HZ <- median(v$f0_mid, na.rm = TRUE)          # for the semitone -> Hz gloss
cat(sprintf("frame: %s vowels | %s word tokens | %s types | %s speakers | median %.1f Hz\n",
            format(nrow(v), big.mark=","), format(uniqueN(v$word_id), big.mark=","),
            format(uniqueN(v$word_label), big.mark=","), uniqueN(v$speaker_id), HZ))

POS <- "f_sidx + f_sN + poly(rel_word,3) + is_utt_final"
fit <- function(rhs) lmer(as.formula(paste("f0_c ~", rhs)), data = v, REML = FALSE,
                          control = lmerControl(calc.derivs = FALSE))
st2hz <- function(st) HZ * (2^(st/12) - 1)

cat("\n=== 1. does the FINAL syllable depart from the f0 trend? ===\n")
ep <- rbindlist(lapply(c("vowel_label","vowel_height"), function(cv) {
  BASE <- paste(cv, "syllable_coda", "z_freq", POS, "(1|word_label)", sep = " + ")
  n0 <- fit(BASE); ma <- fit(paste(BASE, "+ b_final"))
  mb <- fit(paste(BASE, "+ b_final * is_utt_final"))
  g <- function(m, lab) {
    t <- as.data.table(tidy(m, effects = "fixed"))[grepl("b_final", term)]
    data.table(control = cv, model = lab, term = t$term, est_st = t$estimate,
               se = t$std.error, t = t$statistic, est_hz = st2hz(t$estimate),
               dAIC_vs_position_only = AIC(m) - AIC(n0)) }
  rbind(g(ma, "additive"), g(mb, "with utt-final interaction"))
}))
fwrite(ep, file.path(OUT, "f0_endpoint_test.csv"))
print(ep[, .(control, model, term, st = round(est_st,4), t = round(t,2),
             Hz = round(est_hz,2), dAIC = round(dAIC_vs_position_only,1))])

cat("\n=== 2. twelve rules, identical nonparametric position controls ===\n")
PRED <- c(setNames(paste0("is_", RULES), RULES),
          final = "b_final", initial = "b_initial", weight = "b_weight")
res <- rbindlist(lapply(c("vowel_label","vowel_height"), function(cv) {
  BASE <- paste(cv, "syllable_coda", "z_freq", POS, "(1|word_label)", sep = " + ")
  n0 <- fit(BASE); aic0 <- AIC(n0)
  rbindlist(lapply(names(PRED), function(nm) {
    p <- PRED[[nm]]
    X <- model.matrix(as.formula(paste("~", POS, "+", p)), data = v)
    if (qr(X)$rank < ncol(X)) {
      cat(sprintf("  %-8s [%s] NOT IDENTIFIED against position (rank %d of %d)\n",
                  nm, cv, qr(X)$rank, ncol(X)))
      return(data.table(control = cv, rule = nm, identified = FALSE,
                        est_st = NA_real_, se = NA_real_, t = NA_real_,
                        est_hz = NA_real_, AIC = NA_real_, dAIC_vs_position_only = NA_real_))
    }
    m <- fit(paste(BASE, "+", p))
    tt <- as.data.table(tidy(m, effects = "fixed"))[term == p | term == paste0(p, "TRUE")]
    data.table(control = cv, rule = nm, identified = TRUE, est_st = tt$estimate,
               se = tt$std.error, t = tt$statistic, est_hz = st2hz(tt$estimate),
               AIC = AIC(m), dAIC_vs_position_only = AIC(m) - aic0)
  }))
}))
res[identified == TRUE, rank := frank(AIC, ties.method = "min"), by = control]
fwrite(res, file.path(OUT, "f0_rule_models.csv"))
for (cv in unique(res$control)) {
  cat(sprintf("\n-- control set: %s --\n", cv))
  print(res[control == cv][order(rank, na.last = TRUE),
        .(rank, rule, st = round(est_st,4), Hz = round(est_hz,2), t = round(t,2),
          dAIC = round(dAIC_vs_position_only,1), identified)])
}
cat("\nPOSITIVE = higher than the declination trend, which is the direction a\n")
cat("stress correlate must take under Kate's criterion. 1 Hz JND (Gandour 1978)\n")
cat(sprintf("is about %.3f semitones at this corpus's median f0.\n", 12*log2(1 + 1/HZ)))
cat("\n✓ f0_rule_models.R complete\n")
