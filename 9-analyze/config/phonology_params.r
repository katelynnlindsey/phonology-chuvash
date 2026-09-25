# config/phonology_params.R
# ================================================================
# CENTRAL CONFIGURATION FILE
# Edit this file to change phonological assumptions.
# All pipeline scripts and analyses source this file.
# A change here propagates everywhere without touching analysis code.
# ================================================================

library(stringr)

# ── 1. LABEL MAPPING: ARPAbet (in data) ↔ IPA (for display) ─────

ARPABET_TO_IPA <- c(
  "AA" = "a",   # low back        (а)
  "IY" = "i",   # high front      (и)
  "UX" = "y",   # high front round (ÿ / ӱ)
  "EY" = "e",   # mid front       (е)
  "EH" = "ø",   # mid front round (ӗ)
  "IX" = "ʉ",   # high back       (ы)
  "UW" = "u",   # high back round (у)
  "AH" = "ɵ"    # mid central round (ӑ)
)

IPA_TO_ARPABET        <- setNames(names(ARPABET_TO_IPA), ARPABET_TO_IPA)
TARGET_VOWELS_ARPABET <- names(ARPABET_TO_IPA)
TARGET_VOWELS_IPA     <- unname(ARPABET_TO_IPA)

CONSONANT_TO_IPA <- c(
  "п" = "p", "т" = "t", "ч" = "tɕ", "к" = "k",
  "с" = "s", "ш" = "ʃ", "ҫ" = "ɕ", "ç" = "ɕ",
  "х" = "x", "м" = "m", "н" = "n", "в" = "ʋ",
  "л" = "l", "й" = "j", "р" = "r", "c" = "s"
)

VOWEL_TO_IPA <- c(
  "а" = "a", "и" = "i", "ӳ" = "y", "ĕ" = "ø",
  "ы" = "ʉ", "у" = "u", "ă" = "ɵ", "ӱ" = "y",
  "ӑ" = "ɵ", "ӗ" = "ø", "ӱ" = "y"
)

all_vowel_chars <- c(
  "а","ӑ","е","ӗ","и","ы","у","ӱ","ӳ","э","ю","я",
  "a","e","i","u","y","ӑ"
)

SOFT_SIGNS <- "[ьь]"

transliterate_word <- function(word) {
  w <- word
  
  # 1. word-initial "е" -> "je" (must happen BEFORE general е mapping)
  w <- str_replace(w, "^е", "je")
  
  # 2. palatalized consonants: any consonant + ь -> consonant_ipa + ʲ
  #    (do this before plain consonant substitution so ь isn't stranded)
  for (cons in names(CONSONANT_TO_IPA)) {
    pattern <- paste0(cons, SOFT_SIGNS)
    replacement <- paste0(CONSONANT_TO_IPA[[cons]], "ʲ")
    w <- str_replace_all(w, pattern, replacement)
  }
  
  # 3. hard sign has no sound - delete
  w <- str_remove_all(w, "ъ")
  
  # 4. iotated vowels (single symbol, two-segment output)
  w <- str_replace_all(w, "я", "ja")
  w <- str_replace_all(w, "ю", "ju")
  w <- str_replace_all(w, "э", "e")
  
  # 5. remaining (non-initial) "е" -> "e"
  w <- str_replace_all(w, "е", "e")
  
  # 6. plain consonants and vowels - simple 1:1 lookup
  simple_map <- c(CONSONANT_TO_IPA, VOWEL_TO_IPA)
  for (sym in names(simple_map)) {
    w <- str_replace_all(w, sym, simple_map[[sym]])
  }
  
  w
}

# ── 2. VOWEL FEATURE DIMENSIONS (theory-neutral) ────────────────

VOWEL_HEIGHT <- list(
  high    = c("i", "u", "y", "ʉ"),
  mid     = c("e", "ø", "ɵ"),
  low     = c("a")
)

VOWEL_BACKNESS <- list(
  front   = c("i", "e", "y", "ø"),
  central = c("a"),
  back    = c("u", "ɵ", "ʉ")
)

