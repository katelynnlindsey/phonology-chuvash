# Overnight 2026-10-01, contact_phonology Q4: do Russian loans keep Russian stress?
# Input: cache/loan_stress_syllables.csv (built in the session kernel; see NOTEBOOK step 04).
# Russian stress is a PROXY from fixed-stress Russian suffixes (-ист/-изм/-ент/-ант final; -тель/-ци(я)
# on the syllable before; -ика on the syllable before). Native baseline = all-full native words, where
# rule A6 = final syllable. Controls: position (syllable i of n) x utterance-final word, vowel, corpus.
suppressPackageStartupMessages({library(data.table); library(lme4); library(lmerTest); library(broom.mixed)})
OUT <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/contact_phonology/"
d <- fread(paste0(OUT, "cache/loan_stress_syllables.csv"), encoding = "UTF-8")
d <- d[duration > 0 & !is.na(int_midpoint)]
d[, ldur := log(duration)]
d[, int_c := int_midpoint - mean(int_midpoint, na.rm = TRUE), by = file_name]
d[f0_mean > 50 & f0_mean < 500, st := 12 * log2(f0_mean)]
d[, f0_c := st - mean(st, na.rm = TRUE), by = file_name]
d[, loan := as.integer(cls != "native_allfull")]
d[, loan_final := loan * word_final]
# subsample native baseline to keep the fit cheap (all loan rows kept); seed fixed
set.seed(20261002)
nat_files <- unique(d[loan == 0]$file_name)
keep <- sample(nat_files, min(length(nat_files), 12000))
s <- d[loan == 1 | file_name %in% keep]
cat("rows", nrow(s), "loan rows", sum(s$loan), "loan words", uniqueN(s[loan == 1]$w),
    "loan speakers", uniqueN(s[loan == 1]$speaker), "native files", length(keep), "\n")
res <- list()
for (y in c("ldur", "int_c", "f0_c")) {
  f <- as.formula(paste(y, "~ ru_str + loan + loan_final + factor(pos) * utt_final + v + corpus + (1|w) + (1|file_name)"))
  m <- lmer(f, data = s, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  t <- as.data.table(broom.mixed::tidy(m, effects = "fixed", conf.int = TRUE))[term %in% c("ru_str", "loan", "loan_final")]
  t[, `:=`(outcome = y, n_rows = nobs(m))]
  res[[y]] <- t
}
r <- rbindlist(res); fwrite(r, paste0(OUT, "loan_stress_models.csv")); print(r)
# per-class descriptive profile: residual-free cell means of ldur/int_c/f0_c by class x position, non-utterance-final words
prof <- d[utt_final == 0, .(n = .N, n_words = uniqueN(w), mean_ldur = mean(ldur), mean_int_c = mean(int_c, na.rm = TRUE),
                           mean_f0_c = mean(f0_c, na.rm = TRUE), pct_ru_stressed = 100 * mean(ru_str)), by = .(cls, sN, sidx)][order(cls, sN, sidx)]
fwrite(prof, paste0(OUT, "loan_stress_profiles.csv")); print(prof[n >= 10])
cat("DONE\n")
