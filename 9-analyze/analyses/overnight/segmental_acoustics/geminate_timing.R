# Overnight 2026-10-01, segmental_acoustics: vowel duration before / after
# geminates vs singletons in word-internal V1 C(ː) V2.
# Input : geminate_timing_tokens.csv.gz (QC-passed files; mː vː dropped as
#         floor-clipped per gemination_models.csv; loan-only C dropped)
# Output: geminate_timing_models.csv, geminate_timing_cells.csv
suppressPackageStartupMessages({library(data.table); library(lme4); library(lmerTest); library(broom.mixed)})
OUT <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/segmental_acoustics/"
d <- fread(cmd = paste0("gzip -dc ", OUT, "geminate_timing_tokens.csv.gz"), encoding = "UTF-8")
d <- d[!is.na(V1_dur) & !is.na(V2_dur) & !is.na(art_rate) & V1_ascii != "o" & V2_ascii != "o"]
d[, srate := (art_rate - mean(art_rate)) / sd(art_rate), by = corpus]
d[, word := paste0("w", word_ascii)]
d[, V1_first := as.integer(V1_vidx == 1)]
d[, cls := ifelse(klass == "O", "obstruent", "sonorant")]
res <- list(); cells <- list()
for (cp in c("common_voice_chuvash", "chuvash_voice")) {
  s <- d[corpus == cp]
  if (cp == "chuvash_voice") s <- s[speaker == "ch_voice_main"]
  re <- if (cp == "chuvash_voice") "(1|word) + (1|file_name)" else "(1|speaker) + (1|word) + (1|file_name)"
  specs <- list(
    V1 = paste("log(V1_dur) ~ long*cls + C_ascii + V1_ascii + V1_stressed + V1_first + V2_ascii +",
               "word_nphone + utt_final_word + srate +", re),
    V2 = paste("log(V2_dur) ~ long*cls + C_ascii + V2_ascii + V2_stressed + V2_word_final*utt_final_word +",
               "V1_ascii + word_nphone + srate +", re),
    C  = paste("log(dur_ms) ~ long*cls + C_ascii + V1_ascii + V2_ascii + V1_stressed + word_nphone +",
               "utt_final_word + srate +", re),
    V1C_over_V2 = paste("log((V1_dur + dur_ms)/V2_dur) ~ long*cls + C_ascii + V1_ascii + V2_ascii +",
               "V1_stressed + V2_word_final*utt_final_word + word_nphone + srate +", re))
  for (nm in names(specs)) {
    m <- lmer(as.formula(specs[[nm]]), data = s, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
    t <- as.data.table(broom.mixed::tidy(m, effects = "fixed", conf.int = TRUE))
    t <- t[grepl("long|cls|stressed|srate", term)]
    t[, `:=`(corpus = cp, outcome = nm, n = nrow(s), n_words = uniqueN(s$word),
             n_speakers = uniqueN(s$speaker), pct_change = 100 * (exp(estimate) - 1),
             pct_lo = 100 * (exp(conf.low) - 1), pct_hi = 100 * (exp(conf.high) - 1))]
    res[[length(res) + 1]] <- t
    cat(cp, nm, "done\n")
  }
  # stressed-V1 only and reduced-V1 only (closed-syllable shortening of full vs reduced)
  for (vr in c(0, 1)) {
    ss <- s[V1_red == vr]
    m <- lmer(as.formula(specs$V1), data = ss, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
    t <- as.data.table(broom.mixed::tidy(m, effects = "fixed", conf.int = TRUE))[grepl("^long", term)]
    t[, `:=`(corpus = cp, outcome = paste0("V1_subset_V1red=", vr), n = nrow(ss), n_words = uniqueN(ss$word),
             n_speakers = uniqueN(ss$speaker), pct_change = 100 * (exp(estimate) - 1),
             pct_lo = 100 * (exp(conf.low) - 1), pct_hi = 100 * (exp(conf.high) - 1))]
    res[[length(res) + 1]] <- t
  }
  cells[[length(cells) + 1]] <- s[, .(n = .N, n_words = uniqueN(word), med_C = median(dur_ms),
                                      med_V1 = median(V1_dur), med_V2 = median(V2_dur)),
                                  by = .(corpus, cls, long, V1_red)][order(cls, V1_red, long)]
}
fwrite(rbindlist(res, fill = TRUE), paste0(OUT, "geminate_timing_models.csv"))
fwrite(rbindlist(cells), paste0(OUT, "geminate_timing_cells.csv"))
cat("DONE\n")
