# =============================================================================
# shape_class_profiles.R                           2026-10-01, rev. same day
#
# THE "MOVING STRESS" TEST, DRAWN. Intensity and duration profiles across
# syllable positions, grouped by WHERE THE RIGHTMOST FULL VOWEL SITS.
#
# REVISION, at Kate's suggestion. The first version used strict shapes --
# all-full (FF, FFF, ...), F...R, F...RR, all-reduced -- which required every
# syllable before the final reduced one to be full. That is stricter than the
# rule needs: a rightmost-full-vowel rule cares only about the POSITION of the
# rightmost full vowel, so RFFR, RRFR and FRFR all make the same prediction as
# FFFR. Classes are therefore now defined by `from_end = sN - (position of the
# rightmost full vowel)`:
#
#   from_end 0   final            ...F
#   from_end 1   penultimate      ...FR
#   from_end 2   antepenultimate  ...FRR
#   from_end 3   pre-antepenult   ...FRRR
#   no full vowel                 all R  (leftmost reduced under A, stressless under B)
#
# What generalising buys, in word tokens (5-full inventory): penultimate at 4
# syllables 845 -> 1,741 and at 5 syllables 69 -> 176, which rescues two cells
# that were too thin to plot; antepenultimate at 4 syllables 175 -> 279; and a
# pre-antepenultimate class (121 tokens at 4 syllables) that the strict shapes
# could not produce at all. The gain is modest overall (penultimate 1.11x,
# antepenultimate 1.05x) because reduced vowels BEFORE a full vowel are rare in
# Chuvash -- /ø ɵ/ are largely suffixal and sit to the right.
#
# INVENTORY -- this is the answer to Kate's other question. The first version
# used the FIVE-full inventory (a e i u y), i.e. A5/B5, NOT A6. A6/B6 count
# ⟨ы⟩ /ʉ/ as full, and since /ʉ/ is 96% first-syllable that moves words between
# classes. BOTH inventories are now run and reported so the choice is visible.
#
# TWO VERSIONS of each, because neither settles it alone:
#   observed    recording-centred cell means, NO vowel-identity control, on
#               utterance-NON-final words. Cannot separate "the penult is
#               stressed" from "the penult holds a full vowel".
#   controlled  vowel_label, coda, frequency and utterance position in the
#               model -- removes that, but also removes part of what a
#               quality-driven rule predicts, so it under-reads.
#
# Outputs
#   output/shape_class_profiles.csv   both inventories, both versions
#   output/shape_class_counts.csv     token counts per (class, length)
# =============================================================================
suppressMessages({library(data.table); library(lme4); library(broom.mixed)})
OUT <- "output"; MIN_TOKENS <- 100L
INV <- list("5full" = c("a","e","i","u","y"),
            "6full" = c("a","e","i","u","y","ʉ"))
CLSNAME <- c("-1"="no full vowel","0"="final","1"="penultimate",
             "2"="antepenultimate","3"="pre-antepenult")
v0 <- readRDS("/tmp/v2.rds")
prof <- list(); cnts <- list()

for (iv in names(INV)) {
  v <- copy(v0)
  v[, FR := fifelse(vowel_label %in% INV[[iv]], "F", "R")]
  wd <- v[, .(n_syl = .N, sN = sN[1],
              shape = paste(FR[order(sidx)], collapse = "")), by = word_id][n_syl == sN]
  wd[, fp := vapply(gregexpr("F", shape),
                    function(m) if (m[1] == -1L) NA_integer_ else max(m), integer(1))]
  wd[, from_end := fifelse(is.na(fp), -1L, sN - fp)]
  v <- merge(v, wd[, .(word_id, shape, from_end)], by = "word_id")
  v <- v[from_end %in% c(-1L, 0L, 1L, 2L, 3L)]
  v[, cls := CLSNAME[as.character(from_end)]]
  # data.table will NOT recycle a length-1 scalar inside a `by` list -- it
  # demands every element be nrow(x) long. Add the constant as a column first.
  v[, inventory := iv]

  ct <- v[, .(vowel_rows = .N, word_tokens = uniqueN(word_id),
              types = uniqueN(word_label), shapes = uniqueN(shape)),
          by = .(inventory, cls, from_end, sN)]
  ct[, kept := word_tokens >= MIN_TOKENS]
  cnts[[iv]] <- ct
  v <- merge(v, ct[kept == TRUE, .(cls, sN)], by = c("cls","sN"))
  v[, cell := factor(paste(from_end, sN, sidx, sep = "_"))]
  v[, cell := relevel(cell, ref = "0_2_1")]

  obs <- v[is_utt_final == FALSE,
           .(n = .N, int_mean = mean(int_c), int_se = sd(int_c)/sqrt(.N),
             dur_mean = mean(exp(log_duration)), dur_se = sd(exp(log_duration))/sqrt(.N)),
           by = .(inventory, cls, from_end, sN, sidx)]
  obs[, version := "observed"]

  COV <- "vowel_label + syllable_coda + z_freq + poly(rel_word,3) + is_utt_final"
  base_ms <- median(exp(v$log_duration))
  ctl <- rbindlist(lapply(c("int_c","dur_c"), function(this_dv) {
    m <- lmer(as.formula(paste(this_dv, "~", COV, "+ cell + (1|word_label)")),
              data = v, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
    tt <- as.data.table(tidy(m, effects = "fixed"))[grepl("^cell", term)]
    tt[, term := sub("^cell", "", term)]
    tt <- rbind(data.table(term = "0_2_1", estimate = 0), tt[, .(term, estimate)], fill = TRUE)
    tt[, from_end := as.integer(sub("^(-?\\d+)_.*", "\\1", term))]
    tt[, sN   := as.integer(sub("^-?\\d+_(\\d+)_.*", "\\1", term))]
    tt[, sidx := as.integer(sub(".*_(\\d+)$", "\\1", term))]
    tt[, val := if (this_dv == "dur_c") base_ms*(exp(estimate)-1) else estimate]
    tt[, dv := this_dv][]
  }))
  ctl <- dcast(ctl, from_end + sN + sidx ~ dv, value.var = "val")
  setnames(ctl, c("int_c","dur_c"), c("int_mean","dur_mean"))
  ctl[, `:=`(inventory = iv, version = "controlled", cls = CLSNAME[as.character(from_end)])]
  prof[[iv]] <- rbind(obs, ctl, fill = TRUE)
  cat(sprintf("\n%s: %s vowel rows in plotted classes\n", iv, format(nrow(v), big.mark=",")))
}
P <- rbindlist(prof, fill = TRUE); C <- rbindlist(cnts, fill = TRUE)
fwrite(P, file.path(OUT, "shape_class_profiles.csv"))
fwrite(C, file.path(OUT, "shape_class_counts.csv"))

cat("\n== word tokens per class, both inventories ==\n")
print(dcast(C, cls + from_end + sN ~ inventory, value.var = "word_tokens", fill = 0))
cat("\n== where the DURATION peak falls (observed) vs predicted ==\n")
pk <- P[version == "observed", .SD[which.max(dur_mean)], by = .(inventory, cls, from_end, sN)]
pk[, predicted := fifelse(from_end == -1L, 1L, sN - from_end)]
pk[, match := sidx == predicted]
print(pk[order(inventory, from_end, sN), .(inventory, cls, sN, peak = sidx, predicted, match)])
cat(sprintf("\nmatches where a full vowel exists: %s\n",
            paste(pk[from_end >= 0L, .(m = sprintf("%s %d/%d", inventory[1], sum(match), .N)),
                     by = inventory]$m, collapse = " | ")))
cat("\n✓ shape_class_profiles.R complete\n")
