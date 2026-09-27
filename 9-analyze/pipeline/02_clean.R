# pipeline/02_clean.R
# ================================================================
# CLEANING PIPELINE
# Reads from data/loaded/  →  writes to data/cleaned/
#
# Outputs:
#   vowels_spoken_clean.rds
#   zheltov_clean.rds
#   mono_clean.rds           (includes corpus_freq per word type)
#   exclusion_log.csv        machine-readable, one row per step per corpus
#   exclusion_report.txt     human-readable narrative for methods section
# ================================================================

source(here::here("9-analyze", "config", "phonology_params.R"))
source(here::here("9-analyze", "config", "paths.R"))

suppressPackageStartupMessages({
  library(tidyverse)
  library(data.table)
})

cat("══════════════════════════════════════════\n")
cat("  02_clean.R  —  cleaning pipeline\n")
cat("══════════════════════════════════════════\n\n")


# ════════════════════════════════════════════════════════════════
# LOGGING INFRASTRUCTURE
# ════════════════════════════════════════════════════════════════

.log <- list()

snapshot <- function(step_id, step_name, df, reason) {
  entry <- df %>%
    group_by(corpus) %>%
    summarise(
      n_vowels     = n(),
      n_words      = n_distinct(word_id,   na.rm = TRUE),
      n_utterances = n_distinct(file_name, na.rm = TRUE),
      .groups      = "drop"
    ) %>%
    mutate(step_id = step_id, step_name = step_name, reason = reason)
  
  .log[[length(.log) + 1]] <<- entry
  
  totals <- entry %>%
    summarise(n_vowels = sum(n_vowels), n_words = sum(n_words),
              n_utt = sum(n_utterances))
  
  cat(sprintf("  [%s] %-38s  %d vowels  |  %d words  |  %d utts\n",
              step_id, step_name,
              totals$n_vowels, totals$n_words, totals$n_utt))
  invisible(df)
}

