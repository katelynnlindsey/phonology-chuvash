# =============================================================================
# contour_shape_test.R                                              2026-10-01
#
# TWO HYPOTHESES FROM KATE, both about the SHAPE of the within-word contour
# rather than the level of any one syllable:
#
#   H1  POST-TONIC DROP.  The intensity cue to stress is not a peak ON the
#       stressed syllable but a DROP AFTER it.  In final-stress words there is
#       no post-tonic syllable, hence no drop -- which is why the all-full
#       profiles look flat at the right edge.  In all-reduced words the drop
#       starts after syllable 1, which is why those words are HEARD as
#       initially stressed even though syllable 1 is not longer.
#
#   H2  FIRST TO LENGTHEN.  The stressed syllable is the leftmost long one.
#       Syllables after it may be longer still (final lengthening), but
#       PRE-TONIC syllables are much shorter.  So the diagnostic is the step
#       UP INTO the syllable, not its absolute duration.
#
# WHY STEPS.  Both claims are about contour shape, so the measure is the
# difference between adjacent syllables of the SAME word token.  A within-word
# difference cancels the word intercept, the recording level and the speaker
# level exactly -- no random effects needed, and no declination baseline to
# specify.  What remains is attributable to position and to designation.
#
# THE DECIDING CONTRAST.  Every step is stratified on its own position
# (word length x syllable index), so "is the following step more negative when
# THIS syllable is the one the rule designates?" is asked only among steps
# taken from the same place in a word of the same length.  Note that an
# indicator for "this step lands on the word-final syllable" CANNOT be added
# alongside the position strata: it is a deterministic function of (sN, sidx)
# and so is already absorbed.  The edge-vs-stress question is answered instead
# by comparing the per-class step tables in section 3 -- if the big drop sits
# at the word edge in the antepenultimate class rather than immediately after
# the designated syllable, the drop is anchored to the edge, not to the stress.
#
# Standard errors are clustered by word type (word_label): a word contributes
# several steps and its type recurs across tokens.
#
# Inventory: 5-full (a e i u y), i.e. A5/B5.  Classes as in
# shape_class_profiles.R: from_end = sN - (position of rightmost full vowel).
# Utterance-final words are dropped throughout -- the utterance-final intensity
# drop is ~6 dB and would swamp every word-internal step.
#
# Outputs
#   output/contour_token_stats.csv   per-token contour statistics by class
#   output/contour_steps.csv         designation effects on adjacent steps
#   output/contour_step_means.csv    raw step means by class, length, position
# =============================================================================
suppressMessages({library(data.table)})
OUT <- "output"
INV5 <- c("a","e","i","u","y")
MIN_TOKENS <- 100L
CLSNAME <- c("-1"="no full vowel","0"="final","1"="penultimate",
             "2"="antepenultimate","3"="pre-antepenult")

v <- as.data.table(readRDS("/tmp/v2.rds"))

# A contour statistic needs EVERY syllable of the word measured on BOTH cues --
# a word missing one syllable's intensity has no well-defined peak position.
# Drop unmeasured rows first, then require the word still to be complete.
n0 <- nrow(v)
v <- v[!is.na(int_midpoint) & !is.na(log_duration)]
v[, n_meas := .N, by = word_id]
v <- v[n_meas == sN]
cat(sprintf("dropped %s rows with an unmeasured cue and their words; %s remain\n",
            format(n0 - nrow(v), big.mark=","), format(nrow(v), big.mark=",")))

# ---- 1. classes and the designated syllable ---------------------------------
v[, FR := fifelse(vowel_label %in% INV5, "F", "R")]
wd <- v[, .(n_syl = .N, sN = sN[1],
            shape = paste(FR[order(sidx)], collapse = "")), by = word_id][n_syl == sN]
wd[, fp := vapply(gregexpr("F", shape),
                  function(m) if (m[1] == -1L) NA_integer_ else max(m), integer(1))]
wd[, from_end := fifelse(is.na(fp), -1L, sN - fp)]
# all-reduced words: A5 stresses the leftmost reduced vowel, B5 leaves them
# stressless.  Syllable 1 is the A5 prediction and the one Kate's H1 is about.
wd[, desig := fifelse(is.na(fp), 1L, fp)]
wd <- wd[from_end %in% c(-1L, 0L, 1L, 2L, 3L)]
v <- merge(v, wd[, .(word_id, from_end, desig)], by = "word_id")
v[, cls := CLSNAME[as.character(from_end)]]

