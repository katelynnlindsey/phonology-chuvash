# ══════════════════════════════════════════════════════════════════════
# default_adjudication.R
#
# The A-vs-B question, with the edge effects taken out.
#
# A and B differ in exactly one configuration: a polysyllabic word all of
# whose vowels are reduced.  A stresses the leftmost reduced vowel; B leaves
# the word stressless.  So the test is whether the initial syllable of such
# a word is acoustically prominent.
#
# Why this script exists separately from stress_rule_comparison.R.  That
# script compares initial against non-initial syllables directly, and in a
# disyllable — which is most of the sample — "non-initial" *is* the final
# syllable.  final_lengthening_models.csv puts the word-final syllable of an
# utterance-final word at +69% duration, against +4% for stress.  A raw
# initial-vs-non-initial duration contrast in disyllables is therefore
# mostly a measurement of the utterance edge, and it will show the initial
# syllable as *shorter* whether or not it is stressed.  The same applies to
# f0: declination makes anything early in the utterance higher-pitched, so a
# raw f0 difference favouring the initial syllable is expected under either
# hypothesis.
#
# The fix is to estimate the initial-syllable effect with word-final
# position, utterance-final position and (for f0) position within the
# utterance in the same model.  Both the raw and the adjusted estimate are
# reported so the size of the confound is visible.
#
# Thresholds are the perceptual ones the manuscript already cites: 3 dB
# (Moore 2007), 10 ms (Hirsh 1959), 1 Hz (Gandour 1978).  A cue that does
# not reach its threshold cannot be what a listener uses to locate stress.
#
# Outputs
#   output/default_adjudication.csv        raw and adjusted estimates
#   output/default_adjudication_cells.csv  cell means behind them
# ══════════════════════════════════════════════════════════════════════

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(data.table); library(lme4); library(broom.mixed)

OUT <- PATHS$output_dir
JND <- c(intensity = 3, duration = 10, f0 = 1)

v <- as.data.table(vowels)

# Speaker term, as elsewhere: the inferred voice label for Chuvash Voice.
spkf <- file.path(OUT, "speaker_structure.csv")
if (file.exists(spkf)) {
  spk <- as.data.table(readr::read_csv(spkf, show_col_types = FALSE))[
    , .(file_name, voice_label)]
  v <- merge(v, spk, by = "file_name", all.x = TRUE)
  v[, speaker := fifelse(!is.na(voice_label), voice_label,
                         as.character(speaker_id))]
} else v[, speaker := as.character(speaker_id)]
v[is.na(speaker), speaker := paste0("unknown_", corpus)]

# Position terms.
v[, syl_final := as.integer(sidx == sN)]
v[, word_utt_final := as.integer(!is.na(wN) & !is.na(widx) & widx == wN)]
# Where in the utterance this vowel falls, for declination.
v[, utt_pos := (start - phrase_start) / pmax(phrase_end - phrase_start, 1e-6)]
v[!is.finite(utt_pos) | utt_pos < 0 | utt_pos > 1, utt_pos := NA_real_]
if (!"log_speech_rate" %in% names(v)) v[, log_speech_rate := 0]
v[is.na(log_speech_rate), log_speech_rate := 0]
v[, is_initial := as.integer(sidx == 1L)]

results <- list(); cells <- list()

for (inv in c("6", "5", "4")) {
  full_set <- VOWEL_INVENTORIES[[inv]]$full
  # All-reduced polysyllables: no vowel in the word belongs to the full set.
  d <- v[sN > 1L & !is.na(vowel_label)]
  d[, any_full := any(vowel_label %in% full_set), by = word_id]
  d <- d[any_full == FALSE]

  cells[[inv]] <- d[, .(inventory = inv, n = .N,
                        median_duration = median(duration, na.rm = TRUE),
                        mean_int = round(mean(int_midpoint, na.rm = TRUE), 2),
                        mean_f0 = round(mean(f0_mean, na.rm = TRUE), 1)),
                    by = .(is_initial, syl_final, word_utt_final)]

  for (m in c("duration", "int_midpoint", "f0_mean")) {
    cue <- if (m == "duration") "duration" else
           if (m == "int_midpoint") "intensity" else "f0"
    dd <- d[is.finite(get(m)) & !is.na(utt_pos)]
    if (nrow(dd) < 500) next

    # Raw: the contrast as stress_rule_comparison.R draws it.
    raw <- dd[, .(mean_val = mean(get(m))), by = is_initial]
    raw_diff <- raw[is_initial == 1L, mean_val] - raw[is_initial == 0L, mean_val]

    # Adjusted: same contrast with the edges in the model.
    frm <- paste0(m, " ~ is_initial + syl_final + word_utt_final + ",
                  "syl_final:word_utt_final + vowel_label + log_speech_rate",
                  if (cue == "f0") " + utt_pos" else "",
                  " + (1|speaker) + (1|file_name) + (1|word_label)")
    fit <- try(lmer(stats::as.formula(frm), data = dd, REML = FALSE,
                    control = lmerControl(calc.derivs = FALSE)), silent = TRUE)
    if (inherits(fit, "try-error")) next
    tt <- as.data.table(tidy(fit, effects = "fixed"))[term == "is_initial"]

    results[[length(results) + 1L]] <- data.table(
      inventory   = inv,
      measure     = m,
      cue         = cue,
      unit        = c(duration = "ms", intensity = "dB", f0 = "Hz")[[cue]],
      word_tokens = uniqueN(dd$word_id),
      vowel_tokens = nrow(dd),
      raw_diff    = round(raw_diff, 3),
      adj_diff    = round(tt$estimate, 3),
      adj_se      = round(tt$std.error, 4),
      adj_t       = round(tt$statistic, 2),
      jnd         = JND[[cue]],
      raw_reaches_jnd = abs(raw_diff)  >= JND[[cue]],
      adj_reaches_jnd = abs(tt$estimate) >= JND[[cue]])
  }
  cat(sprintf("inventory %s done\n", inv)); flush.console()
}

res <- rbindlist(results)
readr::write_csv(res, file.path(OUT, "default_adjudication.csv"))
readr::write_csv(rbindlist(cells),
                 file.path(OUT, "default_adjudication_cells.csv"))

cat("\n=== A vs B: is the initial syllable of an all-reduced polysyllable prominent? ===\n")
cat("(raw = initial minus non-initial; adjusted = same contrast with word-final,\n")
cat(" utterance-final and utterance position in the model)\n\n")
print(res[, .(inventory, cue, unit, word_tokens, vowel_tokens,
              raw = raw_diff, adjusted = adj_diff, t = adj_t, jnd,
              raw_hits_jnd = raw_reaches_jnd, adj_hits_jnd = adj_reaches_jnd)])

cat("\nCues reaching their JND once the edges are controlled:\n")
hit <- res[adj_reaches_jnd == TRUE]
if (!nrow(hit)) {
  cat("  none, under any inventory -> supports default B (stressless)\n")
} else {
  print(hit[, .(inventory, cue, adjusted = adj_diff, jnd)])
}

cat("\n✓ default_adjudication.R complete\n")