VOWEL_ROUND  <- c("y", "ø", "u", "ɵ")
VOWEL_UNROUND <- setdiff(TARGET_VOWELS_IPA, VOWEL_ROUND)

# ── 3. VOWEL STRENGTH INVENTORIES ───────────────────────────────
# Each named rule defines which vowels are "strong" (stress-eligible).
# Weak vowels bear stress only when no strong vowel is present.
# Add new rules here; all downstream code uses VOWEL_RULES[[name]].

VOWEL_RULES <- list(

  # Rule A — traditional description: ʉ (ы) is strong
  A = list(
    strong = c("a", "i", "y", "e", "u", "ʉ"),
    weak   = c("ø", "ɵ"),
    label  = "Rule A: ʉ strong"
  ),

  # Rule B — alternative: ʉ (ы) is weak
  B = list(
    strong = c("a", "i", "y", "e", "u"),
    weak   = c("ø", "ɵ", "ʉ"),
    label  = "Rule B: ʉ weak"
  ),

  # Rule C — restrictive: only the four cardinal vowels are strong
  C = list(
    strong = c("a", "i", "e", "u"),
    weak   = c("ø", "ɵ", "y", "ʉ"),
    label  = "Rule C: y, ʉ weak"
  )
)

# ── Active rule: change "A" to "B" or "C" to shift globally ─────
ACTIVE_RULE <- "A"

active_strong <- function(rule = ACTIVE_RULE) VOWEL_RULES[[rule]]$strong
active_weak   <- function(rule = ACTIVE_RULE) VOWEL_RULES[[rule]]$weak

# ── 4. STRESS ASSIGNMENT ────────────────────────────────────────
# Given an ordered vector of IPA vowel labels and a rule name,
# return the 1-based index of the stressed syllable.
# Logic: rightmost strong, else leftmost weak, else NA.

assign_stress <- function(vowel_labels, rule = ACTIVE_RULE) {
  r       <- VOWEL_RULES[[rule]]
  strong  <- which(vowel_labels %in% r$strong)
  weak    <- which(vowel_labels %in% r$weak)
  if (length(strong) > 0) return(max(strong))
  if (length(weak)   > 0) return(min(weak))
  return(NA_integer_)
}

# Apply one rule across a whole dataframe.
# df must have columns: word_id, sidx (1-based), label (IPA).
apply_stress_rule <- function(df, rule = ACTIVE_RULE) {
  col <- paste0("stress_rule_", rule)
  df %>%
    dplyr::group_by(word_id) %>%
    dplyr::mutate(
      .target = assign_stress(vowel_label[order(sidx)], rule),
      !!col   := dplyr::if_else(sidx == .target, "Stressed", "Unstressed")
    ) %>%
    dplyr::ungroup() %>%
    dplyr::select(-.target)
}

# Apply all rules at once (adds stress_rule_A, _B, _C columns)
apply_all_stress_rules <- function(df) {
  for (rule in names(VOWEL_RULES)) df <- apply_stress_rule(df, rule)
  df
}

# ── 5. VOWEL CATEGORY FOR WRITTEN CORPUS (F / R / L) ────────────
# Classifies individual vowel characters in Cyrillic/Latin orthography.
# Used for co-occurrence analyses on Zheltov + monolingual corpus.

VOWEL_CATEGORY_RULES <- list(

  A = list(
    F = c("а","е","a","e","i","u","y","ʉ","и","у","ӱ","ӳ","ю","я"),
    R = c("ø","ɵ","ӗ","ӑ"),
    L = c("o","о","ё","ë","O")
  ),

  B = list(
    F = c("а","е","a","e","i","u","y","и","у","ӱ","ӳ","ю","я"),
    R = c("ø","ɵ","ʉ","ӗ","ӑ","ы"),
    L = c("o","о","ё","ë","O")
  ),

  C = list(
    F = c("а","е","a","e","i","u","и","у","ю","я"),
    R = c("ø","ɵ","y","ʉ","ӗ","ӑ","ы","ӱ","ӳ"),
    L = c("o","о","ё","ë","O")
  )
)

