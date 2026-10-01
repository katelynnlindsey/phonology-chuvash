# =============================================================================
# make_macros.R
#
# Emits 9-analyze/output/results_macros.tex: one \newcommand per number the
# manuscript cites, computed from the current data and the saved result CSVs.
#
# WHY. Every count and coefficient in the draft was typed by hand, and they
# came from an older pipeline run: the draft reports N = 350,872 model vowels
# against 280,955 in the data, and 615,634 extracted vowels against a figure
# that changed twice during cleanup. Once the manuscript reads macros instead
# of literals, it cannot drift again.
#
# USAGE in the manuscript preamble:
#   \input{path/to/results_macros}
# then write \NvowelsAnalysed instead of 280,955.
#
# Macro names are camel-case with no digits (LaTeX forbids digits in command
# names), so inventory 6/5/4 become Six/Five/Four and rule A6 becomes ASix.
#
# Run this AFTER run_pipeline() and after the analyses that write to output/,
# i.e. last. It re-reads rather than recomputes wherever a CSV already holds
# the number, so the .tex cannot disagree with the CSVs.
# =============================================================================

source(here::here("9-analyze", "config", "phonology_params.R"))
source(here::here("9-analyze", "config", "paths.R"))
suppressPackageStartupMessages({ library(tidyverse) })

OUT_DIR <- here::here("9-analyze", "output")
MACRO_F <- file.path(OUT_DIR, "results_macros.tex")

# ---- macro accumulator -----------------------------------------------------
.macros <- list()
add <- function(name, value, note = "") {
  stopifnot("macro names must be letters only" = grepl("^[A-Za-z]+$", name))
  .macros[[name]] <<- list(value = value, note = note)
  invisible(NULL)
}
fmt_int  <- function(x) formatC(as.numeric(x), format = "d", big.mark = ",")
fmt_pct  <- function(x, d = 1) sprintf(paste0("%.", d, "f\\%%"), as.numeric(x))
fmt_num  <- function(x, d = 2) sprintf(paste0("%.", d, "f"), as.numeric(x))

# ---- 1. Corpus and dataset sizes -------------------------------------------

v <- readRDS(file.path(PATHS$leveled_dir, "vowels_spoken_annotated.rds"))
w <- readRDS(file.path(PATHS$leveled_dir, "words_spoken_annotated.rds"))
z <- readRDS(file.path(PATHS$leveled_dir, "zheltov_annotated.rds"))
m <- readRDS(file.path(PATHS$leveled_dir, "mono_annotated.rds"))

add("NvowelsAnalysed",  fmt_int(nrow(v)),                  "vowel tokens after cleaning")
add("NwordTokens",      fmt_int(nrow(w)),                  "word tokens, spoken")
add("NwordTypes",       fmt_int(n_distinct(v$word_label)), "word types, spoken")
add("Nrecordings",      fmt_int(n_distinct(v$file_name)),  "recordings")
add("NzheltovTypes",    fmt_int(n_distinct(z$word_label)), "Zheltov word types after cleaning")
add("NmonoTypes",       fmt_int(n_distinct(m$word_label)), "monolingual word types after cleaning")

by_corpus <- v %>% count(corpus)
add("NvowelsChuvashVoice",
    fmt_int(by_corpus$n[by_corpus$corpus == "chuvash_voice"]), "vowels, Chuvash Voice")
add("NvowelsCommonVoice",
    fmt_int(by_corpus$n[by_corpus$corpus == "common_voice_chuvash"]), "vowels, Common Voice")

# The extraction-stage figure, read from the exclusion log rather than retyped.
el <- read_csv(file.path(PATHS$cleaned_dir, "exclusion_log.csv"), show_col_types = FALSE)
raw_n <- el %>% filter(str_detect(reason, "all rows from 01_load_raw")) %>%
  summarise(n = sum(n_vowels)) %>% pull(n)
