# =============================================================================
# morph_stress_test.R                                               2026-10-01
#
# DOES THE DURATION RESULT SURVIVE THE MORPHOLOGY CONFOUND?
#
# The confound.  The reduced vowels that define the right edge of the
# penultimate and antepenultimate shape classes are overwhelmingly SUFFIXAL in
# Chuvash, so "the rightmost full vowel is the penult" and "this word carries a
# suffix" are nearly the same statement.  Every result that rests on the shape
# classes -- the leftward walk of the duration peak, the step up into the
# designated syllable -- is therefore open to a morphological reading: maybe
# what lengthens is the last syllable of the STEM, not the syllable the stress
# rule designates.
#
# Three tests.
#   (a) RESTRICTION.  Refit the vowel-stratified step model on words with no
#       confident suffix parse.  If the step up into the designated syllable
#       survives there, the effect is not carried by suffixation.  Cell counts
#       are reported FIRST: if monomorphemic words with right-edge reduced
#       vowels are too rare, this test is underpowered and a null would mean
#       nothing.
#   (b) INTERACTION.  Is a suffix syllable treated differently from a stem
#       syllable at the same position with the same vowel?  If designation
#       matters only in stem syllables, the rule is really a stem-edge rule.
#   (c) ALIGNMENT.  How often does the designated syllable coincide with the
#       last stem syllable, and is designation more or less likely on a
#       suffixal syllable than chance?
#
# SYLLABLE-LEVEL MORPHOLOGY, and its caveat.  A syllable is called suffixal
# when its index exceeds the number of vowels in the parsed stem string.  That
# is approximate because Chuvash resyllabifies across the boundary: in
# /ɕaʋ-ɵn-pa/ the genitive's vowel takes the stem's final consonant as its
# onset, so the syllable is morphologically mixed.  The approximation assigns
# such a syllable to the suffix, which is the right call for a vowel-based
# analysis -- the VOWEL is the suffix's.
#
# Outputs
#   output/morph_cell_counts.csv   power check, reported before the tests
#   output/morph_stress_test.csv   the three tests
# =============================================================================
suppressMessages({library(data.table)})
OUT <- "output"
INV5 <- c("a","e","i","u","y")
MIN_SUF <- 2L
CLSNAME <- c("-1"="no full vowel","0"="final","1"="penultimate",
             "2"="antepenultimate","3"="pre-antepenult")
VOW <- c("a","e","i","o","u","y","ø","ɵ","ʉ")

mp <- fread(file.path(OUT, "morph_parse.csv"), encoding = "UTF-8")
mp[, n_stem_syl := vapply(strsplit(stem, ""), function(ch) sum(ch %chin% VOW), integer(1))]
mp <- unique(mp[, .(word_label = orth, stem, suffix_chain, n_morphs,
                    polymorphemic, n_stem_syl)])
mp <- unique(mp, by = "word_label")

v <- as.data.table(readRDS("/tmp/f0v.rds"))
v <- v[f0_ok == TRUE & !is.na(int_midpoint) & !is.na(log_duration)]
v[, n_meas := .N, by = word_id]
v <- v[n_meas == sN & sN >= 2L]
v[, dur := exp(log_duration)]
v[, int_c := int_midpoint - mean(int_midpoint), by = file_name]
setorder(v, word_id, sidx)

v[, FR := fifelse(vowel_label %in% INV5, "F", "R")]
wd <- v[, .(n_syl = .N, sN = sN[1],
            shape = paste(FR[order(sidx)], collapse = "")), by = word_id][n_syl == sN]
wd[, fp := vapply(gregexpr("F", shape),
                  function(m) if (m[1] == -1L) NA_integer_ else max(m), integer(1))]
wd[, from_end := fifelse(is.na(fp), -1L, sN - fp)]
wd[, desig := fifelse(is.na(fp), 1L, fp)]
v <- merge(v, wd[from_end %in% c(-1L,0L,1L,2L,3L), .(word_id, from_end, desig)], by = "word_id")
v[, cls := CLSNAME[as.character(from_end)]]
v[, utt_fin_word := any(is_utt_final), by = word_id]
v <- v[utt_fin_word == FALSE]
v <- merge(v, mp, by = "word_label", all.x = TRUE)
cat(sprintf("frame %s rows | parse matched for %.1f%% of rows, %.1f%% of types\n",
            format(nrow(v), big.mark=","), 100*mean(!is.na(v$polymorphemic)),
            100*mean(!is.na(unique(v, by="word_label")$polymorphemic))))
v <- v[!is.na(polymorphemic)]
v[, is_suffixal := sidx > n_stem_syl]
v[, is_desig := sidx == desig]

# ---- power check -------------------------------------------------------------
cc <- v[, .(vowel_rows = .N, word_tokens = uniqueN(word_id), types = uniqueN(word_label)),
        by = .(cls, from_end, sN, polymorphemic)]
fwrite(cc[order(from_end, sN, polymorphemic)], file.path(OUT, "morph_cell_counts.csv"))
cat("\n== power check: word tokens per shape class by parse status ==\n")
print(dcast(cc, cls + from_end + sN ~ polymorphemic, value.var = "word_tokens",
            fill = 0L)[order(from_end, sN)])

