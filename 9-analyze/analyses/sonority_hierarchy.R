# analyses/sonority_hierarchy.R
# ================================================================
# Derive a sonority hierarchy for the eight Chuvash vowels WITHOUT using
# stress, then test whether it predicts stress.
#
# THE CIRCULARITY PROBLEM, AND WHERE IT ACTUALLY SITS
# ---------------------------------------------------
# The obvious way to rank vowels by sonority is to measure their intensity or
# duration. But those are the same two measures used as the phonetic correlates
# of stress in this project. Rank the vowels by intensity, then ask whether
# high-intensity vowels attract stress, and the answer is built in.
#
# There is a second, less obvious circularity in rule SON as currently
# specified. Its tiers are
#
#       a  >  e  >  {i y u}  >  {ø ɵ}  >  ʉ
#
# On vowel height the eight vowels form only THREE classes: /a/ is low,
# /e ø ɵ/ are mid, /i y u ʉ/ are high. SON's tiers cut across that twice:
# it separates /e/ from /ø ɵ/, which are all mid, and it separates /ʉ/ from
# /i y u/, which are all high. Both cuts are exactly the full/reduced
# distinction -- and in this project full-vs-reduced is itself established
# from stress behaviour. So SON's tier structure is not a sonority hierarchy
# with a phonetic basis; it is a height hierarchy refined by reducedness, and
# the refinement is what makes it circular with respect to the stress
# question.
#
# WHAT THIS SCRIPT DOES INSTEAD
# -----------------------------
# 1. Derives intrinsic per-vowel values for F1, intensity and duration from a
#    RULE-NEUTRAL UNSTRESSED SET: vowel tokens that every one of the six
#    stress rules agrees is unstressed. Position and speaker are in the model,
#    so the values are adjusted rather than raw. A ranking built from tokens
#    no rule calls stressed cannot encode the stress pattern.
#
# 2. Builds five candidate hierarchies:
#      SON      Kate's tiers, as specified                     (circular: see above)
#      HEIGHT   low > mid > high, three tiers                   (independent)
#      F1       empirical, ranked by adjusted F1                (independent)
#      INT      empirical, ranked by adjusted intensity         (CIRCULAR)
#      DUR      empirical, ranked by adjusted duration          (CIRCULAR)
#    F1 is the key one. Aperture is the standard articulatory correlate of
#    sonority, and F1 is not used anywhere in this project as a correlate of
#    stress -- so an F1-derived ranking tested against duration and intensity
#    outcomes is a genuine out-of-sample test.
#
# 3. Tests each hierarchy on the conflict subset (the word tokens where the
#    rules disagree), with the utterance edge controlled, against duration and
#    intensity. INT and DUR are reported but flagged: each is circular for its
#    own outcome and is included only to show how much a circular hierarchy
#    flatters itself.
#
# 4. Tests each hierarchy against the WRITTEN corpora, where there are no
#    acoustics at all, using two phonological correlates: which vowels appear
#    in open monosyllables, and which appear in non-initial syllables.
#
# Outputs
#   output/sonority_intrinsic.csv    adjusted per-vowel values + rankings
#   output/sonority_hierarchies.csv  the five hierarchies side by side
#   output/sonority_rule_tests.csv   each hierarchy as a stress rule, AIC
#   output/sonority_written.csv      the written-corpus tests
# ================================================================

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(data.table)

OUT <- PATHS$output_dir
V8 <- c("a", "e", "i", "u", "y", "ø", "ɵ", "ʉ")

v <- as.data.table(vowels)[vowel_label %in% V8]
w <- as.data.table(words)

# ── 1. the rule-neutral unstressed set ──────────────────────────────────
rule_cols <- paste0("stress_rule_", c("A6", "A5", "A4", "B6", "B5", "B4"))
v[, n_rules_stressed := rowSums(.SD == "Stressed", na.rm = TRUE),
  .SDcols = rule_cols]
neutral <- v[n_rules_stressed == 0]
cat(sprintf("\nrule-neutral unstressed set: %d of %d vowels (%.1f%%), %d types\n",
            nrow(neutral), nrow(v), 100 * nrow(neutral) / nrow(v),
            uniqueN(neutral$word_label)))
cat("by vowel:\n"); print(table(neutral$vowel_label))

