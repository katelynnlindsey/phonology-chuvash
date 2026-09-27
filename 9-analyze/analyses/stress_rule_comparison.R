# =============================================================================
# stress_rule_comparison.R                              rewritten 2026-09-25
#
# ⚠ THE Q2 SECTION OF THIS SCRIPT IS SUPERSEDED. Do not quote its
# initial-vs-non-initial contrast. It compares the initial syllable of an
# all-reduced polysyllable against the non-initial ones without controlling
# position, and in a disyllable — most of that sample — "non-initial" *is*
# the final syllable. output/final_lengthening_models.csv puts the final
# syllable of an utterance-final word at +69% duration against +4.4% for
# stress, so the raw contrast is an edge measurement: it reports duration
# −19.6 ms and f0 +12.4 Hz, both past their JNDs, where the same contrast
# with the edges in the model is +0.59 ms (t = 0.64) and −2.52 Hz.
# Use analyses/default_adjudication.R for the A-vs-B question.
#
# ⚠ A SECOND, SMALLER CAVEAT on the acoustic model ranking below. CONTROLS
# carries phrase_position and z_relpos (= widx/wN, where the WORD sits in the
# utterance) but not where the SYLLABLE sits in the word, nor the conjunction
# of the two. Since a word-final syllable in an utterance-final word runs
# +69% (output/final_lengthening_models.csv), any rule whose predictor
# correlates with word-final position absorbs some of that. It bites hardest
# on the `final` baseline, whose predictor IS "word-final syllable": `final`
# beats all six named rules on every intensity measure while carrying a
# NEGATIVE coefficient, which is declination, not prominence. The `final`
# baseline is therefore not comparable to the others here, and it cannot be
# made comparable by adding syl_final to CONTROLS — its predictor would then
# be collinear with a control. Treat the six named rules' relative ranking as
# descriptive and the `final` row as uninterpretable.
#
# Q1 inventory and the coda-attraction section are unaffected.
#
# QUESTION: which candidate stress rule do the Chuvash corpora support?
#
# THE KEY RESTRUCTURE. A rule is two independent choices (see
# config/phonology_params.R), and they are answered by DIFFERENT evidence.
# The previous version of this script scored all nine rules on every measure
# at once, which mixed the two questions and — worse — treated two
# measurements of the same thing as two lines of evidence.
#
#   Q1  WHICH INVENTORY?  6, 5 or 4 full vowels — i.e. are /ʉ/ and /y/ full?
#       Answered by DISTRIBUTIONAL evidence from the WRITTEN corpora, which
#       never touches the acoustics: minimal-word shape, positional
#       restriction, coda attraction, inventory breadth.
#
#   Q2  WHICH DEFAULT?  In a word with NO full vowel, is the leftmost reduced
#       vowel stressed (A) or is the word stressless (B)?
#       A and B are IDENTICAL everywhere else, so only all-reduced words carry
#       any information. Answered by the acoustics of those words alone.
#
# WHY THE OLD SCORING WAS CIRCULAR. `detected_sidx` is the majority vote of
# the longest, loudest and steepest-f0 syllable. The acoustic models' DVs are
# duration and intensity. A rule that predicts the longest, loudest syllable
# must explain duration and intensity — so `detected_accuracy` and the AIC
# ranks are one line of evidence measured twice, and the old reading guide
# treated their agreement as convergence. `detected_accuracy` is retained
# below as a DESCRIPTIVE column only, and is not part of the verdict.
#
# (It was worse than circular before 2026-09-25: `loudest_sidx` was computed
# from `total_intensity`, which correlates with duration at r = 0.909, so the
# "intensity" vote was very nearly a second copy of the duration vote. It now
# comes from int_midpoint.)
#
# ALSO FIXED SINCE THE PREVIOUS VERSION
#   - All six stress_rule_* and stressed_sidx_* columns now come from
#     04_annotate.R, so the ~40 lines that reconstructed the B rules from a
#     written-corpus lookup, and the validation of that reconstruction, are
#     gone.
#   - Random effects are (1|speaker_id) + (1|file_name) + (1|word_label).
#     speaker_id is now populated for 105 talkers covering 93.7% of vowels
#     (see output/methods_speakers.md). It is severely unbalanced — one talker
#     is 69% of the data — so file_name is kept alongside it.
#   - Intensity DV is int_midpoint. total_intensity and peak_intensity are
#     both defective; see output/data_dictionary.csv.
#
# OUTPUTS (9-analyze/output/)
#   rule_inventory_evidence.csv     Q1: distributional, written corpora
#   rule_default_evidence.csv       Q2: acoustics of all-reduced words
#   rule_acoustic_models.csv        all 9 rules x 2 DVs, full dataset
#   rule_detected_descriptive.csv   the bottom-up vote, descriptive only
#   master_rule_comparison.csv      the verdict table
# =============================================================================

