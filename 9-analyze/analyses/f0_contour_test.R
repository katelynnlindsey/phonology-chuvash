# =============================================================================
# f0_contour_test.R                                                 2026-10-01
#
# f0 AS A STRESS CUE, by the within-word step design of contour_shape_test.R.
# Three questions, in order of how much rests on them:
#
#   Q1  Is there a SYLLABLE-2 f0 PEAK?  Intensity peaks on syllable 2 in 13 of
#       14 class x length cells and duration peaks word-finally.  If f0 also
#       peaks on syllable 2, "the second syllable is prominent in Chuvash"
#       becomes a two-of-three-cue claim instead of a one-cue curiosity.
#       Answered by the saturated (sidx, sN) cell means, section 2.
#
#   Q2  Does f0 mark syllable 1 in ALL-REDUCED words?  Neither duration nor
#       intensity does -- intensity RISES after syllable 1 there -- so if those
#       words are heard as initially stressed, f0 is the only candidate left
#       among the cues in Kate's criterion.  Answered by sections 3-4.
#
#   Q3  Does f0 behave like duration (tracks the rule) or like intensity
#       (tracks position)?  Answered by the designation effect on the adjacent
#       step, section 5.
#
# MEASURE: f0_st, semitones from the speaker's own median (f0_measure.R).
# Within-word steps in semitones cancel the speaker's scale AND the word's own
# pitch level, so what is left is contour shape.  Intrinsic f0 rises with vowel
# height, so the vowel-pair control is not optional here either.
#
# Duration and intensity step means are recomputed ON THIS FRAME so the three
# cues are compared on identical rows; their designation-effect regressions are
# NOT refitted -- contour_steps.csv stands.
#
# Outputs
#   output/f0_position_cell_means.csv   saturated (sidx, sN) means, Q1
#   output/f0_token_stats.csv           per-token contour statistics, Q2
#   output/f0_contour_step_means.csv    step means, all three cues
#   output/f0_contour_steps.csv         designation effects on f0 steps, Q3
# =============================================================================
suppressMessages({library(data.table)})
OUT <- "output"
INV5 <- c("a","e","i","u","y")
MIN_TOKENS <- 100L
CLSNAME <- c("-1"="no full vowel","0"="final","1"="penultimate",
             "2"="antepenultimate","3"="pre-antepenult")

v <- as.data.table(readRDS("/tmp/f0v.rds"))
# every syllable of the word must be usable on ALL THREE cues, or the word has
# no well-defined contour on any of them
v <- v[f0_ok == TRUE & !is.na(int_midpoint) & !is.na(log_duration)]
v[, n_meas := .N, by = word_id]
v <- v[n_meas == sN & sN >= 2L]
v[, dur := exp(log_duration)]
v[, int_c := int_midpoint - mean(int_midpoint), by = file_name]   # validated spec
setorder(v, word_id, sidx)
cat(sprintf("frame: %s vowel rows | %s word tokens | %s types | %s speakers\n",
            format(nrow(v), big.mark=","), format(uniqueN(v$word_id), big.mark=","),
            format(uniqueN(v$word_label), big.mark=","), uniqueN(v$speaker_id)))

# ---- 2. Q1: saturated position profile for f0 -------------------------------
# Monosyllables are excluded by construction above; sN capped at 6 as elsewhere.
pc <- v[sN <= 6L, .(n = .N,
                    f0_st  = mean(f0_st),  f0_se  = sd(f0_st)/sqrt(.N),
                    int_c  = mean(int_c),  dur    = mean(dur)),
        by = .(sN, sidx)]
ref <- pc[sN == 2L & sidx == 1L]
pc[, `:=`(f0_rel  = f0_st - ref$f0_st,
          int_rel = int_c - ref$int_c,
          dur_rel = dur   - ref$dur)]
fwrite(pc[order(sN, sidx)], file.path(OUT, "f0_position_cell_means.csv"))
cat("\n== Q1  f0 by syllable index and word length (semitones, ref = syl 1 of 2) ==\n")
print(dcast(pc, sN ~ sidx, value.var = "f0_rel"), digits = 3)
cat("\n   syllable 2 minus syllable 1, per word length (semitones):\n")
s21 <- pc[sidx <= 2L, .(d = f0_rel[sidx == 2L] - f0_rel[sidx == 1L]), by = sN]
print(s21[order(sN)], digits = 3)
cat("\n   where the f0 cell mean PEAKS, per word length:\n")
print(pc[, .(peak_sidx = sidx[which.max(f0_rel)]), by = sN][order(sN)])

# ---- 3. shape classes --------------------------------------------------------
v[, FR := fifelse(vowel_label %in% INV5, "F", "R")]
wd <- v[, .(n_syl = .N, sN = sN[1],
            shape = paste(FR[order(sidx)], collapse = "")), by = word_id][n_syl == sN]
wd[, fp := vapply(gregexpr("F", shape),
                  function(m) if (m[1] == -1L) NA_integer_ else max(m), integer(1))]
wd[, from_end := fifelse(is.na(fp), -1L, sN - fp)]
wd[, desig := fifelse(is.na(fp), 1L, fp)]
wd <- wd[from_end %in% c(-1L, 0L, 1L, 2L, 3L)]
v <- merge(v, wd[, .(word_id, from_end, desig)], by = "word_id")
v[, cls := CLSNAME[as.character(from_end)]]
v[, utt_fin_word := any(is_utt_final), by = word_id]
v <- v[utt_fin_word == FALSE]
ct <- v[, .(wt = uniqueN(word_id)), by = .(cls, sN)][wt >= MIN_TOKENS]
v <- merge(v, ct[, .(cls, sN)], by = c("cls", "sN"))
setorder(v, word_id, sidx)

