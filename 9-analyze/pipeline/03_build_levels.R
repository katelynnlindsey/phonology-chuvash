# pipeline/03_build_levels.R
# ================================================================
# BUILD ANALYSIS TABLES AT EACH LINGUISTIC LEVEL
#
# Inputs  (← data/cleaned/):
#   vowels_spoken_clean.rds, zheltov_clean.rds, mono_clean.rds
#
# Outputs (→ data/leveled/):
#   vowels_spoken.rds        Level 1  one row per vowel token
#   syllables_spoken.rds     Level 2  + syl_position, syllable_label
#   words_spoken.rds         Level 3  one row per word token
#   phrases_spoken.rds       Level 4  one row per utterance
#   syllables_zheltov.rds    one row per syllable
#   syllables_mono.rds       one row per syllable (+ corpus_freq)
# ================================================================

source(here::here("9-analyze", "config", "phonology_params.R"))
source(here::here("9-analyze", "config", "paths.R"))
suppressPackageStartupMessages(library(tidyverse))

cat("══════════════════════════════════════════\n")
cat("  03_build_levels.R\n")
cat("══════════════════════════════════════════\n\n")


# ════════════════════════════════════════════════════════════════
# LOAD
# ════════════════════════════════════════════════════════════════
spoken  <- readRDS(file.path(PATHS$cleaned_dir, "vowels_spoken_clean.rds"))
zheltov <- readRDS(file.path(PATHS$cleaned_dir, "zheltov_clean.rds"))
mono    <- readRDS(file.path(PATHS$cleaned_dir, "mono_clean.rds"))

cat(sprintf("Loaded  spoken  : %d rows\n",         nrow(spoken)))
cat(sprintf("Loaded  zheltov : %d word types\n",   nrow(zheltov)))
cat(sprintf("Loaded  mono    : %d word types\n\n", nrow(mono)))


# ════════════════════════════════════════════════════════════════
# SPOKEN — TRANSLITERATE + SYLLABIFY
# (a) word_label (Cyrillic) → word_label_IPA
# (b) syllabify  → word_label_IPA_syllabified  e.g. "ka.pak"
# (c) sanity check IPA sN == MFA sN
# (d) index with sidx → syllable_label
# (e) rename label → vowel_label  (MUST stay last)
# ════════════════════════════════════════════════════════════════
cat("── Spoken: transliterate + syllabify ──\n")

spoken <- spoken %>%
  mutate(
    word_label_IPA             = map_chr(word_label, transliterate_word),
    word_label_IPA_syllabified = map_chr(word_label_IPA, syllabify_ipa)
  )

sN_check <- spoken %>%
  mutate(sN_ipa = str_count(word_label_IPA_syllabified, fixed(".")) + 1L) %>%
  filter(!is.na(sN), !is.na(sN_ipa), sN != sN_ipa)

if (nrow(sN_check) > 0L) {
  cat(sprintf("  ⚠  %d row(s) where MFA sN ≠ IPA sN  →  syllable_label = NA\n",
              nrow(sN_check)))
  sN_check %>%
    select(word_label, word_label_IPA, word_label_IPA_syllabified, sN, sN_ipa) %>%
    distinct() %>% slice_head(n = 8) %>% print()
} else {
  cat("  ✓  MFA sN = IPA syllable count for all rows\n")
}

spoken <- spoken %>%
  mutate(
    syllable_label = map2_chr(
      word_label_IPA_syllabified, sidx,
      \(w, idx) {
        if (is.na(w) || is.na(idx)) return(NA_character_)
        parts <- strsplit(w, ".", fixed = TRUE)[[1L]]
        i     <- as.integer(idx)
        if (i < 1L || i > length(parts)) NA_character_ else parts[[i]]
      }
    )
  )

# Idempotent rename: safe to re-run
if ("label" %in% names(spoken) && !"vowel_label" %in% names(spoken))
  spoken <- rename(spoken, vowel_label = label)

cat(sprintf("  syllable_label : %d present  |  %d NA\n\n",
            sum(!is.na(spoken$syllable_label)),
            sum( is.na(spoken$syllable_label))))


# ════════════════════════════════════════════════════════════════
# SPOKEN — ACOUSTIC + STRUCTURAL DERIVED COLUMNS
#
# These are factual transformations of the acoustic data.
# Phonological interpretations (stress rules, vowel features,
# word categories) are reserved for 04_annotate.R.
# All blocks are guarded so the script is idempotent.
# ════════════════════════════════════════════════════════════════
cat("── Spoken: deriving structural columns ──\n")