source(here::here("9-analyze", "config", "phonology_params.R"))
source(here::here("9-analyze", "config", "paths.R"))

suppressPackageStartupMessages({
  library(tidyverse); library(lme4); library(lmerTest); library(broom.mixed)
})

OUT_DIR <- here::here("9-analyze", "output")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

RULES <- c(RULE_NAMES, "final", "initial", "weight")   # 6 named + 3 baselines
INVENTORIES <- names(VOWEL_INVENTORIES)                # "6" "5" "4"

# ---- 0. Load ----------------------------------------------------------------

zheltov <- readRDS(file.path(PATHS$leveled_dir, "zheltov_annotated.rds"))
mono    <- readRDS(file.path(PATHS$leveled_dir, "mono_annotated.rds"))
words   <- readRDS(file.path(PATHS$leveled_dir, "words_spoken_annotated.rds"))
vowels  <- readRDS(file.path(PATHS$leveled_dir, "vowels_spoken_annotated.rds"))
cat(sprintf("Loaded: %d vowels, %d word tokens, %d zheltov rows, %d mono rows\n",
            nrow(vowels), nrow(words), nrow(zheltov), nrow(mono)))

# =============================================================================
# Q1. WHICH INVENTORY?  Distributional evidence, written corpora only.
# =============================================================================
# Each test asks the same thing of each inventory: does the F/R split it draws
# line up with a distributional asymmetry that has nothing to do with stress
# measurement? A vowel the inventory calls "reduced" should behave like the
# uncontroversially reduced /ø ɵ/.

# ---- Phonotactic sanity filter on the written corpora ---------------------
# The monolingual corpus contains word types that are not Chuvash words: they
# have consonant clusters no Chuvash syllable permits, because they are
# vowel-less abbreviations or text that lost its vowels. Examples found with
# exactly one vowel, which the syllabifier therefore reads as an "open
# monosyllable": йътъмърӗ /jtmrø/, вкҫӗ /ʋkɕø/, внлчӗ /ʋnltɕø/, въҫъӗ /ʋɕø/.
#
# This matters for the minimal-word test specifically. Unfiltered, they put
# /ø/ at 28.11% open monosyllables in the monolingual corpus — the HIGHEST of
# any vowel — which contradicts both the Zheltov wordlist (0 of 91) and the
# draft's generalisation. They are artefacts, not counter-evidence.
#
# The filter: no consonant cluster of three or more segments anywhere. Chuvash
# permits no complex onsets and at most two-consonant codas, so a 3+ cluster
# is a reliable marker of a non-word here.
.max_cluster <- function(ipa) {
  segs <- tokenize_ipa(ipa)
  isv  <- segs %in% IPA_VOWELS
  if (!length(segs)) return(0L)
  r <- rle(isv)
  runs <- r$lengths[!r$values]
  if (!length(runs)) 0L else max(runs)
}

flag_plausible <- function(df) {
  types <- df %>% distinct(word_label_IPA) %>%
    mutate(max_cluster = map_int(word_label_IPA, .max_cluster),
           plausible   = max_cluster <= 2L)
  df %>% left_join(types, by = "word_label_IPA")
}

zheltov <- flag_plausible(zheltov)
mono    <- flag_plausible(mono)
cat(sprintf("\nPhonotactic filter (max consonant cluster <= 2):\n"))
for (nm in c("zheltov", "mono")) {
  d <- get(nm)
  ty <- d %>% distinct(word_label_IPA, plausible)
  cat(sprintf("  %-8s %d of %d word types kept (%.2f%% dropped)\n", nm,
              sum(ty$plausible), nrow(ty), 100 * mean(!ty$plausible)))
}

written <- bind_rows(
  zheltov %>% transmute(corpus = "zheltov", word_label, sidx, sN, corpus_freq,                        syllable_coda, vowel_label, plausible),
  mono    %>% transmute(corpus = "mono",    word_label, sidx, sN, corpus_freq,                        syllable_coda, vowel_label, plausible)
) %>% filter(plausible)

