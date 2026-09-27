# ══════════════════════════════════════════════════════════════════════
# coda_sonority.R
#
# Does acoustic prominence inside a word go to syllables with codas, or to
# more sonorous vowels?  And is there any secondary stress?
#
# The design is within-word throughout.  A word token is a stratum; its
# syllables are the units; the outcome is "this syllable is the most
# prominent one in this word".  Conditional logistic regression stratified
# by word token (survival::clogit) is the matched-set analysis for that
# design: it conditions every comparison on the word, so word frequency,
# word length, speaker, utterance position and speech rate cannot confound
# it.  Where clogit is unavailable the script falls back to the
# Mantel-Haenszel estimator, which is the same estimand.
#
# Intrinsic duration and intensity are the trap.  /a/ is 20 ms longer and
# 2-3 dB louder than the high vowels for reasons that have nothing to do
# with stress, so "the most prominent syllable contains /a/" is nearly a
# tautology on raw measures.  Every test is therefore run twice: once raw,
# once after removing the vowel's own mean (intrinsic-removed), so the
# question becomes whether a vowel is long *for its own kind*.
#
# Outputs
#   output/coda_sonority_models.csv        odds ratios, both measures, both
#                                          adjustments, plus rule-based codas
#   output/secondary_stress_by_position.csv  duration/intensity z by distance
#                                          from the primary syllable
#   output/secondary_stress_models.csv     mixture-model BIC by k
# ══════════════════════════════════════════════════════════════════════

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(data.table)
HAVE_CLOGIT <- requireNamespace("survival", quietly = TRUE)

OUT <- PATHS$output_dir

# ── Analysis frame ────────────────────────────────────────────────────
# Polysyllables only: a monosyllable has no within-word comparison to make.
# Both measures must be present for a syllable to enter, so the coda and the
# sonority odds ratios are computed on exactly the same rows.

d <- as.data.table(vowels)[
  sN > 1L & !is.na(duration) & !is.na(int_midpoint) &
  !is.na(vowel_label) & !is.na(syllable_coda) & !is.na(word_id)
]

d[, has_coda := as.integer(
    if (is.logical(syllable_coda)) syllable_coda
    else tolower(as.character(syllable_coda)) %in% c("closed", "coda", "true", "1")
  )]
d[, is_a       := as.integer(vowel_label == "a")]
d[, is_nonhigh := as.integer(vowel_label %in% c("a", "e", "ø", "ɵ"))]

# Intrinsic-removed measures: the vowel's own grand mean taken out.
d[, dur_adj := duration     - mean(duration,     na.rm = TRUE), by = vowel_label]
d[, int_adj := int_midpoint - mean(int_midpoint, na.rm = TRUE), by = vowel_label]

# One prominence flag per measure: the within-word argmax.
for (m in c("duration", "int_midpoint", "dur_adj", "int_adj")) {
  d[, (paste0("prom_", m)) := as.integer(seq_len(.N) == which.max(get(m))),
    by = word_id]
}

cat(sprintf("\nAnalysis frame: %s vowels in %s polysyllabic word tokens\n",
            format(nrow(d), big.mark = ","),
            format(uniqueN(d$word_id), big.mark = ",")))

# ── Estimators ────────────────────────────────────────────────────────

mh_or <- function(dt, expo, prom) {
  # Mantel-Haenszel odds ratio with Robins-Breslow-Greenland variance.
  s <- dt[, .(a = sum(get(expo) == 1L & get(prom) == 1L),
              b = sum(get(expo) == 1L & get(prom) == 0L),
              c = sum(get(expo) == 0L & get(prom) == 1L),
              d = sum(get(expo) == 0L & get(prom) == 0L)), by = word_id]
  s[, n := a + b + c + d][n > 0]
  R <- s[, sum(a * d / n)]; S <- s[, sum(b * c / n)]
  if (R == 0 || S == 0) return(list(or = NA_real_, lo = NA_real_,
                                    hi = NA_real_, p = NA_real_))
  P <- s[, (a + d) / n]; Q <- s[, (b + c) / n]
  Rk <- s[, a * d / n]; Sk <- s[, b * c / n]
  v <- sum(P * Rk) / (2 * R^2) +
       sum(P * Sk + Q * Rk) / (2 * R * S) +
       sum(Q * Sk) / (2 * S^2)
  lor <- log(R / S); se <- sqrt(v)
  list(or = R / S, lo = exp(lor - 1.96 * se), hi = exp(lor + 1.96 * se),
       p = 2 * pnorm(-abs(lor / se)))
}

