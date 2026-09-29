# analyses/son_default_test.R
# ================================================================
# SON-A vs SON-B, on the word set where they disagree.
#
# The two rules are identical except in words whose most sonorous vowel is
# mid-central or high-central (/ø ɵ/ or /ʉ/) — tiers 4 and 5. There:
#
#   SON-A  stresses the LEFTMOST member of that tier
#   SON-B  assigns NO STRESS at all
#
# So SON-B predicts nothing is prominent in these words and is unfalsifiable
# on its own terms; the test has to be run as SON-A's prediction, with a null
# result counting for SON-B. Two halves, because the rules disagree in two
# different ways:
#
#   PLACEMENT (polysyllables). Is the syllable SON-A designates longer or
#     louder than the other syllables of the same word? Within-word, so the
#     word's own rate, register and prosodic position are held constant by the
#     word-token random effect and the edge terms.
#
#   PRESENCE (monosyllables). A monosyllable in this set has one vowel and
#     placement is vacuous, but presence is not: SON-A says it bears stress,
#     SON-B says the word is stressless. Compared against reduced vowels in
#     polysyllabic word-final syllables that SON-A also leaves unstressed.
#
# A CHECK THAT MATTERS: if SON-A always designated syllable 1 in this subset,
# the placement test would be the initial-versus-non-initial contrast that
# default_adjudication.R already ran, and would add nothing. It does not —
# because tier 5 sits BELOW tier 4, a word like /ʉ-ø/ has its most sonorous
# vowel second, so SON-A picks syllable 2. The distribution of designated
# positions is reported below.
#
# Outputs
#   output/son_default_test.csv        both halves, both DVs, both control sets
#   output/son_default_profile.csv     the subset's composition
# ================================================================

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(data.table)
library(broom.mixed)

OUT <- PATHS$output_dir
JND_DUR_MS <- 10      # Hirsh (1959)
JND_INT_DB <- 3       # Moore (2007)

v <- as.data.table(vowels)[!is.na(vowel_label) & !is.na(sidx) & !is.na(word_id)]

# ── the restricted set: most sonorous tier present is 4 or 5 ────────────
TIER <- setNames(rep(seq_along(SONORITY_TIERS), lengths(SONORITY_TIERS)),
                 unlist(SONORITY_TIERS))
ord <- v[order(word_id, sidx)]
# WORD COMPLETENESS IS LOAD-BEARING HERE. A rule's target is computed from the
# vowel labels present, so in a word that lost syllables to cleaning (only
# 51.3% of word tokens are complete) SON-A may designate the wrong syllable,
# and a truncated polysyllable with one surviving vowel would be indistinguishable
# from a genuine monosyllable. `sN` is the pipeline's syllable count and is the
# only correct basis for "is this a monosyllable"; the number of surviving vowel
# ROWS is not. Both halves below require word_complete.
ord <- ord[word_complete == TRUE]
wd <- ord[, {
  t <- TIER[vowel_label]
  top <- suppressWarnings(min(t, na.rm = TRUE))
  .(sN = sN[1],
    top_tier = if (is.finite(top)) top else NA_integer_,
    t_SON_A = assign_stress(vowel_label, "SON_A"),
    t_SON_B = assign_stress(vowel_label, "SON_B"),
    t_SON_F = assign_stress(vowel_label, "SON_F"))
}, by = word_id]
wd[, restricted := !is.na(top_tier) & top_tier >= 4L]
cat(sprintf("\nwords where SON-A and SON-B disagree: %s of %s (%.1f%%)\n",
            format(sum(wd$restricted), big.mark = ","),
            format(nrow(wd), big.mark = ","), 100 * mean(wd$restricted)))
cat("SON-B assigns no stress in every one of them:",
    all(is.na(wd[restricted == TRUE, t_SON_B])), "\n")

prof <- wd[restricted == TRUE, .(words = .N), by = .(sN, top_tier,
            son_a_position = t_SON_A)][order(sN, top_tier, son_a_position)]
fwrite(prof, file.path(OUT, "son_default_profile.csv"))
cat("\n== is this just an initial-syllable test? position SON-A designates ==\n")
pp <- wd[restricted == TRUE & sN > 1L,
         .(words = .N), by = .(sN, son_a_position = t_SON_A)][order(sN, son_a_position)]
print(pp)
cat(sprintf("\nin polysyllables, SON-A designates syllable 1 in %.1f%% of them; "
            , 100 * mean(wd[restricted == TRUE & sN > 1L, t_SON_A] == 1L)))
cat(sprintf("non-initial in %s words\n",
            format(sum(wd[restricted == TRUE & sN > 1L, t_SON_A] != 1L),
                   big.mark = ",")))
cat("\nby word length and top tier:\n")
print(dcast(wd[restricted == TRUE, .N, by = .(sN, top_tier)],
            sN ~ top_tier, value.var = "N", fill = 0))

# ── shared covariates ───────────────────────────────────────────────────
v <- merge(v, wd[, .(word_id, top_tier, restricted, t_SON_A, t_SON_F)],
           by = "word_id")           # sN already on v, from the pipeline
v[, son_a_pick := !is.na(t_SON_A) & sidx == t_SON_A]
v[, syl_final := as.integer(sidx == sN)]
v[, word_utt_final := as.integer(!is.na(wN) & !is.na(widx) & widx == wN)]
if (!"log_speech_rate" %in% names(v)) v[, log_speech_rate := 0]
v[is.na(log_speech_rate), log_speech_rate := 0]
v[, z_freq := as.numeric(scale(log_corpus_freq))]
v[is.na(z_freq), z_freq := 0]
HEIGHT <- c(a = "low", e = "mid", ø = "mid", ɵ = "mid",
            i = "high", y = "high", u = "high", ʉ = "high")
