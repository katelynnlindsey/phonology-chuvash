# =============================================================================
# morph_validation.R                                                2026-10-01
#
# CHOOSING THE ACCEPTANCE CUT for the induced suffixes, and building the parse.
#
# morph_induction.R deliberately stopped at continuous scores.  The cut is
# fixed HERE, by agreement with an independently specified list of Chuvash
# inflectional suffixes -- never by anything downstream.  That matters because
# the parse is about to be used to test whether a stress result survives a
# morphology confound; a cut tuned on that result would be worthless.
#
# PROVENANCE OF THE REFERENCE LIST, stated plainly.  The list below is a
# standard inventory of high-frequency Chuvash inflectional and common
# derivational suffixes, written out for this validation from the grammatical
# description of the language (the same descriptive tradition as Krueger 1961,
# Andreev 1985/1997 and Jakovlev 1977/1987, which the draft already cites).  It
# is NOT a transcription of any one published table, and it has not been
# checked by a Chuvash specialist.  IT NEEDS KATE'S EYES BEFORE PUBLICATION.
# Both harmony alternants are listed where the suffix has them.
#
# PRECISION IS SCORED IN THREE CATEGORIES, not two.  An accepted suffix that is
# not on the list is often a legitimate SEQUENCE of listed suffixes -- Chuvash
# is agglutinating, so -sene is plural plus dative and a string-based inducer
# will find it as one unit.  Counting those as errors would understate the
# induction badly.  So each accepted suffix is scored as:
#   listed         on the reference list
#   combination    segmentable into a concatenation of listed suffixes
#   unexplained    neither -- a genuine false positive
# Precision = (listed + combination) / accepted.  Recall is against the list.
#
# THE PARSE.  At the chosen cut, each type is stripped recursively (up to four
# rounds, since Chuvash stacks stem+PL+POSS+CASE) taking at each round the
# accepted suffix with the highest stem count that leaves an attested word.
# n_morphs = 1 + the number of strips.  A type with no strip is the
# monomorphemic class.
#
# Outputs
#   output/morph_validation.csv     precision/recall surface over the cut grid
#   output/morph_accepted.csv       the accepted inventory, with its category
#   output/morph_parse.csv          per type: stem, suffix chain, n_morphs
#   output/methods_morphology.md    method, cut, validation, failure modes
# =============================================================================
# TWO CONSTRAINTS ADDED AFTER A FIRST RUN OVER-SEGMENTED BADLY.  Unconstrained,
# the parse analysed лаша /laʃa/ 'horse' as la-ʃ-a and каларӗ as ka-l-a-r-ø,
# and made 65.5% of types polymorphemic with 31% at five morphemes, which is
# not Chuvash.  The cause was single-phoneme suffixes: -n, -a, -e, -ø, -i are
# real Chuvash suffixes, but STRING RECURRENCE CANNOT IDENTIFY THEM, because it
# has no way to distinguish a genitive -n from a stem-final n.  Once admitted
# they chew through roots one phoneme at a time.  So:
#   MIN_SUF = 2   only suffixes of two or more phonemes are parsed.  This is a
#                 stated limitation, not a fix: words whose only affix is a
#                 single phoneme are left in the unparsed class, which makes
#                 the POLYMORPHEMIC class conservative and the MONOMORPHEMIC
#                 class really "no confident parse".  For the downstream test
#                 that is the safe direction -- it weakens the contrast rather
#                 than manufacturing it.
#   MIN_STEM = 3  a Chuvash root is at least CVC; "la" is not a stem.
# The accepted inventory is also restricted to suffixes that are on the
# reference list or segmentable into listed suffixes, i.e. the intersection of
# corpus evidence with linguistic description.  The induction's work is then to
# VALIDATE the list against 430,008 types, to supply the productivity scores
# that choose between competing parses, to find the high-frequency agglutinated
# SEQUENCES the list does not enumerate, and to impose the stem-attestation
# requirement -- not to discover the inventory unaided.
suppressMessages({library(data.table)})
OUT <- "output"
MAX_SUF <- 8L; MIN_SUF <- 2L; MIN_STEM <- 3L; STEM_FLOOR <- 2L; MAX_STRIP <- 3L

