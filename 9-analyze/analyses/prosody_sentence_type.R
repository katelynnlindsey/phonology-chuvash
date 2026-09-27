# ══════════════════════════════════════════════════════════════════════
# prosody_sentence_type.R
#
# Two things that have to be separated from stress before any stress claim
# is safe:
#
#   1. Final lengthening.  A vowel late in the word, and a word late in the
#      utterance, are both longer for reasons that are not stress.  Fitting
#      stress, word-final position and utterance-final position in the same
#      model shows how much of the "stress" effect is really edge effects.
#   2. Sentence-type intonation.  If questions carry a large f0 movement,
#      any f0-based stress measure computed over a mixed corpus is partly
#      measuring sentence type.
#
# Sentence type comes from the transcript's final punctuation, via
# 7-extract/reextract/build_utterance_table.py.  Both corpora are read
# speech, so a question here is a written question read aloud, not a
# spontaneous one — the effect is real intonation but not conversational.
#
# The f0 caveat matters here more than anywhere else: the contours are read
# off a PitchTier stylised to 2 semitones, so only movements of several
# semitones are trustworthy.  Question intonation is that big; the stress
# differences reported elsewhere are not.
#
# `question_subtype` separates content questions (an interrogative word is
# present) from the rest.  The has_polar_clitic column is deliberately not
# used as a category: the Chuvash polar enclitic -и is written identically
# to the third-person possessive -и, and nothing here can tell them apart.
#
# Outputs
#   output/final_lengthening_models.csv  duration model coefficients
#   output/final_lengthening_cells.csv   cell means behind the model
#   output/sentence_type_f0.csv          normalised f0 contour by type
#   output/sentence_type_models.csv      final-syllable f0 and slope models
# ══════════════════════════════════════════════════════════════════════

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(data.table); library(lme4); library(broom.mixed)

OUT <- PATHS$output_dir
UT  <- here::here("7-extract", "reextract", "utterances_sentence_type.csv")
stopifnot(file.exists(UT))

utt <- as.data.table(readr::read_csv(UT, show_col_types = FALSE))[
  , .(file_name, sentence_type, has_wh, final_token_i, question_subtype, n_tokens)]

v <- as.data.table(vowels)
v <- merge(v, utt, by = "file_name", all.x = TRUE)

# Speaker term: Chuvash Voice has no shipped speaker id, so use the
# acoustically inferred voice label where one exists.
spkf <- file.path(OUT, "speaker_structure.csv")
if (file.exists(spkf)) {
  spk <- as.data.table(readr::read_csv(spkf, show_col_types = FALSE))[
    , .(file_name, voice_label)]
  v <- merge(v, spk, by = "file_name", all.x = TRUE)
  v[, speaker := ifelse(!is.na(voice_label), voice_label,
                        as.character(speaker_id))]
} else v[, speaker := as.character(speaker_id)]
v[, speaker := ifelse(is.na(speaker), paste0("unknown_", corpus), speaker)]

cat(sprintf("\nVowels with a sentence type: %s of %s\n",
            format(sum(!is.na(v$sentence_type)), big.mark = ","),
            format(nrow(v), big.mark = ",")))
print(v[, .N, by = sentence_type][order(-N)])

# ══ 1. Final lengthening, with stress in the same model ═══════════════

ACT <- paste0("stress_rule_", ACTIVE_RULE)
d <- v[sN > 1L & !is.na(duration) & duration > 0 & !is.na(get(ACT)) &
       !is.na(vowel_label) & !is.na(sidx) & !is.na(sN)]
d[, stressed      := as.integer(get(ACT) == "Stressed")]
d[, syl_final     := as.integer(sidx == sN)]
d[, word_utt_final := if ("wN" %in% names(d))
                        as.integer(!is.na(wN) & !is.na(widx) & widx == wN)
                      else NA_integer_]
