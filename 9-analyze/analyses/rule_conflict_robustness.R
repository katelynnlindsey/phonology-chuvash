# ══════════════════════════════════════════════════════════════════════
# rule_conflict_robustness.R
#
# ⚠⚠ SUPERSEDED IN FULL — DO NOT RUN, DO NOT QUOTE
#    output/rule_conflict_robustness.csv, rule_conflict_singular.csv
#
# Same defect as rule_conflict_models.R: targets from the surviving vowels
# rather than the whole word. Its headline finding — that the ranking flips
# between the two control sets (rho = +0.217) — was an ARTEFACT of those
# labels. With full-word labels the two control sets agree at rho = +1.000 in
# all four subset x DV combinations, so the instability this script was
# written to document does not exist.
#
# REPLACEMENT: analyses/stress_rules_full_word.R, which fits both control
# sets and reports the rank correlation.
# ══════════════════════════════════════════════════════════════════════
#
# Two checks on rule_conflict_models.R, both of which change what the
# ranking means.
#
# 1. Every model there reported "boundary (singular) fit". One of the three
#    random effects has zero estimated variance, and with one speaker
#    supplying 365,781 of 574,344 vowels and 74,987 more carrying no speaker
#    id at all, `(1|speaker_id)` is the obvious candidate. A singular term
#    does not bias the fixed effect, but it does mean the AIC is being
#    compared across models that are effectively simpler than specified, so
#    the ranking is refitted without the offending term.
#
# 2. The conflict subset includes MONOSYLLABLES — 10,666 of them, 22.7% of
#    all monosyllabic word tokens. A monosyllable conflicts because the A
#    rules stress an all-reduced monosyllable while the B rules leave it
#    stressless. That is a real disagreement, but it is a disagreement about
#    whether the word is stressed AT ALL, not about which syllable carries
#    it. Mixing it with the placement question means one coefficient is
#    answering two questions. The polysyllabic-only fit isolates placement.
#
# Outputs
#   output/rule_conflict_robustness.csv   the four rankings side by side
# ══════════════════════════════════════════════════════════════════════

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(data.table); library(lme4); library(broom.mixed)

OUT   <- PATHS$output_dir
RULES <- c("A6", "A5", "A4", "B6", "B5", "B4", "SON")

v <- as.data.table(vowels)[!is.na(vowel_label) & !is.na(sidx) & !is.na(word_id)]
ord <- v[order(word_id, sidx)]
tg <- ord[, as.list(setNames(lapply(RULES, function(r) assign_stress(vowel_label, r)),
                             paste0("t_", RULES))), by = word_id]
tcols <- paste0("t_", RULES)
tg[, n_distinct_pred := apply(.SD, 1, function(x) length(unique(x[!is.na(x)]))),
   .SDcols = tcols]
tg[, any_na := apply(.SD, 1, function(x) any(is.na(x))), .SDcols = tcols]
tg[, conflict := (n_distinct_pred > 1L) | (any_na & n_distinct_pred > 0L)]

v <- merge(v, tg[, c("word_id", "conflict", tcols), with = FALSE], by = "word_id")
for (r in RULES) v[, (paste0("is_stressed_", r)) :=
                     !is.na(get(paste0("t_", r))) & sidx == get(paste0("t_", r))]
v[, syl_final := as.integer(sidx == sN)]
v[, word_utt_final := as.integer(!is.na(wN) & !is.na(widx) & widx == wN)]
if (!"log_speech_rate" %in% names(v)) v[, log_speech_rate := 0]
v[is.na(log_speech_rate), log_speech_rate := 0]
v[, z_freq := as.numeric(scale(log_corpus_freq))]
v[is.na(z_freq), z_freq := 0]

CONTROLS <- paste("vowel_label + syllable_coda + syl_final + word_utt_final +",
                  "syl_final:word_utt_final + log_speech_rate + z_freq")
need <- c("log_duration", "int_midpoint", "vowel_label", "syllable_coda",
          "syl_final", "word_utt_final", "log_speech_rate", "z_freq",
          "speaker_id", "file_name", "word_label")

# ── Which random effect is singular? ──────────────────────────────────
md0 <- v[conflict == TRUE][complete.cases(v[conflict == TRUE, ..need])]
probe <- lmer(stats::as.formula(paste("log_duration ~ is_stressed_SON +",
              CONTROLS, "+ (1|speaker_id) + (1|file_name) + (1|word_label)")),
              data = md0, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
vc <- as.data.frame(VarCorr(probe))
cat("\n== random-effect variances, probe model ==\n")
print(vc[, c("grp", "vcov", "sdcor")])
zero <- vc$grp[vc$vcov < 1e-10]
cat("singular term(s):", if (length(zero)) paste(zero, collapse = ", ") else "none", "\n")

RE_FULL <- "(1|speaker_id) + (1|file_name) + (1|word_label)"
RE_RED  <- paste0("(1|", setdiff(c("speaker_id", "file_name", "word_label"),
                                 zero), ")", collapse = " + ")
cat("reduced random-effect structure:", RE_RED, "\n")

run <- function(dat, re, tag) {
  rbindlist(lapply(c("log_duration", "int_midpoint"), function(dv)
    rbindlist(lapply(RULES, function(r) {
      f <- stats::as.formula(sprintf("%s ~ is_stressed_%s + %s + %s",
                                     dv, r, CONTROLS, re))
      m <- try(lmer(f, data = dat, REML = FALSE,
                    control = lmerControl(calc.derivs = FALSE)), silent = TRUE)
      if (inherits(m, "try-error")) return(NULL)
      co <- as.data.table(tidy(m, effects = "fixed"))[
        term == paste0("is_stressed_", r, "TRUE")]
      data.table(variant = tag, dv = dv, rule = r,
                 estimate = co$estimate, statistic = co$statistic,
                 AIC = AIC(m), n_obs = nrow(dat),
                 n_words = uniqueN(dat$word_id),
                 singular = isSingular(m))
    }))))
}

md_poly <- md0[sN > 1L]
cat(sprintf("\nall-conflict frame: %s vowels / %s words | polysyllabic only: %s / %s\n",
            format(nrow(md0), big.mark = ","), format(uniqueN(md0$word_id), big.mark = ","),
            format(nrow(md_poly), big.mark = ","),
            format(uniqueN(md_poly$word_id), big.mark = ",")))

res <- rbindlist(list(
  run(md0,     RE_FULL, "all conflict words, full RE"),
  run(md0,     RE_RED,  "all conflict words, reduced RE"),
  run(md_poly, RE_RED,  "polysyllabic conflict words, reduced RE")
))
res[, dAIC := AIC - min(AIC), by = .(variant, dv)]
res[, rank := frank(AIC, ties.method = "min"), by = .(variant, dv)]
res[, pct := ifelse(dv == "log_duration", round(100 * (exp(estimate) - 1), 2), NA)]
readr::write_csv(res[order(variant, dv, AIC)],
                 file.path(OUT, "rule_conflict_robustness.csv"))

for (vt in unique(res$variant)) for (d in c("log_duration", "int_midpoint")) {
  cat(sprintf("\n== %s | %s ==\n", vt, d))
  print(res[variant == vt & dv == d][order(AIC),
        .(rule, estimate = round(estimate, 5), t = round(statistic, 1),
          dAIC = round(dAIC, 1), rank, pct, singular)])
}

cat("\n✓ rule_conflict_robustness.R complete\n")