# utterance-final words out, whole word at a time
v[, utt_fin_word := any(is_utt_final), by = word_id]
v <- v[utt_fin_word == FALSE]

ct <- v[, .(wt = uniqueN(word_id)), by = .(cls, sN)][wt >= MIN_TOKENS]
v <- merge(v, ct[, .(cls, sN)], by = c("cls", "sN"))
v[, dur := exp(log_duration)]
setorder(v, word_id, sidx)
cat(sprintf("frame: %s vowel rows | %s word tokens | %s types\n",
            format(nrow(v), big.mark=","), format(uniqueN(v$word_id), big.mark=","),
            format(uniqueN(v$word_label), big.mark=",")))

# ---- 2. per-token contour statistics ----------------------------------------
# All threshold-free and word-internal: each is a position index derived from
# the word's own values, so no cross-word normalisation is involved.
#   *_max          where the cue peaks
#   dur_first_above  leftmost syllable above the word's own mean duration
#                    -- the operationalisation of H2 ("first to lengthen")
#   int_last_above   rightmost syllable above the word's own mean intensity
#                    -- the operationalisation of H1 (drop begins right after)
# The two mirror statistics are included as controls: if dur_first_above picks
# out the designated syllable only because durations rise monotonically, then
# dur_last_above will do just as well, and the H2 reading is not supported.
# TWO MEASUREMENT FACTS force the statistics to be defined carefully.
#   (a) Duration is quantised at 10 ms by the extraction grid, so a word can
#       have every syllable at the same duration.  "First syllable above the
#       word's own mean" is then UNDEFINED, not zero, and such tokens are
#       excluded from that statistic's denominator rather than counted as
#       misses.  (The 10 ms quantum happens to equal Hirsh's (1959) duration
#       JND, so the granularity is at the limit of audibility anyway.)
#   (b) which.max() breaks ties LEFTWARD.  Because the designated syllable is
#       at or left of the word edge in every class, that would bias the peak
#       statistic in the hypothesis's favour.  A token therefore counts as a
#       match only when the designated syllable is the STRICT maximum, and the
#       tied-maximum share is reported separately.
amax <- function(x, d) {   # 1 strict max at d, 0 strict max elsewhere, NA tied
  mx <- max(x); w <- which(x == mx)
  if (length(w) > 1L) NA_integer_ else as.integer(w == d)
}
afirst <- function(x, d, last = FALSE) {  # above the word's own mean
  w <- which(x > mean(x))
  if (!length(w)) NA_integer_ else as.integer((if (last) max(w) else min(w)) == d)
}
tk <- v[, {
  d <- desig[1]
  .(sN = sN[1], cls = cls[1], from_end = from_end[1],
    dur_max         = amax(dur, d),
    dur_first_above = afirst(dur, d),
    dur_last_above  = afirst(dur, d, last = TRUE),
    int_max         = amax(int_c, d),
    int_first_above = afirst(int_c, d),
    int_last_above  = afirst(int_c, d, last = TRUE))
}, by = word_id]

STATS <- c("dur_max","dur_first_above","dur_last_above",
           "int_max","int_first_above","int_last_above")
ts <- rbindlist(lapply(STATS, function(s) {
  tk[, .(stat = s, n_tokens = .N, n_defined = sum(!is.na(get(s))),
         rate = mean(get(s), na.rm = TRUE), chance = 1/sN[1]),
     by = .(cls, from_end, sN)]
}))
ts[, `:=`(lift = rate - chance, se = sqrt(rate*(1-rate)/n_defined),
          pct_defined = round(100*n_defined/n_tokens, 1))]
fwrite(ts[order(stat, from_end, sN)], file.path(OUT, "contour_token_stats.csv"))

cat("\n== per-token: how often each contour statistic lands on the designated syllable ==\n")
pr <- dcast(ts, cls + from_end + sN + chance ~ stat, value.var = "rate")
print(pr[order(from_end, sN)], digits = 3)
cat("\n   share of tokens on which each statistic is defined (%)\n")
print(dcast(ts, cls + from_end + sN ~ stat, value.var = "pct_defined")[order(from_end, sN)])

# ---- 3. adjacent-syllable steps ---------------------------------------------
v[, `:=`(int_next = shift(int_c, -1L), dur_next = shift(dur, -1L),
         int_prev = shift(int_c,  1L), dur_prev = shift(dur,  1L),
         v_next   = shift(vowel_label, -1L), v_prev = shift(vowel_label, 1L)),
  by = word_id]