# ── Saves both the CSV log and a plain-text report ───────────────
save_exclusion_report <- function(csv_path, txt_path) {
  
  log_df <- bind_rows(.log) %>%
    arrange(corpus, step_id) %>%
    group_by(corpus) %>%
    mutate(
      vowels_lost     = lag(n_vowels, default = first(n_vowels)) - n_vowels,
      words_lost      = lag(n_words,  default = first(n_words))  - n_words,
      pct_vowels_kept = round(n_vowels / first(n_vowels) * 100, 1),
      pct_vowels_lost = round(vowels_lost / first(n_vowels) * 100, 1)
    ) %>%
    ungroup()
  
  fwrite(log_df, csv_path)
  
  # ── Plain-text report ─────────────────────────────────────────
  lines <- c(
    "CHUVASH PHONOLOGY — DATA CLEANING REPORT",
    sprintf("Generated : %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    sprintf("Script    : pipeline/02_clean.R"),
    "",
    "Exclusion thresholds (set in config/phonology_params.R):",
    sprintf("  Duration       : %d – %d ms",
            CLEANING$min_duration_ms, CLEANING$max_duration_ms),
    sprintf("  F1             : %d – %d Hz",
            CLEANING$min_F1_hz, CLEANING$max_F1_hz),
    sprintf("  F2             : %d – %d Hz",
            CLEANING$min_F2_hz, CLEANING$max_F2_hz),
    sprintf("  IQR multiplier : %.1f  (within vowel × stress × corpus)",
            CLEANING$iqr_multiplier),
    sprintf("  Min cell N     : %d  (cells smaller than this dropped before IQR)",
            CLEANING$min_cell_n),
    "",
    strrep("═", 65)
  )
  
  for (corp in sort(unique(log_df$corpus))) {
    
    sub <- log_df %>% filter(corpus == corp) %>% arrange(step_id)
    n_start <- sub$n_vowels[1]
    n_end   <- sub$n_vowels[nrow(sub)]
    n_lost  <- n_start - n_end
    pct_ret <- round(n_end / n_start * 100, 1)
    
    lines <- c(lines,
               "",
               sprintf("CORPUS: %s", toupper(corp)),
               sprintf("  %-6s  %-38s  %7s  %8s  %6s",
                       "Step", "Description", "N vowels", "Lost", "% kept"),
               sprintf("  %s", strrep("-", 65))
    )
    
    for (i in seq_len(nrow(sub))) {
      row    <- sub[i, ]
      lost   <- if (is.na(row$vowels_lost) || row$vowels_lost == 0) ""
      else sprintf("-%d (%.1f%%)", row$vowels_lost, row$pct_vowels_lost)
      lines <- c(lines,
                 sprintf("  %-6s  %-38s  %7d  %8s  %5.1f%%",
                         row$step_id, row$step_name,
                         row$n_vowels, lost, row$pct_vowels_kept)
      )
    }
    
    lines <- c(lines,
               sprintf("  %s", strrep("-", 65)),
               sprintf("  TOTAL EXCLUDED: %d vowels  (%.1f%% of starting N)",
                       n_lost, round(n_lost / n_start * 100, 1)),
               sprintf("  TOTAL RETAINED: %d vowels  (%d words, %d utterances)",
                       n_end,
                       sub$n_words[nrow(sub)],
                       sub$n_utterances[nrow(sub)])
    )
  }
  
  # Grand total across corpora
  grand_start <- log_df %>%
    group_by(corpus) %>%
    summarise(start = first(n_vowels), .groups = "drop") %>%
    pull(start) %>% sum()
  
  grand_end <- log_df %>%
    group_by(corpus) %>%
    summarise(end = last(n_vowels), .groups = "drop") %>%
    pull(end) %>% sum()
  
  lines <- c(lines,
             "",
             strrep("═", 65),
             sprintf("GRAND TOTAL RETAINED : %d vowels  (%.1f%% of %d raw)",
                     grand_end,
                     round(grand_end / grand_start * 100, 1),
                     grand_start),
             sprintf("GRAND TOTAL EXCLUDED : %d vowels  (%.1f%%)",
                     grand_start - grand_end,
                     round((grand_start - grand_end) / grand_start * 100, 1)),
             ""
  )
  
  writeLines(lines, txt_path)
  
  # Print to console as well
  cat("\n")
  cat(paste(lines, collapse = "\n"))
  cat("\n")
}


# ════════════════════════════════════════════════════════════════
# SPOKEN CORPUS CLEANING
# ════════════════════════════════════════════════════════════════
cat("── Spoken corpus ──\n")

d <- readRDS(file.path(PATHS$loaded_dir, "vowels_spoken_raw.rds"))
d <- d %>%
  mutate(word_id=paste(file_name,word_start,sep="_"))
snapshot("00", "raw data loaded", d,
         "all rows from 01_load_raw.R")

# ── Step 01: Target vowel labels ─────────────────────────────────
# Only the eight vowel categories in ARPABET_TO_IPA are analysed.
d <- d %>%
  filter(label %in% TARGET_VOWELS_ARPABET) %>%
  mutate(label = recode(label, !!!ARPABET_TO_IPA))

snapshot("01", "target vowels only", d,
         paste("kept ARPAbet labels:",
               paste(TARGET_VOWELS_ARPABET, collapse = " ")))

# ── Step 02: Loanwords ───────────────────────────────────
# Loanwords have different phonotactics; excluded from native-stress
# analyses. Flagged by character pattern in orthographic word form.
d <- d %>% filter(!is_loan(word_label))

snapshot("02", "Loanwords removed", d,
         "word matched LOANWORD_PATTERN filter (see phonology_params.R)")

# ── Step 03: Duration bounds ─────────────────────────────────────
# < 20 ms : below psychoacoustic distinctiveness threshold;
#            almost certainly an MFA boundary error
# > 400 ms: likely a boundary spanning a pause or silence region
d <- d %>%
  filter(
    duration >= CLEANING$min_duration_ms,
    duration <= CLEANING$max_duration_ms
  )

snapshot("03", "duration bounds", d,
         sprintf("kept %d–%d ms",
                 CLEANING$min_duration_ms, CLEANING$max_duration_ms))

# ── Step 04: Absolute formant bounds ─────────────────────────────
# Values outside these ranges cannot be produced by the adult human
# vocal tract and indicate fave-recode tracker errors.
d <- d %>%
  filter(
    is.na(F1) | between(F1, CLEANING$min_F1_hz, CLEANING$max_F1_hz),
    is.na(F2) | between(F2, CLEANING$min_F2_hz, CLEANING$max_F2_hz)
  )

snapshot("04", "absolute formant bounds", d,
         sprintf("F1 [%d–%d Hz], F2 [%d–%d Hz]",
                 CLEANING$min_F1_hz, CLEANING$max_F1_hz,
                 CLEANING$min_F2_hz, CLEANING$max_F2_hz))

# ── Step 05: IQR outliers — FLAGGED, not removed ─────────────────
#
# Changed 2026-09-27. These fences used to delete rows, and the
# deletion was not neutral:
#
#   * they were computed within vowel × CORPUS, pooling stressed and
#     unstressed tokens. Stressed vowels are longer, so they populate
#     the upper tail, and trimming a pooled distribution removed
#     stressed tokens preferentially — the filter was correlated with
#     the dependent variable.
#   * they were not computed within speaker. One speaker supplies
#     ~69% of all vowels, so the fences were effectively his and the
#     other 104 speakers were trimmed against a distribution that is
#     not theirs.
#
# Both are fixed by computing within vowel × SPEAKER and by writing a
# flag instead of dropping the row. Physically impossible values are
# already gone at step 03/04; what is left is a judgement about which
# tokens an analysis should trust, and that belongs to the analysis.
#
# `iqr_outlier_any` reproduces the old exclusion set, so the strict
# analysis remains available: filter(!iqr_outlier_any, word_complete).

.speaker_col <- if ("speaker_id" %in% names(d)) "speaker_id" else "corpus"

flag_iqr <- function(df, col) {
  if (!col %in% names(df)) {
    message("  '", col, "' not found — skipping"); return(df)
  }
  out <- paste0("iqr_outlier_", col)
  df %>%
    group_by(label, .data[[.speaker_col]]) %>%
    mutate(
      .n_cell = n(),
      .q1  = quantile(.data[[col]], 0.25, na.rm = TRUE),
      .q3  = quantile(.data[[col]], 0.75, na.rm = TRUE),
      .iqr = .q3 - .q1,
      "{out}" := !is.na(.data[[col]]) &
        .n_cell >= CLEANING$min_cell_n &
        !dplyr::between(.data[[col]],
                        .q1 - CLEANING$iqr_multiplier * .iqr,
                        .q3 + CLEANING$iqr_multiplier * .iqr)
    ) %>%
    select(!starts_with(".")) %>%
    ungroup()
}

for (col in CLEANING$iqr_cols) {
  d <- flag_iqr(d, col)
  fl <- paste0("iqr_outlier_", col)
  if (fl %in% names(d))
    cat(sprintf("    IQR %-12s  flagged %d rows (%.1f%%)\n",
                col, sum(d[[fl]]), 100 * mean(d[[fl]])))
}

.iqr_flags <- intersect(paste0("iqr_outlier_", CLEANING$iqr_cols), names(d))
d <- d %>%
  mutate(iqr_outlier_any = if (length(.iqr_flags))
           rowSums(across(all_of(.iqr_flags))) > 0 else FALSE)

cat(sprintf("    any IQR flag  : %d rows (%.1f%%)  — NOT removed\n",
            sum(d$iqr_outlier_any), 100 * mean(d$iqr_outlier_any)))

snapshot("05", "IQR outliers flagged (not removed)", d,
         sprintf("Tukey %.1f×IQR within vowel×%s for: %s — flag only",
                 CLEANING$iqr_multiplier, .speaker_col,
                 paste(CLEANING$iqr_cols, collapse = ", ")))

# ── Step 06: Word completeness — FLAGGED, not removed ────────────
#
# Changed 2026-09-27. This used to discard a whole polysyllabic word
# when any one of its syllables had been dropped earlier, which cost
# 45-47% of all vowels — by far the largest filter in the pipeline,
# and one that cascaded off the stress-correlated step above. A word
# is now marked rather than deleted.
#
# `word_complete` means every syllable of this word survived to here
# and is not an IQR outlier: word-level measures (stress placement,
# duration ratios) need that, vowel-level measures do not.
d <- d %>%
  group_by(word_id) %>%
  mutate(
    n_syl_present = n_distinct(sidx),
    word_complete = (first(sN) == 1) |
      (n_syl_present == first(sN) & !any(iqr_outlier_any))
  ) %>%
  ungroup()

cat(sprintf("    word_complete : %d rows (%.1f%%) | incomplete %d rows kept\n",
            sum(d$word_complete), 100 * mean(d$word_complete),
            sum(!d$word_complete)))

snapshot("06", "word completeness flagged (not removed)", d,
         "polysyllabic words with a missing or outlying syllable are marked, not dropped")

# ── Save ──────────────────────────────────────────────────────────
saveRDS(d, file.path(PATHS$cleaned_dir, "vowels_spoken_clean.rds"))
cat(sprintf("\n✓ Spoken clean data saved  (%d rows)\n", nrow(d)))


# ════════════════════════════════════════════════════════════════
# WRITTEN CORPUS CLEANING — Zheltov
# ════════════════════════════════════════════════════════════════
cat("\n── Zheltov written corpus ──\n")

z      <- readRDS(file.path(PATHS$loaded_dir, "zheltov_raw.rds"))
n_raw  <- nrow(z)
cat(sprintf("  Raw: %d rows | %d word types\n", n_raw, n_distinct(z$word)))

# Fold the Latin breve/cedilla homoglyphs onto Cyrillic FIRST, so that
# (a) the loan filter does not see ç as a stray Latin letter and
# (b) word_label can be joined against the other two corpora at all.
# Keep the source spelling for traceability.
z <- z %>%
  mutate(word_source = word,
         word        = normalise_orthography(word))

n_folded <- sum(z$word != z$word_source)
cat(sprintf("  Orthography: %d of %d rows (%.1f%%) contained a Latin homoglyph\n",
            n_folded, nrow(z), 100 * n_folded / nrow(z)))

z_clean <- z %>%
  filter(!is_loan(word))  %>%             # no loanwords
  mutate(
    word = word %>%
      str_to_lower() %>%                          # lowercase everything
      str_remove_all("['\\-–\\^’ ]") %>%           # remove the punctuation/symbols you listed
      str_squish()                                  # cleans up any leftover whitespace (optional, in case some symbols were meant as word separators)
)

assert_orthography(z_clean$word, "zheltov_clean$word")

z_clean <- z_clean %>%
  mutate(IPA = map_chr(word, transliterate_word))

n_removed <- n_raw - nrow(z_clean)
cat(sprintf("  Removed: %d rows (%.1f%%)\n",
            n_removed, n_removed / n_raw * 100))
cat(sprintf("  Clean  : %d rows | %d word types\n",
            nrow(z_clean), n_distinct(z_clean$word)))

saveRDS(z_clean, file.path(PATHS$cleaned_dir, "zheltov_clean.rds"))
cat("✓ Zheltov clean data saved\n")


# ════════════════════════════════════════════════════════════════
# WRITTEN CORPUS CLEANING — Monolingual corpus
# NOTE: word frequency (corpus_freq) is computed HERE, before
# distinct(), so it is available in the leveled / annotated data.
# ════════════════════════════════════════════════════════════════
cat("\n── Monolingual corpus ──\n")

mono_raw <- readRDS(file.path(PATHS$loaded_dir, "mono_raw.rds"))
cat(sprintf("  Raw: %d sentences\n", nrow(mono_raw)))

# Repair line-break hyphenation BEFORE tokenising. The character class
# below excludes both the hyphen and the soft hyphen, so without this
# step every hyphenated line break contributes two spurious word types
# — which is where the corpus's open monosyllables with reduced vowels
# come from (нӑ, тӑ, лӑ, нӗ, ҫӗ, чӗ are suffixes, not words).
n_soft <- sum(str_detect(mono_raw$chv, fixed(SOFT_HYPHEN)), na.rm = TRUE)
cat(sprintf("  Line breaks: %d sentences (%.1f%%) carry a soft hyphen\n",
            n_soft, 100 * n_soft / nrow(mono_raw)))

mono_clean <- mono_raw %>%
  mutate(chv = repair_line_breaks(chv)) %>%
  mutate(chv = normalise_orthography(str_to_lower(chv))) %>%
  mutate(token = str_extract_all(chv, "[а-яёӑӗӱӳыҫА-ЯЁҪa-z]+")) %>%
  unnest(token) %>%
  filter(nchar(token) > 0) %>%
  filter(!is_loan(token)) %>%
  mutate(
    vowels          = str_extract_all(
      token,
      paste(all_vowel_chars, collapse = "|")),
    n_vowels        = map_int(vowels, length)
  ) %>%
  filter(n_vowels > 0) %>%
  count(token, name = "corpus_freq") %>%
  mutate(log_corpus_freq = log(corpus_freq),
         corpus          = "mono") %>%
  mutate(IPA = map_chr(token, transliterate_word))

assert_orthography(mono_clean$token, "mono_clean$token")

# Flag types attested in the Zheltov wordlist. The corpus's own type
# inventory is contaminated by de-hyphenation failure, letter-spaced
# emphasis and Russian passages, none of which can be filtered
# phonotactically — the fragments are legal Chuvash syllables. The
# corpus therefore cannot carry a type-level claim about possible
# words on its own; what it CAN carry is the token frequency of types
# that are independently attested. Restrict to in_wordlist for the
# former, use the full table for the latter.
mono_clean <- mono_clean %>%
  mutate(in_wordlist = token %in% unique(z_clean$word))

cat(sprintf("  Types attested in the Zheltov wordlist: %d (%.1f%%), %.1f%% of tokens\n",
            sum(mono_clean$in_wordlist),
            100 * mean(mono_clean$in_wordlist),
            100 * sum(mono_clean$corpus_freq[mono_clean$in_wordlist]) /
              sum(mono_clean$corpus_freq)))

cat(sprintf("  Unique word types after cleaning: %d\n", nrow(mono_clean)))
cat(sprintf("  Total token occurrences counted : %d\n",
            sum(mono_clean$corpus_freq)))
cat(sprintf("  Frequency range: %d – %d (median %d)\n",
            min(mono_clean$corpus_freq),
            max(mono_clean$corpus_freq),
            median(mono_clean$corpus_freq)))

saveRDS(mono_clean, file.path(PATHS$cleaned_dir, "mono_clean.rds"))
cat("✓ Monolingual clean data saved (includes corpus_freq)\n")


# ════════════════════════════════════════════════════════════════
# SAVE EXCLUSION REPORT
# ════════════════════════════════════════════════════════════════
save_exclusion_report(
  csv_path = file.path(PATHS$cleaned_dir, "exclusion_log.csv"),
  txt_path = file.path(PATHS$cleaned_dir, "exclusion_report.txt")
)

cat(sprintf("\n✓ 02_clean.R complete\n"))