# ---- step variables ----------------------------------------------------------
v[, `:=`(dur_prev = shift(dur, 1L), v_prev = shift(vowel_label, 1L),
         int_prev = shift(int_c, 1L), f0_prev = shift(f0_st, 1L),
         suf_prev = shift(is_suffixal, 1L)), by = word_id]
v[, `:=`(d_dur_prev = dur - dur_prev, d_int_prev = int_c - int_prev,
         d_f0_prev  = f0_st - f0_prev)]
v[, vcell := paste(sN, sidx, vowel_label, sep = "_")]

crse <- function(m, cl) {
  b <- coef(m); keep <- !is.na(b)
  X <- model.matrix(m)[, keep, drop = FALSE]; u <- residuals(m)
  bread <- chol2inv(chol(crossprod(X)))
  Xu <- as.data.table(X * u)[, cl := cl[as.integer(rownames(X))]]
  S <- as.matrix(Xu[, lapply(.SD, sum), by = cl][, -1L])
  out <- rep(NA_real_, length(b)); out[keep] <- sqrt(diag(bread %*% crossprod(S) %*% bread))
  setNames(out, names(b))
}
grab <- function(m, se, term, lab, d, key) {
  if (!term %in% names(coef(m)) || is.na(coef(m)[[term]]))
    return(data.table(test = lab, term = term, n_steps = nrow(d),
                      n_strata = uniqueN(d[[key]]), estimate = NA_real_,
                      se = NA_real_, t = NA_real_))
  data.table(test = lab, term = term, n_steps = nrow(d), n_strata = uniqueN(d[[key]]),
             estimate = coef(m)[[term]], se = se[[term]],
             t = coef(m)[[term]]/se[[term]])
}
fit_sub <- function(dv, subset_expr, lab) {
  d <- v[eval(subset_expr) & !is.na(get(dv)) & !is.na(v_prev)]
  d[, nvar := uniqueN(is_desig), by = vcell]; d <- d[nvar == 2L]
  if (!nrow(d) || uniqueN(d$is_desig) < 2L)
    return(data.table(test = lab, term = "is_desigTRUE", n_steps = nrow(d),
                      n_strata = 0L, estimate = NA_real_, se = NA_real_, t = NA_real_))
  m <- lm(as.formula(paste(dv, "~ is_desig + factor(vcell) + v_prev")), data = d)
  grab(m, crse(m, d$word_label), "is_desigTRUE", lab, d, "vcell")
}
cat("\n=== (a) restriction: the step up into the designated syllable ===\n")
ta <- rbindlist(lapply(c("d_dur_prev","d_int_prev","d_f0_prev"), function(dv) rbind(
  fit_sub(dv, quote(rep(TRUE, .N)),            paste(dv, "| all words")),
  fit_sub(dv, quote(polymorphemic == FALSE),   paste(dv, "| no suffix parsed")),
  fit_sub(dv, quote(polymorphemic == TRUE),    paste(dv, "| suffix parsed")))))
print(ta, digits = 4)

cat("\n=== (b) interaction: does suffixal status modulate designation? ===\n")
tb <- rbindlist(lapply(c("d_dur_prev","d_int_prev","d_f0_prev"), function(dv) {
  d <- v[!is.na(get(dv)) & !is.na(v_prev)]
  d[, nvar := uniqueN(paste(is_desig, is_suffixal)), by = vcell]; d <- d[nvar >= 3L]
  m <- lm(as.formula(paste(dv, "~ is_desig * is_suffixal + factor(vcell) + v_prev")), data = d)
  se <- crse(m, d$word_label)
  rbind(grab(m, se, "is_desigTRUE", paste(dv, "| designation, stem syllable"), d, "vcell"),
        grab(m, se, "is_suffixalTRUE", paste(dv, "| suffixal, not designated"), d, "vcell"),
        grab(m, se, "is_desigTRUE:is_suffixalTRUE", paste(dv, "| interaction"), d, "vcell"))
}))
print(tb, digits = 4)

cat("\n=== (c) alignment of designation with the stem edge ===\n")
wsum <- unique(v[, .(word_id, sN, desig, n_stem_syl, polymorphemic, cls, from_end)])
wsum <- wsum[polymorphemic == TRUE & n_stem_syl >= 1L & n_stem_syl <= sN]
tc <- wsum[, .(word_tokens = .N,
               desig_is_last_stem_syl = mean(desig == n_stem_syl),
               desig_is_suffixal      = mean(desig > n_stem_syl),
               chance_suffixal        = mean((sN - n_stem_syl)/sN)),
           by = .(cls, from_end)]
print(tc[order(from_end)], digits = 3)
res <- rbind(ta[, spec := "(a) restriction"], tb[, spec := "(b) interaction"], fill = TRUE)
fwrite(res, file.path(OUT, "morph_stress_test.csv"))
fwrite(tc, file.path(OUT, "morph_alignment.csv"))
cat("\n✓ morph_stress_test.R complete\n")