v[, `:=`(d_int_next = int_next - int_c, d_dur_next = dur_next - dur,
         d_int_prev = int_c - int_prev, d_dur_prev = dur   - dur_prev)]
v[, is_desig := sidx == desig]
v[, pcell := factor(paste(sN, sidx, sep = "_"))]

cat("\n== raw step means at the designated syllable, by class and length ==\n")
sm <- v[, .(n = .N,
            int_step_after  = mean(d_int_next, na.rm = TRUE),
            int_step_before = mean(d_int_prev, na.rm = TRUE),
            dur_step_after  = mean(d_dur_next, na.rm = TRUE),
            dur_step_before = mean(d_dur_prev, na.rm = TRUE)),
        by = .(cls, from_end, sN, sidx, is_desig)]
fwrite(sm[order(from_end, sN, sidx)], file.path(OUT, "contour_step_means.csv"))
print(sm[is_desig == TRUE][order(from_end, sN)], digits = 3)

# THE DECIDING TABLE for H1.  If the intensity drop is anchored to the STRESS,
# the antepenultimate class should drop immediately after its designated
# syllable (1 of 3, 2 of 4) and be flat at the word edge.  If it is anchored to
# the WORD EDGE, the drop sits on the last step whatever the class.
cat("\n== intensity step from each syllable to the next, by class and length ==\n")
cat("   (* marks the step taken FROM the designated syllable)\n")
istep <- dcast(v[!is.na(d_int_next), .(s = round(mean(d_int_next), 2)),
                 by = .(cls, from_end, sN, sidx)],
               cls + from_end + sN ~ sidx, value.var = "s")
print(istep[order(from_end, sN)])
cat("\n== duration step from the previous syllable, by class and length (ms) ==\n")
dstep <- dcast(v[!is.na(d_dur_prev), .(s = round(mean(d_dur_prev), 1)),
                 by = .(cls, from_end, sN, sidx)],
               cls + from_end + sN ~ sidx, value.var = "s")
print(dstep[order(from_end, sN)])

# cluster-robust SEs by word type; a within-word step cancels the word
# intercept, so no random effect is required, but steps are not independent
# across the tokens of a type.
crse <- function(m, cl) {
  b  <- coef(m); keep <- !is.na(b)
  X  <- model.matrix(m)[, keep, drop = FALSE]
  u  <- residuals(m)
  bread <- chol2inv(chol(crossprod(X)))
  Xu <- as.data.table(X * u)[, cl := cl[as.integer(rownames(X))]]
  S  <- as.matrix(Xu[, lapply(.SD, sum), by = cl][, -1L])
  V  <- bread %*% crossprod(S) %*% bread
  out <- rep(NA_real_, length(b)); out[keep] <- sqrt(diag(V)); setNames(out, names(b))
}

fit_step <- function(dv, with_vowels, label) {
  nb <- if (grepl("next", dv)) "v_next" else "v_prev"
  rhs <- if (with_vowels) paste("is_desig + pcell + vowel_label +", nb) else "is_desig + pcell"
  d <- v[!is.na(get(dv)) & !is.na(get(nb))]
  m <- lm(as.formula(paste(dv, "~", rhs)), data = d)
  se <- crse(m, d$word_label)
  data.table(dv = dv, hypothesis = label, vowel_pair_controlled = with_vowels,
             n_steps = nrow(d), n_types = uniqueN(d$word_label),
             estimate = coef(m)[["is_desigTRUE"]], se = se[["is_desigTRUE"]],
             t = coef(m)[["is_desigTRUE"]] / se[["is_desigTRUE"]])
}

cat("\n== designation effect on the adjacent step, net of position ==\n")
grid <- list(
  list("d_int_next", "H1 post-tonic intensity drop (expect NEGATIVE)"),
  list("d_int_prev", "intensity rise into the syllable (control)"),
  list("d_dur_prev", "H2 step up from the pre-tonic syllable (expect POSITIVE)"),
  list("d_dur_next", "duration step after the syllable (control)"))
st <- rbindlist(lapply(grid, function(g)
  rbindlist(lapply(c(FALSE, TRUE), function(w) fit_step(g[[1]], w, g[[2]])))))
fwrite(st, file.path(OUT, "contour_steps.csv"))
print(st, digits = 4)

cat("\n✓ contour_shape_test.R complete\n")