# Lobanov-normalise F1 within speaker so the ranking is not one speaker's
# vocal tract. Chuvash Voice has no speaker_id, so use file_name there.
neutral[, spk := fifelse(is.na(speaker_id), paste0("cv_", corpus), speaker_id)]
neutral[, spk := fifelse(corpus == "chuvash_voice", "chuvash_voice_main", spk)]
neutral <- neutral[!is.na(F1) & !is.na(int_midpoint) & !is.na(duration)]
neutral[, F1z := (F1 - mean(F1, na.rm = TRUE)) / sd(F1, na.rm = TRUE), by = spk]
neutral[, intz := (int_midpoint - mean(int_midpoint, na.rm = TRUE)) /
          sd(int_midpoint, na.rm = TRUE), by = spk]
neutral[, syl_final := as.integer(sidx == sN)]
neutral[, syl_initial := as.integer(sidx == 1L)]
neutral[, closed := as.integer(syllable_coda == "closed")]

# Adjusted intrinsic values: vowel identity as a factor, with the positional
# and speaker structure partialled out.
intrinsic <- function(dv) {
  f <- as.formula(paste0(dv, " ~ 0 + vowel_label + syl_final + syl_initial +",
                         " closed + (1 | spk) + (1 | word_label)"))
  m <- lmer(f, data = neutral, REML = FALSE,
            control = lmerControl(calc.derivs = FALSE))
  fx <- lme4::fixef(m)
  fx <- fx[grepl("^vowel_label", names(fx))]
  setNames(as.numeric(fx), sub("^vowel_label", "", names(fx)))
}
adj_F1  <- intrinsic("F1z")
adj_int <- intrinsic("intz")
adj_dur <- intrinsic("log(duration)")

HEIGHT <- c(a = "low", e = "mid", ø = "mid", ɵ = "mid",
            i = "high", y = "high", u = "high", ʉ = "high")
int_tbl <- data.table(
  vowel = V8,
  n_neutral = as.integer(table(neutral$vowel_label)[V8]),
  height = HEIGHT[V8],
  adj_F1z = round(adj_F1[V8], 4),
  adj_intz = round(adj_int[V8], 4),
  adj_log_dur = round(adj_dur[V8], 4),
  son_tier = vapply(V8, function(x)
    which(vapply(SONORITY_TIERS, function(t) x %in% t, logical(1))), integer(1))
)
int_tbl[, rank_F1  := frank(-adj_F1z,  ties.method = "min")]
int_tbl[, rank_int := frank(-adj_intz, ties.method = "min")]
int_tbl[, rank_dur := frank(-adj_log_dur, ties.method = "min")]
fwrite(int_tbl, file.path(OUT, "sonority_intrinsic.csv"))
cat("\n── adjusted intrinsic values, rule-neutral unstressed tokens ──\n")
print(int_tbl[order(-adj_F1z)])

# ── 2. the five hierarchies ─────────────────────────────────────────────
tiers_from_rank <- function(x) {                 # ties -> same tier
  r <- frank(-x, ties.method = "min")
  as.integer(factor(r))
}
H <- data.table(
  vowel = V8,
  SON = int_tbl$son_tier,
  HEIGHT = as.integer(factor(HEIGHT[V8], levels = c("low", "mid", "high"))),
  F1 = tiers_from_rank(int_tbl$adj_F1z),
  INT = tiers_from_rank(int_tbl$adj_intz),
  DUR = tiers_from_rank(int_tbl$adj_log_dur)
)
fwrite(H, file.path(OUT, "sonority_hierarchies.csv"))
cat("\n── the five hierarchies (1 = most sonorous) ──\n"); print(H)
cat("\nrank correlations with SON (Spearman):\n")
for (nm in c("HEIGHT", "F1", "INT", "DUR"))
  cat(sprintf("  %-7s rho = %+.3f\n", nm,
              cor(H$SON, H[[nm]], method = "spearman")))

# ── 3. each hierarchy as a stress rule, on the conflict subset ──────────
# Stress the rightmost vowel of the most sonorous tier the word contains --
# the same algorithm as SON, with the tier assignment swapped.
assign_by_tiers <- function(vowel_seq, tiermap) {
  vs <- strsplit(vowel_seq, "-", fixed = TRUE)
  vapply(vs, function(x) {
    x <- x[x %in% names(tiermap)]
    if (!length(x)) return(NA_real_)
    t <- tiermap[x]
    max(which(t == min(t)))
  }, numeric(1))
}
for (nm in c("SON", "HEIGHT", "F1", "INT", "DUR")) {
  tm <- setNames(H[[nm]], H$vowel)
  w[, (paste0("sidx_", nm)) := assign_by_tiers(vowel_sequence, tm)]
}
stress_cols <- paste0("sidx_", c("SON", "HEIGHT", "F1", "INT", "DUR"))
# conflict subset: word tokens where the five hierarchies do not all agree
w[, n_distinct_pred := apply(.SD, 1, function(r) uniqueN(r[!is.na(r)])),
  .SDcols = stress_cols]