add("NvowelsExtracted", fmt_int(raw_n), "vowels entering cleaning (after the interval join)")
add("PctVowelsKept",    fmt_pct(100 * nrow(v) / raw_n), "share surviving cleaning")

# ---- 2. Speakers -----------------------------------------------------------

cov <- read_csv(file.path(OUT_DIR, "speaker_coverage.csv"), show_col_types = FALSE)
clips <- read_csv(file.path(OUT_DIR, "speaker_clips.csv"), show_col_types = FALSE)
add("Nspeakers",          fmt_int(nrow(clips)), "talkers with a speaker id")
add("PctVowelsWithSpeaker",
    fmt_pct(100 * sum(clips$vowels) / nrow(v)), "vowels carrying a speaker id")
add("PctVowelsTopSpeaker",
    fmt_pct(100 * max(clips$vowels) / nrow(v)), "share of all vowels from the single largest talker")
add("NspeakersHalfData",
    fmt_int(sum(cumsum(sort(clips$vowels, decreasing = TRUE)) <
                  0.9 * sum(clips$vowels)) + 1),
    "talkers needed to cover 90% of speaker-labelled vowels")
add("MedianVowelsPerSpeaker", fmt_int(median(clips$vowels)), "median vowels per talker")

# ---- 3. Acoustic models ----------------------------------------------------

# SOURCE CHANGED 2026-10-01. These macros used to read rule_acoustic_models.csv,
# which was produced before the whole-word stress fix and recomputed each rule's
# labels over SURVIVING vowel rows rather than reading the pipeline's stored
# full-word labels. full_word_rule_models.csv supersedes it: labels verified
# identical to a fresh full-word recomputation at 100.0000% for all nine
# distinct rules. Only the pooled "all words" subset under the vowel_label
# control set is used here, because that is the specification the draft reports;
# the conflict subset and the vowel_height control set live in the CSV and are
# reported separately, since the two control sets DISAGREE on the conflict
# subset for duration (rank correlation +0.083).
ac <- read_csv(file.path(OUT_DIR, "full_word_rule_models.csv"), show_col_types = FALSE) %>%
  filter(subset == "all words", controls == "vowel_label") %>%
  mutate(n_obs = n_obs, se = se)
stopifnot("full_word_rule_models.csv is missing a dv" =
            all(c("log_duration", "int_midpoint") %in% ac$dv))
best <- ac %>% group_by(dv) %>% slice_min(AIC, n = 1, with_ties = FALSE) %>% ungroup()

bi <- best %>% filter(dv == "int_midpoint")
bd <- best %>% filter(dv == "log_duration")
add("BestRuleIntensity", bi$rule, "rule with lowest AIC on midpoint intensity")
add("BestRuleDuration",  bd$rule, "rule with lowest AIC on log duration")
add("IntensityEffectBest", paste0(fmt_num(bi$estimate, 2), "~dB"),
    "stress effect on midpoint intensity, best-fitting rule")
add("IntensityEffectBestSE", fmt_num(bi$se, 3), "")
add("DurationEffectBest", fmt_pct(100 * (exp(bd$estimate) - 1)),
    "stress effect on duration, best-fitting rule, as a percentage")
add("DurationEffectBestLog", fmt_num(bd$estimate, 3), "")

# The rule the paper argues for, named explicitly so the macro follows the
# argument rather than whichever rule happens to win an AIC race.
ARGUED_RULE <- "B5"
ar_i <- ac %>% filter(dv == "int_midpoint", rule == ARGUED_RULE)
ar_d <- ac %>% filter(dv == "log_duration", rule == ARGUED_RULE)
add("ArguedRule", ARGUED_RULE, "the rule the paper argues for")
add("ArguedRuleIntensity", paste0(fmt_num(ar_i$estimate, 2), "~dB"), "")
add("ArguedRuleDuration",  fmt_pct(100 * (exp(ar_d$estimate) - 1)), "")
add("ArguedRuleDurationLog", fmt_num(ar_d$estimate, 3), "")
add("DeltaAICdurationArguedVsA",
    fmt_int(round((ac %>% filter(dv == "log_duration", rule == "A5") %>% pull(AIC)) -
                  (ac %>% filter(dv == "log_duration", rule == "B5") %>% pull(AIC)))),
    "AIC penalty for A5 over B5 on duration")
