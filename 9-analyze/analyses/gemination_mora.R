# ══════════════════════════════════════════════════════════════════════
# gemination_mora.R
#
# Three questions about weight:
#
#   1. Are Chuvash orthographic geminates phonetically long?
#   2. Does a word-final reduced vowel behave like a mora-bearing segment,
#      or like a fleeting vowel with no mora of its own?
#   3. Do word-final geminates (surface C + reduced vowel) differ from
#      singletons (C + full vowel)?
#
# Data source.  Consonant durations do not exist in data/leveled — the R
# pipeline carries vowels.  They come from
# 7-extract/reextract/phones_chuvash_voice.csv, built by
# 7-extract/reextract/build_phone_table.py from the *pre-recode* Chuvash
# Voice grids.  5-recode/chuvash_phonology.py collapses nine of the fourteen
# long consonants, so the recoded grids cannot answer question 1 at all.
# The pre-recode grids agree with the recoded ones on 100% of interval
# boundaries, so these are the same durations the rest of the study uses.
#
# Common Voice is absent by necessity: its only pre-recode grids are a
# different third-party alignment (18.9% boundary agreement).  Everything
# here is therefore one speaker reading prose, which removes between-speaker
# variance but also removes any claim to cross-speaker generality.
#
# The alternation test (question 2).  Chuvash pairs пулӑ 'fish' with пулли
# 'its fish': the stem-final reduced vowel disappears and the preceding
# consonant geminates.  A vowel that alternates this way is the classic
# candidate for a fleeting, zero-mora vowel.  Rather than hand-coding which
# vowels alternate, the script asks the monolingual corpus: for every type
# ending in ӑ/ӗ, is the corresponding geminate-plus-и form attested?  That
# partitions the final reduced vowels into an alternating and a
# non-alternating class from text alone, with no acoustic circularity, and
# the two classes are then compared acoustically.
#
# Outputs
#   output/gemination_models.csv       long vs singleton duration by place
#   output/gemination_final.csv        word-final rhyme shapes
#   output/mora_evidence.csv           alternating vs non-alternating finals
#   output/mora_alternating_types.csv  the attested пулӑ ~ пулли pairs
# ══════════════════════════════════════════════════════════════════════

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(data.table); library(lme4); library(broom.mixed)

OUT <- PATHS$output_dir
PT  <- here::here("7-extract", "reextract", "phones_chuvash_voice.csv")
stopifnot(file.exists(PT))

ph <- as.data.table(readr::read_csv(PT, show_col_types = FALSE))
ph[, word_label := normalise_orthography(word_label)]
ph[, utt_final  := as.integer(widx == n_words)]
ph[, pre_pause  := as.integer(is.na(next_phone) | next_phone == "")]
cat(sprintf("\nPhone table: %s rows, %s recordings, %s word tokens\n",
            format(nrow(ph), big.mark = ","),
            format(uniqueN(ph$file_name), big.mark = ","),
            format(nrow(unique(ph[, .(file_name, widx)])), big.mark = ",")))

# ══ 1. Are the geminates long? ════════════════════════════════════════
# Restricted to intervocalic, word-medial consonants: that is where a
# geminate can occur, and it holds the syllabic environment constant so the
# long/short contrast is not confounded with position.

g <- ph[is_vowel == 0L & intervocalic == 1L & pos_in_word == "medial" &
        duration > 0]
places <- g[long == 1L, .N, by = phone][N >= 30, phone]

# The aligner has a hard floor: 30 ms is the shortest interval anywhere in
# the 1.4 M-phone table, and 5.7% of all phones sit exactly on it.  A long
# consonant pinned to the floor was not measured, it was clipped, so
# `pct_at_floor` is reported per place and any place above ~40% is excluded
# from the length claim rather than reported as a short geminate.
FLOOR_MS <- g[, min(duration)]
cat(sprintf("Aligner duration floor: %.0f ms (%.2f%% of all phones)\n",
            FLOOR_MS, 100 * mean(ph$duration <= FLOOR_MS)))

gem <- rbindlist(lapply(places, function(p) {
  s <- g[phone == p]
  if (uniqueN(s$long) < 2L) return(NULL)
  m <- try(lmer(log(duration) ~ long + utt_final +
                  (1 | word_label) + (1 | file_name),
                data = s, REML = FALSE,
                control = lmerControl(calc.derivs = FALSE)), silent = TRUE)
  b <- if (inherits(m, "try-error")) NA_real_
       else unname(fixef(m)["long"])
  data.table(
    phone      = p,
    n_long     = s[long == 1L, .N],
    n_short    = s[long == 0L, .N],
    median_long  = s[long == 1L, median(duration)],
    median_short = s[long == 0L, median(duration)],
    ratio_median = round(s[long == 1L, median(duration)] /
                         s[long == 0L, median(duration)], 3),
    lmm_log_ratio = round(b, 4),
    lmm_ratio     = round(exp(b), 3),
    pct_long_at_floor = round(100 * s[long == 1L,
                                      mean(duration <= FLOOR_MS)], 1))
}))[order(-n_long)]
gem[, measurable := pct_long_at_floor < 40]

