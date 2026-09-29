# analyses/stress_rules_full_word.R
# ================================================================
# Re-runs the stress-rule comparison with targets computed from the WHOLE
# WORD rather than from the syllables that survived cleaning.
#
# THE PROBLEM
# -----------
# Stress is a property of the word. Once cleaning was changed to flag rather
# than delete, running a rule over the surviving rows became wrong in two
# separate ways.
#
# THREE COMPLETENESS FIGURES, WHICH MUST NOT BE CONFLATED (they were, in an
# earlier draft of this header):
#
#   61.1%  185,087 of 303,139 word tokens have n_syl_present == sN, i.e. every
#          syllable carries a measured vowel. **This is the figure relevant
#          here** — it is exactly the condition under which running a rule on
#          the surviving rows gives the right answer. The other 38.9%
#          (118,052 word tokens) are what this script fixes.
#   49.7%  150,704 word tokens have word_complete == TRUE, which is stricter:
#          all syllables present AND no vowel flagged as an IQR outlier. The
#          34,383 word-token difference is entirely accounted for by
#          n_iqr_outliers > 0.
#   51.3%  the share of VOWEL ROWS (of 574,344) whose word is word_complete.
#          A row-level statistic, not a word-level one.
#
#   (1) It can pick the wrong syllable. A three-syllable /i.e.a/ word with only
#       syllables 1 and 2 measured has its rightmost full vowel in syllable 3.
#       Run on the surviving pair, a rightmost-full rule picks /e/ in syllable
#       2. The correct labelling is that both measured syllables are UNSTRESSED
#       and the word contributes no stressed row.
#
#   (2) The returned index was compared against sidx. assign_stress() returns a
#       position in the vector it is given, so for a word with surviving sidx
#       {1, 3} a target of 2 means sidx 3 — but `sidx == 2` matches nothing and
#       the word silently lost its stressed row.
#
# Both are fixed by config's full_vowel_sequence() + assign_stress_full(),
# which read word_label_IPA_syllabified. This script quantifies what changed
# and re-runs the models on the full data and on the conflict subset.
#
# Outputs
#   output/full_word_label_changes.csv   how many labels move, per rule
#   output/full_word_rule_models.csv     9 rules x 2 DVs x 2 controls x 2 sets
# ================================================================

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(data.table)
library(broom.mixed)

OUT <- PATHS$output_dir
RULES <- c("A6", "A5", "A4", "B6", "B5", "B4", "SON_F", "SON_A", "SON_B")

v <- as.data.table(vowels)[!is.na(vowel_label) & !is.na(sidx) & !is.na(word_id)]

# ── the full sequence, once per word token ──────────────────────────────
wd <- unique(v[, .(word_id, sN, word_label, word_label_IPA_syllabified)])
wd[, full_seq := full_vowel_sequence(word_label_IPA_syllabified)]
wd[, n_full := lengths(strsplit(full_seq, "-", fixed = TRUE))]
cat(sprintf("\nword tokens: %s | full sequence recovers sN for %.3f%%\n",
            format(nrow(wd), big.mark = ","), 100 * mean(wd$n_full == wd$sN)))
stopifnot("full_vowel_sequence must reproduce sN" =
            mean(wd$n_full == wd$sN, na.rm = TRUE) > 0.999)

# the surviving sequence, for the comparison
sv <- v[order(word_id, sidx), .(surv_seq = paste(vowel_label, collapse = "-"),
                                surv_sidx = paste(sidx, collapse = ","),
                                n_surv = .N), by = word_id]
wd <- merge(wd, sv, by = "word_id")
wd[, has_gap := n_surv < sN]
cat(sprintf("incomplete word tokens: %s (%.1f%%)\n",
            format(sum(wd$has_gap), big.mark = ","), 100 * mean(wd$has_gap)))