d <- d[!is.na(word_utt_final)]
if (!"log_speech_rate" %in% names(d)) d[, log_speech_rate := 0]
d[is.na(log_speech_rate), log_speech_rate := 0]

cells <- d[, .(n = .N, median_ms = median(duration),
               mean_ms = round(mean(duration), 1)),
           by = .(stressed, syl_final, word_utt_final)][
           order(stressed, syl_final, word_utt_final)]
readr::write_csv(cells, file.path(OUT, "final_lengthening_cells.csv"))
cat("\nfinal_lengthening_cells.csv\n"); print(cells)

# vowel_label as a fixed effect absorbs intrinsic duration, so each
# coefficient is a change in duration for a vowel of the same quality.
fl <- lmer(log(duration) ~ vowel_label + stressed + syl_final +
             word_utt_final + syl_final:word_utt_final + log_speech_rate +
             (1 | speaker) + (1 | file_name) + (1 | word_label),
           data = d, REML = FALSE,
           control = lmerControl(calc.derivs = FALSE))
tf <- as.data.table(tidy(fl, effects = "fixed"))
tf[, pct_change := round(100 * (exp(estimate) - 1), 2)]
readr::write_csv(tf[, .(term, estimate, std.error, statistic, pct_change,
                        n = nrow(d))],
                 file.path(OUT, "final_lengthening_models.csv"))
cat("\nfinal_lengthening_models.csv — % change in duration\n")
print(tf[!grepl("^vowel_label", term),
         .(term, estimate = round(estimate, 4), statistic = round(statistic, 1),
           pct_change)])

# ══ 2. Question vs statement: the utterance contour ═══════════════════
# One row per utterance.  phrase_f0_step1..20 is the f0 track over the whole
# utterance at 20 equally spaced points, so it can be averaged across
# utterances of different lengths.

f0cols <- grep("^phrase_f0_step", names(v), value = TRUE)
stopifnot(length(f0cols) == 20L)

up <- unique(v[, c("file_name", "corpus", "speaker", "sentence_type",
                   "question_subtype", "final_token_i", "n_tokens",
                   f0cols), with = FALSE],
             by = "file_name")
up <- up[sentence_type %in% c("question", "statement", "exclamation")]
long <- melt(up, id.vars = c("file_name", "corpus", "speaker",
                             "sentence_type", "question_subtype",
                             "final_token_i", "n_tokens"),
             measure.vars = f0cols, variable.name = "step", value.name = "f0")
long[, step := as.integer(sub("phrase_f0_step", "", step))]
long <- long[is.finite(f0) & f0 > 50 & f0 < 600]

# Semitones relative to the speaker's own median f0: comparable across a
# 125 Hz voice and a 226 Hz one, and in the unit the stylisation is defined in.
long[, spk_med := stats::median(f0, na.rm = TRUE), by = speaker]
long[, st := 12 * log2(f0 / spk_med)]

cont <- long[, .(n = .N, utterances = uniqueN(file_name),
                 st_mean = round(mean(st), 3),
                 st_se = round(stats::sd(st) / sqrt(.N), 4),
                 hz_mean = round(mean(f0), 1)),
             by = .(corpus, sentence_type, step)][order(corpus, sentence_type,
                                                        step)]
readr::write_csv(cont, file.path(OUT, "sentence_type_f0.csv"))
cat(sprintf("\nsentence_type_f0.csv — %s utterances\n",
            format(uniqueN(long$file_name), big.mark = ",")))
print(dcast(cont[step %in% c(1, 5, 10, 15, 18, 19, 20)],
            corpus + sentence_type ~ step, value.var = "st_mean"))

# The diagnostic is the end of the utterance: statements fall, questions in
# most languages do not.  Slope over the final quarter, per utterance.
tail_slope <- long[step >= 15L, {
  co <- if (.N >= 4L) stats::coef(stats::lm(st ~ step))[2] else NA_real_
  .(slope_st_per_step = unname(co), end_st = st[which.max(step)],
    range_st = max(st) - min(st))
}, by = .(file_name, corpus, speaker, sentence_type, question_subtype,
         final_token_i)]

