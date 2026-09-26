# ══════════════════════════════════════════════════════════════════════
# inventory_phonotactics.R
#
# Segment inventory and phonotactic summary across all four corpora.
#
# The spoken half of the inventory comes from the aligner's own phone tier
# (output/inventory_spoken_phones.csv, built by the TextGrid census) rather
# than from the R transliteration, because the aligner is the source of truth
# for what was actually measured — and because it labels geminates, which the
# recode step then collapses.
#
# Outputs
#   output/inventory_segments.csv          segment x corpus, tokens and types
#   output/phonotactics_syllable_shapes.csv  CV shape x corpus x word position
#   output/phonotactics_clusters.csv       medial cluster inventory
#   output/phonotactics_edges.csv          word-initial / word-final segments
#   output/fig_inventory.png
#   output/fig_phonotactics.png
# ══════════════════════════════════════════════════════════════════════

source(here::here("9-analyze", "analyses", "00_session_setup.R"))

library(stringr)
library(purrr)

OUT <- PATHS$output_dir

# ── 1. SEGMENT INVENTORY ──────────────────────────────────────────────
# Written corpora: tokenise the IPA of each word type, weight by frequency.

seg_counts <- function(df, corpus_name, freq_col = NULL) {
  words <- unique(df$word_label_IPA)
  segs  <- tokenize_ipa_all(words)
  names(segs) <- words
  long <- tibble::tibble(
    word_label_IPA = rep(names(segs), lengths(segs)),
    segment        = unlist(segs, use.names = FALSE)
  )
  wt <- df %>%
    distinct(word_label_IPA, .keep_all = TRUE) %>%
    transmute(word_label_IPA,
              freq = if (!is.null(freq_col) && freq_col %in% names(df))
                       coalesce(.data[[freq_col]], 1) else 1)
  long %>%
    left_join(wt, by = "word_label_IPA") %>%
    group_by(segment) %>%
    summarise(corpus = corpus_name,
              n_types  = n_distinct(word_label_IPA),
              n_tokens = sum(freq, na.rm = TRUE),
              .groups = "drop")
}

written_seg <- bind_rows(
  seg_counts(zheltov_ann %>% distinct(word_label_IPA, corpus_freq),
             "zheltov", "corpus_freq"),
  seg_counts(mono_ann %>% distinct(word_label_IPA, corpus_freq),
             "mono", "corpus_freq")
)

# `source` is base::source() here, so address the column explicitly.
.sp <- readr::read_csv(file.path(OUT, "inventory_spoken_phones.csv"),
                       show_col_types = FALSE)
.sp <- as.data.frame(.sp)
names(.sp)[names(.sp) == "source"] <- "grid_set"
stopifnot("grid_set" %in% names(.sp))
spoken_seg <- .sp %>%
  filter(grid_set == "spoken_textgrid_preRecode") %>%
  # The grids are in the aligner's IPA, which transcribes four of the eight
  # vowels differently from this config. Translate before the two halves of
  # the inventory are put in one table.
  transmute(segment = from_aligner_ipa(ipa), corpus,
            n_types = NA_integer_, n_tokens = n) %>%
  group_by(segment, corpus) %>%
  summarise(n_types = NA_integer_, n_tokens = sum(n_tokens), .groups = "drop")

inventory <- bind_rows(written_seg, spoken_seg) %>%
  mutate(
    is_geminate = str_detect(segment, "ː"),
    base        = str_remove(segment, "ː"),
    class       = if_else(base %in% IPA_VOWELS, "vowel", "consonant")
  ) %>%
  arrange(class, desc(n_tokens))

readr::write_csv(inventory, file.path(OUT, "inventory_segments.csv"))
cat(sprintf("inventory_segments.csv: %d rows, %d distinct segments\n",
            nrow(inventory), n_distinct(inventory$segment)))

# ── 2. SYLLABLE SHAPES ────────────────────────────────────────────────
# Each syllable of the syllabified IPA is recoded as a C/V template.

shape_of <- function(syllable) {
  segs <- tokenize_ipa(syllable)
  paste0(if_else(segs %in% IPA_VOWELS, "V", "C"), collapse = "")
}

shapes_for <- function(df, corpus_name, freq_col = NULL) {
  d <- df %>% distinct(word_label_IPA_syllabified, .keep_all = TRUE)
  syl <- str_split(d$word_label_IPA_syllabified, fixed("."))
  freq <- if (!is.null(freq_col) && freq_col %in% names(d))
            coalesce(d[[freq_col]], 1) else rep(1, nrow(d))
  tibble::tibble(
    corpus   = corpus_name,
    word     = rep(d$word_label_IPA_syllabified, lengths(syl)),
    freq     = rep(freq, lengths(syl)),
    sidx     = unlist(lapply(lengths(syl), seq_len)),
    sN       = rep(lengths(syl), lengths(syl)),
    syllable = unlist(syl)
  ) %>%
    mutate(shape = map_chr(syllable, shape_of),
           position = case_when(sN == 1 ~ "only",
                                sidx == 1 ~ "initial",
                                sidx == sN ~ "final",
                                TRUE ~ "medial"))
}