# ── what changes, per rule ──────────────────────────────────────────────
chg <- rbindlist(lapply(RULES, function(r) {
  # NEW: target sidx from the full word
  tgt_new <- assign_stress_full(wd$full_seq, r)
  # OLD: position in the surviving vector, compared against sidx as the
  # pipeline did
  tgt_old <- vapply(strsplit(wd$surv_seq, "-", fixed = TRUE), function(vs) {
    s <- assign_stress(vs, r); if (length(s) && !is.na(s)) as.integer(s) else NA_integer_
  }, integer(1))
  measured <- Map(function(s) as.integer(strsplit(s, ",", fixed = TRUE)[[1]]),
                  wd$surv_sidx)
  new_in_data <- mapply(function(t, m) !is.na(t) && t %in% m, tgt_new, measured)
  old_in_data <- mapply(function(t, m) !is.na(t) && t %in% m, tgt_old, measured)
  data.table(
    rule = r,
    words = nrow(wd),
    pct_target_differs = round(100 * mean(
      (is.na(tgt_new) != is.na(tgt_old)) |
        (!is.na(tgt_new) & !is.na(tgt_old) & tgt_new != tgt_old)), 2),
    pct_target_differs_incomplete = round(100 * mean(
      ((is.na(tgt_new) != is.na(tgt_old)) |
         (!is.na(tgt_new) & !is.na(tgt_old) & tgt_new != tgt_old))[wd$has_gap]), 2),
    pct_stressed_row_new = round(100 * mean(new_in_data), 2),
    pct_stressed_row_old = round(100 * mean(old_in_data), 2),
    pct_words_no_stressed_row_new = round(100 * mean(!new_in_data), 2))
}))
fwrite(chg, file.path(OUT, "full_word_label_changes.csv"))
cat("\n== what moves when the target is computed from the whole word ==\n")
print(chg)

# ── rebuild the labels and re-run the models ───────────────────────────
for (r in RULES) {
  wd[, (paste0("t_", r)) := assign_stress_full(full_seq, r)]
}
tcols <- paste0("t_", RULES)
wd[, n_distinct_pred := apply(.SD, 1, function(x) length(unique(x[!is.na(x)]))),
   .SDcols = tcols]
wd[, any_na := apply(.SD, 1, function(x) any(is.na(x))), .SDcols = tcols]
wd[, conflict := (n_distinct_pred > 1L) | (any_na & n_distinct_pred > 0L)]
cat(sprintf("\nconflict subset on full-word targets: %s of %s word tokens (%.1f%%)\n",
            format(sum(wd$conflict), big.mark = ","),
            format(nrow(wd), big.mark = ","), 100 * mean(wd$conflict)))

v <- merge(v, wd[, c("word_id", "conflict", tcols), with = FALSE], by = "word_id")

# ── the labels the models use come from the PIPELINE, not from this script ──
# Stage 4 (04_annotate.R) now writes stress_rule_<R> using the same
# assign_stress_full() machinery. Read those columns rather than recomputing,
# so that this comparison is a test of what the pipeline actually produced —
# and assert that the two agree exactly, which is the end-to-end check that
# the stage-4 re-run landed.
for (r in RULES) {
  sc <- paste0("stress_rule_", r)
  stopifnot("stage 4 has not written this rule" = sc %in% names(v))
  fresh <- !is.na(v[[paste0("t_", r)]]) & v$sidx == v[[paste0("t_", r)]]
  agree <- mean((v[[sc]] == "Stressed") == fresh)
  cat(sprintf("  stored %-18s == full-word recomputation: %.4f%%\n",
              sc, 100 * agree))
  stopifnot("stored stress labels disagree with full_vowel_sequence()" =
              agree > 0.9999)
  v[, (paste0("is_stressed_", r)) := get(sc) == "Stressed"]
}
HEIGHT <- c(a = "low", e = "mid", ø = "mid", ɵ = "mid",
            i = "high", y = "high", u = "high", ʉ = "high")