# ---- 1a. Minimal word: can this vowel stand in an OPEN monosyllable? -------
# The generalisation in the draft is that /ø ɵ ʉ/ require a coda. If /ʉ/
# patterns with /ø ɵ/ here and /y/ does not, that supports inventory 5.

# Reported BOTH type-weighted and token-weighted, because the two disagree
# sharply for the monolingual corpus and the draft's Table tab:min mixes them
# (its note says the monolingual counts are token-based and the wordlist
# counts type-based, which makes the two halves of that table
# non-comparable).
#
# The disagreement is informative rather than awkward. Type-weighted, /ø/ is
# the MOST open-monosyllable-friendly vowel in the monolingual corpus, which
# contradicts the Zheltov wordlist (0 of 90) and the draft's generalisation.
# Token-weighted, each of those rare non-words counts once rather than as a
# full lexical type. The monolingual corpus is raw running text containing
# abbreviations and vowel-stripped strings; the wordlist is a curated lexicon.
# For a claim about what a possible Chuvash WORD looks like, the wordlist is
# the appropriate evidence and the token-weighted corpus figure is a check.
min_word <- written %>%
  filter(sN == 1) %>%
  group_by(corpus, vowel_label) %>%
  summarise(
    types           = dplyr::n(),
    types_open      = sum(syllable_coda == "open", na.rm = TRUE),
    pct_open_types  = round(100 * mean(syllable_coda == "open", na.rm = TRUE), 2),
    tokens          = sum(corpus_freq, na.rm = TRUE),
    tokens_open     = sum(corpus_freq[syllable_coda == "open"], na.rm = TRUE),
    pct_open_tokens = round(100 * sum(corpus_freq[syllable_coda == "open"], na.rm = TRUE) /
                              sum(corpus_freq, na.rm = TRUE), 2),
    .groups = "drop") %>%
  arrange(corpus, pct_open_types)

# ---- 1b. Positional restriction: is this vowel confined to syllable 1? -----
# /ʉ/ is reported as restricted to the first syllable. A vowel so restricted
# is behaving like a reduced vowel, not a full one.

positional <- written %>%
  filter(sN > 1) %>%
  group_by(corpus, vowel_label) %>%
  summarise(tokens      = n(),
            initial     = sum(sidx == 1),
            pct_initial = round(100 * mean(sidx == 1), 2),
            .groups = "drop") %>%
  arrange(corpus, desc(pct_initial))

# ---- 1c. Per-inventory summary: do the R members behave alike? -------------
# For each inventory, compare its full and reduced classes on the two
# diagnostics above. A good inventory shows a wide gap.

inventory_evidence <- map_dfr(INVENTORIES, function(inv) {
  cls <- tibble(vowel_label = c(VOWEL_INVENTORIES[[inv]]$full,
                                VOWEL_INVENTORIES[[inv]]$reduced),
                class = rep(c("full", "reduced"),
                            c(length(VOWEL_INVENTORIES[[inv]]$full),
                              length(VOWEL_INVENTORIES[[inv]]$reduced))))
  mw <- min_word   %>% inner_join(cls, by = "vowel_label")
  pz <- positional %>% inner_join(cls, by = "vowel_label")
  bind_rows(
    mw %>% group_by(corpus, class) %>%
      summarise(value = round(100 * sum(types_open) / sum(types), 2),                n = sum(types), .groups = "drop") %>%
      mutate(inventory = inv, test = "pct_open_monosyllable"),
    pz %>% group_by(corpus, class) %>%
      summarise(value = round(100 * sum(initial) / sum(tokens), 2),
                n = sum(tokens), .groups = "drop") %>%
      mutate(inventory = inv, test = "pct_in_initial_syllable")
  )
}) %>%
  pivot_wider(names_from = class, values_from = c(value, n)) %>%
  mutate(gap = round(value_full - value_reduced, 2)) %>%
  select(inventory, test, corpus, value_full, value_reduced, gap,
         n_full, n_reduced) %>%
  arrange(test, corpus, inventory)

write_csv(min_word,           file.path(OUT_DIR, "rule_minimal_word.csv"))
write_csv(positional,         file.path(OUT_DIR, "rule_positional.csv"))
write_csv(inventory_evidence, file.path(OUT_DIR, "rule_inventory_evidence.csv"))

cat("\n=== Q1a. OPEN MONOSYLLABLES BY VOWEL (written corpora) ===\n")
print(as.data.frame(min_word), row.names = FALSE)
cat("\n=== Q1b. SHARE OF NON-MONOSYLLABIC TOKENS IN SYLLABLE 1 ===\n")
print(as.data.frame(positional), row.names = FALSE)
cat("\n=== Q1c. FULL-vs-REDUCED GAP UNDER EACH INVENTORY (bigger = better split) ===\n")
print(as.data.frame(inventory_evidence), row.names = FALSE)