cl_or <- function(dt, expo, prom) {
  f <- stats::as.formula(sprintf("%s ~ %s + survival::strata(word_id)",
                                 prom, expo))
  fit <- try(survival::clogit(f, data = dt), silent = TRUE)
  if (inherits(fit, "try-error")) return(NULL)
  s  <- summary(fit)$coefficients
  ci <- suppressWarnings(stats::confint(fit))
  list(or = unname(exp(s[1, "coef"])),
       lo = unname(exp(ci[1, 1])), hi = unname(exp(ci[1, 2])),
       p  = unname(s[1, ncol(s)]))
}

est <- function(dt, expo, prom) {
  r <- if (HAVE_CLOGIT) cl_or(dt, expo, prom) else NULL
  if (is.null(r)) { r <- mh_or(dt, expo, prom); r$method <- "mantel_haenszel" }
  else r$method <- "clogit"
  r
}

# ── Main grid: 3 predictors x 4 prominence definitions ────────────────

grid <- expand.grid(
  predictor  = c("has_coda", "is_a", "is_nonhigh"),
  prominence = c("prom_duration", "prom_int_midpoint",
                 "prom_dur_adj", "prom_int_adj"),
  stringsAsFactors = FALSE
)

run_grid <- function(dt, label) {
  rbindlist(lapply(seq_len(nrow(grid)), function(i) {
    p <- grid$predictor[i]; q <- grid$prominence[i]
    r <- est(dt, p, q)
    data.table(sample = label, predictor = p, prominence = q,
               measure = ifelse(grepl("int", q), "intensity", "duration"),
               intrinsic = ifelse(grepl("adj", q), "removed", "raw"),
               odds_ratio = r$or, ci_low = r$lo, ci_high = r$hi,
               p_value = r$p, method = r$method,
               n_vowels = nrow(dt), n_words = uniqueN(dt$word_id))
  }))
}

res <- run_grid(d, "all")

# Sensitivity: the strict subset.  The IQR fences used to delete these rows
# outright, and they preferentially deleted long vowels — which is to say,
# the stressed ones.  Reporting both shows whether the nulls survive.
strict <- d[word_complete == TRUE & iqr_outlier_any == FALSE]
if (nrow(strict) > 1000) res <- rbind(res, run_grid(strict, "strict"))

# ── Rule-based prominence, for comparison with the acoustic definition ─
# Here "prominent" is what a stress rule predicts, not what the acoustics
# show.  A coda odds ratio near 1 under a rule means the rule's stressed
# syllables are no more likely to be closed than its unstressed ones.

for (rl in c("A6", "B5")) {
  col <- paste0("stress_rule_", rl)
  if (!col %in% names(d)) next
  dd <- copy(d)[!is.na(get(col))]
  dd[, prom_rule := as.integer(get(col) == "Stressed")]
  dd <- dd[, if (sum(prom_rule) > 0 && sum(prom_rule) < .N) .SD,
           by = word_id]
  if (!nrow(dd)) next
  for (p in c("has_coda", "is_a", "is_nonhigh")) {
    r <- est(dd, p, "prom_rule")
    res <- rbind(res, data.table(
      sample = "all", predictor = p, prominence = paste0("rule_", rl),
      measure = "rule", intrinsic = "n/a",
      odds_ratio = r$or, ci_low = r$lo, ci_high = r$hi, p_value = r$p,
      method = r$method, n_vowels = nrow(dd), n_words = uniqueN(dd$word_id)))
  }
}