# ── 1. Intensity aggregates ───────────────────────────────────────
#
# READ THIS BEFORE USING ANY INTENSITY COLUMN.
#
# intensity_step1..20 are NOT 20 measurements. The stage-7 extraction
# writes Praat's "undefined" as a literal 0.0, and 71% of the cells are
# 0. The pattern is symmetric about the vowel midpoint (steps 1, 2, 19,
# 20 are 0 for every vowel; steps 10 and 11 never are) because Praat's
# intensity is undefined within half an analysis-window of each edge of
# the interval. 42% of vowels have only TWO valid readings. The count of
# valid steps therefore correlates with duration at r = 0.93.
#
# Consequences, measured in analyses/intensity_measure_comparison.R:
#
#   int_midpoint     USE THIS. Mean of steps 10 and 11 -- always exactly
#                    two samples at the same relative position, defined
#                    for 100% of rows, so no duration confound by
#                    construction (r = -0.063 with duration).
#
#   total_intensity  DO NOT USE as an amplitude measure. Sum of all 20
#                    steps including the zeros, so it is dominated by how
#                    many steps were defined: r = 0.985 with the valid-
#                    step count and r = 0.909 with duration. It is a
#                    duration measure wearing a dB label, and it is the
#                    source of the "162 dB" figure in earlier drafts.
#                    Retained only so old results can be reproduced.
#
#   peak_intensity   DO NOT USE. A maximum over a VARIABLE number of
#                    samples, so it is biased upward for long vowels
#                    (the peak-minus-midpoint gap grows from 0 to 5.02 dB
#                    as valid steps go 2 -> 16). Since stressed vowels are
#                    longer, it manufactures part of any stress effect.
#
# The `intensity` column (from new-FAVE) is a separate single-point
# measurement and does not come from this series -- but FAVE takes it at
# ~13.8% of vowel duration, i.e. on the onset ramp, not the steady state.

int_cols <- intersect(paste0("intensity_step", 1:20), names(spoken))

if (length(int_cols) > 0L && !"int_midpoint" %in% names(spoken)) {
  int_mtx <- as.matrix(spoken[, int_cols])

  # Undefined-coded-as-zero must become NA before any aggregate, or the
  # zeros are averaged in as if they were 0 dB readings.
  int_mtx[int_mtx == 0] <- NA_real_

  peak <- suppressWarnings(apply(int_mtx, 1L, max, na.rm = TRUE))
  peak[is.infinite(peak)] <- NA_real_          # all-NA rows → NA, not -Inf

  mid_cols <- intersect(c("intensity_step10", "intensity_step11"), int_cols)
  stopifnot("intensity_step10/11 missing — int_midpoint cannot be built" =
              length(mid_cols) == 2L)
  mid_mtx <- int_mtx[, mid_cols, drop = FALSE]

  spoken <- spoken %>%
    mutate(
      n_valid_int_steps = rowSums(!is.na(int_mtx)),
      int_midpoint      = rowMeans(mid_mtx, na.rm = TRUE),
      # kept for reproducing older results only — see the note above
      total_intensity   = rowSums(across(all_of(int_cols)), na.rm = TRUE),
      peak_intensity    = peak
    )
  cat(sprintf("  int_midpoint (+ deprecated total/peak_intensity), %d step cols\n",
              length(int_cols)))
  cat(sprintf("  valid steps per vowel: median %d, range %d-%d; %.1f%% of vowels have only 2\n",
              median(spoken$n_valid_int_steps),
              min(spoken$n_valid_int_steps), max(spoken$n_valid_int_steps),
              100 * mean(spoken$n_valid_int_steps == 2)))
} else {
  cat(sprintf("  intensity aggregates: %s\n",
              if ("int_midpoint" %in% names(spoken))
                "already present — skipped"
              else "⚠  no intensity_step* columns found"))
}

# ── 2. F0 slope + slope type ──────────────────────────────────────
if (all(c("f0_step1", "f0_step20") %in% names(spoken)) &&
    !"slope_type" %in% names(spoken)) {
  spoken <- spoken %>%
    mutate(
      f0_slope   = as.numeric(f0_step20) - as.numeric(f0_step1),
      slope_type = case_when(
        f0_slope >  1    ~ "Rising",
        f0_slope < -1    ~ "Falling",
        !is.na(f0_slope) ~ "Stable",
        TRUE             ~ NA_character_
      ) %>% factor(levels = c("Falling", "Stable", "Rising"))
    )
  cat("  f0_slope + slope_type\n")
} else {
  cat(sprintf("  slope_type: %s\n",
              if ("slope_type" %in% names(spoken))
                "already present — skipped"
              else "⚠  f0_step1 or f0_step20 not found"))
}

