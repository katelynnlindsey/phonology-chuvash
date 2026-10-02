# Overnight 2026-10-01, segmental_acoustics: intervocalic lenition models.
# Input : output/overnight_2026-10-01/segmental_acoustics/voicing_tokens.csv.gz
#         (built in build_tokens.py + QC in the notebook; files failing the
#          full-vowel voicing QC (< 0.8) already removed)
# Output: lenition_lmm.csv, lenition_glmm.csv, lenition_emm.csv,
#         lenition_dur_models.csv, lenition_speaker_level.csv
# Run   : LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 Rscript --vanilla lenition_models.R
suppressPackageStartupMessages({
  library(data.table); library(lme4); library(lmerTest); library(broom.mixed)
})
OUT <- "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/segmental_acoustics/"
d <- fread(cmd = paste0("gzip -dc ", OUT, "voicing_tokens.csv.gz"), encoding = "UTF-8")
POS <- c("VV", "RV", "geminate_VV", "OV", "VR", "VO", "initial_postpause", "initial_postO",
         "initial_postR", "initial_postV", "final_preV", "final_preC", "final_prepause")
d <- d[position %in% POS & !is.na(vf_def_mid) & !is.na(vf_def_all) & !is.na(dur_ms)]
d[, position := factor(position, levels = POS)]
d[, ldur := log(dur_ms)]
d[, sldur := (ldur - mean(ldur)) / sd(ldur), by = .(corpus, manner)]
d[, srate := (art_rate - mean(art_rate, na.rm = TRUE)) / sd(art_rate, na.rm = TRUE), by = corpus]
d[, word := paste0("w", word_ascii)]
set.seed(20261001)

