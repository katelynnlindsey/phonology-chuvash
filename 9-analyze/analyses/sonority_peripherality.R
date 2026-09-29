# analyses/sonority_peripherality.R
# ================================================================
# Can the CLASSIC vocalic sonority hierarchy be measured in the Chuvash data?
#
#   low peripheral > mid peripheral > high peripheral > mid central > high central
#
# (de Lacy 2002/2004/2006; Kenstowicz 1997; Gordon 2006.) Applied to the
# Chuvash inventory this is exactly rule SON:
#
#   a            low peripheral    tier 1
#   e            mid peripheral    tier 2
#   i y u        high peripheral   tier 3
#   ø ɵ          mid central       tier 4
#   ʉ            high central      tier 5
#
# CORRECTION TO analyses/sonority_hierarchy.R
# -------------------------------------------
# That script reported SON's tiers as "a height hierarchy refined by
# reducedness", and concluded the refinement was circular because
# full-versus-reduced is established in this project from stress behaviour.
# **That conclusion was wrong.** SON's departures from pure height are the
# PERIPHERAL/CENTRAL distinction, which is the second dimension of the standard
# hierarchy and has nothing to do with stress. The tiers are the published
# hierarchy, not an ad hoc partition, and the fact that they coincide with the
# full/reduced split in Chuvash is a substantive claim about Chuvash, not a
# circularity.
#
# So the open question is the one Kate actually asked: what is peripherality
# based on phonetically, and can it be measured here?
#
# WHAT PERIPHERALITY IS, AND HOW IT IS MEASURED HERE
# --------------------------------------------------
# A peripheral vowel sits at the EDGE of the vowel space; a central vowel sits
# inside it. That is a statement about formant geometry, and the operationalisation
# turns out to matter a great deal. Three are tried here:
#
#   (a) distance from the speaker's vowel-space centroid in F1 x F2
#   (b) backness deviation alone, |F2 - centroid F2|
#   (c) CONVEX HULL membership: is the vowel a vertex of the speaker's own
#       vowel space?
#
# Only (c) recovers de Lacy's classes, and it is also the formally correct
# reading of "peripheral" -- a vowel at the edge of the space is a vertex of
# its convex hull. (a) misclassifies /e/ and /ɵ/, swapping them, and (b) fails
# in every speaker.
#
# Two design points matter.
#
#   * The centroid is the unweighted mean of the EIGHT VOWEL MEANS, not the
#     mean over tokens. /a/ is 33% of tokens, so a token-weighted centroid is
#     dragged towards /a/ and every other vowel's distance is inflated.
#
#   * Distances are computed on the RULE-NEUTRAL UNSTRESSED SET -- tokens all
#     six stress rules agree are unstressed. This is essential rather than
#     fastidious: stressed vowels are hyperarticulated and therefore more
#     peripheral, so measuring peripherality on all tokens would let the stress
#     pattern into the very measure meant to be independent of it.
#
# Neither F1 nor F2 is used anywhere in this project as a correlate of stress
# (those are duration, intensity and f0), so a hierarchy built from formant
# geometry and tested against duration is an out-of-sample test.
#
# Outputs
#   output/sonority_peripherality.csv    per-vowel distance, height, tier
#   output/sonority_delacy_test.csv      does the measurement recover the tiers?
# ================================================================

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(data.table)

OUT <- PATHS$output_dir
V8 <- c("a", "e", "i", "u", "y", "ø", "ɵ", "ʉ")

# de Lacy's two dimensions, as they apply to this inventory
DELACY <- data.table(
  vowel      = V8,
  height     = c("low", "mid", "high", "high", "high", "mid", "mid", "high"),
  periph     = c("peripheral", "peripheral", "peripheral", "peripheral",
                 "peripheral", "central", "central", "central"),
  son_tier   = c(1L, 2L, 3L, 3L, 3L, 4L, 4L, 5L)
)

# WHICH TOKENS COUNT AS RULE-NEUTRAL — REPORTED BOTH WAYS
# -------------------------------------------------------
# "Rule-neutral unstressed" means every candidate rule calls the token
# unstressed. Which candidates belong in that intersection is not a settled
# question, and the two defensible answers pull against each other:
#
#   AB_only   the six A/B rules. These partition the inventory into full and
#             reduced; they do not refer to sonority tiers. Excluding what
#             they stress cannot bias a measurement of the tiers through the
#             tiers themselves — but the full/reduced split coincides with the
#             tier-3/tier-4 boundary, so it is not perfectly independent.
#   all_rules the six A/B rules plus SON_F/SON_A/SON_B. Stricter, and the only
#             set that is unstressed under EVERY analysis on the table — but a
#             SON rule stresses the most sonorous vowel in the word, so
#             excluding its targets removes tokens in a way that is itself
#             correlated with the hierarchy being measured. That is a
#             circularity the AB_only set does not have.
#
# Both are computed below. The peripherality result is the same under either;
# the height result is not, and the difference is reported rather than
# resolved. Until 2026-09-29 only AB_only was computed, and it was not
# labelled as a choice.
rule_sets <- list(
  AB_only   = c("A6", "A5", "A4", "B6", "B5", "B4"),
  all_rules = setdiff(RULE_NAMES, "SON")
)

