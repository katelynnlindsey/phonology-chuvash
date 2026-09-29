suppressMessages(library(data.table))
v <- as.data.table(readRDS("data/leveled/vowels_spoken_annotated.rds"))
RULES <- c("A6","A5","A4","B6","B5","B4","SON_F","SON_A","SON_B")
v <- v[!is.na(vowel_label) & !is.na(sidx) & !is.na(sN)]
v[, syl_final := as.integer(sidx == sN)]
# the three non-rule baselines, full-word definitions
v[, b_final   := as.integer(sidx == sN)]
v[, b_initial := as.integer(sidx == 1L)]
v[, wt := { z <- suppressWarnings(max(sidx[syllable_coda=="closed"], na.rm=TRUE))
            if (!is.finite(z)) sN[1] else z }, by = word_id]
v[, b_weight := as.integer(sidx == wt)]
cat(sprintf("rows: %s | word-final base rate: %.2f%%\n\n",
            format(nrow(v), big.mark=","), 100*mean(v$syl_final)))

pred <- c(setNames(paste0("stress_rule_", RULES), RULES),
          final="b_final", initial="b_initial", weight="b_weight")
out <- rbindlist(lapply(names(pred), function(nm) {
  s <- if (grepl("^stress_rule_", pred[[nm]])) as.integer(v[[pred[[nm]]]]=="Stressed") else v[[pred[[nm]]]]
  f <- v$syl_final
  # phi = Pearson r on two binaries; 1.000 means the predictor IS the control
  data.table(predictor = nm,
             pct_stressed       = round(100*mean(s), 2),
             pct_of_stressed_that_are_final = round(100*mean(f[s==1]), 2),
             pct_of_final_that_are_stressed = round(100*mean(s[f==1]), 2),
             phi_with_syl_final = round(cor(s, f), 4),
             independent_var_pct = round(100*mean(s != f), 2))
}))
print(out)
cat("\n-- exact identity check --\n")
for (nm in names(pred)) {
  s <- if (grepl("^stress_rule_", pred[[nm]])) as.integer(v[[pred[[nm]]]]=="Stressed") else v[[pred[[nm]]]]
  if (all(s == v$syl_final)) cat(sprintf("  %s is IDENTICAL to syl_final on all %s rows\n",
                                          nm, format(nrow(v), big.mark=",")))
}
fwrite(out, "output/rule_final_collinearity.csv")