res_lmm <- list(); res_glmm <- list(); res_emm <- list(); res_dur <- list()
for (cp in c("common_voice_chuvash", "chuvash_voice")) for (mn in c("stop", "fric")) {
  s <- d[corpus == cp & manner == mn]
  if (cp == "chuvash_voice") s <- s[speaker == "ch_voice_main"]   # single-voice analysis
  cat(sprintf("\n== %s %s: %d tokens, %d words, %d speakers\n", cp, mn, nrow(s),
              uniqueN(s$word), uniqueN(s$speaker)))
  re <- if (cp == "chuvash_voice") "(1|word) + (1|file_name)" else
                                   "(1|speaker) + (1|word) + (1|file_name)"
  # (A) total effect of position on mid-closure voiced fraction (linear probability)
  fA <- as.formula(paste("vf_def_mid ~ position + seg +", re))
  mA <- lmer(fA, data = s, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  tA <- as.data.table(broom.mixed::tidy(mA, effects = "fixed", conf.int = TRUE))
  tA[, `:=`(corpus = cp, manner = mn, model = "A_position", n = nrow(s),
            n_words = uniqueN(s$word), n_speakers = uniqueN(s$speaker))]
  res_lmm[[length(res_lmm) + 1]] <- tA
  # adjusted position means (seg at its observed proportions): predict on data
  s[, predA := predict(mA, re.form = NA)]
  em <- s[, .(adj_mean_vf = mean(predA), raw_mean_vf = mean(vf_def_mid), n = .N,
              n_words = uniqueN(word), n_speakers = uniqueN(speaker)), by = position]
  em[, `:=`(corpus = cp, manner = mn)]
  res_emm[[length(res_emm) + 1]] <- em
  # (B) direct effect net of segment duration and articulation rate
  fB <- as.formula(paste("vf_def_mid ~ position + seg + sldur + srate +", re))
  mB <- lmer(fB, data = s[!is.na(srate)], REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  tB <- as.data.table(broom.mixed::tidy(mB, effects = "fixed", conf.int = TRUE))
  tB[, `:=`(corpus = cp, manner = mn, model = "B_position+dur+rate", n = nrow(s[!is.na(srate)]),
            n_words = uniqueN(s$word), n_speakers = uniqueN(s$speaker))]
  res_lmm[[length(res_lmm) + 1]] <- tB
  # (C) logistic GLMM, voiced (mid-50% >= 0.5), subsample <= 4000 per position
  ss <- s[, .SD[sample(.N, min(.N, 4000))], by = position]
  fC <- as.formula(paste("voiced ~ position + seg +", re))
  mC <- try(glmer(fC, data = ss, family = binomial,
                  control = glmerControl(optimizer = "bobyqa", calc.derivs = FALSE),
                  nAGQ = 0), silent = TRUE)
  if (!inherits(mC, "try-error")) {
    tC <- as.data.table(broom.mixed::tidy(mC, effects = "fixed", conf.int = TRUE))
    tC[, `:=`(corpus = cp, manner = mn, model = "C_glmm_voiced_nAGQ0", n = nrow(ss),
              n_words = uniqueN(ss$word), n_speakers = uniqueN(ss$speaker))]
    res_glmm[[length(res_glmm) + 1]] <- tC
  } else cat("GLMM failed:", as.character(mC), "\n")
  # (D) does voicing fall with duration differently in VV singletons vs geminates?
  sg <- s[position %in% c("VV", "geminate_VV")]
  fD <- as.formula(paste("vf_def_all ~ position * sldur + seg +", re))
  mD <- lmer(fD, data = sg, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  tD <- as.data.table(broom.mixed::tidy(mD, effects = "fixed", conf.int = TRUE))
  tD[, `:=`(corpus = cp, manner = mn, model = "D_vfall_VVvsGem_x_dur", n = nrow(sg))]
  res_dur[[length(res_dur) + 1]] <- tD
  fE <- as.formula(paste("vic_def_ms ~ position + seg + sldur +", re))
  mE <- lmer(fE, data = sg, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
  tE <- as.data.table(broom.mixed::tidy(mE, effects = "fixed", conf.int = TRUE))
  tE[, `:=`(corpus = cp, manner = mn, model = "E_voicing_into_closure_ms", n = nrow(sg))]
  res_dur[[length(res_dur) + 1]] <- tE
}
fwrite(rbindlist(res_lmm, fill = TRUE), paste0(OUT, "lenition_lmm.csv"))
fwrite(rbindlist(res_glmm, fill = TRUE), paste0(OUT, "lenition_glmm.csv"))
fwrite(rbindlist(res_emm, fill = TRUE), paste0(OUT, "lenition_emm.csv"))
fwrite(rbindlist(res_dur, fill = TRUE), paste0(OUT, "lenition_dur_models.csv"))

# ── speaker-level aggregation (Common Voice) ──────────────────────────────
cv <- d[corpus == "common_voice_chuvash" & manner == "stop"]
sp <- cv[, .(vf = mean(vf_def_mid), n = .N), by = .(speaker, position)]
w <- dcast(sp[n >= 5], speaker ~ position, value.var = "vf")
cmp <- list(c("VV", "initial_postpause"), c("VV", "geminate_VV"), c("VV", "OV"),
            c("RV", "VR"), c("initial_postV", "initial_postpause"), c("VV", "initial_postV"))
spl <- rbindlist(lapply(cmp, function(p) {
  x <- w[!is.na(get(p[1])) & !is.na(get(p[2]))]
  dd <- x[[p[1]]] - x[[p[2]]]
  tt <- if (length(dd) > 2) t.test(dd) else NULL
  data.table(contrast = paste(p, collapse = " - "), n_speakers = length(dd),
             mean_diff = mean(dd), ci_lo = if (!is.null(tt)) tt$conf.int[1] else NA,
             ci_hi = if (!is.null(tt)) tt$conf.int[2] else NA,
             n_positive = sum(dd > 0), sign_test_p = if (length(dd) > 0)
               binom.test(sum(dd > 0), length(dd))$p.value else NA)
}))
fwrite(spl, paste0(OUT, "lenition_speaker_level.csv"))
print(spl)
cat("\nDONE\n")