readr::write_csv(gem, file.path(OUT, "gemination_models.csv"))
cat("\ngemination_models.csv — intervocalic word-medial, long vs singleton\n")
print(gem)
ok <- gem[measurable == TRUE, phone]
cat(sprintf("\nPooled over the %d measurable places: %s long / %s singleton tokens; median ratio %.2f\n",
            length(ok),
            format(gem[measurable == TRUE, sum(n_long)], big.mark = ","),
            format(gem[measurable == TRUE, sum(n_short)], big.mark = ","),
            g[long == 1L & phone %in% ok, median(duration)] /
            g[long == 0L & phone %in% ok, median(duration)]))
cat(sprintf("Excluded as clipped at the floor: %s\n",
            paste(gem[measurable == FALSE,
                      sprintf("%sː (%.0f%% at floor, n=%d)", phone,
                              pct_long_at_floor, n_long)], collapse = ", ")))

# ══ 2. The alternation test ═══════════════════════════════════════════

REDUCED_CYR <- c("ӑ", "ӗ")
CONS_CYR <- strsplit("бвгджзйклмнпрстфхцчшщҫ\u04ab", "")[[1]]

types <- unique(normalise_orthography(mono$token))
types <- types[!is.na(types) & nchar(types) >= 3]
type_env <- new.env(hash = TRUE, size = length(types) * 2L)
for (t in types) assign(t, TRUE, envir = type_env)
has_type <- function(x) vapply(x, function(z) exists(z, envir = type_env,
                                                     inherits = FALSE),
                               logical(1))

cand <- data.table(word = types[substr(types, nchar(types), nchar(types)) %in%
                                REDUCED_CYR])
cand[, final_vowel := substr(word, nchar(word), nchar(word))]
cand[, stem := substr(word, 1L, nchar(word) - 1L)]
cand[, final_cons := substr(stem, nchar(stem), nchar(stem))]
cand <- cand[final_cons %in% CONS_CYR]
cand[, gem_form := paste0(stem, final_cons, "и")]
cand[, alternating := has_type(gem_form)]

freq <- as.data.table(mono)[, .(word = normalise_orthography(token),
                                corpus_freq, in_wordlist)]
freq <- freq[, .(corpus_freq = sum(corpus_freq, na.rm = TRUE),
                 in_wordlist = any(in_wordlist)), by = word]
cand <- merge(cand, freq, by = "word", all.x = TRUE)
cand <- merge(cand, freq[, .(gem_form = word, gem_freq = corpus_freq,
                             gem_in_wordlist = in_wordlist)],
              by = "gem_form", all.x = TRUE)

# The corpus carries de-hyphenated fragments, so a single occurrence of a
# string is not attestation.  Require the geminate form twice.
cand[, alternating := alternating & !is.na(gem_freq) & gem_freq >= 2L]
cat(sprintf("Alternating with gem_freq >= 2: %s; also dictionary-attested: %s\n",
            format(sum(cand$alternating), big.mark = ","),
            format(sum(cand$alternating & !is.na(cand$gem_in_wordlist) &
                       cand$gem_in_wordlist), big.mark = ",")))

cat(sprintf("\nAlternation search: %s types end in a reduced vowel after a consonant; %s (%.1f%%) have the geminate form attested\n",
            format(nrow(cand), big.mark = ","),
            format(sum(cand$alternating), big.mark = ","),
            100 * mean(cand$alternating)))
readr::write_csv(cand[alternating == TRUE][order(-corpus_freq)],
                 file.path(OUT, "mora_alternating_types.csv"))
print(cand[alternating == TRUE][order(-corpus_freq)][1:15,
      .(word, gem_form, corpus_freq, gem_freq)])

# Acoustics of the final vowel, by class.  The unit is the word-final vowel
# token in the spoken data; `alternating` is a property of the type, learned
# from text.
fin <- ph[is_vowel == 1L & pos_in_word %in% c("final") &
          phone %in% c("ɵ", "ø") & duration > 0 & word_nphone >= 3L]
fin <- merge(fin, cand[, .(word_label = word, alternating, corpus_freq)],
             by = "word_label")
fin[, log_freq := log1p(corpus_freq)]

cat(sprintf("\nFinal reduced vowels matched to a class: %s tokens, %s types (%s alternating types)\n",
            format(nrow(fin), big.mark = ","),
            format(uniqueN(fin$word_label), big.mark = ","),
            format(uniqueN(fin[alternating == TRUE]$word_label),
                   big.mark = ",")))