add("NmodelRows", fmt_int(max(ac$n_obs)), "rows entering the acoustic models")

# ---- 4. The A-vs-B test (all-reduced words) --------------------------------

de <- read_csv(file.path(OUT_DIR, "rule_default_evidence.csv"), show_col_types = FALSE)
d5 <- de %>% filter(inventory == 5)
add("NallReducedWords",  fmt_int(d5$word_tokens),  "polysyllabic all-reduced word tokens, inventory 5")
add("NallReducedVowels", fmt_int(d5$vowel_tokens), "their vowel tokens")
add("AllReducedDeltaIntensity", paste0(fmt_num(d5$d_intensity_dB, 2), "~dB"), "initial minus non-initial")
add("AllReducedDeltaDuration",  paste0(fmt_num(d5$d_duration_ms, 2), "~ms"),  "initial minus non-initial")
add("AllReducedDeltaFzero",     paste0(fmt_num(d5$d_f0_Hz, 2), "~Hz"),        "initial minus non-initial")

# ---- 5. Minimal word, Zheltov (the curated source) -------------------------

mw <- read_csv(file.path(OUT_DIR, "rule_minimal_word.csv"), show_col_types = FALSE) %>%
  filter(corpus == "zheltov")
gv <- function(vl, col) mw[[col]][mw$vowel_label == vl]
for (p in list(c("ø","Oslash"), c("ɵ","Obar"), c("ʉ","Ubar"), c("y","Yfront"))) {
  add(paste0("OpenMono", p[2]),      fmt_int(gv(p[1], "types_open")),     "")
  add(paste0("TotalMono", p[2]),     fmt_int(gv(p[1], "types")),          "")
  add(paste0("PctOpenMono", p[2]),   fmt_pct(gv(p[1], "pct_open_types")), "")
}

# ---- 6. Intensity-measure diagnostics --------------------------------------

di <- read_csv(file.path(OUT_DIR, "intensity_measure_diagnostics.csv"), show_col_types = FALSE)
zp <- read_csv(file.path(OUT_DIR, "intensity_step_zero_profile.csv"), show_col_types = FALSE)
add("PctIntensityStepsUndefined", fmt_pct(100 * sum(zp$n_zero) / sum(zp$n)),
    "share of the 20-step intensity cells that are Praat undefined")
add("PctVowelsTwoValidSteps",
    fmt_pct(100 * mean(v$n_valid_int_steps == 2)), "vowels with only two valid intensity readings")
add("CorrTotalIntensityDuration",
    fmt_num(di$r_with_duration[di$measure == "int_total"], 3),
    "correlation of total_intensity with duration")
add("CorrMidpointDuration",
    fmt_num(di$r_with_duration[di$measure == "int_midpoint"], 3),
    "correlation of int_midpoint with duration")

# ---- 7. Syllabification ----------------------------------------------------

sa <- read_csv(file.path(OUT_DIR, "syllabification_audit.csv"), show_col_types = FALSE)
sc <- read_csv(file.path(OUT_DIR, "syllabification_clusters.csv"), show_col_types = FALSE)
for (p in list(c("zheltov","Zheltov"), c("mono","Mono"), c("spoken","Spoken"))) {
  add(paste0("PctDiverge", p[2]),
      fmt_pct(sa$pct_diverging[sa$corpus == p[1]], 1),
      "word types parsed differently by the documented onset-maximisation rule")
  add(paste0("PctClusterOneOrTwo", p[2]),
      fmt_pct(sum(sc$pct[sc$corpus == p[1] & sc$cluster_size <= 2]), 1),
      "medial clusters of one or two consonants")
}

