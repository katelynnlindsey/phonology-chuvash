# speaker_cues/models/01_pooled_models.R
# Pooled reference ("canonical") models: one per rule x cue, Kate's positional controls.
#   DV (centred within file) ~ rule + syl1 + syl2 + word_final + utt_final_word + utt_final_syl + (1|word_label)
# Specs:
#   kate     : positional controls only, all rows with all three DVs (sN 2-6)
#   kate_bs  : + file broadcast score (centred) + rule x score, rows with a score
#   kate_vh  : + vowel_height (project convention in full_word_rule_models.R)
#   kate_novm: kate spec without chv_voice_main
# Run: LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 Rscript --vanilla 01_pooled_models.R
suppressPackageStartupMessages({library(data.table); library(arrow); library(lme4); library(broom.mixed)})
A <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/speaker_cues_2026-10-02"
v <- as.data.table(read_parquet(file.path(A, "models/cache/model_frame.parquet")))
v <- v[sN >= 2 & sN <= 6]
bs <- fread(file.path(A, "broadcast_score/broadcast_score_by_file.csv"), select = c("file_name","broadcast_score"))
v <- merge(v, bs, by = "file_name", all.x = TRUE)
v[, dur_c := log_duration - mean(log_duration), by = file_name]
v[, f0_c := f0_st - mean(f0_st, na.rm = TRUE), by = file_name]
v <- v[!is.na(dur_c) & !is.na(int_c) & !is.na(f0_c)]
v[, bs_c := broadcast_score - mean(broadcast_score, na.rm = TRUE)]
rules <- c("A6","A5","A4","B6","B5","B4","SON_F","SON_A","SON_B")
for (r in rules) v[, (r) := as.integer(get(paste0("stress_rule_", r)) == "Stressed")]
ctrl <- "syl1 + syl2 + word_final + utt_final_word + utt_final_syl"
cues <- c(duration = "dur_c", intensity = "int_c", f0 = "f0_c")
specs <- list(
  kate      = list(d = v,                          extra = ""),
  kate_bs   = list(d = v[!is.na(bs_c)],            extra = " + bs_c + RULE:bs_c"),
  kate_vh   = list(d = v,                          extra = " + vowel_height"),
  kate_novm = list(d = v[spk != "chv_voice_main"], extra = ""))
out <- list(); i <- 0
for (sp in names(specs)) for (cn in names(cues)) for (r in rules) {
  if (sp %in% c("kate_bs","kate_novm","kate_vh") && !(r %in% c("A6","B5","A5","B6"))) next
  d <- specs[[sp]]$d
  f <- as.formula(paste(cues[[cn]], "~ RULE +", ctrl, gsub("RULE", r, specs[[sp]]$extra), "+ (1|word_label)") |> gsub(pattern = "RULE", replacement = r))
  t0 <- Sys.time()
  m <- lmer(f, data = d, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  td <- as.data.table(tidy(m, effects = "fixed", conf.int = TRUE))
  td[, `:=`(spec = sp, cue = cn, rule = r, AIC = AIC(m), n = nrow(d), n_spk = uniqueN(d$spk), secs = as.numeric(Sys.time() - t0, units = "secs"))]
  i <- i + 1; out[[i]] <- td
  cat(sp, cn, r, "n", nrow(d), "est", round(td[term == r, estimate], 4), "AIC", round(AIC(m)), round(td$secs[1]), "s\n")
  fwrite(rbindlist(out, fill = TRUE), file.path(A, "models/pooled_models.csv"))
}
cat("done\n")
