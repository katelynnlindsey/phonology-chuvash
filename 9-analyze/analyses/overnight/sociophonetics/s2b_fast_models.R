# overnight/sociophonetics/s2b_fast_models.R
# Fast-spec companion to s2_representativeness_models.R (lead's recommendation: DV centred within
# file_name, (1|word_label) only; ~1.7% different from the full random-effect spec for intensity).
# Same fixed effects. Fits all / no_vm / cv_only / vm_only so the subsets are directly comparable.
suppressPackageStartupMessages({library(data.table); library(arrow); library(lme4)})
O <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/sociophonetics"
D0 <- as.data.table(read_parquet(file.path(O, "cache/model_data.parquet")))
D0[, is_stressed_A6 := stress_rule_A6 == "Stressed"]; D0[, is_stressed_B5 := stress_rule_B5 == "Stressed"]
D0[, is_reduced := vowel_class == "reduced"]
for (dv in c("log_duration", "int_midpoint", "f0_st")) D0[, (paste0(dv, "_c")) := get(dv) - mean(get(dv), na.rm = TRUE), by = file_name]
CTRL <- "syllable_coda + phrase_position + z_relpos + z_rate + z_freq"
out <- list()
for (SUB in c("all", "no_vm", "cv_only", "vm_only")) {
  d <- switch(SUB, all = D0, no_vm = D0[is_vm == FALSE], cv_only = D0[corpus == "common_voice_chuvash"], vm_only = D0[is_vm == TRUE])
  for (dv in c("log_duration", "int_midpoint", "f0_st")) {
    dvc <- paste0(dv, "_c"); dd <- d[!is.na(get(dvc))]
    for (spec in list(c("is_stressed_B5TRUE", "is_stressed_B5 + vowel_label"), c("is_stressed_A6TRUE", "is_stressed_A6 + vowel_label"), c("is_reducedTRUE", "is_reduced"))) {
      t0 <- Sys.time()
      m <- lmer(as.formula(sprintf("%s ~ %s + %s + (1|word_label)", dvc, spec[2], CTRL)), data = dd, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
      cf <- summary(m)$coefficients
      out[[length(out) + 1]] <- data.table(subset = SUB, dv = dv, term = spec[1], estimate = cf[spec[1], 1], se = cf[spec[1], 2],
        n_tokens = nrow(dd), n_speakers = uniqueN(dd$spk), n_files = uniqueN(dd$file_name), n_word_types = uniqueN(dd$word_label),
        secs = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))))
      cat(SUB, dv, spec[1], round(cf[spec[1], 1], 4), "\n"); flush.console()
      fwrite(rbindlist(out), file.path(O, "s2b_fast_models.csv"))
    }
  }
}
cat("done\n")