classify_vowel <- function(v, rule = ACTIVE_RULE) {
  cats <- VOWEL_CATEGORY_RULES[[rule]]
  dplyr::case_when(
    v %in% cats$F ~ "F",
    v %in% cats$R ~ "R",
    v %in% cats$L ~ "L",
    TRUE          ~ NA_character_
  )
}

# Build a word-level category string (e.g., "FR", "FFF") from
# an ordered vector of vowel characters under a given rule.
word_category_string <- function(vowel_chars, rule = ACTIVE_RULE) {
  cats <- sapply(vowel_chars, classify_vowel, rule = rule)
  cats <- cats[!is.na(cats) & cats != "L"]   # exclude loan vowels
  paste(cats, collapse = "")
}

# ── 6. DATA CLEANING THRESHOLDS ────────────────────────────────
# Justifications are documented alongside each threshold.

CLEANING <- list(

  # Absolute duration bounds (ms).
  # Below 20 ms: below the threshold for perceptual distinctiveness;
  #   almost certainly a MFA boundary error.
  # Above 400 ms: plausible only for highly emphatic speech or
  #   pausal lengthening; more likely a boundary spanning a silence.
  min_duration_ms  = 20,
  max_duration_ms  = 400,

  # Absolute formant bounds (Hz).
  # Based on expected range for adult speakers of Chuvash.
  min_F1_hz        = 200,
  max_F1_hz        = 1100,
  min_F2_hz        = 500,
  max_F2_hz        = 3500,

  # IQR Tukey fence multiplier for within-cell outlier removal.
  # Applied within vowel × stress_cat × corpus cells.
  iqr_multiplier   = 1.5,

  # Columns to apply IQR removal to (at vowel level)
  iqr_cols         = c("duration", "F1", "F2"),

  # Cells smaller than this are dropped entirely rather than
  # having IQR computed on too few observations.
  min_cell_n       = 5
)

# ── 7. RUSSIAN LOANWORD FILTER ──────────────────────────────────

RUSSIAN_SEQS    <- c("ZH","ts","B","G","D","F","Z","O",
                     "Б","Г","Д","О","Ж","Ц","Ф","З","Ë","ё","Ё","Щ")
ENGLISH_SEQS <- c("B","D","F","G","H","I","K","L","M","N","P","Q","R","S","T","U","V","W","X","Z")
LOAN_SEQS <- c(RUSSIAN_SEQS,ENGLISH_SEQS)
LOAN_PATTERN <- paste(sapply(LOAN_SEQS, stringr::fixed), collapse = "|")

is_loan <- function(word_vec) {
  stringr::str_detect(stringr::str_to_upper(word_vec), LOAN_PATTERN)
}

# ── 8. CORPORA REGISTRY ─────────────────────────────────────────

CORPORA <- list(
  mfa = list(
    type      = "spoken",
    source    = "Chuvash Voice — HuggingFace: alexantonov/chuvash_voice",
    aligner   = "MFA 3.4, Vox Communis chuvash_mfa acoustic model",
    dict      = "Vox Communis chuvash_cv_mfa pronunciation dictionary"
  ),
  vox = list(
    type      = "spoken",
    source    = "Mozilla Common Voice (Chuvash subset)",
    aligner   = "MFA 3.4, Vox Communis chuvash_mfa acoustic model",
    dict      = "Vox Communis chuvash_cv_mfa pronunciation dictionary"
  ),
  zheltov = list(
    type      = "written",
    source    = "Zheltov (1875) wordlist",
    aligner   = "none — lexical data only"
  ),
  mono = list(
    type      = "written",
    source    = "Chuvash monolingual text corpus (HuggingFace)",
    aligner   = "none — lexical data only"
  )
)

SPOKEN_CORPORA  <- names(Filter(function(c) c$type == "spoken",  CORPORA))
WRITTEN_CORPORA <- names(Filter(function(c) c$type == "written", CORPORA))

# ── 9. DISPLAY SETTINGS ─────────────────────────────────────────

VOWEL_COLORS <- c(
  "a" = "#E41A1C", "e" = "#FF7F00", "i" = "#4DAF4A",
  "u" = "#377EB8", "y" = "#984EA3", "ʉ" = "#A65628",
  "ø" = "#F781BF", "ɵ" = "#999999"
)

