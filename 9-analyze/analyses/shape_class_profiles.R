# =============================================================================
# shape_class_profiles.R                                          2026-10-01
#
# THE "MOVING STRESS" TEST, DRAWN. Intensity and duration profiles across
# syllable positions, separately for the four full/reduced word shapes that
# place the rightmost full vowel in a different place:
#
#   all full          FF FFF FFFF FFFFF FFFFFF   -> rightmost full = FINAL
#   penultimate       FR FFR FFFR FFFFR          -> rightmost full = PENULT
#   antepenultimate   FRR FFRR FFFRR             -> rightmost full = ANTEPENULT
#   all reduced       RR RRR RRRR                -> no full vowel: leftmost
#                                                   reduced (rule A) or
#                                                   stressless (rule B)
#
# If stress tracks the rightmost full vowel, the prominence peak should sit one
# syllable further left in each successive class. If stress is word-final it
# should sit on the last syllable in all four.
#
# INVENTORY. F/R uses B5's five full vowels (a e i u y), B5 being the
# best-fitting rule. A6 differs only in counting ⟨ы⟩ /ʉ/ as full, which is 1.9%
# of tokens.
#
# TWO VERSIONS, and the difference between them is the methodological point.
#   observed    recording-centred cell means, NO vowel-identity control, on
#               utterance-NON-final words only (the utterance-edge effect would
#               otherwise dominate the last syllable). This is what these word
#               shapes actually look like.
#   controlled  model-based cell means with vowel_label, coda, frequency and
#               utterance position in the model -- i.e. position effects NET of
#               intrinsic vowel quality. Comparable to the panels in
#               output/position_cell_means.csv.
# The observed version cannot distinguish "the penult is stressed" from "the
# penult has a full vowel and full vowels are intrinsically longer and louder".
# The controlled version removes that, at the cost of removing part of what a
# quality-driven rule predicts. Neither alone settles it; shown together they
# bound it.
#
# SHAPES EXCLUDED as too sparse (any syllable cell under 20 vowel rows):
#   FFFFFR (11 word tokens), FFFFRR (1), RRRRR (1), RRRRRR (1).
#
# Outputs
#   output/shape_class_profiles.csv      both versions, every cell
#   output/shape_class_counts.csv        token counts per shape
# =============================================================================
suppressMessages({library(data.table); library(lme4); library(broom.mixed)})
OUT <- "output"; MIN_CELL <- 20L
FULL5 <- c("a","e","i","u","y")

v <- readRDS("/tmp/v2.rds")
v[, FR := fifelse(vowel_label %in% FULL5, "F", "R")]
wd <- v[, .(n_syl = .N, sN = sN[1], shape = paste(FR[order(sidx)], collapse="")), by = word_id]
wd <- wd[n_syl == sN]                       # shape string valid only if complete
v <- merge(v, wd[, .(word_id, shape)], by = "word_id")
cls <- function(s) { n <- nchar(s)
  if (s == strrep("F", n)) "all full"
  else if (s == paste0(strrep("F", n-1), "R")) "penultimate"
  else if (n >= 3 && s == paste0(strrep("F", n-2), "RR")) "antepenultimate"
  else if (s == strrep("R", n)) "all reduced" else NA_character_ }
shp <- unique(v[, .(shape)]); shp[, shape_class := vapply(shape, cls, character(1))]
v <- merge(v, shp, by = "shape")[!is.na(shape_class)]

keep <- v[, .N, by = .(shape, sidx)][, .(min_cell = min(N)), by = shape][min_cell >= MIN_CELL, shape]
cnt <- v[, .(vowel_rows = .N, word_tokens = uniqueN(word_id), types = uniqueN(word_label),
             kept = shape[1] %in% keep), by = .(shape_class, shape, sN)]
setorder(cnt, shape_class, sN); fwrite(cnt, file.path(OUT,"shape_class_counts.csv"))
cat("\n== shapes and whether they are usable ==\n"); print(cnt)
v <- v[shape %in% keep]
v[, cell := factor(paste(shape, sidx, sep = "_"))]
v[, cell := relevel(cell, ref = "FF_1")]

# ── observed: recording-centred means, utterance-non-final words ────────
obs <- v[is_utt_final == FALSE, .(n = .N,
          int_mean = mean(int_c), int_se = sd(int_c)/sqrt(.N),
          dur_mean = mean(exp(log_duration)),
          dur_c_mean = mean(dur_c), dur_c_se = sd(dur_c)/sqrt(.N)),
         by = .(shape_class, shape, sN, sidx)]
obs[, version := "observed"]

# ── controlled: model-based cell means ─────────────────────────────────
COV <- "vowel_label + syllable_coda + z_freq + poly(rel_word,3) + is_utt_final"
base_ms <- median(exp(v$log_duration))
ctl <- rbindlist(lapply(c("int_c","dur_c"), function(this_dv) {
  m <- lmer(as.formula(paste(this_dv, "~", COV, "+ cell + (1|word_label)")),
            data = v, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  tt <- as.data.table(tidy(m, effects="fixed"))[grepl("^cell", term)]
  tt[, term := sub("^cell", "", term)]
  tt <- rbind(data.table(term="FF_1", estimate=0, std.error=NA_real_), tt[, .(term, estimate, std.error)],
              fill = TRUE)
  tt[, dv := this_dv]
  tt[, shape := sub("_\\d+$", "", term)][, sidx := as.integer(sub(".*_(\\d+)$","\\1",term))]
  tt[, value := if (this_dv=="dur_c") base_ms*(exp(estimate)-1) else estimate]
  tt[]
}))
ctl <- merge(ctl, unique(v[, .(shape, shape_class, sN)]), by = "shape")
fwrite(rbind(obs, ctl, fill = TRUE), file.path(OUT,"shape_class_profiles.csv"))

for (this_dv in c("int_c","dur_c")) {
  cat(sprintf("\n== CONTROLLED %s, cell means (ref = FF syllable 1) ==\n",
              ifelse(this_dv=="int_c","INTENSITY dB","DURATION ms")))
  u <- dcast(ctl[dv==this_dv], shape_class + shape + sN ~ sidx, value.var="value")
  setorder(u, shape_class, sN); print(u[, lapply(.SD, function(x) if (is.numeric(x)) round(x,2) else x)])
}
cat("\n✓ shape_class_profiles.R complete\n")