# The alternating class is not a random sample of consonants — it is
# dominated by л р н ҫ т, the segments that geminate.  Every model below
# therefore carries the preceding consonant as a fixed effect, so the
# `alternating` coefficient is a comparison of words with the *same* final
# consonant.  Without that control the contrast is partly a place effect.
prevc <- ph[is_vowel == 0L, .(file_name, widx, pidx_next = pidx + 1L,
                              c_phone = phone, c_long = long,
                              c_dur = duration)]
fin <- merge(fin, prevc, by.x = c("file_name", "widx", "pidx"),
             by.y = c("file_name", "widx", "pidx_next"), all.x = FALSE)
keep_c <- fin[, .N, by = c_phone][N >= 100, c_phone]
fin <- fin[c_phone %in% keep_c]
cat(sprintf("After requiring a preceding consonant with n>=100: %s tokens, %s consonants\n",
            format(nrow(fin), big.mark = ","), length(keep_c)))
print(fin[, .(n = .N, types = uniqueN(word_label), median_v = median(duration)),
          by = .(c_phone, alternating)][order(c_phone, alternating)])

mora_rows <- list()
if (nrow(fin) > 200 && uniqueN(fin$alternating) == 2L) {
  m1 <- lmer(log(duration) ~ alternating + c_phone + word_nphone + utt_final +
               pre_pause + log_freq + (1 | word_label) + (1 | file_name),
             data = fin, REML = FALSE,
             control = lmerControl(calc.derivs = FALSE))
  t1 <- as.data.table(tidy(m1, effects = "fixed"))
  mora_rows[[1]] <- t1[, .(outcome = "final_vowel_duration", term, estimate,
                           std.error, statistic,
                           n = nrow(fin),
                           n_types = uniqueN(fin$word_label))]
  cat("\nFinal reduced vowel duration ~ alternating class\n")
  print(t1[, .(term, estimate = round(estimate, 4),
               std.error = round(std.error, 4),
               statistic = round(statistic, 2))])
  print(fin[, .(n = .N, types = uniqueN(word_label),
                median_ms = median(duration),
                mean_ms = round(mean(duration), 1)), by = alternating])

  # The rhyme as a whole.  If the final vowel carries no mora of its own,
  # the consonant-plus-vowel sequence should not be shorter for it: the
  # weight should sit on the consonant instead.  Constant rhyme duration
  # with a longer consonant and a shorter vowel is the moraic prediction.
  fin2 <- copy(fin)[, v_dur := duration][, rhyme := c_dur + v_dur]
  if (nrow(fin2) > 200 && uniqueN(fin2$alternating) == 2L) {
    m2 <- lmer(log(rhyme) ~ alternating + c_phone + word_nphone + utt_final +
                 pre_pause + log_freq + (1 | word_label) + (1 | file_name),
               data = fin2, REML = FALSE,
               control = lmerControl(calc.derivs = FALSE))
    t2 <- as.data.table(tidy(m2, effects = "fixed"))
    mora_rows[[2]] <- t2[, .(outcome = "final_rhyme_duration", term, estimate,
                             std.error, statistic, n = nrow(fin2),
                             n_types = uniqueN(fin2$word_label))]
    m3 <- lmer(log(c_dur) ~ alternating + c_phone + word_nphone + utt_final +
                 pre_pause + log_freq + (1 | word_label) + (1 | file_name),
               data = fin2, REML = FALSE,
               control = lmerControl(calc.derivs = FALSE))
    t3 <- as.data.table(tidy(m3, effects = "fixed"))
    mora_rows[[3]] <- t3[, .(outcome = "final_consonant_duration", term,
                             estimate, std.error, statistic, n = nrow(fin2),
                             n_types = uniqueN(fin2$word_label))]
    cat("\nFinal rhyme (C+V) and final consonant, by class\n")
    print(fin2[, .(n = .N, median_C = median(c_dur), median_V = median(v_dur),
                   median_rhyme = median(rhyme)), by = alternating])
  }
}
if (length(mora_rows))
  readr::write_csv(rbindlist(mora_rows, fill = TRUE),
                   file.path(OUT, "mora_evidence.csv"))

