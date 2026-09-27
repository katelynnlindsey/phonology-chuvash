# ══════════════════════════════════════════════════════════════════════
# rule_conflict_models.R
#
# Rank the candidate stress rules on the subset of words where they
# actually disagree, and add SON — pure rightmost-to-sonority — to the
# comparison.
#
# Why a subset. stress_rule_comparison.R fits each rule over the whole
# dataset, and in roughly nine words out of ten every rule picks the same
# syllable. Those words contribute identical predictors to every model, so
# they add the same explanatory power to all of them and dilute the
# differences without informing them. The AIC gaps it reports are therefore
# small relative to the noise in the part of the data that carries the
# signal. Restricting to words where at least two rules disagree puts every
# row in the model on a comparison that distinguishes the rules.
#
# Why the edge terms are in the model. final_lengthening_models.csv puts the
# final syllable of an utterance-final word at +69% duration against +4.4%
# for stress. Any rule whose predictor correlates with word-final position
# absorbs part of that unless position is controlled, so `syl_final`,
# `word_utt_final` and their interaction are in every model here. This is
# the one substantive difference from stress_rule_comparison.R's model
# specification besides the subset.
#
# The `final` baseline is deliberately absent: its predictor IS `syl_final`,
# so it cannot be fitted alongside that control.
#
# Outputs
#   output/rule_conflict_profile.csv    how often the rules disagree, and how
#   output/rule_conflict_pairwise.csv   pairwise disagreement rates
#   output/rule_conflict_models.csv     AIC and beta per rule per measure
# ══════════════════════════════════════════════════════════════════════

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(data.table); library(lme4); library(broom.mixed)

OUT   <- PATHS$output_dir
RULES <- c("A6", "A5", "A4", "B6", "B5", "B4", "SON")

v <- as.data.table(vowels)[!is.na(vowel_label) & !is.na(sidx) & !is.na(word_id)]

# ── Predicted stressed syllable per word, per rule ────────────────────
# stress_rule_SON is not yet in data/leveled — it needs a stage-4 re-run —
# so every rule's target is recomputed here from vowel_label directly. That
# also guarantees all seven come from the same code path.
ord <- v[order(word_id, sidx)]
tg <- ord[, {
  vl <- vowel_label
  as.list(setNames(lapply(RULES, function(r) assign_stress(vl, r)), 
                   paste0("t_", RULES)))
}, by = word_id]

wd <- merge(unique(ord[, .(word_id, sN)]), tg, by = "word_id")
tcols <- paste0("t_", RULES)
wd[, n_distinct_pred := apply(.SD, 1, function(x) length(unique(x[!is.na(x)]))),
   .SDcols = tcols]
wd[, any_na := apply(.SD, 1, function(x) any(is.na(x))), .SDcols = tcols]
# A word where some rules predict a syllable and others predict "stressless"
# is also a conflict, so NA counts as its own prediction.
# NA (rule B leaving a word stressless) counts as its own prediction, so a
# word where some rules pick a syllable and others pick "none" is a conflict.
wd[, conflict := (n_distinct_pred > 1L) | (any_na & n_distinct_pred > 0L)]

prof <- wd[, .(words = .N,
               conflict_words = sum(conflict),
               pct_conflict = round(100 * mean(conflict), 2)), by = sN][order(sN)]
readr::write_csv(prof, file.path(OUT, "rule_conflict_profile.csv"))
cat("\n== how often do the seven rules disagree, by word length ==\n")
print(prof)
cat(sprintf("\noverall: %s of %s word tokens (%.1f%%) have at least two rules disagreeing\n",
            format(sum(wd$conflict), big.mark = ","),
            format(nrow(wd), big.mark = ","), 100 * mean(wd$conflict)))

# Pairwise disagreement, so it is visible which rules SON is and is not
# distinguishable from.
pw <- rbindlist(lapply(RULES, function(a) rbindlist(lapply(RULES, function(b) {
  x <- wd[[paste0("t_", a)]]; y <- wd[[paste0("t_", b)]]
  data.table(rule_a = a, rule_b = b,
             pct_disagree = round(100 * mean(!(is.na(x) & is.na(y)) &
                                             (is.na(x) | is.na(y) | x != y)), 2))
}))))
readr::write_csv(pw, file.path(OUT, "rule_conflict_pairwise.csv"))
cat("\n== pairwise disagreement (% of word tokens) ==\n")
print(dcast(pw, rule_a ~ rule_b, value.var = "pct_disagree"))

# ── Model frame: conflict words only ──────────────────────────────────
v <- merge(v, wd[, c("word_id", "conflict", tcols), with = FALSE], by = "word_id")
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
md <- v[conflict == TRUE][complete.cases(v[conflict == TRUE, ..need])]
cat(sprintf("\nConflict-subset model frame: %s vowels in %s word tokens | %s speakers, %s word types\n",
            format(nrow(md), big.mark = ","),
            format(uniqueN(md$word_id), big.mark = ","),
            uniqueN(md$speaker_id), uniqueN(md$word_label)))

fit_one <- function(dv, rule) {
  f <- stats::as.formula(sprintf(
    "%s ~ is_stressed_%s + %s + (1|speaker_id) + (1|file_name) + (1|word_label)",
    dv, rule, CONTROLS))
  lmer(f, data = md, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
}

res <- list()
for (dv in c("log_duration", "int_midpoint")) {
  for (r in RULES) {
    t0 <- proc.time()[["elapsed"]]
    m <- try(fit_one(dv, r), silent = TRUE)
    if (inherits(m, "try-error")) { cat("  FAILED", dv, r, "\n"); next }
    co <- as.data.table(tidy(m, effects = "fixed"))[
      term == paste0("is_stressed_", r, "TRUE")]
    res[[length(res) + 1L]] <- data.table(
      dv = dv, rule = r,
      estimate = if (nrow(co)) co$estimate else NA_real_,
      se       = if (nrow(co)) co$std.error else NA_real_,
      statistic = if (nrow(co)) co$statistic else NA_real_,
      AIC = AIC(m), n_obs = nrow(md))
    cat(sprintf("  %-13s %-4s beta=%9.5f AIC=%11.1f (%.0fs)\n", dv, r,
                res[[length(res)]]$estimate, AIC(m),
                proc.time()[["elapsed"]] - t0)); flush.console()
  }
}

r <- rbindlist(res)
r[, dAIC := AIC - min(AIC), by = dv]
r[, AIC_rank := frank(AIC, ties.method = "min"), by = dv]
# Duration is modelled on the log scale, so report the multiplicative effect.
r[, pct_change := ifelse(dv == "log_duration",
                         round(100 * (exp(estimate) - 1), 2), NA_real_)]
readr::write_csv(r[order(dv, AIC)], file.path(OUT, "rule_conflict_models.csv"))
cat("\n== rule ranking on the conflict subset, edges controlled ==\n")
print(r[order(dv, AIC), .(dv, rule, estimate = round(estimate, 5),
                          t = round(statistic, 1), dAIC = round(dAIC, 1),
                          AIC_rank, pct_change)])

cat("\n✓ rule_conflict_models.R complete\n")
