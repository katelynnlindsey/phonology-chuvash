# ══════════════════════════════════════════════════════════════════════
# vowel_space.R
#
# Speaker-normalised vowel space: the chart, the rounding test, and the
# export the clustering and vowel-shift analyses read.
#
# Speaker term: Chuvash Voice ships no speaker identity, so `speaker_id` is
# one constant across 75% of the data. output/speaker_structure.csv assigns
# an acoustically inferred voice label per recording (see
# methods_speaker_structure.md); `speaker` below is that label for Chuvash
# Voice and the Common Voice client_id otherwise.
#
# Palatal context: Chuvash has no phonemic palatalisation on most consonants,
# but /j/ and the palatal fricatives front an adjacent vowel enough to smear
# the F2 dimension. `non_palatal` excludes vowels with j, ɕ, ʃ or tɕ on either
# side, following the request to read the inventory off non-palatal contexts.
#
# Outputs
#   output/vowel_space_means.csv    per vowel: n, normalised means, ellipse axes
#   output/rounding_models.csv      F3 and F2-F3 distance by vowel
#   output/vowels_normalised.csv    row-level export for clustering / shift
#   output/fig_vowel_chart.png      built in Python from the export
# ══════════════════════════════════════════════════════════════════════

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(lme4); library(broom.mixed)

OUT <- PATHS$output_dir
PALATAL <- c("J", "SH", "CH", "ZH", "ɕ", "ʃ", "tʃ", "tɕ", "ʒ", "j")

v <- vowels %>%
  filter(!is.na(F1), !is.na(F2), !is.na(F3), F1 > 0, F2 > 0, F3 > 0)

# ── Speaker term ──────────────────────────────────────────────────────
spk <- readr::read_csv(file.path(OUT, "speaker_structure.csv"),
                       show_col_types = FALSE) %>%
  select(file_name, voice_label)

v <- v %>%
  left_join(spk, by = "file_name") %>%
  mutate(speaker = coalesce(voice_label, as.character(speaker_id)),
         speaker = if_else(is.na(speaker), paste0("unk_", file_name), speaker))

cat(sprintf("vowels with a full formant triple: %d | speakers: %d\n",
            nrow(v), n_distinct(v$speaker)))

# ── Lobanov normalisation, within speaker ─────────────────────────────
# z-score each formant within speaker. Nearey (log-mean) is computed too, as
# the sensitivity check: if a result flips between them it is a normalisation
# artifact, not a finding.
v <- v %>%
  group_by(speaker) %>%
  mutate(
    n_speaker = n(),
    F1z = as.numeric(scale(F1)),
    F2z = as.numeric(scale(F2)),
    F3z = as.numeric(scale(F3)),
    .log_mean = mean(c(log(F1), log(F2), log(F3)), na.rm = TRUE),
    F1n = log(F1) - .log_mean,
    F2n = log(F2) - .log_mean,
    F3n = log(F3) - .log_mean
  ) %>%
  ungroup() %>%
  filter(n_speaker >= 20) %>%      # a z-score over <20 tokens is noise
  select(-.log_mean)

v <- v %>%
  mutate(non_palatal = !(pre_seg %in% PALATAL | fol_seg %in% PALATAL))

cat(sprintf("after the 20-token speaker floor: %d vowels, %d speakers | non-palatal: %d (%.1f%%)\n",
            nrow(v), n_distinct(v$speaker), sum(v$non_palatal),
            100 * mean(v$non_palatal)))

# ── Per-vowel summary, with dispersion ────────────────────────────────
vowel_means <- v %>%
  group_by(vowel_label, non_palatal) %>%
  summarise(n = n(),
            F1z_mean = mean(F1z), F2z_mean = mean(F2z), F3z_mean = mean(F3z),
            F1z_sd = sd(F1z), F2z_sd = sd(F2z), F3z_sd = sd(F3z),
            F1_hz = mean(F1), F2_hz = mean(F2), F3_hz = mean(F3),
            .groups = "drop")
