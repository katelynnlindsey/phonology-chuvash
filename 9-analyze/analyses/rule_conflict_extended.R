# analyses/rule_conflict_extended.R
# ================================================================
# Extends analyses/rule_conflict_models.R with four things Kate asked for.
#
# 1. THE THREE SONORITY VARIANTS. SON-F, SON-A and SON-B cross the sonority
#    tiers with the A-vs-B question in exactly the way the full/reduced rules
#    do: rightmost of the most sonorous tier present, and then when that tier
#    is mid-central or high-central (/ø ɵ/, /ʉ/) either take it anyway (F),
#    take the leftmost instead (A), or assign no stress (B). Nine rules are
#    compared here rather than seven.
#
# 2. CONTROLS: vowel_label OR vowel_height. Both are run, because the choice
#    is a real methodological decision with a bias in each direction.
#
#      vowel_label (8 levels) asks: among tokens of the SAME vowel, is the one
#        the rule picks longer? It removes all intrinsic vowel duration, so a
#        rule cannot be credited for picking an inherently long vowel. The risk
#        is OVER-control: a sonority rule's prediction is partly constituted by
#        vowel identity, so conditioning on identity removes some of the
#        variance the rule is meant to explain.
#
#      vowel_height (3 levels) leaves intrinsic differences WITHIN a height
#        class in the residual. Since /a/ is both the longest vowel and tier 1,
#        this biases towards the sonority rules.
#
#    Neither is neutral, so the honest thing is to report both and see whether
#    the ranking depends on it. If it does, that is a finding about how fragile
#    the ranking is.
#
# 3. MONOSYLLABLES. rule_conflict_robustness.R dropped them, on the grounds
#    that "placement" is trivial in a one-syllable word. That was wrong, and
#    Kate's objection is the right one: the A-vs-B contrast is not about
#    placement at all, it is about whether stress is PRESENT. A monosyllable
#    whose only vowel is reduced is stressed under every A rule (it is the
#    leftmost reduced vowel) and stressless under every B rule. Monosyllables
#    are therefore the cleanest available discriminator between the defaults,
#    and they are the one place where the two analyses make opposite
#    predictions about the same token. Section 3 below tests them.
#
# 4. WHY THE SINGULAR FITS APPEAR, and whether they matter. Reported here
#    rather than guessed at.
#
# Outputs
#   output/rule_conflict_extended.csv     9 rules x 2 DVs x 2 control sets
#   output/rule_conflict_singular.csv     random-effect variances
#   output/monosyllable_default_test.csv  the A-vs-B test on monosyllables
# ================================================================

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(data.table)
library(broom.mixed)

OUT <- PATHS$output_dir
RULES <- c("A6", "A5", "A4", "B6", "B5", "B4", "SON_F", "SON_A", "SON_B")

v <- as.data.table(vowels)[!is.na(vowel_label) & !is.na(sidx) & !is.na(word_id)]

# ── predicted target per word, per rule ─────────────────────────────────
ord <- v[order(word_id, sidx)]
tg <- ord[, {
  vl <- vowel_label
  as.list(setNames(lapply(RULES, function(r) assign_stress(vl, r)),
                   paste0("t_", RULES)))
}, by = word_id]
tcols <- paste0("t_", RULES)
wd <- merge(unique(ord[, .(word_id, sN)]), tg, by = "word_id")
wd[, n_distinct_pred := apply(.SD, 1, function(x) length(unique(x[!is.na(x)]))),
   .SDcols = tcols]
wd[, any_na := apply(.SD, 1, function(x) any(is.na(x))), .SDcols = tcols]
wd[, conflict := (n_distinct_pred > 1L) | (any_na & n_distinct_pred > 0L)]
cat(sprintf("\nconflict on %s of %s word tokens (%.1f%%) with nine rules\n",
            format(sum(wd$conflict), big.mark = ","),
            format(nrow(wd), big.mark = ","), 100 * mean(wd$conflict)))
print(wd[, .(words = .N, conflict = sum(conflict),
             pct = round(100 * mean(conflict), 1)), by = sN][order(sN)])

