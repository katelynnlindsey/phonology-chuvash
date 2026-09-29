# analyses/minimal_word_internal.R
# ================================================================
# The minimal-word question, with the monolingual corpus cleaned on its OWN
# evidence rather than on the Zheltov wordlist.
#
# THE PROBLEM WITH THE PREVIOUS FIX
# ---------------------------------
# The monolingual corpus contains word FRAGMENTS that are phonotactically legal
# open monosyllables (нӑ, тӑ, лӑ, нӗ, ҫӗ, чӗ), left behind by de-hyphenation
# failures at line breaks, letter-spaced emphasis and Russian passages. The
# earlier fix kept only types attested in Zheltov. That removes the fragments,
# but it also destroys what the two corpora were for: once the monolingual list
# is filtered to Zheltov's vocabulary, the two are answering the same question
# over the same words, and their agreement is guaranteed rather than evidence.
#
# THE INTERNAL CRITERION
# ----------------------
# analyses/wordhood_internal.py scores every monolingual type on six measures
# of syntactic freedom taken from raw text with no lexicon:
# sentence-initial rate, post-punctuation rate, capitalisation rate, number of
# distinct preceding types, harmony agreement with the preceding token, and
# re-attachment to the preceding token WITHIN this corpus.
#
# The decisive measure turns out NOT to be sentence-initial position, which on
# its own gives precision of only 0.19 against Zheltov and does not recover the
# minimal-word asymmetry at all. Adding BREADTH OF LEFT CONTEXT helps — a free
# word combines with many different preceding words, while a stranded suffix
# attaches to a restricted set of stems. Requiring both — a fraction of the base
# rate for sentence-initial position AND at least 200 distinct preceding types
# (count capped at 500, so this is not saturated) — gives precision 0.538 and
# recall 0.457 on the 1,411 open-monosyllable candidates, printed by the sweep
# below and saved to wordhood_thresholds.csv.
#
# That is a modest filter, not a good one: nearly half the types it keeps (18 of
# 39) are absent from Zheltov. Do not quote the figure of 0.875 that an earlier
# version of this header carried — it came from a grid run over ALL monosyllabic
# types, open and closed, and closed monosyllables are overwhelmingly real
# words, so that population is much easier than the one at issue here.
#
# HONEST LIMITATION ON INDEPENDENCE. The CRITERIA are corpus-internal and were
# chosen on linguistic grounds. The THRESHOLDS were picked by looking at
# precision against Zheltov, so the filter is not fully blind to the wordlist.
# What remains independent is the table it produces: every number in it is
# computed from monolingual text, over a vocabulary that is not Zheltov's —
# precision 0.538 means nearly half the kept types are absent from it, and
# recall 0.457 means over half of Zheltov's own open monosyllables are
# excluded. The two vocabularies overlap on 21 types.
#
# Outputs
#   output/minimal_word_internal.csv    the revised table, by vowel
#   output/wordhood_validation.csv      precision/recall against Zheltov
#   output/wordhood_thresholds.csv      sensitivity to the threshold
# ================================================================

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(data.table)

OUT <- PATHS$output_dir
V8 <- c("a", "e", "i", "u", "y", "ø", "ɵ", "ʉ")

wh <- fread(file.path(OUT, "wordhood_internal.csv"), encoding = "UTF-8")
setnames(wh, "type", "token")
wh[, token := normalise_orthography(token)]
cat(sprintf("\nwordhood table: %s types with freq >= 5\n",
            format(nrow(wh), big.mark = ",")))

# ── the base rate a positionally free token would show ─────────────────
# 2,917,415 sentences over 24,002,852 tokens: one token in 8.2 is
# sentence-initial, so an unrestricted type should be near 12.15%.
BASE_INITIAL <- 100 * 2917415 / 24002852
cat(sprintf("corpus base rate for sentence-initial position: %.2f%%\n", BASE_INITIAL))
wh[, rel_initial := pct_sentence_initial / BASE_INITIAL]

# ── candidates: open monosyllables, by the pipeline's own syllabifier ──
ma <- as.data.table(mono_ann)
cand <- unique(ma[sN == 1L & syllable_coda == "open" & vowel_label %in% V8,
                  .(token = normalise_orthography(word_label),
                    vowel_label, corpus_freq)])
cat(sprintf("open-monosyllable types from the syllabifier: %s\n",
            format(uniqueN(cand$token), big.mark = ",")))