readr::write_csv(vowel_means, file.path(OUT, "vowel_space_means.csv"))

# ── Rounding ──────────────────────────────────────────────────────────
# Rounding lowers F2 and F3 and narrows F2-F3. VOWEL_ROUND in the config
# asserts {y, ø, u, ɵ}. Test it rather than assume it: fit each measure by
# vowel with speaker and word random effects, and read the ordering.
vr <- v %>%
  filter(non_palatal, vowel_label %in% TARGET_VOWELS_IPA) %>%
  mutate(vowel_label = factor(vowel_label),
         f2f3 = F3z - F2z)

fit_by_vowel <- function(dv) {
  f <- as.formula(paste0(dv, " ~ 0 + vowel_label + (1|speaker) + (1|word_label)"))
  m <- lmer(f, data = vr, REML = FALSE,
            control = lmerControl(optimizer = "bobyqa"))
  broom.mixed::tidy(m, effects = "fixed") %>%
    mutate(dv = dv,
           vowel = sub("^vowel_label", "", term)) %>%
    select(dv, vowel, estimate, std.error, statistic)
}

rounding <- bind_rows(lapply(c("F2z", "F3z", "f2f3"), fit_by_vowel)) %>%
  mutate(config_says_round = vowel %in% VOWEL_ROUND)
readr::write_csv(rounding, file.path(OUT, "rounding_models.csv"))

# A global ordering on F3-F2 cannot test rounding, because that distance is
# also a function of backness: a front vowel has a high F2 whether or not it
# is rounded. Rounding is only identified WITHIN a height/backness pair, where
# the rounded member should show the lower F2 and the lower F3.
PAIRS <- list(c("y", "i"), c("ø", "e"), c("u", "ʉ"), c("ɵ", "a"))
contrast <- function(p, dv) {
  r <- rounding %>% filter(dv == !!dv, vowel %in% p)
  if (nrow(r) < 2) return(NULL)
  a <- r$estimate[r$vowel == p[1]]; b <- r$estimate[r$vowel == p[2]]
  sa <- r$std.error[r$vowel == p[1]]; sb <- r$std.error[r$vowel == p[2]]
  tibble::tibble(pair = paste(p, collapse = " vs "), dv = dv,
                 difference = a - b, se = sqrt(sa^2 + sb^2),
                 z = (a - b) / sqrt(sa^2 + sb^2))
}
round_contrasts <- bind_rows(lapply(PAIRS, function(p)
  bind_rows(lapply(c("F2z", "F3z"), function(d) contrast(p, d)))))
readr::write_csv(round_contrasts, file.path(OUT, "rounding_contrasts.csv"))
cat("\nrounding contrasts (first member minus second; rounding predicts both negative):\n")
print(round_contrasts %>% mutate(across(where(is.numeric), ~ round(.x, 3))), n = 20)

# ── Row-level export ──────────────────────────────────────────────────
readr::write_csv(
  v %>% select(file_name, corpus, speaker, word_id, word_label, word_label_IPA,
               vowel_label,
               any_of(c("vowel_class", "vowel_cat_6", "vowel_cat_5",
                        "vowel_cat_4", "vowel_height", "vowel_backness",
                        "vowel_rounding")),
               sidx, sN, any_of(c("syl_position", "syl_pos_raw")),
               syllable_coda, vowel_position,
               pre_seg, fol_seg, non_palatal,
               F1, F2, F3, F1z, F2z, F3z, F1n, F2n, F3n,
               duration, log_duration, int_midpoint,
               any_of(c("age", "gender")),
               starts_with("stress_rule_")),
  file.path(OUT, "vowels_normalised.csv"))

cat(sprintf("\nvowels_normalised.csv: %d rows\n", nrow(v)))
cat("\n✓ vowel_space.R complete\n")