STRESS_COLORS <- c("Stressed" = "#2166AC", "Unstressed" = "#D6604D")

CORPUS_COLORS <- c(
  "mfa"     = "#1B9E77",
  "vox"     = "#D95F02",
  "zheltov" = "#7570B3",
  "mono"    = "#E7298A"
)

RULE_LABELS <- setNames(
  vapply(VOWEL_RULES, `[[`, character(1), "label"),
  names(VOWEL_RULES)
)

# ═══════════════════════════════════════════════════════════════════════
# SYLLABIFICATION PARAMETERS
# Append to the bottom of config/phonology_params.R.
# Used by 02_clean.R to build word_label_IPA_syllabified, syllable_label,
# and vowel_label across all three corpora.
# ═══════════════════════════════════════════════════════════════════════

# ── Multi-character IPA segments (digraphs / affricates) ───────────────
# The tokeniser greedily matches the LONGEST match first, so order does
# not strictly matter here (we re-sort inside tokenize_ipa), but listing
# longer forms first is good documentation practice.
# !! Adjust to match what your transliterate_word() actually outputs !!
IPA_DIGRAPHS <- c(
  # Tie-bar affricates (U+0361)
  "t͡ʃ", "d͡ʒ", "t͡s",
  # Plain-text affricates
  "tʃ",  "dʒ",  "ts",
  # Palatalized consonants — list ALL that transliterate_word() can produce
  # so that 'ʲ' is never left as a standalone token
  "lʲ",  "nʲ",  "rʲ",
  "sʲ",  "zʲ",  "tʲ",  "dʲ",
  "kʲ",  "ɡʲ",  "gʲ",          # velars
  "mʲ",  "pʲ",  "bʲ",          # labials
  "fʲ",  "vʲ",  "ʋʲ",          # labiodentals
  "xʲ",  "ɣʲ",  "ɕʲ"           # velars / post-alveolars
)

# ── IPA vowel nuclei ────────────────────────────────────────────────────
# Must contain every nucleus symbol produced by ARPABET_TO_IPA AND by
# transliterate_word(). After first run, verify with:
#   unique(unlist(tokenize_ipa_all(z_clean$word_label_IPA))) |> sort()
# and confirm each vowel-like symbol appears here.
IPA_VOWELS <- c(
  "a", "ɑ", "æ",
  "e", "ɛ",
  "ə", "ɘ", "ɵ",
  "i", "ɪ", "ɨ",
  "o", "ɔ",
  "u", "ʊ",
  "ʌ", "ɐ"
)

# ── Sonority scale ──────────────────────────────────────────────────────
# Higher value = more sonorous.
# Segments NOT listed receive NA → fall back to "rightmost C goes to onset".
IPA_SONORITY <- c(
  # Stops
  "p"   = 1L, "b"   = 1L, "t"   = 1L, "d"   = 1L,
  "k"   = 1L, "ɡ"   = 1L, "g"   = 1L, "q"   = 1L,
  "kʲ"  = 1L, "ɡʲ"  = 1L, "gʲ"  = 1L,   # ← NEW
  "pʲ"  = 1L, "bʲ"  = 1L, "tʲ"  = 1L, "dʲ" = 1L,  # ← NEW (tʲ was missing)
  # Affricates
  "t͡s" = 2L, "t͡ʃ" = 2L, "d͡ʒ" = 2L,
  "ts"  = 2L, "tʃ"  = 2L, "dʒ"  = 2L,
  # Fricatives
  "f"   = 3L, "v"   = 3L, "h"   = 3L, "ɦ"   = 3L,
  "s"   = 3L, "z"   = 3L, "ʃ"   = 3L, "ʒ"   = 3L,
  "ɕ"   = 3L, "ʑ"   = 3L,
  "x"   = 3L, "ɣ"   = 3L, "χ"   = 3L, "ʁ"   = 3L,
  "sʲ"  = 3L, "zʲ"  = 3L, "fʲ"  = 3L, "vʲ"  = 3L,  # ← NEW
  "ʋʲ"  = 3L, "xʲ"  = 3L, "ɣʲ"  = 3L, "ɕʲ"  = 3L,  # ← NEW
  # Nasals
  "m"   = 4L, "n"   = 4L, "ŋ"   = 4L, "nʲ"  = 4L,
  "mʲ"  = 4L,                                         # ← NEW
  # Laterals
  "l"   = 5L, "lʲ"  = 5L,
  # Rhotics
  "r"   = 6L, "rʲ"  = 6L,
  # Approximants
  "ʋ"   = 6L,
  "j"   = 7L, "w"   = 7L
)