v0 <- as.data.table(vowels)[vowel_label %in% V8]
for (rs in rule_sets) {
  stopifnot("stage 4 must supply every rule column" =
              all(paste0("stress_rule_", rs) %in% names(v0)))
}

# ── everything below is per rule-set ────────────────────────────────────
analyse_set <- function(set_name) {
  rule_cols <- paste0("stress_rule_", rule_sets[[set_name]])
  v <- copy(v0)
  v[, n_rules_stressed := rowSums(.SD == "Stressed", na.rm = TRUE),
    .SDcols = rule_cols]
  nu <- v[n_rules_stressed == 0 & !is.na(F1) & !is.na(F2)]
  nu[, spk := fifelse(corpus == "chuvash_voice", "chuvash_voice_main",
                      fifelse(is.na(speaker_id), "unknown",
                              as.character(speaker_id)))]

  # Lobanov within speaker, then per-speaker per-vowel means
  nu[, `:=`(F1z = (F1 - mean(F1)) / sd(F1),
            F2z = (F2 - mean(F2)) / sd(F2)), by = spk]
  vm <- nu[, .(n = .N, F1z = mean(F1z), F2z = mean(F2z)),
           by = .(spk, vowel_label)]
  # only speakers with all eight vowels at n >= 20, so the centroid and the
  # hull are comparable across speakers
  ok <- vm[n >= 20, .(n_vowels = .N), by = spk][n_vowels == 8L, spk]
  vm <- vm[spk %in% ok & n >= 20]

  # centroid = unweighted mean of the eight vowel means, per speaker
  cen <- vm[, .(c1 = mean(F1z), c2 = mean(F2z)), by = spk]
  vm <- merge(vm, cen, by = "spk")
  vm[, dist := sqrt((F1z - c1)^2 + (F2z - c2)^2)]
  vm[, d_f2 := abs(F2z - c2)]
  # (c) is this vowel a vertex of the speaker's own F1 x F2 vowel space?
  vm <- merge(vm, vm[, {h <- chull(F1z, F2z)
                        .(vowel_label = vowel_label,
                          on_hull = as.integer(seq_len(.N) %in% h))}, by = spk],
              by = c("spk", "vowel_label"))

  per <- vm[, .(n_speakers = .N,
                periph_dist = mean(dist), periph_sd = sd(dist),
                backness_dev = mean(d_f2),
                pct_on_hull = 100 * mean(on_hull),
                F1z = mean(F1z), F2z = mean(F2z)),
            by = .(vowel = vowel_label)]
  per <- merge(per, DELACY, by = "vowel")
  per[, rank_periph := frank(-periph_dist, ties.method = "min")]
  per[, rank_F1 := frank(-F1z, ties.method = "min")]
  per[, rule_set := set_name]
  per[, n_tokens := nu[spk %in% ok, .N]]
  per[, n_speakers_ok := length(ok)]
  setorder(per, son_tier, -periph_dist)

  cat(sprintf("\n\n##################### rule set: %s  (%s)\n", set_name,
              paste(rule_sets[[set_name]], collapse = " ")))
  cat(sprintf("speakers with all eight vowels at n>=20: %d\n", length(ok)))
  cat(sprintf("rule-neutral unstressed tokens used: %s\n",
              format(nu[spk %in% ok, .N], big.mark = ",")))
  cat("\n── measured peripherality and height, by de Lacy class ──\n")
  print(per[, .(vowel, son_tier, periph, height,
                centroid_dist = round(periph_dist, 3),
                backness_dev = round(backness_dev, 3),
                pct_on_hull = round(pct_on_hull, 1),
                F1z = round(F1z, 3), n_speakers)])

  # ── test 1: does the measurement separate peripheral from central? ────
  cat("\n── test 1: does each measure separate peripheral from central? ──\n")
  PMEAS <- c(centroid_dist = "periph_dist", backness_dev = "backness_dev",
             convex_hull = "pct_on_hull")
  t1 <- rbindlist(lapply(names(PMEAS), function(nm) {
    col <- PMEAS[[nm]]
    pd <- per[periph == "peripheral"][[col]]
    cd <- per[periph == "central"][[col]]
    rep <- vm[, {
      x <- switch(nm, centroid_dist = dist, backness_dev = d_f2,
                  convex_hull = on_hull)
      p <- x[vowel_label %in% c("a", "e", "i", "u", "y")]
      q <- x[vowel_label %in% c("ø", "ɵ", "ʉ")]
      .(clean = as.integer(min(p) > max(q)))
    }, by = spk]
    cat(sprintf(paste0("  %-14s peripheral %.3f-%.3f | central %.3f-%.3f | ",
                       "%-7s (gap %+.3f) | clean in %d/%d speakers\n"),
                nm, min(pd), max(pd), min(cd), max(cd),
                fifelse(min(pd) > max(cd), "CLEAN", "OVERLAP"),
                min(pd) - max(cd), sum(rep$clean), nrow(rep)))
    data.table(rule_set = set_name, measure = nm,
               peripheral_min = min(pd), peripheral_max = max(pd),
               central_min = min(cd), central_max = max(cd),
               gap = min(pd) - max(cd), separates = min(pd) > max(cd),
               speakers_clean = sum(rep$clean), speakers = nrow(rep))
  }))

  # ── test 2: within each class, does height order the vowels? ──────────
  cat("\n── test 2: height within class (de Lacy predicts low > mid > high) ──\n")
  for (cl in c("peripheral", "central")) {
    d <- per[periph == cl][order(-F1z)]
    cat(sprintf("  %-10s measured F1 order: %s\n", cl,
                paste(sprintf("%s(%s)", d$vowel, d$height), collapse = " > ")))
  }

  # ── test 3: reconstruct the tiers, WITHOUT A TUNED THRESHOLD ──────────
  # Two magic numbers used to live here: a hull cutoff of 35% and F1z height
  # breaks of -0.55 / +0.30. Both had been chosen against one particular
  # labelling of the data, so "recovery" was partly fitted. Neither is needed.
  #
  #   class  the peripheral/central split is taken at the LARGEST GAP in the
  #          sorted pct_on_hull values, which is data-driven.
  #   height de Lacy predicts an ORDERING within each class, not membership in
  #          three named bins, so it is tested as an ordering: Spearman rho
  #          between son_tier and the F1z rank within the measured class. No
  #          break points enter.
  ph <- sort(per$pct_on_hull)
  cut_at <- mean(ph[which.max(diff(ph)) + 0:1])
  per[, meas_class := fifelse(pct_on_hull >= cut_at, "peripheral", "central")]
  # tier reconstruction: peripheral classes come before central ones, and
  # within a class the vowels are ordered by descending F1z (lower = higher
  # vowel = less sonorous)
  per[, meas_tier := frank(
    list(fifelse(meas_class == "peripheral", 0L, 1L), -F1z),
    ties.method = "dense")]
  agree <- per[, .(rule_set = set_name, vowel, son_tier, meas_tier,
                   class_ok = as.integer(meas_class == periph))]
  rho_all <- cor(per$son_tier, per$meas_tier, method = "spearman")
  rho_in <- per[, .(rho = if (.N > 2) cor(son_tier, frank(-F1z),
                                          method = "spearman") else NA_real_),
                by = periph]
  cat(sprintf("\n── test 3: tiers reconstructed, hull split taken at %.1f%% ──\n",
              cut_at))
  print(agree[, .(vowel, son_tier, meas_tier, class_ok)])
  cat(sprintf("\nperipherality class recovered for %d of 8 vowels\n",
              sum(agree$class_ok)))
  for (i in seq_len(nrow(rho_in)))
    cat(sprintf("height ordering within %-10s Spearman rho = %+.3f\n",
                rho_in$periph[i], rho_in$rho[i]))
  # Do NOT read the exact-match count as a score. meas_tier is built from a
  # continuous F1z and so takes eight distinct values, whereas de Lacy's tiers
  # are tied (i y u are all tier 3; ø ɵ both tier 4). A tied target cannot be
  # matched exactly by an untied reconstruction, so the rank correlation is the
  # only interpretable summary.
  cat(sprintf("full tier: Spearman rho = %+.3f (exact matches %d/8, not a score — see code)\n",
              rho_all, sum(agree$son_tier == agree$meas_tier)))
  list(per = per, t1 = t1,
       agree = cbind(agree, hull_cut = cut_at, rho_tier = rho_all))
}

res <- lapply(names(rule_sets), analyse_set)
names(res) <- names(rule_sets)
fwrite(rbindlist(lapply(res, `[[`, "per")),
       file.path(OUT, "sonority_peripherality.csv"))
fwrite(rbindlist(lapply(res, `[[`, "t1")),
       file.path(OUT, "sonority_peripherality_separation.csv"))
fwrite(rbindlist(lapply(res, `[[`, "agree")),
       file.path(OUT, "sonority_delacy_test.csv"))

cat("\n\n== the two rule sets side by side ==\n")
cmp <- rbindlist(lapply(names(res), function(nm) {
  a <- res[[nm]]$agree; p <- res[[nm]]$per
  h <- res[[nm]]$t1[measure == "convex_hull"]
  data.table(rule_set = nm, tokens = p$n_tokens[1], speakers = p$n_speakers_ok[1],
             hull_gap = round(h$gap, 1), hull_clean_speakers = h$speakers_clean,
             class_ok = sum(a$class_ok), tier_exact = sum(a$son_tier == a$meas_tier),
             rho_tier = round(a$rho_tier[1], 3))
}))
print(cmp)
cat("\n✓ sonority_peripherality.R complete\n")