# ---- 1d. Coda attraction, by rule, written corpora -------------------------
# Rule-level rather than inventory-level, because it needs a predicted
# stressed syllable. Independent of the acoustics.

rule_cols <- paste0("stress_rule_", RULE_NAMES)

derive_baselines <- function(df, id) {
  df %>% group_by(across(all_of(id))) %>% arrange(sidx, .by_group = TRUE) %>%
    mutate(stress_rule_final   = if_else(sidx == max(sidx), "Stressed", "Unstressed"),
           stress_rule_initial = if_else(sidx == min(sidx), "Stressed", "Unstressed"),
           .wt = if (any(syllable_coda == "closed", na.rm = TRUE))
                   max(sidx[syllable_coda == "closed"], na.rm = TRUE) else max(sidx),
           stress_rule_weight  = if_else(sidx == .wt, "Stressed", "Unstressed")) %>%
    ungroup() %>% select(-.wt)
}

# 04_annotate.R applies the six stress rules only to the SPOKEN data, so the
# written tables carry vowel_cat_* and word_cat_* but no stress_rule_* columns.
# apply_all_stress_rules() groups by word_id, so a word_id alias is supplied.
# (Worth moving into 04_annotate.R so every corpus carries the same rule
# columns; kept here for now.)
written_r <- bind_rows(
  zheltov %>% mutate(corpus = "zheltov"),
  mono    %>% mutate(corpus = "mono")
) %>%
  filter(plausible) %>%
  mutate(word_id = paste(corpus, word_label, sep = "|")) %>%
  apply_all_stress_rules() %>%
  derive_baselines("word_id")

coda_results <- map_dfr(RULES, function(r) {
  col <- paste0("stress_rule_", r)
  written_r %>%
    filter(!is.na(syllable_coda), !is.na(.data[[col]])) %>%
    group_by(corpus) %>%
    group_modify(~ {
      m <- glm(I(syllable_coda == "closed") ~ I(.x[[col]] == "Stressed") + sN,
               data = .x, family = binomial())
      s <- summary(m)$coefficients
      tibble(log_odds = s[2, "Estimate"], se = s[2, "Std. Error"],
             p_value = s[2, "Pr(>|z|)"], n = nrow(.x))
    }) %>% ungroup() %>% mutate(rule = r)
})
write_csv(coda_results, file.path(OUT_DIR, "rule_coda_attraction.csv"))
cat("\n=== Q1d. CODA ATTRACTION TO THE PREDICTED-STRESSED SYLLABLE ===\n")
cat("(positive log-odds = codas attracted to the syllable the rule stresses)\n")
print(as.data.frame(coda_results %>% arrange(corpus, desc(log_odds))), row.names = FALSE)

# =============================================================================
# Q2. WHICH DEFAULT?  Acoustics of all-reduced words ONLY.
# =============================================================================
# A and B differ only where a word has no full vowel. Under A the leftmost
# syllable is stressed; under B nothing is. So the whole question is: in
# all-reduced words, is the initial syllable acoustically prominent?
#
# Restricted to POLYSYLLABIC all-reduced words: in a monosyllable "initial vs
# non-initial" is vacuous, and monosyllables are 60% of all-reduced words.

default_evidence <- map_dfr(INVENTORIES, function(inv) {
  full_set <- VOWEL_INVENTORIES[[inv]]$full
  ar <- vowels %>%
    group_by(word_id) %>%
    filter(!any(vowel_label %in% full_set), dplyr::n() > 1) %>%
    ungroup()
  if (!nrow(ar)) return(tibble())
  ar %>%
    mutate(pos = if_else(sidx == 1, "initial", "non_initial")) %>%
    group_by(pos) %>%
    summarise(n = dplyr::n(),
              int_midpoint = mean(int_midpoint, na.rm = TRUE),
              duration     = mean(duration,     na.rm = TRUE),
              f0           = mean(f0_mean,      na.rm = TRUE), .groups = "drop") %>%
    pivot_wider(names_from = pos, values_from = c(n, int_midpoint, duration, f0)) %>%
    transmute(
      inventory        = inv,
      word_tokens      = n_distinct(ar$word_id),
      vowel_tokens     = n_initial + n_non_initial,
      d_intensity_dB   = round(int_midpoint_initial - int_midpoint_non_initial, 3),
      d_duration_ms    = round(duration_initial     - duration_non_initial, 2),
      d_f0_Hz          = round(f0_initial           - f0_non_initial, 2),
      intensity_JND_3dB = abs(d_intensity_dB) >= 3,
      duration_JND_10ms = abs(d_duration_ms)  >= 10,
      f0_JND_1Hz        = abs(d_f0_Hz)        >= 1
    )
})
write_csv(default_evidence, file.path(OUT_DIR, "rule_default_evidence.csv"))
cat("\n=== Q2. INITIAL vs NON-INITIAL IN POLYSYLLABIC ALL-REDUCED WORDS ===\n")
cat("(this is the ONLY place rules A and B differ; JND refs: 3 dB, 10 ms, 1 Hz)\n")
print(as.data.frame(default_evidence), row.names = FALSE)