conf_ids <- w[sN > 1 & n_distinct_pred > 1, word_id]
cat(sprintf("\nconflict subset: %d of %d polysyllabic word tokens (%.1f%%)\n",
            length(conf_ids), nrow(w[sN > 1]),
            100 * length(conf_ids) / nrow(w[sN > 1])))

md <- merge(v, w[, c("word_id", stress_cols), with = FALSE], by = "word_id")
md <- md[word_id %in% conf_ids]
md[, spk := fifelse(corpus == "chuvash_voice", "chuvash_voice_main",
                    fifelse(is.na(speaker_id), "unknown", speaker_id))]
md[, syl_final := as.integer(sidx == sN)]
md[, utt_final := as.integer(phrase_position == "final")]
md <- md[!is.na(int_midpoint) & !is.na(duration) & duration > 0]
cat(sprintf("model frame: %d vowels, %d word tokens, %d types\n",
            nrow(md), uniqueN(md$word_id), uniqueN(md$word_label)))

fit_one <- function(nm, dv) {
  md[, pred := as.integer(sidx == get(paste0("sidx_", nm)))]
  f <- as.formula(paste0(dv, " ~ pred + vowel_label + syl_final + utt_final +",
                         " syl_final:utt_final + log_speech_rate +",
                         " (1 | spk) + (1 | word_label)"))
  m <- lmer(f, data = md, REML = FALSE,
            control = lmerControl(calc.derivs = FALSE))
  tt <- as.data.table(broom.mixed::tidy(m, effects = "fixed"))[term == "pred"]
  data.table(hierarchy = nm, outcome = dv, beta = tt$estimate,
             se = tt$std.error, t = tt$statistic, AIC = AIC(m),
             n = nobs(m))
}
res <- rbindlist(lapply(c("SON", "HEIGHT", "F1", "INT", "DUR"),
                        function(nm) rbindlist(list(
                          fit_one(nm, "log(duration)"),
                          fit_one(nm, "int_midpoint")))))
res[, dAIC := round(AIC - min(AIC), 1), by = outcome]
res[, pct := ifelse(outcome == "log(duration)",
                    round(100 * (exp(beta) - 1), 2), NA_real_)]
res[, circular_for_this_outcome := fifelse(
  (hierarchy == "DUR" & outcome == "log(duration)") |
  (hierarchy == "INT" & outcome == "int_midpoint") |
   hierarchy == "SON", "yes", "no")]
fwrite(res, file.path(OUT, "sonority_rule_tests.csv"))
cat("\n── each hierarchy as a stress rule, conflict subset ──\n")
print(res[order(outcome, dAIC)])

# ── 4. the written corpora: no acoustics at all ─────────────────────────
# Two phonological correlates that do not involve any measurement:
#   open_mono  — can the vowel stand in an open monosyllable? (minimal word)
#   noninitial — what share of its polysyllabic tokens are non-initial?
za <- as.data.table(zheltov_ann)
wr <- za[vowel_label %in% V8, .(
  n_syllables = .N,
  pct_open_monosyllable = round(100 * mean(sN == 1 & syllable_coda == "open"), 2),
  pct_noninitial = round(100 * mean(sidx > 1 & sN > 1) / mean(sN > 1), 2)
), by = .(vowel = vowel_label)]
wr <- merge(wr, H, by = "vowel")
fwrite(wr, file.path(OUT, "sonority_written.csv"))
cat("\n── written corpus (Zheltov), no acoustics ──\n")
print(wr[order(SON)])
cat("\nSpearman rho of each hierarchy against the written correlates:\n")
for (nm in c("SON", "HEIGHT", "F1")) {
  cat(sprintf("  %-7s vs open monosyllables %+.3f | vs non-initial %+.3f\n", nm,
              cor(wr[[nm]], wr$pct_open_monosyllable, method = "spearman"),
              cor(wr[[nm]], wr$pct_noninitial, method = "spearman")))
}
cat("\n✓ sonority_hierarchy.R complete\n")
