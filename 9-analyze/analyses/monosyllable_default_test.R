# =============================================================================
# monosyllable_default_test.R
#
# THE A-vs-B DEFAULT, TESTED ON MONOSYLLABLES.
# A and B differ only in a word with no full vowel: A stresses the leftmost
# reduced vowel, B leaves the word stressless. A monosyllable with a reduced
# vowel is the cleanest case — under A it bears stress, under B it does not —
# but its duration also carries whole-word and utterance-edge lengthening,
# which is why every cell below is a WORD-FINAL syllable: final lengthening is
# then equalised across cells rather than confounded with the contrast.
#
# Reference cell = reduced vowel in the final syllable of a polysyllable that
# no A rule stresses. If the monosyllabic reduced vowel patterns with that
# reference it supports B; if it patterns with the stressed full vowels it
# supports A.
#
# LABELS COME FROM THE PIPELINE. Earlier this script recomputed each A rule
# over the vowels that survived cleaning. That is wrong for the 38.9% of word
# tokens with a missing syllable (see analyses/stress_rules_full_word.R): the
# rule must target the rightmost full vowel of the WHOLE word, whether or not
# that syllable was measured. Stage 4 now writes full-word labels, so this
# script reads stress_rule_<R> instead of deriving anything. It bit only the
# two polysyllabic cells — a monosyllable is complete by construction.
#
# Output: output/monosyllable_default_test.csv
# =============================================================================
source(here::here("9-analyze","analyses","00_session_setup.R"))
library(data.table); library(broom.mixed)
OUT <- PATHS$output_dir
FULLV <- c("a","e","i","u","y"); REDV <- c("ø","ɵ","ʉ")
ARULES <- c("A6","A5","A4")
v <- as.data.table(vowels)[!is.na(vowel_label) & !is.na(sidx) & !is.na(word_id)]
stopifnot("stage 4 must supply full-word stress labels" =
            all(paste0("stress_rule_", ARULES) %in% names(v)))
v[, any_A := Reduce(`|`, lapply(paste0("stress_rule_", ARULES),
                                function(cn) get(cn) == "Stressed"))]
v[, vclass := fifelse(vowel_label %in% FULLV,"full",
              fifelse(vowel_label %in% REDV,"reduced",NA_character_))]
v[, syl_final := as.integer(sidx==sN)]
v[, word_utt_final := as.integer(!is.na(wN) & !is.na(widx) & widx==wN)]
if (!"log_speech_rate" %in% names(v)) v[, log_speech_rate := 0]
v[is.na(log_speech_rate), log_speech_rate := 0]
v[, z_freq := as.numeric(scale(log_corpus_freq))]; v[is.na(z_freq), z_freq := 0]

# EVERY cell is a WORD-FINAL syllable, so word-final lengthening is equalised
w <- v[syl_final==1L & !is.na(vclass) & !is.na(log_duration) & !is.na(int_midpoint)]
w[, cell := fifelse(sN==1L & vclass=="reduced","a_reduced_mono",
            fifelse(sN>1L & vclass=="reduced" & !any_A,"b_reduced_polyfinal_unstressed",
            fifelse(sN==1L & vclass=="full","c_full_mono",
            fifelse(sN>1L & vclass=="full" & any_A,"d_full_polyfinal_stressed",NA_character_))))]
w <- w[!is.na(cell)]
cat("\n== all cells are word-final syllables ==\n")
print(w[, .(n=.N, types=uniqueN(word_label), median_ms=round(median(exp(log_duration)),1),
            median_dB=round(median(int_midpoint),2)), by=cell][order(cell)])
w[, cell := relevel(factor(cell), ref="b_reduced_polyfinal_unstressed")]
out <- rbindlist(lapply(c("log_duration","int_midpoint"), function(dv) {
  f <- stats::as.formula(paste(dv,"~ cell + vowel_label + syllable_coda +",
        "word_utt_final + log_speech_rate + z_freq + (1|speaker_id) + (1|word_label)"))
  m <- lmer(f, data=w, REML=FALSE, control=lmerControl(calc.derivs=FALSE))
  tt <- as.data.table(tidy(m, effects="fixed"))[grepl("^cell", term)]
  data.table(dv=dv, term=sub("^cell","",tt$term), estimate=tt$estimate,
             se=tt$std.error, t=tt$statistic,
             pct=if (dv=="log_duration") round(100*(exp(tt$estimate)-1),2) else NA_real_)
}))
fwrite(out, file.path(OUT,"monosyllable_default_test.csv"))
cat("\n== reference = reduced vowel, word-final syllable of a polysyllable, no A rule stresses it ==\n")
print(out)