# ---- 8. Orthography and the minimal-word diagnosis -------------------------

mwd <- read_csv(file.path(OUT_DIR, "minimal_word_diagnosis.csv"),
                show_col_types = FALSE)
for (p in list(c("ʉ","YBar"), c("ø","Oe"), c("ɵ","SchwaBar"),
               c("y","YRound"), c("a","A"), c("e","E"))) {
  r <- mwd[mwd$vowel == p[1], ]
  if (!nrow(r)) next
  add(paste0("OpenMonoWordlist", p[2]),
      fmt_pct(r$`Wordlist (types)`, 1), "open-syllable share of monosyllables, wordlist")
  add(paste0("OpenMonoCorpus", p[2]),
      fmt_pct(r$`Corpus, attested types`, 1), "same, corpus restricted to attested types")
}

# ---- 9. Segment inventory and phonotactics ---------------------------------

gem <- read_csv(file.path(OUT_DIR, "inventory_geminates.csv"), show_col_types = FALSE)
add("NGeminateTokens", fmt_int(sum(gem$total)),
    "long-consonant tokens in the pre-recode TextGrids")
add("NGeminateTypes", fmt_int(nrow(gem)), "distinct long consonants attested")
shp <- read_csv(file.path(OUT_DIR, "phonotactics_syllable_shapes.csv"),
                show_col_types = FALSE)
for (p in list(c("zheltov","Zheltov"), c("mono","Mono"), c("spoken","Spoken"))) {
  s <- shp[shp$corpus == p[1], ]
  add(paste0("PctCVorCVC", p[2]),
      fmt_pct(100 * sum(s$n_syllables[s$shape %in% c("CV","CVC")]) / sum(s$n_syllables), 1),
      "syllables that are CV or CVC")
}

# ---- 10. Speaker structure -------------------------------------------------

ss <- read_csv(file.path(OUT_DIR, "speaker_structure.csv"), show_col_types = FALSE)
add("PctChuvashVoiceOneSpeaker",
    fmt_pct(100 * mean(ss$voice_label == "voice_main"), 1),
    "Chuvash Voice recordings assigned to the dominant voice")
add("NChuvashVoiceVoices", fmt_int(dplyr::n_distinct(ss$voice_label)),
    "acoustic voice clusters in Chuvash Voice")

# ---- 11. Vowel space, coda and sonority ------------------------------------

# Rounding. rounding_contrasts.csv was reshaped AGAIN on 2026-10-01 and is now
# one row per (pair, dv) with `difference`, `se` and `z`. The earlier shape used
# ONE anchor per harmony series, which compared mid ⟨ӗ⟩ against high /i/ and mid
# ⟨ӑ⟩ against low /a/ and so confounded rounding with height; the pairs are now
# HEIGHT-MATCHED. Three things must stay true of these macros:
#   * the /u/~/ʉ/ row is a POSITIVE CONTROL, not a result. It presupposes
#     Krueger's description of that pair, so it cannot be cited as evidence
#     that ⟨ы⟩ is unrounded or ⟨у⟩ rounded. An early draft did exactly that and
#     the sentence was withdrawn.
#   * ⟨ӑ⟩ /ɵ/ is NOT DETERMINABLE, for a structural reason: the inventory has
#     no mid back unrounded vowel to anchor it. Its positive dF3z means there
#     is no valid comparison, not that the vowel is unrounded.
#   * there is therefore NO macro asserting rounding for either back vowel.
rc <- read_csv(file.path(OUT_DIR, "rounding_contrasts.csv"), show_col_types = FALSE)
rpick <- function(pr, which = "F3z", col = "difference", dg = 3) {
  r <- rc[rc$pair == pr & rc$dv == which, ]
  if (nrow(r)) sprintf(paste0("%.", dg, "f"), r[[col]][1]) else "NA"
}
add("RoundYvsIFThreeZ",  rpick("y vs i"),
    "F3 of /y/ minus height-matched /i/ (z): front rounded")
