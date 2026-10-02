# overnight/sociophonetics/s2_representativeness_models.R
# Step 2: do the headline stress / vowel-class effects survive without voice_main?
# Mirrors analyses/intensity_measure_comparison.R: DV ~ is_stressed + vowel_label + syllable_coda +
#   phrase_position + z_relpos + z_rate + z_freq + (1|word_label) + (1|file_name), plus (1|spk)
#   (spk = CV speaker / CH voice cluster). f0_st = f0_mid (steps 10/11) in st re speaker median,
#   screened as in analyses/f0_measure.R (|st|<=12, steps within an octave).
# Usage: Rscript s2_representativeness_models.R <subset>   subset in all | no_vm | cv_only
suppressPackageStartupMessages({library(data.table); library(arrow); library(lme4)})
args <- commandArgs(TRUE); SUB <- args[1]
O <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/sociophonetics"
d <- as.data.table(read_parquet(file.path(O, "cache/model_data.parquet")))
if (SUB == "no_vm")   d <- d[is_vm == FALSE]
if (SUB == "cv_only") d <- d[corpus == "common_voice_chuvash"]
d[, is_stressed_A6 := stress_rule_A6 == "Stressed"]
d[, is_stressed_B5 := stress_rule_B5 == "Stressed"]
d[, is_reduced := vowel_class == "reduced"]
CTRL <- "syllable_coda + phrase_position + z_relpos + z_rate + z_freq"
ctl <- lmerControl(calc.derivs = FALSE)
out <- list()
fit <- function(dv, term, rhs) {
  dd <- d[!is.na(get(dv))]
  f <- as.formula(sprintf("%s ~ %s + %s + (1|word_label) + (1|file_name) + (1|spk)", dv, rhs, CTRL))
  t0 <- Sys.time()
  m <- lmer(f, data = dd, REML = FALSE, control = ctl)
  cf <- summary(m)$coefficients
  r <- data.table(subset = SUB, dv = dv, term = term, estimate = cf[term, 1], se = cf[term, 2],
                  n_tokens = nrow(dd), n_speakers = uniqueN(dd$spk), n_files = uniqueN(dd$file_name),
                  n_word_types = uniqueN(dd$word_label),
                  sd_spk = attr(VarCorr(m)$spk, "stddev"), singular = isSingular(m),
                  secs = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  cat(sprintf("%s %s %s est=%.4f se=%.4f (%ds)\n", SUB, dv, term, r$estimate, r$se, r$secs)); flush.console()
  r
}
for (dv in c("log_duration", "int_midpoint", "f0_st")) {
  for (rule in c("B5", "A6"))
    out[[length(out) + 1]] <- fit(dv, sprintf("is_stressed_%sTRUE", rule),
                                  sprintf("is_stressed_%s + vowel_label", rule))
  out[[length(out) + 1]] <- fit(dv, "is_reducedTRUE", "is_reduced")
  fwrite(rbindlist(out), file.path(O, sprintf("s2_models_%s.csv", SUB)))
}
cat("done\n")