# ---- the reference list ------------------------------------------------------
REF <- c(
  # number
  "sem",
  # possessive
  "ɵm","øm","ɵmɵr","ømør","ɵr","ør","ø","i",
  # case
  "ɵn","øn","n","a","e","na","ne","ta","te","ra","re","tɕe","tɕi",
  "tan","ten","ran","ren","ntɕen","pa","pe","ʃɵn","ʃøn",
  # plural + case, listed because they are single high-frequency strings
  "sene","sen","sempe","sentɕen","sente","senpe",
  # verbal
  "ma","me","sa","se","nɵ","nø","rø","rɵm","røm","ɵp","øp","at","et",
  "akan","eken","ɕɕø","tɕtɕø","mast","mest","mar",
  # common derivation
  "lɵ","lø","sɵr","sør","lɵx","løx","u","y","lan","len"
)
REF <- unique(REF)

ind <- fread(file.path(OUT, "induced_suffixes.csv"), encoding = "UTF-8")
m   <- as.data.table(readRDS("data/leveled/mono_annotated.rds"))
ty  <- unique(m[, .(orth = word_label, ipa = word_label_IPA, freq = corpus_freq)])
rm(m); invisible(gc())
OKCH <- c("a","e","i","o","u","y","ø","ɵ","ʉ","p","t","k","s","ʃ","ɕ","x","m",
          "n","r","l","ʋ","j","ʲ","b","d","g","z","ʒ","f","h","c","ŋ","q","w")
ty <- ty[!is.na(ipa) & nchar(ipa) >= 2L]
ty <- ty[vapply(strsplit(ipa, ""), function(ch) all(ch %chin% OKCH), logical(1))]
att <- ty[freq >= STEM_FLOOR, ipa]

# is a string segmentable into listed suffixes?  (greedy over all splits)
segmentable <- local({
  memo <- new.env(hash = TRUE, parent = emptyenv())
  function(s) {
    if (s == "") return(TRUE)
    if (!is.null(memo[[s]])) return(memo[[s]])
    L <- nchar(s); ok <- FALSE
    for (k in 1:L) {
      h <- substr(s, 1L, k)
      if (h %chin% REF && segmentable(substr(s, k + 1L, L))) { ok <- TRUE; break }
    }
    memo[[s]] <- ok; ok
  }
})

# ---- the cut grid ------------------------------------------------------------
NS <- c(20L, 50L, 100L, 200L, 500L, 1000L, 2000L)
DC <- c(0.00, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70)
grid <- rbindlist(lapply(NS, function(ns) rbindlist(lapply(DC, function(dc) {
  acc <- ind[suf_len >= MIN_SUF & n_stems >= ns & decomposability >= dc, suffix]
  if (!length(acc)) return(NULL)
  listed <- acc %chin% REF
  comb   <- !listed & vapply(acc, segmentable, logical(1))
  REFP <- REF[nchar(REF) >= MIN_SUF]   # recall is only askable of parsable suffixes
  rec <- mean(REFP %chin% acc)
  prc <- mean(listed | comb)
  data.table(min_stems = ns, min_decomp = dc, n_accepted = length(acc),
             n_listed = sum(listed), n_combination = sum(comb),
             n_unexplained = sum(!listed & !comb),
             recall = rec, precision = prc,
             f1 = if (rec + prc > 0) 2*rec*prc/(rec + prc) else 0)
}))))
fwrite(grid, file.path(OUT, "morph_validation.csv"))
best <- grid[which.max(f1)]
cat("== cut grid: agreement with the reference list ==\n")
print(grid[order(-f1)][1:12], digits = 3)
cat(sprintf("\nCHOSEN CUT: n_stems >= %d and decomposability >= %.2f\n",
            best$min_stems, best$min_decomp))