add("RoundYvsIZ",        rpick("y vs i", col = "z", dg = 1), "")
add("RoundOeVsEFThreeZ", rpick("ø vs e"),
    "F3 of ⟨ӗ⟩ minus height-matched /e/ (z): front rounded")
add("RoundOeVsEZ",       rpick("ø vs e", col = "z", dg = 1), "")
add("RoundControlUvsYbarFThreeZ", rpick("u vs ʉ"),
    "F3 of /u/ minus /ʉ/ (z): the POSITIVE CONTROL, which passes. Not a result.")
add("RoundSchwaVsAFThreeZ", rpick("ɵ vs a"),
    "F3 of ⟨ӑ⟩ minus /a/ (z): NOT height-matched, so not determinable")

sep <- read_csv(file.path(OUT_DIR, "separability_classifier_comparison.csv"),
                show_col_types = FALSE)
spick <- function(lab, col) {
  r <- sep[sep$pair == lab, ]
  if (nrow(r)) sprintf("%.3f", r[[col]][1]) else "NA"
}
add("SepYBarSchwaBarQda",      spick("ʉ vs ɵ", "qda"),
    "pairwise separability, quadratic discriminant, chance = 0.500")
add("SepYBarSchwaBarBoosting", spick("ʉ vs ɵ", "boosting"),
    "pairwise separability, gradient boosting, same sample")
add("SepIYQda",                spick("i vs y", "qda"),
    "pairwise separability, quadratic discriminant, chance = 0.500")
add("SepIYBoosting",           spick("i vs y", "boosting"),
    "pairwise separability, gradient boosting, same sample")

# coda_sonority_models.csv was reshaped on 2026-09-27: the keys are now
# `predictor` (has_coda / is_a / is_nonhigh), `prominence` (prom_duration /
# prom_dur_adj / prom_int_midpoint / prom_int_adj / rule_*) and `sample`
# (all / strict).
cs <- read_csv(file.path(OUT_DIR, "coda_sonority_models.csv"), show_col_types = FALSE)
gr <- function(pred, prom, smp = "all") {
  r <- cs[cs$predictor == pred & cs$prominence == prom & cs$sample == smp, ]
  if (nrow(r)) sprintf("%.3f", r$odds_ratio[1]) else "NA"
}
add("OddsCodaLongest",        gr("has_coda", "prom_dur_adj"),
    "odds of a coda on the most-prominent syllable, intrinsic duration removed")
add("OddsCodaLongestStrict",  gr("has_coda", "prom_dur_adj", "strict"),
    "the same on the strict subset")
add("OddsCodaRuleBFive",      gr("has_coda", "rule_B5"),
    "odds of a coda on the syllable rule B5 stresses")
add("OddsLowVowelLongest",    gr("is_a", "prom_dur_adj"),
    "odds of /a/ on the most-prominent syllable, intrinsic duration removed")
add("OddsLowVowelLongestRaw", gr("is_a", "prom_duration"),
    "the same before the intrinsic control")
add("OddsLowVowelLoudest",    gr("is_a", "prom_int_adj"),
    "odds of /a/ on the loudest syllable, intrinsic intensity removed")
add("OddsNonHighLongest",     gr("is_nonhigh", "prom_dur_adj"),
    "odds of a non-high vowel on the most-prominent syllable, intrinsic removed")

# ---- 11b. Edges, weight and sentence type (added 2026-09-27) ---------------

fl <- read_csv(file.path(OUT_DIR, "final_lengthening_models.csv"),
               show_col_types = FALSE)