# ── 3. Log duration ───────────────────────────────────────────────
spoken <- spoken %>%
  mutate(log_duration = log(pmax(duration, 1e-6)))
cat("  log_duration\n")

# ── 4. Syllable open / closed ─────────────────────────────────────
# A syllable is open  if its final segment is a vowel nucleus.
# A syllable is closed if its final segment is a consonant.
if ("syllable_label" %in% names(spoken) &&
    !"syl_open_closed" %in% names(spoken)) {
  spoken <- spoken %>%
    mutate(
      .last_seg = map_chr(syllable_label, \(syl) {
        if (is.na(syl)) return(NA_character_)
        segs <- tokenize_ipa(syl)
        if (!length(segs)) NA_character_ else tail(segs, 1L)
      }),
      syl_open_closed = case_when(
        is.na(.last_seg)           ~ NA_character_,
        .last_seg %in% IPA_VOWELS  ~ "open",
        TRUE                       ~ "closed"
      ) %>% factor(levels = c("open", "closed"))
    ) %>%
    select(-.last_seg)
  cat("  syl_open_closed\n")
}

# ── 5. Vowel context within word ──────────────────────────────────
# Named `context` for 04_annotate.R backward compatibility
# (04 uses:  vowel_position = factor(context, levels = ...))
if (!"context" %in% names(spoken)) {
  spoken <- spoken %>%
    mutate(
      context = case_when(
        sN == 1    ~ "only",
        sidx == 1  ~ "initial",
        sidx == sN ~ "final",
        TRUE       ~ "internal"
      ) %>% factor(levels = c("only", "initial", "internal", "final"))
    )
  cat("  context (vowel position within word)\n")
}

# ── 6. widx / wN / phrase_position ───────────────────────────────
# String-match each word_label against its sentence transcript.
# ~287 k rows × pmap: expect 1–3 min.
if (all(c("sentence", "word_label", "word_start", "word_end") %in%
        names(spoken)) && !"widx" %in% names(spoken)) {
  
  cat("  widx / wN / phrase_position (sentence matching — may take ~2 min) …\n")
  
  sent_bounds <- spoken %>%
    group_by(file_name) %>%
    summarise(.ss = min(word_start, na.rm = TRUE),
              .se = max(word_end,   na.rm = TRUE),
              .groups = "drop")
  
  spoken <- spoken %>%
    left_join(sent_bounds, by = "file_name") %>%
    mutate(
      .wp  = (word_start - .ss) / pmax(0.001, .se - .ss),
      .cs  = sentence %>%
        str_to_lower() %>%
        str_replace_all("[\\\\][nrt]|[\n\r\t]|[—–]", " ") %>%
        str_replace_all("[^[:alnum:][:space:]-]", " ") %>%
        str_squish(),
      .cl  = word_label %>%
        str_to_lower() %>%
        str_remove_all("[^[:alnum:][:space:]-]"),
      .sw  = str_split(.cs, "\\s+"),
      wN   = map_int(.sw, length),
      widx = pmap_int(
        list(.sw, .cl, .wp),
        \(words, lbl, prop) {
          # A. exact match
          pos <- which(words == lbl)
          # B. hyphen-boundary match
          if (!length(pos))
            pos <- which(str_detect(words,
                                    paste0("(^|-)", fixed(lbl), "(-|$)")))
          # C. strip leading "n" artifact from forced aligner
          if (!length(pos) && str_starts(lbl, "n"))
            pos <- which(words == substring(lbl, 2L))
          if (!length(pos)) return(NA_integer_)
          if (length(pos) == 1L || length(words) <= 1L) return(pos[1L])
          # Resolve ties by temporal proximity
          pp  <- (pos - 1L) / (length(words) - 1L)
          pos[which.min(abs(pp - prop))]
        }
      ),
      phrase_position = case_when(
        widx == 1   ~ "initial",
        widx == wN  ~ "final",
        is.na(widx) ~ NA_character_,
        TRUE        ~ "medial"
      )
    ) %>%
    select(-.ss, -.se, -.wp, -.cs, -.cl, -.sw)
  
  cat(sprintf("    widx resolved for %.1f%% of rows\n",
              mean(!is.na(spoken$widx)) * 100))
  
} else {
  cat(sprintf("  widx: %s\n",
              if ("widx" %in% names(spoken))
                "already present — skipped"
              else "⚠  sentence/word_label/word_start/word_end not all present"))
}

