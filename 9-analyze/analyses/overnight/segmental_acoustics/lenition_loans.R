# Overnight 2026-10-01, segmental_acoustics: is intervocalic lenition blocked in
# Russian loans?  Loan flag = word spelled with any of о ё ф ц щ ъ б г д ж з
# (letters that native Chuvash orthography does not use; crude, declared).
suppressPackageStartupMessages({library(data.table); library(lme4); library(lmerTest); library(broom.mixed)})
OUT <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/segmental_acoustics/"
d <- fread(cmd = paste0("gzip -dc ", OUT, "voicing_tokens.csv.gz"), encoding = "UTF-8")
d <- d[position == "VV" & manner == "stop" & !is.na(vf_def_mid)]
d[, loan := as.integer(grepl("[оёфцщъбгджз]", tolower(word_label)))]
d[, sldur := as.numeric(scale(log(dur_ms))), by = corpus]; d[, word := paste0("w", word_ascii)]
res <- list()
for (cp in c("common_voice_chuvash", "chuvash_voice")) for (dc in c("no_dur", "with_dur")) {
  s <- d[corpus == cp]; if (cp == "chuvash_voice") s <- s[speaker == "ch_voice_main"]
  re <- if (cp == "chuvash_voice") "(1|word) + (1|file_name)" else "(1|speaker) + (1|word) + (1|file_name)"
  f <- paste("vf_def_mid ~ loan + seg", if (dc == "with_dur") "+ sldur" else "", "+", re)
  m <- lmer(as.formula(f), data = s, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  t <- as.data.table(broom.mixed::tidy(m, effects = "fixed", conf.int = TRUE))[term %in% c("loan", "sldur")]
  t[, `:=`(corpus = cp, model = dc, n = nrow(s), n_loan_tokens = sum(s$loan), n_words = uniqueN(s$word),
           n_loan_words = uniqueN(s[loan == 1]$word), n_speakers = uniqueN(s$speaker))]
  res[[length(res) + 1]] <- t
}
fwrite(rbindlist(res), paste0(OUT, "lenition_loan_models.csv")); print(rbindlist(res)); cat("DONE\n")
