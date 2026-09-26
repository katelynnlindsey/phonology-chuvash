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

ac <- read_csv(file.path(OUT_DIR, "rule_acoustic_models.csv"), show_col_types = FALSE)
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

rc <- read_csv(file.path(OUT_DIR, "rounding_contrasts.csv"), show_col_types = FALSE)
r_ao <- rc[rc$pair == "ɵ vs a" & rc$dv == "F3z", ]
if (nrow(r_ao)) add("SchwaBarFThreeZ", sprintf("%.3f", r_ao$difference[1]),
                    "F3 of the reduced back vowel minus /a/: no rounding")
vs <- read_csv(file.path(OUT_DIR, "vowel_separability.csv"), show_col_types = FALSE)
pick <- function(a, b) {
  r <- vs[(vs$v1 == a & vs$v2 == b) | (vs$v1 == b & vs$v2 == a), ]
  if (nrow(r)) sprintf("%.3f", r$balanced_accuracy[1]) else "NA"
}
add("SepYBarSchwaBar", pick("ʉ", "ɵ"), "pairwise separability, chance = 0.500")
add("SepIY",          pick("i", "y"),  "pairwise separability, chance = 0.500")

cs <- read_csv(file.path(OUT_DIR, "coda_sonority_models.csv"), show_col_types = FALSE)
gr <- function(pr, ou) {
  r <- cs[cs$prominence == pr & cs$outcome == ou, ]
  if (nrow(r)) sprintf("%.2f", r$odds_ratio[1]) else "NA"
}
add("OddsCodaLongest",       gr("duration, intrinsic removed", "coda"),
    "odds of a coda on the longest syllable, intrinsic duration removed")
add("OddsLowVowelLongest",   gr("duration, intrinsic removed", "/a/"),
    "odds of /a/ on the longest syllable, intrinsic duration removed")
add("OddsLowVowelLongestRaw", gr("raw duration", "/a/"),
    "the same before the intrinsic control")
add("OddsLowVowelLoudest",   gr("intensity, intrinsic removed", "/a/"),
    "odds of /a/ on the loudest syllable, intrinsic intensity removed")

pos <- read_csv(file.path(OUT_DIR, "positional_restrictions.csv"), show_col_types = FALSE)
pct_initial <- function(v) {
  p <- pos[pos$vowel_label == v & pos$position != "only", ]
  if (!nrow(p)) return("NA")
  fmt_pct(100 * sum(p$n[p$position == "initial"]) / sum(p$n), 1)
}
for (p in list(c("ʉ","YBar"), c("u","U"), c("y","YRound"), c("e","E"))) {
  add(paste0("PctInitial", p[2]), pct_initial(p[1]),
      "share of this vowel's polysyllabic tokens standing in syllable 1")
}

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