# ---- 4. Q2: per-token f0 statistics -----------------------------------------
amax <- function(x, d) { mx <- max(x); w <- which(x == mx)
  if (length(w) > 1L) NA_integer_ else as.integer(w == d) }
afirst <- function(x, d, last = FALSE) { w <- which(x > mean(x))
  if (!length(w)) NA_integer_ else as.integer((if (last) max(w) else min(w)) == d) }
tk <- v[, { d <- desig[1]
  .(sN = sN[1], cls = cls[1], from_end = from_end[1],
    f0_max         = amax(f0_st, d),
    f0_first_above = afirst(f0_st, d),
    f0_last_above  = afirst(f0_st, d, last = TRUE))
}, by = word_id]
ts <- rbindlist(lapply(c("f0_max","f0_first_above","f0_last_above"), function(s)
  tk[, .(stat = s, n_tokens = .N, n_defined = sum(!is.na(get(s))),
         rate = mean(get(s), na.rm = TRUE), chance = 1/sN[1]), by = .(cls, from_end, sN)]))
ts[, `:=`(lift = rate - chance, se = sqrt(rate*(1-rate)/n_defined))]
fwrite(ts[order(stat, from_end, sN)], file.path(OUT, "f0_token_stats.csv"))
cat("\n== Q2  how often each f0 statistic lands on the designated syllable ==\n")
print(dcast(ts, cls + from_end + sN + chance ~ stat, value.var = "rate")[order(from_end, sN)],
      digits = 3)

# ---- 5. steps ----------------------------------------------------------------
v[, `:=`(f0_next  = shift(f0_st, -1L), f0_prev  = shift(f0_st, 1L),
         int_next = shift(int_c, -1L), int_prev = shift(int_c, 1L),
         dur_next = shift(dur,   -1L), dur_prev = shift(dur,   1L),
         v_next   = shift(vowel_label, -1L), v_prev = shift(vowel_label, 1L)),
  by = word_id]
v[, `:=`(d_f0_next  = f0_next  - f0_st, d_f0_prev  = f0_st - f0_prev,
         d_int_next = int_next - int_c, d_int_prev = int_c - int_prev,
         d_dur_next = dur_next - dur,   d_dur_prev = dur   - dur_prev)]
v[, is_desig := sidx == desig]
v[, pcell := factor(paste(sN, sidx, sep = "_"))]

sm <- v[, .(n = .N,
            f0_step_after   = mean(d_f0_next,  na.rm = TRUE),
            f0_step_before  = mean(d_f0_prev,  na.rm = TRUE),
            int_step_after  = mean(d_int_next, na.rm = TRUE),
            dur_step_before = mean(d_dur_prev, na.rm = TRUE)),
        by = .(cls, from_end, sN, sidx, is_desig)]
fwrite(sm[order(from_end, sN, sidx)], file.path(OUT, "f0_contour_step_means.csv"))
cat("\n== f0 step from each syllable to the next (semitones) ==\n")
print(dcast(v[!is.na(d_f0_next), .(s = round(mean(d_f0_next), 3)), by = .(cls, from_end, sN, sidx)],
            cls + from_end + sN ~ sidx, value.var = "s")[order(from_end, sN)])
cat("\n== f0 step from the previous syllable (semitones) ==\n")
print(dcast(v[!is.na(d_f0_prev), .(s = round(mean(d_f0_prev), 3)), by = .(cls, from_end, sN, sidx)],
            cls + from_end + sN ~ sidx, value.var = "s")[order(from_end, sN)])

crse <- function(m, cl) {
  b <- coef(m); keep <- !is.na(b)
  X <- model.matrix(m)[, keep, drop = FALSE]; u <- residuals(m)
  bread <- chol2inv(chol(crossprod(X)))
  Xu <- as.data.table(X * u)[, cl := cl[as.integer(rownames(X))]]
  S <- as.matrix(Xu[, lapply(.SD, sum), by = cl][, -1L])
  out <- rep(NA_real_, length(b)); out[keep] <- sqrt(diag(bread %*% crossprod(S) %*% bread))
  setNames(out, names(b))
}
fit_step <- function(dv, with_vowels, label) {
  nb  <- if (grepl("next", dv)) "v_next" else "v_prev"
  rhs <- if (with_vowels) paste("is_desig + pcell + vowel_label +", nb) else "is_desig + pcell"
  d <- v[!is.na(get(dv)) & !is.na(get(nb))]
  m <- lm(as.formula(paste(dv, "~", rhs)), data = d); se <- crse(m, d$word_label)
  data.table(dv = dv, question = label, vowel_pair_controlled = with_vowels,
             n_steps = nrow(d), n_types = uniqueN(d$word_label),
             estimate = coef(m)[["is_desigTRUE"]], se = se[["is_desigTRUE"]],
             t = coef(m)[["is_desigTRUE"]]/se[["is_desigTRUE"]])
}
cat("\n== Q3  designation effect on the adjacent f0 step, net of position ==\n")
st <- rbindlist(lapply(list(
        list("d_f0_prev", "f0 step UP into the syllable (stress -> POSITIVE)"),
        list("d_f0_next", "f0 step out of the syllable (stress -> NEGATIVE)")),
     function(g) rbindlist(lapply(c(FALSE, TRUE), function(w) fit_step(g[[1]], w, g[[2]])))))
fwrite(st, file.path(OUT, "f0_contour_steps.csv"))
print(st, digits = 4)
cat("\n✓ f0_contour_test.R complete\n")
