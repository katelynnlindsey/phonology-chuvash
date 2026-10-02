# Robustness for 04_loan_stress_models.R: (i) Chuvash Voice voice_main only, (ii) non-utterance-final words only.
suppressPackageStartupMessages({library(data.table); library(lme4); library(lmerTest); library(broom.mixed)})
OUT <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/contact_phonology/"
d <- fread(paste0(OUT, "cache/loan_stress_syllables.csv"), encoding = "UTF-8")
d <- d[duration > 0 & !is.na(int_midpoint)]
d[, ldur := log(duration)]; d[, int_c := int_midpoint - mean(int_midpoint, na.rm = TRUE), by = file_name]
d[f0_mean > 50 & f0_mean < 500, st := 12 * log2(f0_mean)]; d[, f0_c := st - mean(st, na.rm = TRUE), by = file_name]
d[, loan := as.integer(cls != "native_allfull")]; d[, loan_final := loan * word_final]
set.seed(20261002); nat_files <- unique(d[loan == 0]$file_name); keep <- sample(nat_files, min(length(nat_files), 12000))
d <- d[loan == 1 | file_name %in% keep]
subs <- list(ch_voice_main = d[speaker == "ch_voice_main"], non_utt_final = d[utt_final == 0])
res <- list()
for (nm in names(subs)) for (y in c("ldur", "int_c", "f0_c")) {
  s <- subs[[nm]]
  rhs <- if (nm == "non_utt_final") "ru_str + loan + loan_final + factor(pos) + v + corpus" else "ru_str + loan + loan_final + factor(pos) * utt_final + v"
  m <- lmer(as.formula(paste(y, "~", rhs, "+ (1|w) + (1|file_name)")), data = s, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  t <- as.data.table(broom.mixed::tidy(m, effects = "fixed", conf.int = TRUE))[term %in% c("ru_str", "loan_final")]
  t[, `:=`(subset = nm, outcome = y, n_rows = nobs(m), n_loan_rows = sum(s$loan), n_loan_words = uniqueN(s[loan == 1]$w))]
  res[[length(res) + 1]] <- t
}
r <- rbindlist(res); fwrite(r, paste0(OUT, "loan_stress_models_robustness.csv"))
print(r[, .(subset, outcome, term, est = round(estimate, 3), lo = round(conf.low, 3), hi = round(conf.high, 3), n_loan_rows, n_loan_words)])