shapes <- bind_rows(
  shapes_for(zheltov_ann, "zheltov", "corpus_freq"),
  shapes_for(mono_ann,    "mono",    "corpus_freq"),
  shapes_for(words %>% mutate(corpus_freq = 1L), "spoken")
)

# n_syllables counts each syllable of each distinct WORD TYPE once, so the
# type column is not dominated by frequent words; n_tokens weights by corpus
# frequency. (`count(wt = 1)` would sum the constant 1 per group and return 1
# for every shape.)
shape_tab <- shapes %>%
  group_by(corpus, position, shape) %>%
  summarise(n_syllables      = n(),
            n_syllable_types = n_distinct(syllable),
            n_tokens         = sum(freq),
            .groups = "drop") %>%
  group_by(corpus, position) %>%
  mutate(pct_types  = 100 * n_syllables / sum(n_syllables),
         pct_tokens = 100 * n_tokens    / sum(n_tokens)) %>%
  ungroup() %>%
  arrange(corpus, position, desc(n_syllables))

readr::write_csv(shape_tab, file.path(OUT, "phonotactics_syllable_shapes.csv"))
cat(sprintf("phonotactics_syllable_shapes.csv: %d rows, %d distinct shapes\n",
            nrow(shape_tab), n_distinct(shape_tab$shape)))

# ── 3. MEDIAL CLUSTERS ────────────────────────────────────────────────
# Consonant runs between two vowels, taken from the unsyllabified IPA so the
# result does not depend on the syllabifier's decisions.

clusters_for <- function(df, corpus_name, freq_col = NULL) {
  d <- df %>% distinct(word_label_IPA, .keep_all = TRUE)
  freq <- if (!is.null(freq_col) && freq_col %in% names(d))
            coalesce(d[[freq_col]], 1) else rep(1, nrow(d))
  segs <- tokenize_ipa_all(d$word_label_IPA)
  out  <- vector("list", length(segs))
  for (i in seq_along(segs)) {
    s  <- segs[[i]]
    iv <- which(s %in% IPA_VOWELS)
    if (length(iv) < 2) { out[[i]] <- NULL; next }
    cl <- character(0)
    for (k in seq_len(length(iv) - 1)) {
      run <- s[(iv[k] + 1):(iv[k + 1] - 1)]
      if (length(run)) cl <- c(cl, paste0(run, collapse = ""))
    }
    if (length(cl))
      out[[i]] <- tibble::tibble(cluster = cl, freq = freq[i])
  }
  bind_rows(out) %>%
    mutate(corpus = corpus_name,
           size   = map_int(cluster, ~ length(tokenize_ipa(.x))))
}

clusters <- bind_rows(
  clusters_for(zheltov_ann, "zheltov", "corpus_freq"),
  clusters_for(mono_ann,    "mono",    "corpus_freq"),
  clusters_for(words,       "spoken")
)

cluster_tab <- clusters %>%
  group_by(corpus, cluster, size) %>%
  summarise(n_types = n(), n_tokens = sum(freq), .groups = "drop") %>%
  group_by(corpus) %>%
  mutate(pct_types = 100 * n_types / sum(n_types)) %>%
  ungroup() %>%
  arrange(corpus, desc(n_types))

readr::write_csv(cluster_tab, file.path(OUT, "phonotactics_clusters.csv"))
cat(sprintf("phonotactics_clusters.csv: %d rows\n", nrow(cluster_tab)))

# ── 4. WORD EDGES ─────────────────────────────────────────────────────
edges_for <- function(df, corpus_name, freq_col = NULL) {
  d <- df %>% distinct(word_label_IPA, .keep_all = TRUE)
  freq <- if (!is.null(freq_col) && freq_col %in% names(d))
            coalesce(d[[freq_col]], 1) else rep(1, nrow(d))
  segs <- tokenize_ipa_all(d$word_label_IPA)
  keep <- lengths(segs) > 0
  tibble::tibble(
    corpus = corpus_name,
    freq   = freq[keep],
    first  = map_chr(segs[keep], 1),
    last   = map_chr(segs[keep], ~ .x[length(.x)])
  )
}

edges <- bind_rows(
  edges_for(zheltov_ann, "zheltov", "corpus_freq"),
  edges_for(mono_ann,    "mono",    "corpus_freq"),
  edges_for(words,       "spoken")
)

edge_tab <- bind_rows(
  edges %>% count(corpus, segment = first, wt = freq, name = "n_tokens") %>%
    mutate(edge = "word-initial"),
  edges %>% count(corpus, segment = last, wt = freq, name = "n_tokens") %>%
    mutate(edge = "word-final")
) %>%
  group_by(corpus, edge) %>%
  mutate(pct = 100 * n_tokens / sum(n_tokens)) %>%
  ungroup() %>%
  mutate(class = if_else(segment %in% IPA_VOWELS, "vowel", "consonant")) %>%
  arrange(corpus, edge, desc(n_tokens))

readr::write_csv(edge_tab, file.path(OUT, "phonotactics_edges.csv"))
cat(sprintf("phonotactics_edges.csv: %d rows\n", nrow(edge_tab)))

cat("\n✓ inventory_phonotactics.R complete\n")