v[, vowel_height := HEIGHT[vowel_label]]
v[, syl_final := as.integer(sidx == sN)]
v[, word_utt_final := as.integer(!is.na(wN) & !is.na(widx) & widx == wN)]
if (!"log_speech_rate" %in% names(v)) v[, log_speech_rate := 0]
v[is.na(log_speech_rate), log_speech_rate := 0]
v[, z_freq := as.numeric(scale(log_corpus_freq))]
v[is.na(z_freq), z_freq := 0]

CTRL <- list(
  vowel_label  = "vowel_label + syllable_coda + syl_final + word_utt_final + syl_final:word_utt_final + log_speech_rate + z_freq",
  vowel_height = "vowel_height + syllable_coda + syl_final + word_utt_final + syl_final:word_utt_final + log_speech_rate + z_freq"
)
RE <- "(1|speaker_id) + (1|word_label)"   # file_name singular for duration
need <- c("log_duration", "int_midpoint", "vowel_label", "vowel_height",
          "syllable_coda", "syl_final", "word_utt_final", "log_speech_rate",
          "z_freq", "speaker_id", "word_label")

fit <- function(dat, dv, rule, cn, tag) {
  f <- stats::as.formula(paste(dv, "~ is_stressed_", rule, " + ",
                               CTRL[[cn]], " + ", RE, sep = ""))
  m <- lmer(f, data = dat, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  tt <- as.data.table(tidy(m, effects = "fixed"))[
    term == paste0("is_stressed_", rule, "TRUE")]
  base <- if (dv == "log_duration") median(exp(dat$log_duration)) else NA_real_
  data.table(subset = tag, dv = dv, rule = rule, controls = cn,
             estimate = tt$estimate, se = tt$std.error, t = tt$statistic,
             pct = if (dv == "log_duration") 100 * (exp(tt$estimate) - 1) else NA_real_,
             effect_ms = if (dv == "log_duration") base * (exp(tt$estimate) - 1) else NA_real_,
             effect_dB = if (dv == "int_midpoint") tt$estimate else NA_real_,
             AIC = AIC(m), n_obs = nobs(m), singular = isSingular(m))
}

md_all <- v[complete.cases(v[, ..need])]
md_cf <- md_all[conflict == TRUE]
cat(sprintf("\nfull frame: %s vowels | conflict frame: %s vowels\n",
            format(nrow(md_all), big.mark = ","),
            format(nrow(md_cf), big.mark = ",")))

res <- list()
for (tag in c("all words", "conflict subset")) {
  dat <- if (tag == "all words") md_all else md_cf
  for (dv in c("log_duration", "int_midpoint")) for (cn in names(CTRL)) {
    for (r in RULES) {
      o <- fit(dat, dv, r, cn, tag)
      res[[length(res) + 1L]] <- o
      cat(sprintf("  %-16s %-12s %-6s %-12s beta=%9.5f AIC=%12.1f\n",
                  tag, dv, r, cn, o$estimate, o$AIC))
    }
  }
}
out <- rbindlist(res)
out[, dAIC := round(AIC - min(AIC), 1), by = .(subset, dv, controls)]
out[, rank := frank(AIC, ties.method = "min"), by = .(subset, dv, controls)]
fwrite(out, file.path(OUT, "full_word_rule_models.csv"))
# `dv` would shadow the column of the same name inside out[...], making the
# filter `dv == dv` — always TRUE — so both response variables were printed
# into every table. The CSV was never affected (dAIC and rank are computed
# by .(subset, dv, controls)), but the printed tables before 2026-09-29 were
# duration and intensity rows interleaved. Use a non-colliding name.
for (tag in unique(out$subset)) for (this_dv in unique(out$dv)) for (cn in names(CTRL)) {
  cat(sprintf("\n-- %s | %s | controlling %s --\n", tag, this_dv, cn))
  print(out[subset == tag & dv == this_dv & controls == cn][order(rank),
        .(rule, estimate = round(estimate, 5), t = round(t, 2),
          pct = round(pct, 2), effect_ms = round(effect_ms, 2),
          effect_dB = round(effect_dB, 3), dAIC)])
}
cat("\n✓ stress_rules_full_word.R complete\n")