# ═══════════════════════════════════════════════════════════════════════
# SYLLABIFICATION FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════

#' Tokenize one IPA string into a character vector of segments.
#' Digraphs in `digraphs` are treated as single indivisible units.
tokenize_ipa <- function(s, digraphs = IPA_DIGRAPHS) {
  if (is.na(s) || nchar(s) == 0L) return(character(0L))
  dgs  <- digraphs[order(-nchar(digraphs))]     # longest first
  segs <- character(0L)
  while (nchar(s) > 0L) {
    matched <- FALSE
    for (dg in dgs) {
      if (startsWith(s, dg)) {
        segs    <- c(segs, dg)
        s       <- substr(s, nchar(dg) + 1L, nchar(s))
        matched <- TRUE
        break
      }
    }
    if (!matched) {
      segs <- c(segs, substr(s, 1L, 1L))
      s    <- substr(s, 2L, nchar(s))
    }
  }
  segs
}

#' Convenience wrapper: tokenize a whole character vector → list of segment
#' vectors.  Useful for corpus-wide vowel inventory checks.
tokenize_ipa_all <- function(words, digraphs = IPA_DIGRAPHS) {
  lapply(words, tokenize_ipa, digraphs = digraphs)
}

#' How many segments from the RIGHT end of `cluster` form a valid onset?
#' Valid = single consonant, OR strictly rising sonority with no NA values.
#' Falls back to 1 (single rightmost consonant) if all multi-segment
#' candidates contain unknown sonority values.
.max_onset_size <- function(cluster, sonority = IPA_SONORITY) {
  if (length(cluster) == 0L) 0L else 1L
}

# ══════════════════════════════════════════════════════════════════════
# SYLLABIFICATION BLOCK
# Append to the bottom of config/phonology_params.R
# Used exclusively by pipeline/03_build_levels.R
# ══════════════════════════════════════════════════════════════════════

# ── Multi-character IPA segments (digraphs / affricates) ───────────────
# tokenize_ipa() matches the longest form first, so order within the
# vector does not matter functionally, but longer entries are listed
# first for readability.
# !! Keep in sync with what transliterate_word() actually outputs !!
IPA_DIGRAPHS <- c(
  "t͡ʃ", "d͡ʒ", "t͡s",        # tie-bar affricates  (U+0361 combiner)
  "tʃ",  "dʒ",  "ts",        # plain-text affricates
  "lʲ",  "nʲ",  "rʲ",        # palatalized sonorants
  "sʲ",  "zʲ",  "tʲ",  "dʲ" # palatalized obstruents
)

# ── Vowel nuclei ────────────────────────────────────────────────────────
# Must contain every nucleus symbol that transliterate_word() can produce.
# After a first run, verify completeness with:
#   unique(unlist(tokenize_ipa_all(mono_syl$word_label_IPA))) |>
#     setdiff(c(IPA_VOWELS, names(IPA_SONORITY))) |> sort()
IPA_VOWELS <- c(
  "a", "ɑ", "æ",
  "e", "ɛ",
  "ø", "œ",                 # ← NEW: Chuvash ӗ → ø; add œ for safety
  "ə", "ɘ", "ɵ",
  "i", "ɪ", "ɨ",
  "o", "ɔ",
  "u", "ʊ", "y", "ʉ",      # ← NEW: Chuvash ӳ/ӱ → y
  "ʌ", "ɐ"
)

