source(here::here("9-analyze","analyses","00_session_setup.R"))
library(data.table); library(broom.mixed)
OUT <- PATHS$output_dir
FULLV <- c("a","e","i","u","y"); REDV <- c("ø","ɵ","ʉ")
v <- as.data.table(vowels)[!is.na(vowel_label) & !is.na(sidx) & !is.na(word_id)]
ord <- v[order(word_id, sidx)]
tg <- ord[, as.list(setNames(lapply(c("A6","A5","A4"), function(r) assign_stress(vowel_label, r)),
                             c("tA6","tA5","tA4"))), by=word_id]
v <- merge(v, tg, by="word_id")
for (r in c("A6","A5","A4")) v[, (paste0("s",r)) := !is.na(get(paste0("t",r))) & sidx==get(paste0("t",r))]
v[, any_A := sA6 | sA5 | sA4]
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