v[, vowel_height := HEIGHT[vowel_label]]

CTRL <- list(
  vowel_label  = "vowel_label + syllable_coda + syl_final + word_utt_final + syl_final:word_utt_final + log_speech_rate + z_freq",
  vowel_height = "vowel_height + syllable_coda + syl_final + word_utt_final + syl_final:word_utt_final + log_speech_rate + z_freq"
)
# file_name is singular for duration (log_speech_rate is per-recording and
# absorbs it); see output/rule_conflict_singular.csv.
RE <- "(1|speaker_id) + (1|word_label)"

# ── half 1: PLACEMENT, polysyllables in the restricted set ─────────────
need <- c("log_duration", "int_midpoint", "vowel_label", "vowel_height",
          "syllable_coda", "syl_final", "word_utt_final", "log_speech_rate",
          "z_freq", "speaker_id", "word_label")
pl <- v[restricted == TRUE & sN > 1L][
  complete.cases(v[restricted == TRUE & sN > 1L, ..need])]
cat(sprintf("\n\n== PLACEMENT frame: %s vowels, %s word tokens, %s types ==\n",
            format(nrow(pl), big.mark = ","),
            format(uniqueN(pl$word_id), big.mark = ","),
            format(uniqueN(pl$word_label), big.mark = ",")))
cat("raw medians by whether SON-A designates the syllable:\n")
print(pl[, .(n = .N, median_ms = round(median(exp(log_duration)), 1),
             median_dB = round(median(int_midpoint), 2)), by = son_a_pick])

res <- list()
for (dv in c("log_duration", "int_midpoint")) for (cn in names(CTRL)) {
  f <- stats::as.formula(paste(dv, "~ son_a_pick +", CTRL[[cn]], "+", RE))
  m <- lmer(f, data = pl, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  tt <- as.data.table(tidy(m, effects = "fixed"))[term == "son_a_pickTRUE"]
  base <- if (dv == "log_duration") median(exp(pl$log_duration)) else NA_real_
  res[[length(res) + 1L]] <- data.table(
    half = "placement (polysyllables)", dv = dv, controls = cn,
    estimate = tt$estimate, se = tt$std.error, t = tt$statistic,
    pct = if (dv == "log_duration") 100 * (exp(tt$estimate) - 1) else NA_real_,
    effect_ms = if (dv == "log_duration") base * (exp(tt$estimate) - 1) else NA_real_,
    effect_dB = if (dv == "int_midpoint") tt$estimate else NA_real_,
    n_obs = nobs(m), n_words = uniqueN(pl$word_id), singular = isSingular(m))
}

# ── half 2: PRESENCE, monosyllables in the restricted set ──────────────
# Reference: a reduced vowel in the word-final syllable of a polysyllable that
# SON-A does NOT designate. Both cells are word-final, so final lengthening is
# equalised.
REDV <- c("ø", "ɵ", "ʉ")
pr <- v[syl_final == 1L & vowel_label %in% REDV]
pr[, cell := fifelse(sN == 1L & restricted == TRUE, "mono_SONA_stressed",
             fifelse(sN > 1L & !son_a_pick, "poly_final_unstressed",
                     NA_character_))]
pr <- pr[!is.na(cell)][complete.cases(pr[!is.na(cell), ..need])]
pr[, cell := relevel(factor(cell), ref = "poly_final_unstressed")]
cat(sprintf("\n== PRESENCE frame: %s vowels, %s types ==\n",
            format(nrow(pr), big.mark = ","),
            format(uniqueN(pr$word_label), big.mark = ",")))
print(pr[, .(n = .N, types = uniqueN(word_label),
             median_ms = round(median(exp(log_duration)), 1),
             median_dB = round(median(int_midpoint), 2)), by = cell])
for (dv in c("log_duration", "int_midpoint")) for (cn in names(CTRL)) {
  f <- stats::as.formula(paste(dv, "~ cell +", CTRL[[cn]], "+", RE))
  m <- lmer(f, data = pr, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  tt <- as.data.table(tidy(m, effects = "fixed"))[grepl("^cell", term)]
  base <- if (dv == "log_duration") median(exp(pr$log_duration)) else NA_real_
  res[[length(res) + 1L]] <- data.table(
    half = "presence (monosyllables)", dv = dv, controls = cn,
    estimate = tt$estimate, se = tt$std.error, t = tt$statistic,
    pct = if (dv == "log_duration") 100 * (exp(tt$estimate) - 1) else NA_real_,
    effect_ms = if (dv == "log_duration") base * (exp(tt$estimate) - 1) else NA_real_,
    effect_dB = if (dv == "int_midpoint") tt$estimate else NA_real_,
    n_obs = nobs(m), n_words = uniqueN(pr$word_id), singular = isSingular(m))
}

out <- rbindlist(res)
out[, clears_jnd := fifelse(dv == "log_duration", abs(effect_ms) > JND_DUR_MS,
                            abs(effect_dB) > JND_INT_DB)]
out[, verdict := fifelse(abs(t) < 2, "null -> SON-B",
                  fifelse(clears_jnd, "real and audible -> SON-A",
                          "significant but below the JND"))]
fwrite(out, file.path(OUT, "son_default_test.csv"))
cat("\n\n════ SON-A's prediction, on the set where the two rules disagree ════\n")
print(out[, .(half, dv, controls, estimate = round(estimate, 5),
              t = round(t, 2), pct = round(pct, 2),
              effect_ms = round(effect_ms, 2), effect_dB = round(effect_dB, 3),
              clears_jnd, verdict)])
cat(sprintf("\nJND references: duration %d ms (Hirsh 1959), intensity %d dB (Moore 2007)\n",
            JND_DUR_MS, JND_INT_DB))
cat("\n✓ son_default_test.R complete\n")