# ── Sonority scale ──────────────────────────────────────────────────────
# Higher value = more sonorous.
# Segments absent from this table get NA → onset-maximisation falls back
# to the single rightmost consonant rule for that cluster.
IPA_SONORITY <- c(
  # Stops
  "p"   = 1L, "b"   = 1L, "t"   = 1L, "d"   = 1L,
  "k"   = 1L, "ɡ"   = 1L, "g"   = 1L, "q"   = 1L,
  # Affricates — both encodings
  "t͡s" = 2L, "t͡ʃ" = 2L, "d͡ʒ" = 2L,
  "ts"  = 2L, "tʃ"  = 2L, "dʒ"  = 2L,
  # Fricatives
  "f"   = 3L, "v"   = 3L, "h"   = 3L, "ɦ"   = 3L,
  "s"   = 3L, "z"   = 3L, "ʃ"   = 3L, "ʒ"   = 3L,
  "ɕ"   = 3L, "ʑ"   = 3L,
  "x"   = 3L, "ɣ"   = 3L, "χ"   = 3L, "ʁ"   = 3L,
  "sʲ"  = 3L, "zʲ"  = 3L,
  # Nasals
  "m"   = 4L, "n"   = 4L, "ŋ"   = 4L, "nʲ"  = 4L,
  # Laterals
  "l"   = 5L, "lʲ"  = 5L,
  # Rhotics
  "r"   = 6L, "rʲ"  = 6L,
  # Approximants / glides         ← NEW: ʋ (Chuvash в in some positions)
  "ʋ"   = 6L,
  "j"   = 7L, "w"   = 7L
)


# ══════════════════════════════════════════════════════════════════════
# FUNCTIONS
# ══════════════════════════════════════════════════════════════════════

#' Tokenize one IPA string into a character vector of segments.
#' Digraphs in `digraphs` are matched greedily (longest first).
tokenize_ipa <- function(s, digraphs = IPA_DIGRAPHS) {
  if (is.na(s) || nchar(s) == 0L) return(character(0L))
  # Sort by descending length so longer patterns win ties
  dgs  <- digraphs[order(-nchar(digraphs))]
  segs <- character(0L)
  while (nchar(s) > 0L) {
    matched <- FALSE
    for (dg in dgs) {
      if (startsWith(s, dg)) {
        segs    <- c(segs, dg)
        s       <- substr(s, nchar(dg) + 1L, nchar(s))
        matched <- TRUE
        break
      }
    }
    if (!matched) {
      segs <- c(segs, substr(s, 1L, 1L))
      s    <- substr(s, 2L, nchar(s))
    }
  }
  segs
}

#' Vectorised wrapper — returns a list of segment vectors.
#' Useful for inventory checks:  unique(unlist(tokenize_ipa_all(words)))
tokenize_ipa_all <- function(words, digraphs = IPA_DIGRAPHS) {
  lapply(words, tokenize_ipa, digraphs = digraphs)
}

#' How many segments from the RIGHT of `cluster` form a valid onset?
#' Valid = single consonant, OR strictly rising sonority with no unknowns.
.max_onset_size <- function(cluster, sonority = IPA_SONORITY) {
  n <- length(cluster)
  if (n == 0L) return(0L)
  for (k in seq(n, 1L)) {
    cand <- cluster[(n - k + 1L):n]
    s    <- sonority[cand]
    if (k == 1L || (all(!is.na(s)) && all(diff(s) > 0L))) return(k)
  }
  1L
}