readr::write_csv(res, file.path(OUT, "coda_sonority_models.csv"))
cat("\ncoda_sonority_models.csv\n")
print(res[, .(sample, predictor, prominence, odds_ratio = round(odds_ratio, 3),
              ci_low = round(ci_low, 3), ci_high = round(ci_high, 3))])

# Intrinsic values, so the reader can see why the adjustment matters.
intr <- d[, .(n = .N,
              median_duration = median(duration),
              mean_int_midpoint = round(mean(int_midpoint), 2)),
          by = .(vowel_label)][order(-median_duration)]
readr::write_csv(intr, file.path(OUT, "vowel_intrinsic_values.csv"))
print(intr)

# ── Secondary stress ──────────────────────────────────────────────────
# If Chuvash had secondary stress, non-primary syllables would not be flat:
# some fixed distance from the primary, or alternating positions, would be
# reliably longer or louder.  Words of three or more syllables are the only
# place this can show.

ACT <- paste0("stress_rule_", ACTIVE_RULE)
s <- d[sN >= 3L & !is.na(get(ACT))]
s[, z_dur := (duration     - mean(duration))     / stats::sd(duration),
  by = .(vowel_label)]
s[, z_int := (int_midpoint - mean(int_midpoint)) / stats::sd(int_midpoint),
  by = .(vowel_label)]
s[, prim := { w <- which(get(ACT) == "Stressed")
              if (length(w)) sidx[w[1]] else NA_integer_ }, by = word_id]
s2 <- s[!is.na(prim) & get(ACT) != "Stressed"]
s2[, rel := sidx - prim]

pos <- s2[abs(rel) <= 3, .(n = .N,
                           dur_z = round(mean(z_dur, na.rm = TRUE), 3),
                           int_z = round(mean(z_int, na.rm = TRUE), 3)),
          by = rel][order(rel)]
pos[, rule := ACTIVE_RULE]
readr::write_csv(pos, file.path(OUT, "secondary_stress_by_position.csv"))
cat(sprintf("\nSecondary stress: %s words with sN>=3, %s non-primary syllables\n",
            format(uniqueN(s$word_id), big.mark = ","),
            format(nrow(s2), big.mark = ",")))
print(pos)

# A two-component mixture over the non-primary syllables would be the
# positive result: one quiet class and one secondary-stressed class.  BIC is
# reported for k = 1..4 so the reader can see whether it prefers a genuine
# second mode or just keeps buying flexibility.
mix_bic <- function(x, kmax = 4L) {
  x <- x[is.finite(x)]
  vapply(seq_len(kmax), function(k) {
    if (k == 1L) return(-2 * sum(stats::dnorm(x, mean(x), stats::sd(x),
                                              log = TRUE)) +
                        2 * log(length(x)))
    q  <- stats::quantile(x, seq(0, 1, length.out = k + 1)[-c(1, k + 1)])
    cl <- cut(x, c(-Inf, q, Inf), labels = FALSE)
    ll <- 0
    for (j in seq_len(k)) {
      xi <- x[cl == j]
      if (length(xi) > 2)
        ll <- ll + sum(stats::dnorm(xi, mean(xi), stats::sd(xi), log = TRUE))
    }
    -2 * ll + (3 * k - 1) * log(length(x))
  }, numeric(1))
}

sm <- rbindlist(lapply(c("z_dur", "z_int"), function(v) {
  b <- mix_bic(s2[[v]])
  data.table(measure = v, k = seq_along(b), BIC = round(b, 1),
             n = sum(is.finite(s2[[v]])))
}))
readr::write_csv(sm, file.path(OUT, "secondary_stress_models.csv"))
print(sm)

cat("\n✓ coda_sonority.R complete\n")
