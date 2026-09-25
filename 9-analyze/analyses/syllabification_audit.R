# =============================================================================
# syllabification_audit.R
#
# QUESTION: config/phonology_params.R ships a syllabifier whose docstring
# claims onset maximisation ("the longest strictly-rising-sonority suffix of
# each inter-vocalic cluster goes to the following onset") but whose
# .max_onset_size() returns 1 for any non-empty cluster and ignores its
# `sonority` argument. So IPA_SONORITY is dead code, and the Methods sentence
# in the manuscript -- "onset maximization and sonority-sequencing
# principles" -- describes something the code does not do.
#
# How much does that actually matter? This script implements BOTH algorithms
# and compares their output on every word type in all three corpora.
#
# WHERE THEY DIVERGE. Not only on long clusters. For a medial cluster:
#   V C V      -> both give V.CV                       (never diverges)
#   V C1 C2 V  -> shipped: VC1.C2V
#                 documented: V.C1C2V if sonority(C1) < sonority(C2)
#                             VC1.C2V otherwise
#   V C1 C2 C3 V and longer -> diverge whenever the documented rule finds a
#                 rising-sonority suffix longer than one segment
# So any 2-consonant cluster with rising sonority (/tr/, /kl/, /pr/) already
# diverges. An earlier note in this project said divergence needed 3+
# consonants; that was wrong.
#
# WHY THE SHIPPED RULE IS PROBABLY STILL RIGHT FOR CHUVASH. Chuvash does not
# permit complex onsets in native vocabulary, so VC.CV is the correct parse
# even when the cluster rises in sonority -- i.e. the documented algorithm
# would be WRONG for Chuvash and the shipped one right. The point of this
# audit is to establish the size of the discrepancy so the Methods section can
# describe what the code does and say why.
#
# OUTPUTS (9-analyze/output/)
#   syllabification_audit.csv          per-corpus divergence rates
#   syllabification_clusters.csv       medial cluster size x corpus counts
#   syllabification_examples.csv       the most frequent diverging word types
# =============================================================================

source(here::here("9-analyze", "config", "phonology_params.R"))
source(here::here("9-analyze", "config", "paths.R"))

suppressPackageStartupMessages({
  library(tidyverse)
})

OUT_DIR <- here::here("9-analyze", "output")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ---- 1. The two onset rules -------------------------------------------------

# What the code ships: exactly one consonant to the following onset.
onset_size_shipped <- function(cluster, sonority = IPA_SONORITY) {
  if (length(cluster) == 0L) 0L else 1L
}

# What the docstring and the Methods section describe: the longest suffix of
# the cluster that is a legal onset, where legal = one segment, or strictly
# rising sonority throughout with every segment known to IPA_SONORITY.
onset_size_documented <- function(cluster, sonority = IPA_SONORITY) {
  n <- length(cluster)
  if (n == 0L) return(0L)
  best <- 1L
  for (k in seq(2L, max(2L, n))) {
    if (k > n) break
    suf <- cluster[(n - k + 1L):n]
    s   <- sonority[suf]
    if (anyNA(s)) next
    if (all(diff(as.integer(s)) > 0L)) best <- k
  }
  best
}

# Syllabify with a pluggable onset rule. Mirrors syllabify_ipa() otherwise.
syllabify_with <- function(word, onset_fn,
                           digraphs = IPA_DIGRAPHS, vowels = IPA_VOWELS,
                           sonority = IPA_SONORITY) {
  if (is.na(word) || nchar(trimws(word)) == 0L) return(word)
  segs <- tokenize_ipa(word, digraphs)
  n    <- length(segs)
  vpos <- which(segs %in% vowels)
  n_v  <- length(vpos)
  if (n_v <= 1L) return(paste(segs, collapse = ""))

  syll <- integer(n)
  for (i in seq_along(vpos)) syll[vpos[i]] <- i
  if (vpos[1L] > 1L)  syll[seq_len(vpos[1L] - 1L)] <- 1L
  if (vpos[n_v] < n)  syll[seq(vpos[n_v] + 1L, n)] <- n_v

  for (i in seq_len(n_v - 1L)) {
    cs <- vpos[i] + 1L; ce <- vpos[i + 1L] - 1L
    if (cs > ce) next
    cluster <- segs[cs:ce]
    on_sz   <- min(onset_fn(cluster, sonority), length(cluster))
    coda_sz <- length(cluster) - on_sz
    if (coda_sz > 0L) syll[seq(cs, cs + coda_sz - 1L)] <- i
    if (on_sz  > 0L)  syll[seq(ce - on_sz + 1L, ce)]   <- i + 1L
  }
  parts <- split(segs, syll)
  parts <- parts[order(as.integer(names(parts)))]
  paste(vapply(parts, paste, character(1L), collapse = ""), collapse = ".")
}