ts <- tail_slope[is.finite(slope_st_per_step),
  .(utterances = .N,
    slope = round(mean(slope_st_per_step), 4),
    slope_se = round(stats::sd(slope_st_per_step) / sqrt(.N), 4),
    end_st = round(mean(end_st, na.rm = TRUE), 3)),
  by = .(corpus, sentence_type)][order(corpus, sentence_type)]
cat("\nFinal-quarter f0 slope (semitones per step of 1/20 utterance)\n")
print(ts)

mods <- list()
ms <- tail_slope[is.finite(slope_st_per_step) &
                 sentence_type %in% c("question", "statement")]
if (nrow(ms) > 100 && uniqueN(ms$sentence_type) == 2L) {
  ms[, is_q := as.integer(sentence_type == "question")]
  m1 <- lmer(slope_st_per_step ~ is_q + (1 | speaker), data = ms,
             REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  mods[[1]] <- as.data.table(tidy(m1, effects = "fixed"))[
    , .(outcome = "final_quarter_slope_st", term, estimate, std.error,
        statistic, n = nrow(ms))]
  m2 <- lmer(end_st ~ is_q + (1 | speaker), data = ms, REML = FALSE,
             control = lmerControl(calc.derivs = FALSE))
  mods[[2]] <- as.data.table(tidy(m2, effects = "fixed"))[
    , .(outcome = "utterance_final_f0_st", term, estimate, std.error,
        statistic, n = nrow(ms))]
  # Content questions carry an interrogative word; the rest have to signal
  # questionhood some other way.  If intonation is doing the work, the
  # wh-less questions should show the larger f0 effect.
  #
  # `clitic_final` means the sentence's last token ends in -и/-ши, where the
  # Chuvash polar enclitic sits.  That string is also the third-person
  # possessive, so the label is not a clean morphological diagnosis.  The
  # enrichment check below is what licenses using it at all: if -и-final
  # were just possessives it would be no commoner in questions than in
  # statements.
  enr <- unique(v[sentence_type %in% c("question", "statement"),
                  .(file_name, sentence_type, final_token_i)],
                by = "file_name")[
                , .(utterances = .N, final_i = sum(final_token_i == 1L),
                    pct = round(100 * mean(final_token_i == 1L), 2)),
                by = sentence_type]
  cat("\nSentence-final -и token, by sentence type\n"); print(enr)
  readr::write_csv(enr, file.path(OUT, "sentence_type_clitic_enrichment.csv"))

  qs <- tail_slope[is.finite(slope_st_per_step) &
                   (question_subtype %in% c("content", "no_marking",
                                            "clitic_final") |
                    sentence_type == "statement")]
  qs[, group := ifelse(sentence_type == "statement",
                       ifelse(final_token_i == 1L, "statement_i_final",
                              "statement_other"),
                       paste0("question_", question_subtype))]
  sub <- qs[, .(utterances = .N,
                slope = round(mean(slope_st_per_step), 4),
                slope_se = round(stats::sd(slope_st_per_step) / sqrt(.N), 4),
                end_st = round(mean(end_st, na.rm = TRUE), 3),
                end_se = round(stats::sd(end_st, na.rm = TRUE) / sqrt(.N), 4)),
            by = group][order(-end_st)]
  cat("\nBy question subtype, with two statement controls\n"); print(sub)
  readr::write_csv(sub, file.path(OUT, "sentence_type_subtypes.csv"))
}
if (length(mods))
  readr::write_csv(rbindlist(mods, fill = TRUE),
                   file.path(OUT, "sentence_type_models.csv"))

readr::write_csv(ts, file.path(OUT, "sentence_type_tail_slope.csv"))
cat("\n✓ prosody_sentence_type.R complete\n")