# ── 7. word_id ────────────────────────────────────────────────────
# Keyed on widx so each occurrence of a word in a sentence is
# distinct (a word appearing twice in one sentence gets two IDs).
if ("widx" %in% names(spoken)) {
  spoken <- spoken %>%
    mutate(word_id = paste(file_name, widx, sN, sep = "_"))
} else {
  spoken <- spoken %>%
    mutate(word_id = paste(file_name, word_start, sN, sep = "_"))
}
cat("  word_id\n")

# ── 8. Speech rate ────────────────────────────────────────────────
dur_ok <- !is.null(PATHS$durations_mfa) && file.exists(PATHS$durations_mfa) &&
  !is.null(PATHS$durations_vox)  && file.exists(PATHS$durations_vox)

if (dur_ok && !"log_speech_rate" %in% names(spoken)) {
  utt_dur <- bind_rows(
    read_csv(PATHS$durations_mfa, show_col_types = FALSE),
    read_csv(PATHS$durations_vox, show_col_types = FALSE)
  ) %>% distinct(file_name, .keep_all = TRUE)
  
  # Count vowels per utterance from the data itself (no transcript parsing)
  utt_rate <- spoken %>%
    count(file_name, name = "n_vowels_utt") %>%
    left_join(utt_dur, by = "file_name") %>%
    mutate(
      speech_rate     = n_vowels_utt / duration_seconds,
      log_speech_rate = log(speech_rate)
    ) %>%
    select(file_name, speech_rate, log_speech_rate)
  
  spoken <- left_join(spoken, utt_rate, by = "file_name")
  cat("  speech_rate + log_speech_rate\n")
} else {
  cat(sprintf("  speech_rate: %s\n",
              if ("log_speech_rate" %in% names(spoken))
                "already present — skipped"
              else "⚠  duration files not found (check PATHS$durations_mfa/vox)"))
}

cat("\n")


# ════════════════════════════════════════════════════════════════
# ZHELTOV — STANDARDISE + SYLLABIFY + EXPAND
# ════════════════════════════════════════════════════════════════
cat("── Zheltov: syllabify + expand ──\n")

if ("word" %in% names(zheltov) && !"word_label"     %in% names(zheltov))
  zheltov <- rename(zheltov, word_label     = word)
if ("IPA"  %in% names(zheltov) && !"word_label_IPA" %in% names(zheltov))
  zheltov <- rename(zheltov, word_label_IPA = IPA)

zheltov <- zheltov %>%
  mutate(word_label_IPA_syllabified = map_chr(word_label_IPA, syllabify_ipa))

zheltov_syl <- zheltov %>%
  filter(str_detect(word_label_IPA, paste(IPA_VOWELS, collapse = "|"))) %>%
  expand_to_syllables() %>%
  add_syl_position()

cat(sprintf("  %d word types  →  %d syllable rows  (%d vowel types)\n\n",
            nrow(zheltov), nrow(zheltov_syl),
            n_distinct(zheltov_syl$vowel_label, na.rm = TRUE)))


# ════════════════════════════════════════════════════════════════
# MONO — STANDARDISE + SYLLABIFY + EXPAND
# ════════════════════════════════════════════════════════════════
cat("── Mono: syllabify + expand ──\n")

if ("token" %in% names(mono) && !"word_label"     %in% names(mono))
  mono <- rename(mono, word_label     = token)
if ("IPA"   %in% names(mono) && !"word_label_IPA" %in% names(mono))
  mono <- rename(mono, word_label_IPA = IPA)

mono <- mono %>%
  mutate(word_label_IPA_syllabified = map_chr(word_label_IPA, syllabify_ipa))

mono_syl <- mono %>%
  filter(str_detect(word_label_IPA, paste(IPA_VOWELS, collapse = "|"))) %>%
  expand_to_syllables() %>%
  add_syl_position()

cat(sprintf("  %d word types  →  %d syllable rows  (%d vowel types)\n\n",
            nrow(mono), nrow(mono_syl),
            n_distinct(mono_syl$vowel_label, na.rm = TRUE)))


# ════════════════════════════════════════════════════════════════
# LEVEL 1 — VOWEL (spoken)
# ════════════════════════════════════════════════════════════════
saveRDS(spoken, file.path(PATHS$leveled_dir, "vowels_spoken.rds"))
cat(sprintf("Level 1  vowels    : %d rows saved\n", nrow(spoken)))


