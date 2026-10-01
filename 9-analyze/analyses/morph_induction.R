# =============================================================================
# morph_induction.R                                                 2026-10-01
#
# AN INDUCED MORPHOLOGICAL PARSE OF THE CHUVASH WORDLIST, because there is no
# morphological annotation anywhere in this project's data and the shape-class
# and contour-step results both have a morphology confound that cannot be
# checked without one: the reduced vowels that define the right edge of the
# penultimate and antepenultimate classes are overwhelmingly SUFFIXAL, so
# "word shape" and "morphological structure" co-vary.
#
# THE HYPOTHESIS BEING OPERATIONALISED.  Chuvash is agglutinating and
# exclusively suffixing, so a polymorphemic word is a shorter attested word
# plus a string that recurs across many other words in the same position.  A
# monomorphemic word is one with no such decomposition.  This is the
# Harris/Goldsmith signature idea: morpheme boundaries are where the
# conditional predictability of the next character collapses, which shows up as
# one residue string attaching to many distinct stems.
#
# TWO DESIGN DECISIONS THAT MATTER FOR CIRCULARITY.
#   (1) Induction runs on the PHONEMIC form (word_label_IPA), not Cyrillic
#       orthography.  Kate has been explicit that the analysis should not rest
#       on orthography, and the phonemic form is also what the spoken data is
#       represented in, so the join downstream is exact.
#   (2) NO VOWEL-QUALITY INFORMATION IS USED ANYWHERE.  The scoring is pure
#       string recurrence.  This is essential: Chuvash suffixes carry reduced
#       vowels, so a parser that knew about vowel quality would reproduce the
#       shape classes it is supposed to provide an independent check on.
#
# WHAT IS AND IS NOT DECIDED HERE.  This script computes CONTINUOUS scores for
# every candidate suffix and writes them out.  It deliberately does NOT choose
# an acceptance cut -- that is done in morph_validation.R by maximising
# agreement with an independently curated list of Chuvash inflectional
# suffixes, so the cut is fixed by linguistic knowledge rather than tuned on
# the stress result.
#
# SCORES per candidate suffix s:
#   n_stems          distinct attested stems it attaches to -- the signature
#                    productivity measure
#   n_types          word types decomposable as (attested stem) + s
#   n_ending         word types ending in s, whether decomposable or not
#   decomposability  n_types / n_ending.  A real suffix should leave a real
#                    word behind most of the time; a frequent accidental
#                    string ending (e.g. a stem-final sequence) should not.
#   tok_weighted     token frequency carried by the decomposable types
#
# SENSITIVITY.  n_stems is recomputed at stem-attestation floors of 1, 2, 5, 10
# and 20 corpus tokens, and the rank correlation between floors is reported, so
# the ranking's dependence on that floor is visible rather than assumed away.
#
# Outputs
#   output/induced_suffixes.csv       every candidate with its scores
#   output/morph_induction_sens.csv   rank stability across stem floors
# =============================================================================
suppressMessages({library(data.table)})
OUT <- "output"
MAX_SUF <- 8L     # longest single strip considered; longer sequences are
                  # reached by recursive stripping in morph_validation.R
MIN_STEM <- 2L    # a one-phoneme stem is not a Chuvash root

m <- as.data.table(readRDS("data/leveled/mono_annotated.rds"))
ty <- unique(m[, .(orth = word_label, ipa = word_label_IPA, freq = corpus_freq)])
rm(m); invisible(gc())
n_raw <- nrow(ty)

# keep only types written entirely in the project's phoneme inventory; the
# wordlist carries a small amount of code-switched Latin material and a
# residual soft sign
OKCH <- c("a","e","i","o","u","y","ø","ɵ","ʉ","p","t","k","s","ʃ","ɕ","x","m",
          "n","r","l","ʋ","j","ʲ","b","d","g","z","ʒ","f","h","c","ŋ","q","w")
ty <- ty[!is.na(ipa) & nchar(ipa) >= 2L]
ty[, clean := vapply(strsplit(ipa, ""), function(ch) all(ch %chin% OKCH), logical(1))]
ty <- ty[clean == TRUE][, clean := NULL]
setorder(ty, -freq)
cat(sprintf("types: %s raw -> %s in-inventory (%.1f%%)\n",
            format(n_raw, big.mark=","), format(nrow(ty), big.mark=","),
            100*nrow(ty)/n_raw))

# ---- candidate splits --------------------------------------------------------
ty[, L := nchar(ipa)]
cands <- rbindlist(lapply(MIN_STEM:(max(ty$L) - 1L), function(k) {
  t <- ty[L > k & L - k <= MAX_SUF]
  if (!nrow(t)) return(NULL)
  data.table(ipa = t$ipa, freq = t$freq,
             stem = substr(t$ipa, 1L, k), suffix = substr(t$ipa, k + 1L, t$L))
}))
cat(sprintf("candidate splits: %s\n", format(nrow(cands), big.mark=",")))

# how often does each string occur as a word ending at all?  (denominator of
# decomposability -- computed BEFORE the attestation filter)
n_ending <- cands[, .(n_ending = uniqueN(ipa)), by = suffix]

# ---- scores at several stem-attestation floors ------------------------------
FLOORS <- c(1L, 2L, 5L, 10L, 20L)
score_at <- function(fmin) {
  att <- ty[freq >= fmin, ipa]
  cc <- cands[stem %chin% att]
  cc[, .(n_stems = uniqueN(stem), n_types = uniqueN(ipa),
         tok_weighted = sum(freq)), by = suffix][, floor := fmin][]
}
sc <- rbindlist(lapply(FLOORS, score_at))

main <- sc[floor == 2L]                       # the reported scoring
main <- merge(main, n_ending, by = "suffix", all.x = TRUE)
main[, decomposability := n_types / n_ending]
main[, suf_len := nchar(suffix)]
setorder(main, -n_stems)
main[, rank_n_stems := .I]
fwrite(main[, .(suffix, suf_len, n_stems, n_types, n_ending, decomposability,
                tok_weighted, rank_n_stems)],
       file.path(OUT, "induced_suffixes.csv"))

# rank stability across floors
w <- dcast(sc, suffix ~ floor, value.var = "n_stems", fill = 0L)
setnames(w, as.character(FLOORS), paste0("f", FLOORS))
sens <- rbindlist(lapply(setdiff(FLOORS, 2L), function(f) {
  a <- w[["f2"]]; b <- w[[paste0("f", f)]]
  data.table(floor_vs_2 = f, n_suffixes = nrow(w),
             spearman = cor(a, b, method = "spearman"),
             top50_overlap = length(intersect(
               w$suffix[order(-a)][1:50], w$suffix[order(-b)][1:50])))
}))
fwrite(sens, file.path(OUT, "morph_induction_sens.csv"))

cat(sprintf("\ncandidate suffixes scored: %s\n", format(nrow(main), big.mark=",")))
cat("\n== top 30 induced suffixes by number of distinct stems ==\n")
print(main[1:30, .(suffix, suf_len, n_stems, n_types, n_ending,
                   decomp = round(decomposability, 3))])
cat("\n== rank stability of n_stems across stem-attestation floors ==\n")
print(sens, digits = 4)
cat("\n✓ morph_induction.R complete\n")
