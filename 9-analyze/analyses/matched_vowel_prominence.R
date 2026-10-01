# =============================================================================
# matched_vowel_prominence.R                                      2026-10-01
#
# THE FRAME-EXPERIMENT LOGIC, RUN ON THE CORPUS.
#
# The elicited design being imitated: identical carrier utterance, target words
# of different phonological shape. If stress is NOT word-final it moves through
# the word with the shape; if it IS word-final it stays on the last syllable
# whatever the shape.
#
# THE CONTRAST THAT DOES THE WORK. Matching the vowel MULTISET is not by itself
# enough, because at a given syllable the vowel still differs across orders
# (syllable 3 of /aaɵ/ is ɵ, of /aɵa/ is a), so a position-by-position
# comparison would re-import the intrinsic-vowel confound the matching was
# meant to remove. The contrast that removes it exactly is one step tighter:
#
#     SAME vowel, SAME syllable index, SAME word length,
#     differing only in whether the rule predicts stress there.
#
# Whether a rule designates a given syllable depends on the OTHER vowels in the
# word, so this varies within such a cell. /a/ in syllable 2 of a trisyllable
# is rule-designated in /aaɵ/ (rightmost full vowel = 2) but not in /aau/
# (rightmost full = 3). Vowel identity, position and word length are therefore
# held fixed by STRATIFICATION, not by covariate adjustment -- which matters
# because a quality-driven rule's prediction is partly constituted by vowel
# identity, so adjusting it away removes the prediction under test.
#
# THE DECISIVE SUB-TEST, and why it answers the final-stress question:
#
#   Among WORD-FINAL syllables only, compare those the rule designates with
#   those it does not. Both are word-final, so final lengthening, boundary
#   lowering and utterance position are identical by construction.
#     * word-final stress predicts NO DIFFERENCE -- every final syllable is
#       stressed, so rule-designated or not is irrelevant.
#     * a rightmost-full-vowel rule predicts A DIFFERENCE -- only some final
#       syllables carry the full vowel.
#   e.g. каланӑ /aaɵ/ ends in reduced ɵ (not designated); ҫавӑнпа /aɵa/ ends in
#   full a (designated). Same length, same final-syllable status.
#
#   The mirror test on NON-FINAL syllables: final stress predicts no
#   difference there either (nothing is stressed), the rule predicts one.
#
# TWO VERSIONS ARE REPORTED.
#   all cells     every (vowel, sidx, sN) cell holding both outcomes -- larger n
#   matched sets  additionally restricted to word types inside a dissociating
#                 matched-vowel set, so the word-level vowel content is also
#                 balanced (output/matched_vowel_sets.csv)
#
# Per Kate, 2026-10-01: syllable_coda enters as a covariate rather than as a
# matching criterion, and the carrier-frame constraint is NOT stacked on top.
#
# RESIDUAL CONFOUND TO STATE. Within a cell, whether the rule designates the
# syllable depends on the word's other vowels, which correlates with
# morphology -- words ending in a reduced vowel are disproportionately
# suffixed. (1|word_label) and z_freq absorb part of this; it is not fully
# controlled and should be named as a limitation.
#
# Outputs
#   output/matched_vowel_prominence.csv    the tests
#   output/matched_vowel_cells.csv         the cells used, with counts
# =============================================================================

suppressMessages({library(data.table); library(lme4); library(broom.mixed)})
OUT <- "output"
RULES <- c("B5", "A6", "SON_B")
MIN_N <- 20L

v <- readRDS("/tmp/v2.rds")        # built by the prep step; see header of
                                   # analyses/final_syllable_prominence.R for
                                   # why 00_session_setup.R is not sourced
ms <- fread(file.path(OUT, "matched_vowel_sets.csv"))
setkey(ms, word_label)
v[, in_matched_set := word_label %in% ms[dissociates == TRUE, word_label]]
cat(sprintf("frame: %s vowels | %s in a dissociating matched-vowel set (%.1f%%)\n",
            format(nrow(v), big.mark=","),
            format(sum(v$in_matched_set), big.mark=","),
            100*mean(v$in_matched_set)))

COV <- "syllable_coda + z_freq + poly(rel_word,3) + is_utt_final"
res <- list(); cells_out <- list()

for (rl in RULES) {
  v[, pred := get(paste0("is_", rl))]
  for (scope in c("all cells", "matched sets")) {
    d0 <- if (scope == "all cells") v else v[in_matched_set == TRUE]
    for (pos in c("word-final syllables", "non-final syllables")) {
      d <- if (pos == "word-final syllables") d0[is_final == TRUE] else d0[is_final == FALSE]
      # cells holding BOTH outcomes at >= MIN_N each
      cc <- d[, .(n_pred = sum(pred), n_not = sum(!pred)),
              by = .(vowel_label, sidx, sN)][n_pred >= MIN_N & n_not >= MIN_N]
      if (nrow(cc) == 0L) next
      dd <- merge(d, cc[, .(vowel_label, sidx, sN)], by = c("vowel_label","sidx","sN"))
      dd[, cell := factor(paste(vowel_label, sidx, sN, sep = "_"))]
      cells_out[[length(cells_out)+1L]] <- data.table(
        rule = rl, scope = scope, position = pos, cells = nrow(cc),
        vowels = uniqueN(cc$vowel_label), rows = nrow(dd),
        n_designated = sum(dd$pred), n_not = sum(!dd$pred),
        word_types = uniqueN(dd$word_label))
      for (dv in c("dur_c", "int_c")) {
        m <- lmer(as.formula(paste(dv, "~ pred + cell +", COV, "+ (1|word_label)")),
                  data = dd, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
        tt <- as.data.table(tidy(m, effects = "fixed"))[term == "predTRUE"]
        base_ms <- median(exp(dd$log_duration))
        res[[length(res)+1L]] <- data.table(
          rule = rl, scope = scope, position = pos, dv = dv,
          estimate = tt$estimate, se = tt$std.error, t = tt$statistic,
          pct = if (dv=="dur_c") 100*(exp(tt$estimate)-1) else NA_real_,
          ms  = if (dv=="dur_c") base_ms*(exp(tt$estimate)-1) else NA_real_,
          dB  = if (dv=="int_c") tt$estimate else NA_real_,
          cells = nrow(cc), rows = nrow(dd))
        cat(sprintf("  %-6s %-12s %-22s %-6s est=%+8.5f t=%7.2f  n=%s\n",
                    rl, scope, pos, dv, tt$estimate, tt$statistic,
                    format(nrow(dd), big.mark=",")))
      }
    }
  }
}
out <- rbindlist(res); fwrite(out, file.path(OUT,"matched_vowel_prominence.csv"))
cl <- unique(rbindlist(cells_out)); fwrite(cl, file.path(OUT,"matched_vowel_cells.csv"))

cat("\n== cells used ==\n"); print(cl)
cat("\n== result: does rule-designation matter, vowel and position held fixed? ==\n")
print(out[, .(rule, scope, position, dv, est=round(estimate,5), t=round(t,2),
              ms=round(ms,2), dB=round(dB,3), cells)])
cat("\nREADING IT. Among WORD-FINAL syllables a word-final-stress rule predicts\n")
cat("NO effect of designation; a rightmost-full rule predicts a positive one.\n")
cat("JND: duration 10 ms (Hirsh 1959), intensity 3 dB (Moore 2007).\n")
cat("\n✓ matched_vowel_prominence.R complete\n")