flp <- function(tm) {
  r <- fl[fl$term == tm, ]
  if (nrow(r)) r$estimate[1] else NA_real_
}
add("PctLongerStressed", fmt_pct(100 * (exp(flp("stressed")) - 1), 1),
    "duration change for a stressed vowel, vowel quality held constant")
add("PctLongerUttFinal",
    fmt_pct(100 * (exp(flp("syl_final") + flp("word_utt_final") +
                       flp("syl_final:word_utt_final")) - 1), 1),
    "duration change for the final syllable of an utterance-final word")

da <- read_csv(file.path(OUT_DIR, "default_adjudication.csv"),
               show_col_types = FALSE)
dap <- function(cue, col, inv = "5") {
  r <- da[da$cue == cue & as.character(da$inventory) == inv, ]
  if (nrow(r)) sprintf("%.2f", r[[col]][1]) else "NA"
}
# LaTeX forbids digits in command names, so f0 becomes FZero.
CUE_MACRO <- c(duration = "Duration", intensity = "Intensity", f0 = "FZero")
for (cu in c("duration", "intensity", "f0")) {
  nm <- CUE_MACRO[[cu]]
  add(paste0("AdjInitial", nm), dap(cu, "adj_diff"),
      "initial minus non-initial in all-reduced polysyllables, edges controlled")
  add(paste0("RawInitial", nm), dap(cu, "raw_diff"),
      "the same contrast without the edge controls")
}

gm <- read_csv(file.path(OUT_DIR, "gemination_models.csv"), show_col_types = FALSE)
gmk <- gm[gm$measurable, ]
add("GeminateRatioLow",  sprintf("%.2f", min(gmk$lmm_ratio)),
    "smallest long-to-singleton duration ratio across measurable places")
add("GeminateRatioHigh", sprintf("%.2f", max(gmk$lmm_ratio)),
    "largest long-to-singleton duration ratio")
add("GeminateRatioMedian", sprintf("%.2f", stats::median(gmk$lmm_ratio)),
    "median long-to-singleton duration ratio")
add("NGeminateTokens", fmt_int(sum(gmk$n_long)),
    "long-consonant tokens entering the length comparison")

gw <- read_csv(file.path(OUT_DIR, "gemination_weight_model.csv"),
               show_col_types = FALSE)
gwp <- function(cell) {
  r <- gw[gw$kind == "adjusted_cell" & gw$term == cell, ]
  if (nrow(r)) fmt_pct(100 * (exp(r$estimate[1]) - 1), 1) else "NA"
}
add("WeightLongCFullV",    gwp("Cː+full"),
    "adjusted final-rhyme duration vs short C + full vowel")
add("WeightShortCReducedV", gwp("C+reduced"), "the same")
add("WeightLongCReducedV",  gwp("Cː+reduced"), "the same")

st <- read_csv(file.path(OUT_DIR, "sentence_type_subtypes.csv"),
               show_col_types = FALSE)
stp <- function(g, col) {
  r <- st[st$group == g, ]
  if (nrow(r)) sprintf("%.2f", r[[col]][1]) else "NA"
}
add("EndFZeroCliticQuestion", stp("question_clitic_final", "end_st"),
    "end-of-utterance f0 in semitones re speaker median, clitic-marked question")
add("EndFZeroWhQuestion",     stp("question_content", "end_st"), "wh-question")
add("EndFZeroStatement",      stp("statement_other", "end_st"),  "statement")

pos <- read_csv(file.path(OUT_DIR, "positional_restrictions.csv"), show_col_types = FALSE)
# positional_restrictions.csv is now one row per vowel with a
# pct_polysyll_in_syl1 column, computed in analyses/vowel_features.py.
vcol <- names(pos)[1]
pct_initial <- function(v) {
  p <- pos[pos[[vcol]] == v, ]
  if (!nrow(p)) return("NA")
  fmt_pct(p$pct_polysyll_in_syl1[1], 1)
}
for (p in list(c("ʉ","YBar"), c("u","U"), c("y","YRound"), c("e","E"))) {
  add(paste0("PctInitial", p[2]), pct_initial(p[1]),
      "share of this vowel's polysyllabic tokens standing in syllable 1")
}

