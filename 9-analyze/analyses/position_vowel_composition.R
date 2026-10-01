# =============================================================================
# position_vowel_composition.R                                    2026-10-01
#
# KATE'S QUESTION: rather than asking what makes syllable 2 special, is
# syllable 1 being DEMOTED? Does it carry a higher proportion of vowels other
# than /a/ and /e/ -- i.e. vowels with lower intrinsic intensity and duration?
#
# The first half is descriptive and the answer is yes. The second half is the
# test that matters: the cell-means profile already carries vowel_label as an
# additive covariate, but an additive term only controls composition if the
# position effect is the SAME within every vowel. If instead the profile is a
# composition artefact, it should DISAPPEAR when computed within a single
# vowel. So the profile is re-estimated with a full vowel x position
# interaction on trisyllables, where syllable 2 is word-internal.
#
# Outputs
#   output/position_vowel_composition.csv   composition and intrinsic values
#   output/position_profile_by_vowel.csv    the profile within each vowel
# =============================================================================
suppressMessages({library(data.table); library(lme4); library(broom.mixed)})
OUT <- "output"
v <- readRDS("/tmp/v2.rds")

# ── 1. composition and intrinsic values ─────────────────────────────────
LOUD <- c("a","e")   # the two long/loud vowels
comp <- v[, .N, by = .(sidx, vowel_label)]
comp[, pct_of_position := 100*N/sum(N), by = sidx]
wide <- dcast(comp, sidx ~ vowel_label, value.var = "pct_of_position", fill = 0)
intr <- v[, .(n = .N, median_dur_ms = median(exp(log_duration)),
              mean_int_dB = mean(int_midpoint)), by = vowel_label][order(-median_dur_ms)]
share <- v[, .(pct_a_or_e = 100*mean(vowel_label %in% LOUD),
               n = .N), by = sidx][order(sidx)]
cat("\n== intrinsic values per vowel (raw, uncentred) ==\n"); print(intr)
cat("\n== share of each syllable position that is /a/ or /e/ ==\n"); print(share)
cat("\n== full composition, % of each position's tokens ==\n")
print(wide[, lapply(.SD, function(x) if (is.numeric(x)) round(x,1) else x)])
fwrite(merge(comp, intr, by="vowel_label"), file.path(OUT,"position_vowel_composition.csv"))

# ── 2. does the profile survive WITHIN a vowel? ─────────────────────────
# Trisyllables only: syllable 2 is word-internal there, so the contrast is not
# confounded with final lowering.
d <- v[sN == 3L]
d[, f_sidx := factor(sidx)]
d[, vowel_label := droplevels(factor(vowel_label))]
COV <- "syllable_coda + z_freq + poly(rel_word,3) + is_utt_final"
res <- rbindlist(lapply(c("int_c","dur_c"), function(dv) {
  m <- lmer(as.formula(paste(dv, "~ vowel_label * f_sidx +", COV, "+ (1|word_label)")),
            data = d, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  # syllable-2-minus-syllable-1 within each vowel = main effect + interaction
  b <- fixef(m); V <- as.matrix(vcov(m))
  lv <- levels(d$vowel_label)
  rbindlist(lapply(lv, function(vl) {
    k <- numeric(length(b)); names(k) <- names(b)
    k["f_sidx2"] <- 1
    it <- paste0("vowel_label", vl, ":f_sidx2")
    if (it %in% names(b)) k[it] <- 1
    est <- sum(k*b); se <- sqrt(as.numeric(t(k) %*% V %*% k))
    base <- median(exp(d[vowel_label == vl, log_duration]))
    data.table(dv = dv, vowel = vl, n = d[vowel_label == vl, .N],
               syl2_minus_syl1 = est, se = se, t = est/se,
               ms = if (dv=="dur_c") base*(exp(est)-1) else NA_real_,
               dB = if (dv=="int_c") est else NA_real_)
  }))
}))
fwrite(res, file.path(OUT,"position_profile_by_vowel.csv"))
cat("\n== syllable 2 minus syllable 1, WITHIN each vowel (trisyllables) ==\n")
print(res[, .(dv, vowel, n=format(n,big.mark=","), est=round(syl2_minus_syl1,4),
              t=round(t,2), ms=round(ms,2), dB=round(dB,3))])
cat("\nIf the syllable-2 peak were a composition artefact it would vanish here.\n")
cat("\n✓ position_vowel_composition.R complete\n")