# ════════════════════════════════════════════════════════════════
# LEVEL 2 — SYLLABLE (spoken)
# ════════════════════════════════════════════════════════════════
syllables <- spoken %>% add_syl_position()
saveRDS(syllables, file.path(PATHS$leveled_dir, "syllables_spoken.rds"))
cat(sprintf("Level 2  syllables : %d rows saved\n", nrow(syllables)))


# ════════════════════════════════════════════════════════════════
# LEVEL 3 — WORD (spoken)
# Core summarise uses only guaranteed columns.
# Optional columns are added via guarded left_joins so the
# script works even if upstream steps were skipped.
# ════════════════════════════════════════════════════════════════
cat("\n── Level 3: word ──\n")

has <- \(col) col %in% names(spoken)   # convenience predicate

# ── Core (always present after 02_clean) ─────────────────────────
words <- spoken %>%
  arrange(word_id, sidx) %>%
  group_by(word_id) %>%
  summarise(
    # Identifiers
    file_name                  = first(file_name),
    corpus                     = first(corpus),
    speaker_id                 = first(speaker_id),
    word_label                 = first(word_label),
    word_label_IPA             = first(word_label_IPA),
    word_label_IPA_syllabified = first(word_label_IPA_syllabified),
    sN                         = first(sN),
    word_category              = first(word_category),
    # Duration
    total_duration    = sum(duration,     na.rm = TRUE),
    dur_per_syl       = list(setNames(duration, paste0("v", sidx))),
    dur_ratio_v1      = first(duration[sidx == 1L]) /
      sum(duration, na.rm = TRUE),
    longest_sidx      = sidx[which.max(duration)][1L],
    log_duration_mean = mean(log_duration, na.rm = TRUE),
    # Sequences
    vowel_sequence    = paste(vowel_label,    collapse = "-"),
    syllable_sequence = paste(syllable_label, collapse = "-"),
    .groups = "drop"
  )

# ── Optional: positional ─────────────────────────────────────────
opt_pos <- intersect(c("widx", "wN", "phrase_position"), names(spoken))
if (length(opt_pos) > 0L) {
  pos_tbl <- spoken %>%
    arrange(word_id, sidx) %>%
    group_by(word_id) %>%
    summarise(across(all_of(opt_pos), first), .groups = "drop")
  words <- left_join(words, pos_tbl, by = "word_id")
  cat(sprintf("  Added: %s\n", paste(opt_pos, collapse = ", ")))
} else {
  message("  ⚠  widx / wN / phrase_position not found — omitted from words table")
}

# ── Optional: slope pattern ───────────────────────────────────────
if (has("slope_type")) {
  slope_tbl <- spoken %>%
    arrange(word_id, sidx) %>%
    group_by(word_id) %>%
    summarise(
      slope_pattern = paste(as.character(slope_type), collapse = "-"),
      f0_slope_mean = mean(f0_slope, na.rm = TRUE),
      .groups = "drop"
    )
  words <- left_join(words, slope_tbl, by = "word_id")
  cat("  Added: slope_pattern, f0_slope_mean\n")
} else {
  message("  ⚠  slope_type not found — slope_pattern omitted")
}

# ── Optional: amplitude ───────────────────────────────────────────
#
# loudest_sidx is the "which syllable is loudest" vote used by the
# bottom-up detected-stress measure in analyses/. It was previously
# computed from total_intensity -- which correlates with duration at
# r = 0.909 -- so it was very nearly a second copy of longest_sidx, and
# the three-way duration/intensity/f0 agreement rate it fed was
# correspondingly inflated. It now uses int_midpoint, which is the
# actual amplitude at a fixed point in the vowel.
if (has("int_midpoint")) {
  amp_tbl <- spoken %>%
    arrange(word_id, sidx) %>%
    group_by(word_id) %>%
    summarise(
      intensity_per_syl = list(setNames(int_midpoint, paste0("v", sidx))),
      loudest_sidx      = sidx[which.max(int_midpoint)][1L],
      .groups = "drop"
    )
  words <- left_join(words, amp_tbl, by = "word_id")
  cat("  Added: intensity_per_syl (list), loudest_sidx  [from int_midpoint]\n")
} else {
  message("  ⚠  int_midpoint not found — loudest_sidx omitted")
}

# ── Optional: speech rate ─────────────────────────────────────────
if (has("log_speech_rate")) {
  rate_tbl <- spoken %>%
    group_by(word_id) %>%
    summarise(log_speech_rate = first(log_speech_rate), .groups = "drop")
  words <- left_join(words, rate_tbl, by = "word_id")
  cat("  Added: log_speech_rate\n")
}