# Medial cluster sizes for one word.
medial_clusters <- function(word, digraphs = IPA_DIGRAPHS, vowels = IPA_VOWELS) {
  segs <- tokenize_ipa(word, digraphs)
  vpos <- which(segs %in% vowels)
  if (length(vpos) <= 1L) return(integer(0))
  out <- integer(0)
  for (i in seq_len(length(vpos) - 1L)) {
    gap <- vpos[i + 1L] - vpos[i] - 1L
    out <- c(out, gap)
  }
  out[out > 0L]
}

# ---- 2. Word types from each corpus ----------------------------------------

get_types <- function(file, corpus) {
  d <- readRDS(file.path(PATHS$leveled_dir, file))
  stopifnot("word_label_IPA missing" = "word_label_IPA" %in% names(d))
  d %>%
    distinct(word_label_IPA) %>%
    filter(!is.na(word_label_IPA), nchar(word_label_IPA) > 0) %>%
    transmute(corpus = corpus, ipa = word_label_IPA)
}

types <- bind_rows(
  get_types("zheltov_annotated.rds",       "zheltov"),
  get_types("mono_annotated.rds",          "mono"),
  get_types("vowels_spoken_annotated.rds", "spoken")
)
cat(sprintf("Word types: %s\n",
            paste(sprintf("%s=%d", names(table(types$corpus)),
                          as.integer(table(types$corpus))), collapse = "  ")))

# ---- 3. Compare the two algorithms -----------------------------------------

cat("Syllabifying under both rules (this takes a few minutes)...\n")
types <- types %>%
  mutate(
    syl_shipped    = map_chr(ipa, syllabify_with, onset_fn = onset_size_shipped),
    syl_documented = map_chr(ipa, syllabify_with, onset_fn = onset_size_documented),
    diverges       = syl_shipped != syl_documented,
    max_cluster    = map_int(ipa, ~ { cc <- medial_clusters(.x)
                                      if (length(cc)) max(cc) else 0L })
  )

audit <- types %>%
  group_by(corpus) %>%
  summarise(
    word_types            = n(),
    types_with_medial_CC  = sum(max_cluster >= 2L),
    pct_with_medial_CC    = round(100 * mean(max_cluster >= 2L), 2),
    types_with_medial_CCC = sum(max_cluster >= 3L),
    pct_with_medial_CCC   = round(100 * mean(max_cluster >= 3L), 2),
    types_diverging       = sum(diverges),
    pct_diverging         = round(100 * mean(diverges), 2),
    .groups = "drop"
  )
write_csv(audit, file.path(OUT_DIR, "syllabification_audit.csv"))
cat("\n--- DIVERGENCE BETWEEN SHIPPED AND DOCUMENTED SYLLABIFIER ---\n")
print(as.data.frame(audit), row.names = FALSE)

clusters <- types %>%
  select(corpus, ipa) %>%
  mutate(cc = map(ipa, medial_clusters)) %>%
  unnest_longer(cc) %>%
  count(corpus, cluster_size = cc, name = "n_clusters") %>%
  group_by(corpus) %>%
  mutate(pct = round(100 * n_clusters / sum(n_clusters), 2)) %>%
  ungroup()
write_csv(clusters, file.path(OUT_DIR, "syllabification_clusters.csv"))
cat("\n--- MEDIAL CLUSTER SIZES ---\n")
print(as.data.frame(clusters), row.names = FALSE)

examples <- types %>%
  filter(diverges) %>%
  count(corpus, ipa, syl_shipped, syl_documented, sort = TRUE) %>%
  group_by(corpus) %>% slice_head(n = 12) %>% ungroup()
write_csv(examples, file.path(OUT_DIR, "syllabification_examples.csv"))
cat("\n--- EXAMPLE DIVERGENCES ---\n")
print(as.data.frame(examples %>% select(-n)), row.names = FALSE)

cat("\nWrote 3 CSVs to ", OUT_DIR, "\n", sep = "")
