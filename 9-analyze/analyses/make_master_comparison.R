# =============================================================================
# make_master_comparison.R                                          2026-10-01
#
# REBUILDS output/master_rule_comparison.csv FROM CURRENT SOURCES.
#
# The previous version came from stress_rule_comparison.R sections 3-5, which
# recomputed every rule's labels over SURVIVING vowel rows instead of reading
# the pipeline's stored whole-word labels. Those sections are now gated behind
# RUN_SUPERSEDED_ACOUSTICS and take about four hours to run; rebuilding from
# the current per-cue outputs is both correct and cheap.
#
# WHAT CHANGED IN THE TABLE
#   * duration and intensity now come from full_word_rule_models.csv (all
#     words, vowel_label control), whose labels are verified identical to a
#     fresh whole-word recomputation at 100.0000% for all nine distinct rules.
#   * f0 columns are NEW. The old table had no f0 at all, so the paper's
#     three-cue criterion was only ever testable on two cues.
#   * `detected_accuracy_DESCRIPTIVE` is DROPPED. It came from the superseded
#     run and has no current source; it was descriptive only and was never
#     cited as evidence.
#
# The f0 columns use a DIFFERENT specification from the duration and intensity
# columns -- nonparametric position controls rather than the full-word model's
# controls -- so dAIC is comparable WITHIN a cue and never ACROSS cues. The
# `spec` column records which is which.
#
# Output
#   output/master_rule_comparison.csv
# =============================================================================
suppressMessages({library(data.table)})
OUT <- "output"

fw <- fread(file.path(OUT, "full_word_rule_models.csv"), encoding = "UTF-8")[
  subset == "all words" & controls == "vowel_label"]
f0 <- fread(file.path(OUT, "f0_rule_models.csv"), encoding = "UTF-8")[
  control == "vowel_label"]
cd <- fread(file.path(OUT, "rule_coda_attraction.csv"), encoding = "UTF-8")

wide <- dcast(fw, rule ~ dv, value.var = c("estimate", "se", "AIC", "dAIC", "rank"))
f0c  <- f0[, .(rule, estimate_f0_st = est_st, se_f0 = se, AIC_f0 = AIC,
               dAIC_f0 = dAIC_vs_position_only, rank_f0 = rank,
               identified_f0 = identified)]
M <- merge(wide, f0c, by = "rule", all = TRUE)

# rule_coda_attraction.csv is LONG (one row per corpus x rule); widen it.
# log_odds is the association between a syllable being designated and carrying
# a coda -- the test of whether any rule behaves like a weight-sensitive rule.
cw <- dcast(cd, rule ~ corpus, value.var = c("log_odds", "p_value", "n"))
setnames(cw, setdiff(names(cw), "rule"), paste0("coda_", setdiff(names(cw), "rule")))
M <- merge(M, cw, by = "rule", all.x = TRUE)

M[, spec_duration_intensity := "full-word models, all words, vowel_label control"]
M[, spec_f0 := "nonparametric position (f_sidx + f_sN + poly(rel_word,3) + is_utt_final), vowel_label control"]
setorder(M, rank_log_duration, na.last = TRUE)
fwrite(M, file.path(OUT, "master_rule_comparison.csv"))
cat(sprintf("rebuilt master_rule_comparison.csv: %d rules x %d columns\n",
            nrow(M), ncol(M)))
print(M[, .(rule,
            dur_pct    = round(100*(exp(estimate_log_duration)-1), 2),
            dur_rank   = rank_log_duration,
            int_dB     = round(estimate_int_midpoint, 3),
            int_rank   = rank_int_midpoint,
            f0_st      = round(estimate_f0_st, 3),
            f0_rank    = rank_f0)])
cat("\nNOTE: dAIC is comparable WITHIN a cue, never across cues -- the f0\n")
cat("columns use a different control specification. See the `spec_*` columns.\n")
cat("\n✓ make_master_comparison.R complete\n")