# =============================================================================
# 3. ACOUSTIC MODELS, all nine rules, full dataset
# =============================================================================

vowels <- vowels %>%
  derive_baselines("word_id") %>%
  mutate(across(all_of(paste0("stress_rule_", RULES)),
                ~ .x == "Stressed", .names = "is_{.col}")) %>%
  rename_with(~ str_replace(., "^is_stress_rule_", "is_stressed_"),
              starts_with("is_stress_rule_")) %>%
  mutate(z_freq   = as.numeric(scale(log_corpus_freq_smoothed)),
         z_rate   = as.numeric(scale(log_speech_rate)),
         z_relpos = as.numeric(scale(widx / wN)))

CONTROLS <- "vowel_label + syllable_coda + phrase_position + z_relpos + z_rate + z_freq"
need <- c("vowel_label","syllable_coda","phrase_position","z_relpos","z_rate",
          "z_freq","int_midpoint","log_duration","speaker_id","file_name","word_label")
md <- vowels %>% filter(if_all(all_of(need), ~ !is.na(.x)))
cat(sprintf("\nAcoustic model rows: %d of %d | %d speakers, %d recordings, %d word types\n",
            nrow(md), nrow(vowels), n_distinct(md$speaker_id),
            n_distinct(md$file_name), n_distinct(md$word_label)))

fit_one <- function(dv, rule) {
  f <- as.formula(sprintf(
    "%s ~ is_stressed_%s + %s + (1|speaker_id) + (1|file_name) + (1|word_label)",
    dv, rule, CONTROLS))
  lmer(f, data = md, REML = FALSE)
}

grid <- expand_grid(dv = c("int_midpoint", "log_duration"), rule = RULES)
cat(sprintf("Fitting %d models...\n", nrow(grid)))
acoustic <- pmap_dfr(grid, function(dv, rule) {
  t0 <- proc.time()[["elapsed"]]
  m <- fit_one(dv, rule)
  co <- broom.mixed::tidy(m, effects = "fixed") %>%
    filter(term == paste0("is_stressed_", rule, "TRUE"))
  cat(sprintf("  %-13s %-8s beta=%8.4f AIC=%11.1f (%.0fs)\n", dv, rule,
              if (nrow(co)) co$estimate else NA, AIC(m),
              proc.time()[["elapsed"]] - t0))
  tibble(dv = dv, rule = rule,
         estimate = if (nrow(co)) co$estimate  else NA_real_,
         se       = if (nrow(co)) co$std.error else NA_real_,
         p_value  = if (nrow(co)) co$p.value   else NA_real_,
         AIC = AIC(m), n_obs = nobs(m))
}) %>%
  group_by(dv) %>%
  mutate(AIC_rank = rank(AIC), dAIC = round(AIC - min(AIC), 1)) %>%
  ungroup() %>% arrange(dv, AIC)

write_csv(acoustic, file.path(OUT_DIR, "rule_acoustic_models.csv"))
cat("\n=== 3. ACOUSTIC MODEL COMPARISON (AIC comparable WITHIN a dv only) ===\n")
print(as.data.frame(acoustic), row.names = FALSE)

# =============================================================================
# 4. BOTTOM-UP DETECTED STRESS — DESCRIPTIVE ONLY
# =============================================================================
# NOT evidence for the verdict. detected_sidx is built from duration and
# intensity, which are the acoustic models' dependent variables, so agreement
# between this and section 3 is the same measurement twice. It is reported to
# show how often the raw phonetics point anywhere consistent at all, and
# because `final` scoring well here is diagnostic of phrase-final lengthening
# rather than of stress.