v <- merge(v, wd[, c("word_id", "conflict", tcols), with = FALSE], by = "word_id")
for (r in RULES) v[, (paste0("is_stressed_", r)) :=
                     !is.na(get(paste0("t_", r))) & sidx == get(paste0("t_", r))]

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
  vowel_label  = paste("vowel_label + syllable_coda + syl_final +",
                       "word_utt_final + syl_final:word_utt_final +",
                       "log_speech_rate + z_freq"),
  vowel_height = paste("vowel_height + syllable_coda + syl_final +",
                       "word_utt_final + syl_final:word_utt_final +",
                       "log_speech_rate + z_freq")
)
need <- c("log_duration", "int_midpoint", "vowel_label", "vowel_height",
          "syllable_coda", "syl_final", "word_utt_final", "log_speech_rate",
          "z_freq", "speaker_id", "file_name", "word_label")
md <- v[conflict == TRUE][complete.cases(v[conflict == TRUE, ..need])]
cat(sprintf("model frame: %s vowels, %s word tokens, %s types\n",
            format(nrow(md), big.mark = ","),
            format(uniqueN(md$word_id), big.mark = ","),
            format(uniqueN(md$word_label), big.mark = ",")))

# ── 4. which random effect is singular, and does it matter? ─────────────
probe <- lmer(stats::as.formula(paste("log_duration ~ is_stressed_SON_F +",
              CTRL$vowel_label,
              "+ (1|speaker_id) + (1|file_name) + (1|word_label)")),
              data = md, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
vc <- as.data.frame(VarCorr(probe))[, c("grp", "vcov", "sdcor")]
zero <- vc$grp[vc$vcov < 1e-10]
cat("\n== random-effect variances (log_duration) ==\n"); print(vc)
cat("singular:", if (length(zero)) paste(zero, collapse = ", ") else "none", "\n")
probe_i <- lmer(stats::as.formula(paste("int_midpoint ~ is_stressed_SON_F +",
                CTRL$vowel_label,
                "+ (1|speaker_id) + (1|file_name) + (1|word_label)")),
                data = md, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
vci <- as.data.frame(VarCorr(probe_i))[, c("grp", "vcov", "sdcor")]
cat("\n== random-effect variances (int_midpoint) ==\n"); print(vci)
fwrite(rbind(cbind(dv = "log_duration", vc), cbind(dv = "int_midpoint", vci)),
       file.path(OUT, "rule_conflict_singular.csv"))

RE_FULL <- "(1|speaker_id) + (1|file_name) + (1|word_label)"
RE_RED <- paste0("(1|", setdiff(c("speaker_id", "file_name", "word_label"),
                                zero), ")", collapse = " + ")
cat("reduced random-effect structure:", RE_RED, "\n")

# ── 1 + 2. nine rules, two DVs, two control sets ───────────────────────
fit <- function(dv, rule, ctrl_name, re) {
  f <- stats::as.formula(sprintf("%s ~ is_stressed_%s + %s + %s",
                                 dv, rule, CTRL[[ctrl_name]], re))
  m <- lmer(f, data = md, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  co <- as.data.table(tidy(m, effects = "fixed"))[
    term == paste0("is_stressed_", rule, "TRUE")]
  data.table(dv = dv, rule = rule, controls = ctrl_name,
             estimate = co$estimate, statistic = co$statistic,
             AIC = AIC(m), singular = isSingular(m),
             n_obs = nobs(m))
}
res <- rbindlist(lapply(c("log_duration", "int_midpoint"), function(dv)
  rbindlist(lapply(names(CTRL), function(cn)
    rbindlist(lapply(RULES, function(r) {
      out <- fit(dv, r, cn, RE_RED)
      cat(sprintf("  %-12s %-6s %-12s beta=%8.5f AIC=%11.1f\n",
                  dv, r, cn, out$estimate, out$AIC))
      out
    }))))))
res[, dAIC := round(AIC - min(AIC), 1), by = .(dv, controls)]
res[, rank := frank(AIC, ties.method = "min"), by = .(dv, controls)]
res[, pct := ifelse(dv == "log_duration", round(100 * (exp(estimate) - 1), 2),
                    NA_real_)]
fwrite(res, file.path(OUT, "rule_conflict_extended.csv"))
cat("\n== nine rules, by DV and control set ==\n")
for (dv in unique(res$dv)) for (cn in names(CTRL)) {
  cat(sprintf("\n-- %s, controlling %s --\n", dv, cn))
  print(res[dv == get("dv") & controls == cn][order(rank),
        .(rule, estimate = round(estimate, 5), t = round(statistic, 2),
          pct, dAIC, rank)])
}
cat("\nDoes the ranking depend on the control set?\n")
for (dv in unique(res$dv)) {
  a <- res[dv == get("dv") & controls == "vowel_label"][order(rank), rule]
  b <- res[dv == get("dv") & controls == "vowel_height"][order(rank), rule]
  cat(sprintf("  %-12s vowel_label: %s\n", dv, paste(a, collapse = " > ")))
  cat(sprintf("  %-12s vowel_height: %s  | Spearman rho = %+.3f\n", "",
              paste(b, collapse = " > "),
              cor(match(a, RULES), match(b, RULES), method = "spearman")))
}

# ── 3. monosyllables: the A-vs-B default, where it is testable ─────────
# A monosyllable whose only vowel is reduced is stressed under every A rule
# and stressless under every B rule. The test is whether such a vowel looks
# like a stressed vowel or an unstressed one.
#
# The comparison has to be made WITHIN the reduced vowels and within
# monosyllables where possible, because monosyllables differ from
# polysyllables in frequency, function-word status and length. Three cells:
#
#   (a) reduced vowel, monosyllable            A: stressed   B: stressless
#   (b) reduced vowel, polysyllable, no rule stresses it    both: unstressed
#   (c) full vowel, monosyllable               all rules: stressed
#
# If (a) sits with (c) the A default is right; if it sits with (b), B is.
FULLV <- c("a", "e", "i", "u", "y")
REDV <- c("ø", "ɵ", "ʉ")
m <- copy(v)
m[, is_mono := as.integer(sN == 1L)]
m[, vclass := fifelse(vowel_label %in% FULLV, "full",
              fifelse(vowel_label %in% REDV, "reduced", NA_character_))]
acols <- paste0("is_stressed_", c("A6", "A5", "A4"))
m[, any_A := rowSums(.SD) > 0, .SDcols = acols]
m[, cell := fifelse(is_mono == 1L & vclass == "reduced", "a_reduced_mono",
            fifelse(is_mono == 0L & vclass == "reduced" & !any_A,
                    "b_reduced_poly_unstressed",
            fifelse(is_mono == 1L & vclass == "full", "c_full_mono",
                    NA_character_)))]
mm <- m[!is.na(cell) & !is.na(log_duration) & !is.na(int_midpoint) &
          !is.na(speaker_id) | (!is.na(cell) & !is.na(log_duration) &
          !is.na(int_midpoint))]
mm <- mm[!is.na(cell) & !is.na(log_duration) & !is.na(int_midpoint)]
cat("\n\n== monosyllable test: cell sizes ==\n")
print(mm[, .(n = .N, types = uniqueN(word_label),
             median_dur_ms = round(median(exp(log_duration)), 1),
             median_int_dB = round(median(int_midpoint), 2)), by = cell][order(cell)])

# Model: the three cells against each other, with the utterance edge, speech
# rate, frequency and vowel identity controlled. Reduced polysyllabic
# unstressed is the reference, so a positive coefficient on a_reduced_mono
# means monosyllabic reduced vowels are longer than unstressed ones.
mm[, cell := relevel(factor(cell), ref = "b_reduced_poly_unstressed")]
mono_res <- rbindlist(lapply(c("log_duration", "int_midpoint"), function(dv) {
  f <- stats::as.formula(paste(dv, "~ cell + vowel_label + syllable_coda +",
                               "word_utt_final + log_speech_rate + z_freq +",
                               "(1|file_name) + (1|word_label)"))
  mo <- lmer(f, data = mm, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  tt <- as.data.table(tidy(mo, effects = "fixed"))[grepl("^cell", term)]
  tt[, `:=`(dv = dv, pct = ifelse(dv == "log_duration",
                                  round(100 * (exp(estimate) - 1), 2), NA_real_))]
  tt[, .(dv, term, estimate, std.error, statistic, pct)]
}))
fwrite(mono_res, file.path(OUT, "monosyllable_default_test.csv"))
cat("\n== monosyllabic reduced vowels vs unstressed reduced vowels ==\n")
cat("   (reference = reduced vowel in a polysyllable that no A rule stresses)\n")
print(mono_res)
cat("\n✓ rule_conflict_extended.R complete\n")
