# Overnight 2026-10-01, contact_phonology Q5: re-run the Segmental track's loan-vs-native V_V stop voicing
# comparison (segmental_acoustics/lenition_loans.R, same token table, same model) with the contact-track
# loan classifier (loan_classifier.py; flags exported to cache/voicing_word_loan_flags.csv).
suppressPackageStartupMessages({library(data.table); library(lme4); library(lmerTest); library(broom.mixed)})
SEG <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/segmental_acoustics/"
OUT <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/contact_phonology/"
d <- fread(cmd = paste0("gzip -dc ", SEG, "voicing_tokens.csv.gz"), encoding = "UTF-8")
d <- d[position == "VV" & manner == "stop" & !is.na(vf_def_mid)]
fl <- fread(paste0(OUT, "cache/voicing_word_loan_flags.csv"), encoding = "UTF-8")
d <- merge(d, fl, by = "word_label", all.x = TRUE)
stopifnot(!anyNA(d$loan_full))
d[, loan_crude_R := as.integer(grepl("[оёфцщъбгджз]", tolower(word_label)))]   # the Segmental definition, verbatim
d[, sldur := as.numeric(scale(log(dur_ms))), by = corpus]; d[, word := paste0("w", word_ascii)]
d[, stratum := fifelse(loan_crude_R == 1, "crude_loan", fifelse(loan_full, "new_only_loan", "native_both"))]
desc <- d[, .(n_tokens = .N, n_words = uniqueN(word), n_speakers = uniqueN(speaker), pct_voiced = 100 * mean(vf_def_mid >= 0.5),
              mean_vf = mean(vf_def_mid)), by = .(corpus, stratum)][order(corpus, stratum)]
fwrite(desc, paste0(OUT, "lenition_loan_reclassified_descriptive.csv")); print(desc)
res <- list()
for (cp in c("common_voice_chuvash", "chuvash_voice")) for (def in c("loan_crude_R", "loan_full", "loan_vowelblind", "stratum")) for (dc in c("no_dur", "with_dur")) {
  s <- d[corpus == cp]; if (cp == "chuvash_voice") s <- s[speaker == "ch_voice_main"]
  s[, x := if (def == "stratum") factor(stratum, levels = c("native_both", "crude_loan", "new_only_loan")) else as.numeric(get(def))]
  re <- if (cp == "chuvash_voice") "(1|word) + (1|file_name)" else "(1|speaker) + (1|word) + (1|file_name)"
  f <- paste("vf_def_mid ~ x + seg", if (dc == "with_dur") "+ sldur" else "", "+", re)
  m <- lmer(as.formula(f), data = s, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  t <- as.data.table(broom.mixed::tidy(m, effects = "fixed", conf.int = TRUE))[grepl("^x", term)]
  t[, `:=`(corpus = cp, loan_def = def, model = dc, n = nrow(s), n_words = uniqueN(s$word), n_speakers = uniqueN(s$speaker),
           n_loan_tokens = if (def == "stratum") sum(s$stratum != "native_both") else sum(s$x),
           n_loan_words = if (def == "stratum") uniqueN(s[stratum != "native_both"]$word) else uniqueN(s[x == 1]$word))]
  res[[length(res) + 1]] <- t
}
r <- rbindlist(res); fwrite(r, paste0(OUT, "lenition_loan_reclassified_models.csv"))
print(r[, .(corpus, loan_def, model, term, estimate = round(estimate, 3), lo = round(conf.low, 3), hi = round(conf.high, 3), n_loan_tokens, n_loan_words)])
cat("DONE\n")