#' Syllabify a single IPA word; returns a period-delimited string.
#'
#' Algorithm
#' ---------
#'  1. Each vowel heads exactly one syllable.
#'  2. Onset maximisation: the longest strictly-rising-sonority suffix
#'     of each inter-vocalic cluster goes to the following onset.
#'  3. The prefix of that cluster goes to the preceding coda.
#'  4. Word-initial consonants → onset of syllable 1.
#'  5. Word-final consonants   → coda of the last syllable.
#'
#' "kastrul"  →  "kas.trul"
#' "antrop"   →  "an.trop"
#' "pɑrni"    →  "pɑr.ni"
#' "ka"       →  "ka"
syllabify_ipa <- function(word,
                          digraphs = IPA_DIGRAPHS,
                          vowels   = IPA_VOWELS,
                          sonority = IPA_SONORITY) {
  if (is.na(word) || nchar(trimws(word)) == 0L) return(word)
  
  segs <- tokenize_ipa(word, digraphs)
  n    <- length(segs)
  is_v <- segs %in% vowels
  vpos <- which(is_v)
  n_v  <- length(vpos)
  
  # Monosyllable or vowel-free
  if (n_v <= 1L) return(paste(segs, collapse = ""))
  
  syll <- integer(n)
  for (i in seq_along(vpos)) syll[vpos[i]] <- i
  
  # Word-initial consonants → onset of syllable 1
  if (vpos[1L] > 1L)
    syll[seq_len(vpos[1L] - 1L)] <- 1L
  
  # Word-final consonants → coda of last syllable
  if (vpos[n_v] < n)
    syll[seq(vpos[n_v] + 1L, n)] <- n_v
  
  # Intervocalic clusters
  for (i in seq_len(n_v - 1L)) {
    cs      <- vpos[i] + 1L
    ce      <- vpos[i + 1L] - 1L
    if (cs > ce) next                      # adjacent vowels
    
    cluster <- segs[cs:ce]
    n_c     <- length(cluster)
    on_sz   <- .max_onset_size(cluster, sonority)
    coda_sz <- n_c - on_sz
    
    if (coda_sz > 0L)
      syll[seq(cs,              cs + coda_sz - 1L)] <- i
    if (on_sz  > 0L)
      syll[seq(ce - on_sz + 1L, ce              )] <- i + 1L
  }
  
  parts <- split(segs, syll)
  parts <- parts[order(as.integer(names(parts)))]
  paste(vapply(parts, paste, character(1L), collapse = ""), collapse = ".")
}

#' Extract the vowel nucleus from a single IPA syllable string.
#' Returns NA_character_ if no vowel found.
extract_syllable_vowel <- function(syllable,
                                   vowels   = IPA_VOWELS,
                                   digraphs = IPA_DIGRAPHS) {
  if (is.na(syllable)) return(NA_character_)
  segs <- tokenize_ipa(syllable, digraphs)
  v    <- segs[segs %in% vowels]
  if (length(v) == 0L) NA_character_ else v[[1L]]
}

#' Expand a word-level data frame to one row per syllable.
#'
#' Requires column `word_label_IPA_syllabified` (period-delimited).
#' Adds / overwrites:
#'   sN             — total syllable count in the word
#'   sidx           — 1-based syllable position (integer)
#'   syllable_label — IPA string for onset + nucleus + coda
#'   vowel_label    — nucleus extracted from syllable_label
#'
#' Note: if the input already has sN or sidx those columns are
#' replaced to stay consistent with the syllabified word.
expand_to_syllables <- function(df) {
  df_out <- df %>%
    select(-any_of(c("sN", "sidx"))) %>%      # avoid carry-over conflicts
    mutate(
      syllable_parts = str_split(word_label_IPA_syllabified, fixed(".")),
      sN             = map_int(syllable_parts, length)
    ) %>%
    tidyr::unnest_longer(syllable_parts, indices_to = "sidx") %>%
    rename(syllable_label = syllable_parts) %>%
    mutate(vowel_label = map_chr(syllable_label, extract_syllable_vowel))
  
  n_na <- sum(is.na(df_out$vowel_label))
  if (n_na > 0L)
    message("  ⚠  expand_to_syllables: ", n_na,
            " syllable row(s) have no vowel nucleus — ",
            "check IPA_VOWELS or transliterate_word() output")
  df_out
}

#' Add a syl_position factor column (works for both spoken and written).
#' Requires `sidx` and `sN`.
add_syl_position <- function(df) {
  df %>%
    mutate(
      syl_position = case_when(
        sN == 1    ~ "only",
        sidx == 1  ~ "initial",
        sidx == sN ~ "final",
        TRUE       ~ "medial"
      ) %>%
        factor(levels = c("only", "initial", "medial", "final"))
    )
}