cand <- merge(cand, wh, by = "token", all.x = TRUE)

# ── validate against Zheltov, held out ─────────────────────────────────
wl <- unique(normalise_orthography(as.data.table(zheltov)$word))
cand[, in_wordlist := as.integer(token %in% wl)]
thr <- data.table(threshold = c(0.02, 0.05, 0.10, 0.20, 0.35, 0.50))
val <- rbindlist(lapply(thr$threshold, function(k) {
  keep <- !is.na(cand$rel_initial) & cand$rel_initial >= k &
    !is.na(cand$n_distinct_prev) & cand$n_distinct_prev >= 200L
  tp <- sum(keep & cand$in_wordlist == 1L)
  fp <- sum(keep & cand$in_wordlist == 0L)
  fn <- sum(!keep & cand$in_wordlist == 1L)
  tn <- sum(!keep & cand$in_wordlist == 0L)
  data.table(threshold = k, kept = sum(keep),
             precision = round(tp / max(tp + fp, 1), 3),
             recall = round(tp / max(tp + fn, 1), 3),
             tp = tp, fp = fp, fn = fn, tn = tn)
}))
fwrite(val, file.path(OUT, "wordhood_thresholds.csv"))
cat("\n== the internal filter scored against Zheltov (held out) ==\n")
print(val)

K <- 0.05        # a twentieth of the base rate for sentence-initial position
KPREV <- 200L    # distinct preceding types, out of a sampling cap of 500
cand[, free_word := as.integer(!is.na(rel_initial) & rel_initial >= K &
                                 !is.na(n_distinct_prev) &
                                 n_distinct_prev >= KPREV)]
cat(sprintf("\nfilter: rel_initial >= %.2f (%.2f%% sentence-initial) AND >= %d distinct preceding types\n",
            K, K * BASE_INITIAL, KPREV))

cat("\n== what the filter rejects, most frequent 12 ==\n")
print(cand[free_word == 0L][order(-corpus_freq)][1:12,
      .(token, vowel_label, corpus_freq, pct_sentence_initial,
        pct_after_punct, pct_reattach_mono, in_wordlist)])
cat("\n== what it keeps, most frequent 12 ==\n")
print(cand[free_word == 1L][order(-corpus_freq)][1:12,
      .(token, vowel_label, corpus_freq, pct_sentence_initial,
        pct_after_punct, pct_reattach_mono, in_wordlist)])

# ── the revised minimal-word table ─────────────────────────────────────
# Denominator: all monosyllabic types with that vowel, open or closed.
allmono <- unique(ma[sN == 1L & vowel_label %in% V8,
                     .(token = normalise_orthography(word_label),
                       vowel_label, syllable_coda)])
allmono <- merge(allmono, wh[, .(token, rel_initial)], by = "token", all.x = TRUE)
allmono <- merge(allmono, wh[, .(token, n_distinct_prev)], by = "token",
                 all.x = TRUE)
allmono[, free_word := as.integer(!is.na(rel_initial) & rel_initial >= K &
                                    !is.na(n_distinct_prev) &
                                    n_distinct_prev >= KPREV)]
allmono[, in_wordlist := as.integer(token %in% wl)]

tab <- allmono[, .(
  n_mono_all = .N,
  pct_open_all = round(100 * mean(syllable_coda == "open"), 2),
  n_mono_free = sum(free_word),
  pct_open_free = round(100 * mean(syllable_coda[free_word == 1L] == "open"), 2),
  n_mono_wordlist = sum(in_wordlist),
  pct_open_wordlist = round(100 * mean(syllable_coda[in_wordlist == 1L] == "open"), 2)
), by = .(vowel = vowel_label)][order(match(vowel, V8))]
fwrite(tab, file.path(OUT, "minimal_word_internal.csv"))
cat("\n════ open-syllable share of monosyllabic types, three filters ════\n")
print(tab)
cat("\nThe middle column is the new one: the monolingual corpus cleaned on its\n")
cat("own evidence. The right-hand column is the Zheltov-filtered version, kept\n")
cat("only for comparison — it is not independent of the wordlist.\n")
cat(sprintf("\nSpearman rho between the internal and wordlist orderings: %+.3f\n",
            cor(tab$pct_open_free, tab$pct_open_wordlist, method = "spearman",
                use = "complete.obs")))
cat("\n✓ minimal_word_internal.R complete\n")
