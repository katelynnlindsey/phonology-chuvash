# =============================================================================
# step_vowel_stratified.R                                           2026-10-01
#
# THE DEFINITIVE SPECIFICATION for the adjacent-step designation effect, on all
# THREE cues at once and on IDENTICAL rows.
#
# WHY THIS EXISTS.  contour_shape_test.R entered the target's vowel identity as
# an ADDITIVE covariate.  That is not enough to make the contrast within-vowel:
#   - A rule designates a word-final syllable if and only if that syllable's
#     own vowel is full, so in the word-final stratum `is_desig` is a
#     DETERMINISTIC function of `vowel_label`.  An additive control does not
#     remove that; it just spreads it.
#   - At non-final positions designation implies the target vowel is full,
#     while non-designation mixes reduced vowels with full vowels that have a
#     full vowel somewhere to their right.  So the additive estimate is part
#     within-vowel comparison and part full-versus-reduced comparison.
# Stratifying on (word length x syllable index x TARGET VOWEL) instead forces
# every comparison to be between the same vowel at the same place in a word of
# the same length -- exactly the matched-vowel design of
# matched_vowel_prominence.R, now applied to a within-word step.  What is left
# to drive designation is the vowel content of OTHER syllables, which is in
# neither the step nor the strata.
#
# Three specifications are reported side by side so the cost of each control is
# visible:
#   position            strata = (sN, sidx)
#   position + vowels   strata = (sN, sidx), target and neighbour vowel added
#   vowel-stratified    strata = (sN, sidx, target vowel), neighbour added
# The third is the one to quote.
#
# Output
#   output/step_vowel_stratified.csv
# =============================================================================
suppressMessages({library(data.table)})
OUT <- "output"
INV5 <- c("a","e","i","u","y")
CLSNAME <- c("-1"="no full vowel","0"="final","1"="penultimate",
             "2"="antepenultimate","3"="pre-antepenult")

v <- as.data.table(readRDS("/tmp/f0v.rds"))
v <- v[f0_ok == TRUE & !is.na(int_midpoint) & !is.na(log_duration)]
v[, n_meas := .N, by = word_id]
v <- v[n_meas == sN & sN >= 2L]
v[, dur := exp(log_duration)]
v[, int_c := int_midpoint - mean(int_midpoint), by = file_name]
setorder(v, word_id, sidx)

v[, FR := fifelse(vowel_label %in% INV5, "F", "R")]
wd <- v[, .(n_syl = .N, sN = sN[1],
            shape = paste(FR[order(sidx)], collapse = "")), by = word_id][n_syl == sN]
wd[, fp := vapply(gregexpr("F", shape),
                  function(m) if (m[1] == -1L) NA_integer_ else max(m), integer(1))]
wd[, from_end := fifelse(is.na(fp), -1L, sN - fp)]
wd[, desig := fifelse(is.na(fp), 1L, fp)]
v <- merge(v, wd[from_end %in% c(-1L,0L,1L,2L,3L), .(word_id, from_end, desig)], by = "word_id")
v[, utt_fin_word := any(is_utt_final), by = word_id]
v <- v[utt_fin_word == FALSE]
ct <- v[, .(wt = uniqueN(word_id)), by = .(cls = CLSNAME[as.character(from_end)], sN)][wt >= 100L]
v[, cls := CLSNAME[as.character(from_end)]]
v <- merge(v, ct[, .(cls, sN)], by = c("cls", "sN"))
setorder(v, word_id, sidx)

v[, `:=`(f0_prev = shift(f0_st, 1L), f0_next = shift(f0_st, -1L),
         int_prev = shift(int_c, 1L), int_next = shift(int_c, -1L),
         dur_prev = shift(dur, 1L),   dur_next = shift(dur, -1L),
         v_prev = shift(vowel_label, 1L), v_next = shift(vowel_label, -1L)), by = word_id]
v[, `:=`(d_f0_prev = f0_st - f0_prev, d_f0_next = f0_next - f0_st,
         d_int_prev = int_c - int_prev, d_int_next = int_next - int_c,
         d_dur_prev = dur - dur_prev,   d_dur_next = dur_next - dur)]
v[, is_desig := sidx == desig]
v[, pcell := paste(sN, sidx, sep = "_")]
v[, vcell := paste(sN, sidx, vowel_label, sep = "_")]

crse <- function(m, cl) {
  b <- coef(m); keep <- !is.na(b)
  X <- model.matrix(m)[, keep, drop = FALSE]; u <- residuals(m)
  bread <- chol2inv(chol(crossprod(X)))
  Xu <- as.data.table(X * u)[, cl := cl[as.integer(rownames(X))]]
  S <- as.matrix(Xu[, lapply(.SD, sum), by = cl][, -1L])
  out <- rep(NA_real_, length(b)); out[keep] <- sqrt(diag(bread %*% crossprod(S) %*% bread))
  setNames(out, names(b))
}
fit1 <- function(dv, spec) {
  nb <- if (grepl("next", dv)) "v_next" else "v_prev"
  rhs <- switch(spec,
    "position"          = "is_desig + factor(pcell)",
    "position + vowels" = paste("is_desig + factor(pcell) + vowel_label +", nb),
    "vowel-stratified"  = paste("is_desig + factor(vcell) +", nb))
  d <- v[!is.na(get(dv)) & !is.na(get(nb))]
  # a stratum with no designation variation contributes nothing and makes the
  # design rank-deficient; drop those explicitly so the fit is interpretable
  key <- if (spec == "vowel-stratified") "vcell" else "pcell"
  d[, nvar := uniqueN(is_desig), by = key]
  d <- d[nvar == 2L]
  m <- lm(as.formula(paste(dv, "~", rhs)), data = d)
  se <- crse(m, d$word_label)
  data.table(cue = sub("^d_([a-z0]+)_.*", "\\1", dv),
             direction = fifelse(grepl("prev", dv), "step into syllable", "step out of syllable"),
             spec = spec, n_steps = nrow(d), n_strata = uniqueN(d[[key]]),
             n_types = uniqueN(d$word_label),
             estimate = coef(m)[["is_desigTRUE"]], se = se[["is_desigTRUE"]],
             t = coef(m)[["is_desigTRUE"]]/se[["is_desigTRUE"]])
}
DVS <- c("d_dur_prev","d_dur_next","d_int_prev","d_int_next","d_f0_prev","d_f0_next")
res <- rbindlist(lapply(DVS, function(dv)
  rbindlist(lapply(c("position","position + vowels","vowel-stratified"),
                   function(s) fit1(dv, s)))))
res[, unit := fifelse(cue == "dur", "ms", fifelse(cue == "int", "dB", "semitones"))]
fwrite(res, file.path(OUT, "step_vowel_stratified.csv"))
print(res, digits = 4)
cat("\n✓ step_vowel_stratified.R complete\n")