# ---- 11c. f0, within-word steps, morphology (added 2026-10-01) -------------
# Three bodies of work the draft has no macros for at all: f0 (Kate's third
# cue, previously untested), the within-word step design, and the induced
# morphology that clears the suffixation confound.

# f0: the measure, the rule ranking, and the word-edge boundary tone.
f0d <- read_csv(file.path(OUT_DIR, "f0_measure_diagnostics.csv"), show_col_types = FALSE)
f0a <- f0d %>% filter(corpus == "ALL")
add("FzeroPctUsable",  fmt_pct(f0a$pct_usable[1]),  "vowels usable on f0 after screening")
add("FzeroOctaveOutliers", fmt_int(f0a$octave_outlier[1]),
    "rows removed as octave-tracking errors (|semitones from speaker median| > 12)")

f0r <- read_csv(file.path(OUT_DIR, "f0_rule_models.csv"), show_col_types = FALSE) %>%
  filter(control == "vowel_label", identified)
f0best <- f0r %>% slice_min(AIC, n = 1, with_ties = FALSE)
add("BestRuleFzero", f0best$rule, "rule with lowest AIC on f0")
add("BestRuleFzeroHz", paste0(fmt_num(f0best$est_hz, 2), "~Hz"), "")
add("BestRuleFzeroSt", fmt_num(f0best$est_st, 3), "")
fzb5 <- f0r %>% filter(rule == "B5")
add("ArguedRuleFzeroHz", paste0(fmt_num(fzb5$est_hz, 2), "~Hz"),
    "f0 effect of the argued rule, net of nonparametric position")

f0e <- read_csv(file.path(OUT_DIR, "f0_endpoint_test.csv"), show_col_types = FALSE) %>%
  filter(control == "vowel_label")
add("FinalSyllableFzeroHz",
    paste0(fmt_num(f0e$est_hz[f0e$model == "additive"][1], 2), "~Hz"),
    "word-final syllable f0 relative to the declination trend, pooled")
add("FinalSyllableFzeroWordInternalHz",
    paste0(fmt_num(f0e$est_hz[f0e$term == "b_final" & f0e$model != "additive"][1], 2), "~Hz"),
    "same, utterance-medial words only")
add("FinalSyllableFzeroUttFinalHz",
    paste0(fmt_num(sum(f0e$est_hz[f0e$model != "additive"]), 2), "~Hz"),
    "same, utterance-final words: the SIGN REVERSES, which is a boundary tone")

# The within-word step design, vowel-stratified: the headline duration result.
svs <- read_csv(file.path(OUT_DIR, "step_vowel_stratified.csv"), show_col_types = FALSE) %>%
  filter(spec == "vowel-stratified")
spick <- function(cu, dir) svs %>% filter(cue == cu, direction == dir)
sd_in  <- spick("dur", "step into syllable")
sd_out <- spick("dur", "step out of syllable")
si_in  <- spick("int", "step into syllable")
sf_in  <- spick("f0",  "step into syllable")
add("StepUpDurationMs", paste0(fmt_num(sd_in$estimate, 2), "~ms"),
    "duration step UP into the designated syllable, same vowel / position / word length")
add("StepUpDurationT",  fmt_num(sd_in$t, 1), "")
add("StepDownDurationMs", paste0(fmt_num(sd_out$estimate, 2), "~ms"),
    "duration step out of the designated syllable")
add("StepUpIntensityDb", paste0(fmt_num(si_in$estimate, 2), "~dB"),
    "intensity step into the designated syllable: NULL")
add("StepUpIntensityT", fmt_num(si_in$t, 2), "")
add("StepUpFzeroSt", fmt_num(sf_in$estimate, 3),
    "f0 step into the designated syllable, semitones")