# ══ 3. The word-final CV sequence ════════════════════════════════════════
# This is the пулӑ ~ пулли comparison: the last consonant-plus-vowel of the
# word, by whether that consonant is long and whether the vowel is full or
# reduced.  The four cells of (long / short C) x (reduced / full final V).
#
# NAMING, CORRECTED 2026-09-27.  Earlier versions of this block, and the
# summaries built from it, called the measured unit a "word-final rhyme" and
# c_long a "word-final geminate".  Both are wrong and the error mattered.
# The join below takes the consonant at pidx - 1, i.e. the one BEFORE the
# final vowel, so the unit is the final CV sequence and a long consonant here
# is INTERVOCALIC (пул-ли), not word-final.  A CV sequence is not a rhyme --
# in пул.ли the consonant belongs to the preceding syllable.
#
# The corpus cannot speak to word-final geminates at all: Chuvash Voice has
# 61 word-final long-consonant tokens in 22 word types, and they are almost
# all Russian loans (класс, пресс, стресс, Кирилл, кристалл) plus a few
# onomatopoeia and line-break truncations.  That agrees with the orthographic
# distribution -- word-final geminates are 1.2% of monolingual types and
# 0.05% of tokens -- so the generalisation is that a Chuvash geminate is
# licensed prevocalically (96.7% of types V__V or C__V), and пулӑ ~ пулли is
# what a /CVCː/ stem looks like when nothing follows it.  See
# output/geminate_position.csv and output/geminating_stems.csv.

FULL <- c("a", "e", "i", "u", "y")
RED  <- c("ø", "ɵ", "ʉ")
lastv <- ph[is_vowel == 1L & pos_in_word == "final" & word_nphone >= 3L,
            .(file_name, widx, pidx, word_label, v_phone = phone,
              v_dur = duration, utt_final, pre_pause, word_nphone)]
lastc <- ph[is_vowel == 0L, .(file_name, widx, pidx_next = pidx + 1L,
                              c_phone = phone, c_long = long,
                              c_dur = duration)]
sh <- merge(lastv, lastc, by.x = c("file_name", "widx", "pidx"),
            by.y = c("file_name", "widx", "pidx_next"))
sh[, v_class := ifelse(v_phone %in% FULL, "full",
                ifelse(v_phone %in% RED, "reduced", NA_character_))]
sh <- sh[!is.na(v_class) & c_dur > 0 & v_dur > 0]
sh[, cell := paste0(ifelse(c_long == 1L, "Cː", "C"), "+", v_class)]

shp <- sh[, .(n = .N, types = uniqueN(word_label),
              median_C = median(c_dur), median_V = median(v_dur),
              median_final_CV = median(c_dur + v_dur),
              mean_C = round(mean(c_dur), 1), mean_V = round(mean(v_dur), 1)),
          by = .(cell, c_long, v_class)][order(-n)]
readr::write_csv(shp, file.path(OUT, "gemination_final.csv"))
cat("\ngemination_final.csv — word-final C+V sequences\n")
print(shp)

# The raw cell medians are not a controlled comparison: the four cells hold
# different consonants and different vowels, so a level result across cells
# could be an accident of which segments happen to occur.
# The model below puts the consonant's identity, the utterance edge and the
# pause in, and estimates the four cells as a 2x2 interaction.  The moraic
# prediction is that Cː+reduced and C+full come out level while Cː+full is
# longer than both and C+reduced shorter.
sh[, log_freq := 0]
keep2 <- sh[, .N, by = c_phone][N >= 200, c_phone]
shm <- sh[c_phone %in% keep2]
wm <- lmer(log(c_dur + v_dur) ~ c_long * v_class + c_phone + word_nphone +
             utt_final + pre_pause + (1 | word_label) + (1 | file_name),
           data = shm, REML = FALSE,
           control = lmerControl(calc.derivs = FALSE))
tw <- as.data.table(tidy(wm, effects = "fixed"))
fx <- lme4::fixef(wm)
# Adjusted rhyme for each cell, on the reference consonant, relative to
# C+full.  exp() of the sum of the relevant terms.
rel <- c(
  `C+full`      = 0,
  `Cː+full`     = unname(fx["c_long"]),
  `C+reduced`   = unname(fx["v_classreduced"]),
  `Cː+reduced`  = unname(fx["c_long"] + fx["v_classreduced"] +
                         fx["c_long:v_classreduced"]))
adj <- data.table(cell = names(rel), log_diff_vs_C_full = round(rel, 4),
                  pct_vs_C_full = round(100 * (exp(rel) - 1), 1))
readr::write_csv(
  rbind(tw[, .(kind = "coefficient", term, estimate, std.error, statistic)],
        adj[, .(kind = "adjusted_cell", term = cell,
                estimate = log_diff_vs_C_full,
                std.error = NA_real_, statistic = NA_real_)], fill = TRUE),
  file.path(OUT, "gemination_weight_model.csv"))
cat(sprintf("\nWeight model: %s tokens, %s consonants, %s word types\n",
            format(nrow(shm), big.mark = ","), length(keep2),
            format(uniqueN(shm$word_label), big.mark = ",")))
print(tw[term %in% c("c_long", "v_classreduced", "c_long:v_classreduced",
                     "utt_final", "pre_pause"),
         .(term, estimate = round(estimate, 4), statistic = round(statistic, 1))])
cat("\nAdjusted final-rhyme duration, relative to C + full vowel\n")
print(adj)

cat("\n✓ gemination_mora.R complete\n")