f0_vote <- vowels %>% filter(!is.na(f0_slope)) %>% group_by(word_id) %>%
  slice_max(abs(f0_slope), n = 1, with_ties = FALSE) %>% ungroup() %>%
  select(word_id, f0_vote_sidx = sidx)

wd <- words %>% left_join(f0_vote, by = "word_id")
cat("\n=== 4. PAIRWISE AGREEMENT OF THE THREE BOTTOM-UP VOTES (polysyllabic) ===\n")
wp <- wd %>% filter(sN > 1)
cat(sprintf("  longest vs loudest : %.3f\n", mean(wp$longest_sidx == wp$loudest_sidx, na.rm = TRUE)))
cat(sprintf("  longest vs f0      : %.3f\n", mean(wp$longest_sidx == wp$f0_vote_sidx, na.rm = TRUE)))
cat(sprintf("  loudest vs f0      : %.3f\n", mean(wp$loudest_sidx == wp$f0_vote_sidx, na.rm = TRUE)))

maj <- function(a, b, c) pmap_int(list(a, b, c), function(x, y, z) {
  v <- c(x, y, z); v <- v[!is.na(v)]
  if (!length(v)) return(NA_integer_)
  tb <- table(v); top <- tb[tb == max(tb)]
  if (length(top) == 1) as.integer(names(top)) else NA_integer_
})
wd <- wd %>% mutate(detected_sidx = maj(longest_sidx, loudest_sidx, f0_vote_sidx))

detected <- map_dfr(RULES, function(r) {
  col <- paste0("stressed_sidx_", r)
  if (!col %in% names(wd)) {
    pr <- vowels %>% filter(.data[[paste0("is_stressed_", r)]]) %>%
      distinct(word_id, sidx) %>% rename(pred = sidx)
    d <- wd %>% select(word_id, detected_sidx) %>% left_join(pr, by = "word_id")
  } else {
    d <- wd %>% transmute(word_id, detected_sidx, pred = .data[[col]])
  }
  d %>% filter(!is.na(detected_sidx), !is.na(pred)) %>%
    summarise(rule = r, n = dplyr::n(), accuracy = round(mean(pred == detected_sidx), 4))
}) %>% arrange(desc(accuracy))
write_csv(detected, file.path(OUT_DIR, "rule_detected_descriptive.csv"))
cat("\n  rule accuracy against the majority vote (DESCRIPTIVE, not evidence):\n")
print(as.data.frame(detected), row.names = FALSE)

# =============================================================================
# 5. MASTER TABLE
# =============================================================================

master <- acoustic %>%
  select(rule, dv, estimate, se, p_value, AIC_rank, dAIC) %>%
  pivot_wider(names_from = dv, values_from = c(estimate, se, p_value, AIC_rank, dAIC)) %>%
  left_join(coda_results %>% filter(corpus == "zheltov") %>%
              select(rule, zheltov_coda_log_odds = log_odds, zheltov_coda_p = p_value),
            by = "rule") %>%
  left_join(coda_results %>% filter(corpus == "mono") %>%
              select(rule, mono_coda_log_odds = log_odds, mono_coda_p = p_value),
            by = "rule") %>%
  left_join(detected %>% select(rule, detected_accuracy_DESCRIPTIVE = accuracy),
            by = "rule") %>%
  arrange(AIC_rank_log_duration)

write_csv(master, file.path(OUT_DIR, "master_rule_comparison.csv"))
cat("\n================ MASTER RULE COMPARISON ================\n")
print(as.data.frame(master), row.names = FALSE)
cat("\nHOW TO READ THIS\n")
cat("  The inventory question (6/5/4) is settled by Q1 — minimal word,\n")
cat("  positional restriction and coda attraction in the WRITTEN corpora,\n")
cat("  which never touch the acoustics.\n")
cat("  The default question (A vs B) is settled by Q2 — the acoustics of\n")
cat("  polysyllabic all-reduced words, the only place the two differ.\n")
cat("  The AIC ranks here describe how well each rule's stress predictor\n")
cat("  explains duration and midpoint intensity across the whole dataset;\n")
cat("  they are dominated by the ~90% of words where all six named rules\n")
cat("  agree, so they discriminate weakly between them.\n")
cat("  detected_accuracy_DESCRIPTIVE is NOT independent of the AIC columns\n")
cat("  and must not be cited as corroborating them.\n")
cat("\nWrote 8 CSVs to ", OUT_DIR, "\n", sep = "")