add("NstepStrata", fmt_int(sd_in$n_strata),
    "within-vowel strata with designation variation; the structural ceiling on this design")
add("NstepsDuration", fmt_int(sd_in$n_steps), "")

# Induced morphology, and the confound it clears.
mv <- read_csv(file.path(OUT_DIR, "morph_validation.csv"), show_col_types = FALSE)
mvb <- mv %>% slice_max(f1, n = 1, with_ties = FALSE)
add("MorphCutStems", fmt_int(mvb$min_stems), "stem-count floor at which induction F1 peaks")
add("MorphRecall", fmt_num(mvb$recall, 3), "recall against the reference suffix list")
add("MorphPrecision", fmt_num(mvb$precision, 3),
    "precision counting listed suffixes and segmentable combinations as correct")
mac <- read_csv(file.path(OUT_DIR, "morph_accepted.csv"), show_col_types = FALSE)
add("MorphNaccepted", fmt_int(nrow(mac)), "suffixes in the accepted inventory")
mst <- read_csv(file.path(OUT_DIR, "morph_stress_test.csv"), show_col_types = FALSE)
mpick <- function(lab) mst %>% filter(test == lab)
m_all  <- mpick("d_dur_prev | all words")
m_mono <- mpick("d_dur_prev | no suffix parsed")
m_int  <- mpick("d_dur_prev | interaction")
add("StepUpDurationMonomorphemicMs", paste0(fmt_num(m_mono$estimate, 2), "~ms"),
    "duration step up into the designated syllable, words with no suffix parsed")
add("StepUpDurationMonomorphemicT", fmt_num(m_mono$t, 1), "")
add("NstepsMonomorphemic", fmt_int(m_mono$n_steps), "")
add("StemSuffixInteractionMs", paste0(fmt_num(m_int$estimate, 2), "~ms"),
    "designation x suffixal-status interaction on duration: NULL")
add("StemSuffixInteractionT", fmt_num(m_int$t, 2), "")
sfx <- mpick("d_dur_prev | suffixal, not designated")
sfi <- mpick("d_int_prev | suffixal, not designated")
add("SuffixalSyllableMs", paste0(fmt_num(sfx$estimate, 2), "~ms"),
    "a suffixal syllable vs a stem syllable, same vowel and position, independent of stress")
add("SuffixalSyllableDb", paste0(fmt_num(sfi$estimate, 2), "~dB"), "")
mal <- read_csv(file.path(OUT_DIR, "morph_alignment.csv"), show_col_types = FALSE)
add("DesigIsLastStemSylPenult",
    fmt_pct(100 * mal$desig_is_last_stem_syl[mal$from_end == 1][1]),
    "how often the designated syllable is the last stem syllable, penultimate class")

# ---- 12. Write ---------------------------------------------------------------

lines <- c(
  "% results_macros.tex -- GENERATED, do not edit by hand.",
  paste0("% Written by 9-analyze/analyses/make_macros.R on ",
         format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "."),
  "% Every value is computed from data/leveled/ or read from output/*.csv.",
  "% Regenerate after any pipeline run:  source('analyses/make_macros.R')",
  "",
  sprintf("%% ACTIVE_RULE at generation time: %s", ACTIVE_RULE),
  ""
)
for (nm in names(.macros)) {
  e <- .macros[[nm]]
  lines <- c(lines, sprintf("\\newcommand{\\%s}{%s}%s", nm, e$value,
                            if (nzchar(e$note)) paste0("   % ", e$note) else ""))
}
writeLines(lines, MACRO_F, useBytes = TRUE)

cat(sprintf("Wrote %d macros to %s\n", length(.macros), MACRO_F))
cat("\n--- generated macros ---\n")
for (nm in names(.macros)) cat(sprintf("  \\%-30s %s\n", nm, .macros[[nm]]$value))