saveRDS(words, file.path(PATHS$leveled_dir, "words_spoken.rds"))
cat(sprintf("Level 3  words     : %d rows saved\n", nrow(words)))


# ════════════════════════════════════════════════════════════════
# LEVEL 4 — PHRASE / UTTERANCE (spoken)
# ════════════════════════════════════════════════════════════════
cat("\n── Level 4: phrase ──\n")

# Use the midpoint f0 step as a summary pitch estimate
f0_mid <- intersect(c("f0_step10", "f0_step11"), names(spoken))[1]

phrases <- spoken %>%
  group_by(file_name, corpus, speaker_id) %>%
  summarise(
    sentence      = first(sentence),
    n_vowels      = n(),
    n_words       = n_distinct(word_id),
    mean_duration = mean(duration, na.rm = TRUE),
    mean_F1       = mean(F1,       na.rm = TRUE),
    mean_F2       = mean(F2,       na.rm = TRUE),
    mean_f0       = if (!is.na(f0_mid))
      mean(.data[[f0_mid]], na.rm = TRUE)
    else NA_real_,
    .groups = "drop"
  )

# Speech rate: reuse utterance-level value if already joined to spoken,
# otherwise recompute from duration files.
if (has("speech_rate")) {
  sr_tbl  <- spoken %>%
    group_by(file_name) %>%
    summarise(speech_rate_vps = first(speech_rate), .groups = "drop")
  phrases <- left_join(phrases, sr_tbl, by = "file_name")
} else if (dur_ok) {
  durations <- bind_rows(
    read_csv(PATHS$durations_mfa, show_col_types = FALSE),
    read_csv(PATHS$durations_vox, show_col_types = FALSE)
  ) %>% distinct(file_name, .keep_all = TRUE)
  phrases <- phrases %>%
    left_join(durations, by = "file_name") %>%
    mutate(speech_rate_vps = n_vowels / duration_seconds)
}

saveRDS(phrases, file.path(PATHS$leveled_dir, "phrases_spoken.rds"))
cat(sprintf("Level 4  phrases   : %d rows saved\n", nrow(phrases)))


# ════════════════════════════════════════════════════════════════
# WRITTEN CORPUS SYLLABLE TABLES
# ════════════════════════════════════════════════════════════════
saveRDS(zheltov_syl, file.path(PATHS$leveled_dir, "syllables_zheltov.rds"))
cat(sprintf("Zheltov syllables  : %d rows saved\n", nrow(zheltov_syl)))

saveRDS(mono_syl, file.path(PATHS$leveled_dir, "syllables_mono.rds"))
cat(sprintf("Mono    syllables  : %d rows saved\n", nrow(mono_syl)))


# ════════════════════════════════════════════════════════════════
# COLUMN INVENTORY CHECK
# ════════════════════════════════════════════════════════════════
cat("\n── Column inventory ──\n")

expected_04 <- c(
  "vowel_label", "word_label", "sidx", "sN", "duration", "log_duration",
  "F1", "F2", "file_name", "corpus", "speaker_id", "sentence",
  "word_label_IPA", "word_label_IPA_syllabified", "syllable_label",
  "syl_open_closed", "context",
  "f0_slope", "slope_type", "total_intensity",
  "widx", "wN", "phrase_position", "word_id", "log_speech_rate"
)

miss <- setdiff(expected_04, names(spoken))
if (!length(miss)) {
  cat("  ✓  All columns expected by 04_annotate.R present\n")
} else {
  cat(sprintf("  ⚠  Missing from vowels_spoken.rds:\n     %s\n",
              paste(miss, collapse = ", ")))
}

syl_std <- c("word_label", "word_label_IPA", "word_label_IPA_syllabified",
             "syllable_label", "vowel_label", "sidx", "sN", "syl_position")
for (nm in c("syllables_spoken", "syllables_zheltov", "syllables_mono")) {
  obj <- switch(nm, syllables_spoken  = syllables,
                syllables_zheltov = zheltov_syl,
                syllables_mono    = mono_syl)
  ms  <- setdiff(syl_std, names(obj))
  cat(sprintf("  %s  %s\n", if (!length(ms)) "✓" else "✗", nm))
  if (length(ms)) cat(sprintf("     MISSING: %s\n", paste(ms, collapse = ", ")))
}

cat("\n✓ 03_build_levels.R complete\n")