cat(sprintf("  accepted %d  (listed %d, combination %d, unexplained %d)\n",
            best$n_accepted, best$n_listed, best$n_combination, best$n_unexplained))
cat(sprintf("  recall %.3f  precision %.3f  F1 %.3f\n", best$recall, best$precision, best$f1))

ACC <- ind[suf_len >= MIN_SUF & n_stems >= best$min_stems &
           decomposability >= best$min_decomp]
ACC[, category := fifelse(suffix %chin% REF, "listed",
                   fifelse(vapply(suffix, segmentable, logical(1)),
                           "combination", "unexplained"))]
ACC <- ACC[category != "unexplained"]   # corpus evidence AND description
setorder(ACC, -n_stems)
fwrite(ACC[, .(suffix, suf_len, n_stems, n_types, decomposability, category)],
       file.path(OUT, "morph_accepted.csv"))
cat("\n== reference suffixes the induction MISSED ==\n")
missed <- setdiff(REF[nchar(REF) >= MIN_SUF], ACC$suffix)
print(data.table(suffix = missed,
                 n_stems = ind[match(missed, suffix), n_stems],
                 decomp  = round(ind[match(missed, suffix), decomposability], 3)))
cat("\n== accepted but UNEXPLAINED (genuine false positives) ==\n")
print(ACC[category == "unexplained"][1:min(20, .N), .(suffix, n_stems, decomposability)])

# ---- the parse ---------------------------------------------------------------
accset <- ACC$suffix; nst <- setNames(ACC$n_stems, ACC$suffix)
cur <- ty[, .(ipa, orth, freq, stem = ipa, chain = "", n_strip = 0L)]
for (round in seq_len(MAX_STRIP)) {
  work <- cur[n_strip == round - 1L]
  work[, L := nchar(stem)]
  cand <- rbindlist(lapply(MIN_STEM:max(work$L, MIN_STEM), function(k) {
    w <- work[L - k >= MIN_SUF & L - k <= MAX_SUF]
    if (!nrow(w)) return(NULL)
    data.table(ipa = w$ipa, newstem = substr(w$stem, 1L, k),
               suf = substr(w$stem, k + 1L, w$L))
  }))
  if (!nrow(cand)) break
  cand <- cand[suf %chin% accset & newstem %chin% att]
  if (!nrow(cand)) break
  cand[, sc := nst[suf]][, nl := nchar(newstem)]
  setorder(cand, ipa, -sc, -nl)
  pick <- cand[, .SD[1L], by = ipa]
  cur[pick, on = "ipa", `:=`(stem = i.newstem,
                             chain = fifelse(chain == "", i.suf, paste(i.suf, chain, sep = "-")),
                             n_strip = round)]
  cat(sprintf("  strip round %d: %s types stripped\n", round,
              format(nrow(pick), big.mark = ",")))
}
cur[, n_morphs := 1L + n_strip]
cur[, polymorphemic := n_strip > 0L]
fwrite(cur[, .(orth, ipa, freq, stem, suffix_chain = chain, n_morphs, polymorphemic)],
       file.path(OUT, "morph_parse.csv"))

cat("\n== parse summary ==\n")
print(cur[, .(types = .N, tokens = sum(freq),
              pct_types = round(100*.N/nrow(cur), 1)), by = n_morphs][order(n_morphs)])
cat(sprintf("\npolymorphemic: %.1f%% of types, %.1f%% of tokens\n",
            100*mean(cur$polymorphemic), 100*sum(cur$freq[cur$polymorphemic])/sum(cur$freq)))
cat("\n== worked examples ==\n")
ex <- cur[orth %chin% c("каларӗ","пулнӑ","вӗсене","ҫынсем","ҫӑкӑр","пӗрремӗш",
                        "хушшинче","амӑшӗ","лаша","шупашкарта","ҫавӑнпа","каласа")]
print(ex[, .(orth, ipa, stem, chain, n_morphs)])
cat("\n✓ morph_validation.R complete\n")
