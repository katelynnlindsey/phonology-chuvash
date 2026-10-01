# =============================================================================
# carrier_frame_prominence.R                                      2026-10-01
#
# THE CARRIER-FRAME COUNTERPART to analyses/matched_vowel_prominence.R.
#
# The two designs control NON-OVERLAPPING confounds, which is why agreement
# between them is worth more than either alone:
#   matched-vowel test   holds the target's vowel content fixed; utterance
#                        position and local context are modelled
#   carrier-frame test   holds the neighbouring words -- hence local segmental
#                        context, phrasing and utterance position -- fixed BY
#                        DESIGN, and compares only within a frame
#
# A frame is a (preceding word, following word) pair in which several different
# target words occur: the corpus analogue of an elicited frame sentence. Both
# a two-sided version (both neighbours fixed, tight but sparse) and a one-sided
# version (preceding word only, looser but far larger) are run.
#
# The designation contrast is the same as in the matched-vowel test: within
# cells of (vowel, syllable index, word length), does it matter whether the
# rule designates the syllable? Frame enters as a random effect, so every
# comparison is made between targets sharing a carrier.
#
# Also writes a worked-examples table: for the largest cells, the actual word
# types on each side of the contrast.
#
# Outputs
#   output/carrier_frame_prominence.csv   the tests
#   output/designation_examples.csv       what the test compares, by cell
# =============================================================================
suppressMessages({library(data.table); library(lme4); library(broom.mixed)})
OUT <- "output"; RULES <- c("B5","A6","SON_B")

v <- readRDS("/tmp/v2.rds")
w <- as.data.table(readRDS("data/leveled/words_spoken_annotated.rds"))[
       !is.na(widx) & !is.na(word_label), .(file_name, widx, word_label, sN)]
setorder(w, file_name, widx)
w[, prev_w := shift(word_label, 1, type="lag"),  by = file_name]
w[, next_w := shift(word_label, 1, type="lead"), by = file_name]
v <- merge(v, w[, .(file_name, widx, prev_w, next_w)],
           by = c("file_name","widx"), all.x = TRUE)
v[, frame2 := fifelse(!is.na(prev_w) & !is.na(next_w), paste(prev_w, next_w, sep="\u2423"), NA_character_)]
v[, frame1 := prev_w]

for (nm in c("frame2","frame1")) {
  tg <- unique(v[!is.na(get(nm)), .(fr = get(nm), word_label, sN)])
  ok <- tg[, .(targets = uniqueN(word_label), lengths = uniqueN(sN)), by = fr][
          targets >= 3L & lengths >= 2L, fr]
  v[, (paste0("ok_", nm)) := get(nm) %in% ok]
  cat(sprintf("%s: %s usable frames | %s vowel rows\n", nm,
              format(length(ok), big.mark=","),
              format(sum(v[[paste0("ok_", nm)]], na.rm=TRUE), big.mark=",")))
}

COV <- "syllable_coda + z_freq"
res <- list()
for (rl in RULES) {
  v[, pred := get(paste0("is_", rl))]
  for (design in c("two-sided frame","one-sided frame")) {
    fcol <- if (design == "two-sided frame") "frame2" else "frame1"
    d0 <- v[get(paste0("ok_", fcol)) == TRUE & !is.na(get(fcol))]
    d0[, fr := factor(get(fcol))]
    for (pos in c("word-final syllables","non-final syllables")) {
      d <- if (pos == "word-final syllables") d0[is_final == TRUE] else d0[is_final == FALSE]
      for (mn in c(20L, 5L)) {
        cc <- d[, .(n_pred = sum(pred), n_not = sum(!pred)),
                by = .(vowel_label, sidx, sN)][n_pred >= mn & n_not >= mn]
        if (nrow(cc) == 0L) next
        dd <- merge(d, cc[, .(vowel_label, sidx, sN)], by = c("vowel_label","sidx","sN"))
        dd[, cell := factor(paste(vowel_label, sidx, sN, sep="_"))]
        if (uniqueN(dd$cell) < 2L || uniqueN(dd$fr) < 5L) next
        for (dv in c("dur_c","int_c")) {
          m <- try(lmer(as.formula(paste(dv,"~ pred + cell +",COV,"+ (1|fr) + (1|word_label)")),
                        data = dd, REML = FALSE, control = lmerControl(calc.derivs = FALSE)),
                   silent = TRUE)
          if (inherits(m,"try-error")) next
          tt <- as.data.table(tidy(m, effects="fixed"))[term == "predTRUE"]
          base <- median(exp(dd$log_duration))
          res[[length(res)+1L]] <- data.table(
            rule = rl, design = design, position = pos, min_cell_n = mn, dv = dv,
            estimate = tt$estimate, se = tt$std.error, t = tt$statistic,
            ms = if (dv=="dur_c") base*(exp(tt$estimate)-1) else NA_real_,
            dB = if (dv=="int_c") tt$estimate else NA_real_,
            cells = nrow(cc), frames = uniqueN(dd$fr), rows = nrow(dd))
          cat(sprintf("  %-6s %-16s %-22s n>=%2d %-6s est=%+8.5f t=%6.2f cells=%2d frames=%4d rows=%s\n",
                      rl, design, pos, mn, dv, tt$estimate, tt$statistic,
                      nrow(cc), uniqueN(dd$fr), format(nrow(dd), big.mark=",")))
        }
      }
    }
  }
}
out <- rbindlist(res); fwrite(out, file.path(OUT,"carrier_frame_prominence.csv"))
cat("\n== carrier-frame designation test ==\n")
print(out[, .(rule, design, position, min_cell_n, dv, est=round(estimate,5),
              t=round(t,2), ms=round(ms,2), dB=round(dB,3), cells, frames, rows)])

# ── worked examples: what is actually being compared, per cell ──────────
v[, pred := get("is_B5")]
ex <- v[, .(tokens = .N, designated = as.integer(pred[1])),
        by = .(vowel_label, sidx, sN, word_label, pred)]
cc <- v[, .(n_pred = sum(pred), n_not = sum(!pred)),
        by = .(vowel_label, sidx, sN)][n_pred >= 20L & n_not >= 20L]
ex <- merge(ex, cc[, .(vowel_label, sidx, sN)], by = c("vowel_label","sidx","sN"))
setorder(ex, vowel_label, sidx, sN, -pred, -tokens)
ex <- ex[, head(.SD, 4), by = .(vowel_label, sidx, sN, pred)]
ex[, rule := "B5"][, is_final := sidx == sN]
fwrite(ex, file.path(OUT,"designation_examples.csv"))
cat(sprintf("\nworked examples written for %d cells\n", uniqueN(ex[, .(vowel_label,sidx,sN)])))
cat("\n✓ carrier_frame_prominence.R complete\n")
