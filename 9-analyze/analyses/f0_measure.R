# =============================================================================
# f0_measure.R                                                      2026-10-01
#
# THE f0 MEASURE, and the screening it needs before any stress analysis.
# Until now this project has had no f0 column in any rule comparison, so Kate's
# three-cue criterion for stress -- longer duration, higher intensity, HIGHER
# PITCH -- has only ever been tested on two of the three.
#
# MEASURE.  f0_mid = mean of f0_step10 and f0_step11, the exact analogue of the
# adopted int_midpoint (pipeline/03_build_levels.R:114, "Mean of steps 10 and
# 11").  Using the midpoint rather than the mean over the whole vowel matters
# more for f0 than for intensity: onset f0 is raised after voiceless obstruents
# and offset f0 falls in creak, so an all-steps mean mixes consonantal
# perturbation into the vowel's pitch target.
#
# NORMALISATION.  Semitones relative to each SPEAKER's own median f0_mid.
# Semitones because f0 is perceived ratio-wise, and within-speaker because the
# corpus pools ~109 speakers of very different vocal-tract scale: the medians
# here run from 128.7 Hz (Common Voice, male-labelled) to 227.1 Hz (Chuvash
# Voice, also male-labelled).  That last figure is the project's open question
# about whether the Chuvash Voice dominant speaker is male or the metadata is
# wrong.  WITHIN-SPEAKER NORMALISATION MAKES THAT QUESTION MOOT for every
# analysis downstream of here -- the speaker's own median is the reference
# whatever their sex -- and the question only has to be settled if an absolute
# f0 value is ever reported.
#
# SCREENING.  Two principled exclusions, neither of them a tuned threshold:
#   octave_outlier   |semitones from the speaker's own median| > 12, i.e. more
#                    than one octave.  A real speaking range does not exceed
#                    an octave either side of its own median; pitch trackers
#                    halve and double.
#   step_disagree    f0_step10 and f0_step11 differ by more than an octave.
#                    The two steps are adjacent samples of one vowel, so a
#                    factor-of-two disagreement is a tracking failure, not
#                    speech.  This uses only the two steps the measure uses.
#
# FRAGILITY CHECK.  A two-step measure could be noisy, so the correlation of
# f0_mid with a robust median over steps 8-13 is reported in the diagnostics.
# This is a measurement-validity check on the measure, not a second analysis;
# f0_mid stays the measure either way, for consistency with int_midpoint.
#
# Outputs
#   output/f0_measure_diagnostics.csv   coverage and exclusions per corpus
#   output/f0_measure_distributions.csv binned distributions for the figure
#   /tmp/f0v.rds                        the screened frame for steps 2-3
# =============================================================================
suppressMessages({library(data.table)})
OUT <- "output"

KEEP <- c("file_name","speaker_id","corpus","gender","word_id","word_label",
          "sidx","sN","vowel_label","vowel_height","syllable_coda",
          "f0_step8","f0_step9","f0_step10","f0_step11","f0_step12","f0_step13",
          "f0_mean","int_midpoint","log_duration",
          "widx","wN","log_corpus_freq_smoothed","word_complete","n_syl_present")
v <- readRDS("data/leveled/vowels_spoken_annotated.rds")
setDT(v)
rule_cols <- grep("^stress_rule_", names(v), value = TRUE)
v <- v[, c(KEEP, rule_cols), with = FALSE]
invisible(gc())
# utterance position, derived exactly as in _prep_prominence_frame.R
v[, is_utt_final := widx == wN][, rel_word := widx/wN]
v[, z_freq := as.numeric(scale(log_corpus_freq_smoothed))][is.na(z_freq), z_freq := 0]
n_all <- nrow(v)

# ---- measure -----------------------------------------------------------------
v[, f0_mid := rowMeans(cbind(f0_step10, f0_step11), na.rm = FALSE)]
v[, f0_rob := apply(cbind(f0_step8, f0_step9, f0_step10,
                          f0_step11, f0_step12, f0_step13), 1L, median, na.rm = TRUE)]
n_meas <- sum(!is.na(v$f0_mid))
rob_r  <- cor(v$f0_mid, v$f0_rob, use = "complete.obs")

# ---- normalisation and screening --------------------------------------------
v[!is.na(f0_mid), spk_med := median(f0_mid, na.rm = TRUE), by = speaker_id]
v[, f0_st := 12 * log2(f0_mid / spk_med)]
v[, octave_outlier := !is.na(f0_st) & abs(f0_st) > 12]
v[, step_disagree  := !is.na(f0_step10) & !is.na(f0_step11) &
                      (pmax(f0_step10, f0_step11) / pmin(f0_step10, f0_step11) > 2)]
v[, f0_ok := !is.na(f0_st) & !octave_outlier & !step_disagree]

diag <- v[, .(rows = .N,
              speakers      = uniqueN(speaker_id),
              spk_median_hz = round(median(spk_med, na.rm = TRUE), 1),
              measured      = sum(!is.na(f0_mid)),
              pct_measured  = round(100*mean(!is.na(f0_mid)), 2),
              octave_outlier = sum(octave_outlier),
              step_disagree  = sum(step_disagree),
              usable         = sum(f0_ok),
              pct_usable     = round(100*mean(f0_ok), 2),
              st_sd          = round(sd(f0_st[f0_ok]), 3)),
          by = .(corpus, gender)]
tot <- v[, .(corpus = "ALL", gender = "ALL", rows = .N,
             speakers = uniqueN(speaker_id), spk_median_hz = NA_real_,
             measured = sum(!is.na(f0_mid)),
             pct_measured = round(100*mean(!is.na(f0_mid)), 2),
             octave_outlier = sum(octave_outlier), step_disagree = sum(step_disagree),
             usable = sum(f0_ok), pct_usable = round(100*mean(f0_ok), 2),
             st_sd = round(sd(f0_st[f0_ok]), 3))]
diag <- rbind(diag, tot)
diag[, f0mid_vs_robust_r := round(rob_r, 4)]
fwrite(diag, file.path(OUT, "f0_measure_diagnostics.csv"))
cat("== f0 coverage and screening ==\n"); print(diag)
cat(sprintf("\nf0_mid vs robust median of steps 8-13: r = %.4f\n", rob_r))

# ---- distributions for the figure -------------------------------------------
hz <- v[!is.na(f0_mid), .(scale = "hz", bin = cut(f0_mid, breaks = seq(50, 450, 10),
         labels = seq(55, 445, 10)), corpus, gender)][, .(n = .N), by = .(scale, bin, corpus, gender)]
st <- v[f0_ok == TRUE, .(scale = "st", bin = cut(f0_st, breaks = seq(-12, 12, 0.5),
         labels = seq(-11.75, 11.75, 0.5)), corpus, gender)][, .(n = .N), by = .(scale, bin, corpus, gender)]
dd <- rbind(hz, st)
dd[, bin := as.numeric(as.character(bin))]
fwrite(dd[!is.na(bin)], file.path(OUT, "f0_measure_distributions.csv"))

saveRDS(v[, !c("f0_step8","f0_step9","f0_step12","f0_step13","f0_rob"), with = FALSE],
        "/tmp/f0v.rds")
cat(sprintf("\nframe saved: %s rows, %s usable on f0 (%.1f%%)\n",
            format(n_all, big.mark=","), format(sum(v$f0_ok), big.mark=","),
            100*mean(v$f0_ok)))
cat("\n✓ f0_measure.R complete\n")
