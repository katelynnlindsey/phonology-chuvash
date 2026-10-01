suppressMessages({library(data.table);library(lme4);library(broom.mixed)})
v <- readRDS("/tmp/v2.rds"); OUT <- "output"
COV <- "vowel_label + syllable_coda + z_freq + poly(rel_word,3) + is_utt_final"
# FULLY SATURATED position: one free mean per (sidx, sN) cell. factor(sidx) +
# factor(sN) additively CANNOT separate "2nd syllable" from "final syllable of
# a disyllable", because in a disyllable they are the same thing and 43.6% of
# rows are disyllables. A cell-means model can.
m <- lmer(as.formula(paste("int_c ~", COV, "+ cell + (1|word_label)")),
          data=v, REML=FALSE, control=lmerControl(calc.derivs=FALSE))
tt <- as.data.table(tidy(m, effects="fixed"))[grepl("^cell", term)]
tt[, term := sub("^cell","",term)]
tt <- rbind(data.table(term="s1of2", estimate=0, std.error=NA, statistic=NA), 
            tt[, .(term, estimate, std.error, statistic)], fill=TRUE)
tt[, sidx := as.integer(sub("^s(\\d)of.*","\\1",term))]
tt[, sN   := as.integer(sub(".*of(\\d)$","\\1",term))]
tt[, is_final := sidx == sN]
tt[, n := v[, .N, by=.(sidx,sN)][tt, on=.(sidx,sN), x.N]]
setorder(tt, sN, sidx)
fwrite(tt, file.path(OUT,"position_cell_means.csv"))
cat("\n== intensity by (syllable, word length), reference = syllable 1 of a disyllable ==\n")
print(tt[, .(cell=term, sidx, sN, is_final, dB=round(estimate,3),
             se=round(std.error,3), n=format(n,big.mark=","))])
cat("\n== the question: is syllable 2 above syllable 1 WITHIN each word length? ==\n")
d <- dcast(tt, sN ~ sidx, value.var="estimate")
for (k in 2:6) {
  r <- d[sN==k]; if (!nrow(r)) next
  s1 <- r[["1"]]; s2 <- r[["2"]]
  cat(sprintf("  sN=%d : syl2 - syl1 = %+.3f dB   (syllable 2 is %s)\n",
              k, s2-s1, ifelse(k==2,"WORD-FINAL","word-internal")))
}
