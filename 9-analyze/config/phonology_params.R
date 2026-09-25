# config/phonology_params.R
# ================================================================
# CENTRAL CONFIGURATION FILE
# Edit this file to change phonological assumptions.
# All pipeline scripts and analyses source this file.
# A change here propagates everywhere without touching analysis code.
# ================================================================

library(stringr)

# ── 0. ENCODING GUARD ───────────────────────────────────────────
# Every vowel identity in this project is an IPA character (ø ɵ ʉ y).
# If the session's native encoding is not UTF-8, string literals
# typed in a script do NOT compare equal to the values stored in the
# .rds files: `vowel_label %in% c("ø","ɵ")` silently matches NOTHING
# and returns zero rows with no error. That failure mode produced a
# wrong "there are no all-reduced words" result during development.
#
# Guarding rather than warning, because a silent zero-match is worse
# than a failed run. If this stops you on a machine where the data
# really is fine, set the locale before sourcing:
#   Sys.setlocale("LC_CTYPE", "en_US.UTF-8")    # macOS / Linux
# On Windows use R >= 4.2, which is UTF-8 natively.
local({
  enc <- toupper(Sys.getenv("LC_ALL", Sys.getenv("LC_CTYPE", "")))
  native_utf8 <- isTRUE(l10n_info()$`UTF-8`)
  if (!native_utf8) {
    stop("Native encoding is not UTF-8 (LC_CTYPE=", Sys.getlocale("LC_CTYPE"),
         ").\n  IPA vowel literals will not match the stored vowel_label ",
         "values, silently.\n  Fix with: ",
         'Sys.setlocale("LC_CTYPE", "en_US.UTF-8")', call. = FALSE)
  }
  invisible(enc)
})

# Belt and braces: assert that the IPA literals this file defines
# survive a round trip, so a mis-encoded *source file* is also caught.
stopifnot(
  "IPA literals in this config are mis-encoded" =
    identical(nchar(c("ø", "ɵ", "ʉ", "y")), c(1L, 1L, 1L, 1L))
)

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

# ════════════════════════════════════════════════════════════════
# 3-5.  STRESS RULES
#
# A candidate stress rule is TWO independent choices, and the old
# A/B/C scheme conflated them into one letter. They are now separate
# objects, and the six named rules are their cross product:
#
#            which vowels count as "full"      what happens in a word
#            (the INVENTORY: 6, 5 or 4)        with no full vowel
#                                              (the DEFAULT: A or B)
#   A6   =   6 full                        x   leftmost reduced
#   A5   =   5 full                        x   leftmost reduced
#   A4   =   4 full                        x   leftmost reduced
#   B6   =   6 full                        x   no stress at all
#   B5   =   5 full                        x   no stress at all
#   B4   =   4 full                        x   no stress at all
#
# This is the naming used in the manuscript and in analyses/. The old
# names map as: vowel_cat_A/B/C -> vowel_cat_6/5/4, and
# stress_rule_A/B/C -> stress_rule_A6/A5/A4 (the old config had no
# equivalent of the B default at all).
#
# Terminology: "full" and "reduced" throughout, matching the
# manuscript. The old config said "strong"/"weak" for the same thing.
# ════════════════════════════════════════════════════════════════

# ── 3. VOWEL INVENTORIES ────────────────────────────────────────
# The three inventories differ only in how far the reduced class
# extends. Each is a substantive phonological hypothesis:

VOWEL_INVENTORIES <- list(

  # 6 full — the traditional description (Krueger 1961): only the two
  # mid central vowels are reduced.
  "6" = list(
    full    = c("a", "e", "i", "u", "y", "ʉ"),
    reduced = c("ø", "ɵ"),
    label   = "6 full (ʉ, y full)"
  ),

  # 5 full — ʉ joins the reduced class. Motivated by word minimality:
  # ʉ never forms an open monosyllable (see manuscript §word-min).
  "5" = list(
    full    = c("a", "e", "i", "u", "y"),
    reduced = c("ø", "ɵ", "ʉ"),
    label   = "5 full (ʉ reduced)"
  ),

  # 4 full — y also joins. Motivated by the phonetic centrality of
  # y ʉ ɵ ø: only the four peripheral vowels remain full.
  "4" = list(
    full    = c("a", "e", "i", "u"),
    reduced = c("ø", "ɵ", "ʉ", "y"),
    label   = "4 full (ʉ, y reduced)"
  )
)

# ── 4. DEFAULT PLACEMENT ────────────────────────────────────────
# Every rule stresses the RIGHTMOST full vowel. They differ only in
# what they do when a word contains no full vowel:

STRESS_DEFAULTS <- list(
  A = list(label = "else leftmost reduced"),  # Krueger 1961
  B = list(label = "else stressless")         # Dobrovolsky 1999
)

# ── 5. THE SIX NAMED RULES ──────────────────────────────────────

STRESS_RULES <- local({
  out <- list()
  for (d in names(STRESS_DEFAULTS)) {
    for (inv in names(VOWEL_INVENTORIES)) {
      nm <- paste0(d, inv)
      out[[nm]] <- list(
        default   = d,
        inventory = inv,
        full      = VOWEL_INVENTORIES[[inv]]$full,
        reduced   = VOWEL_INVENTORIES[[inv]]$reduced,
        label     = paste0(nm, ": rightmost full, ",
                           STRESS_DEFAULTS[[d]]$label,
                           "  [", VOWEL_INVENTORIES[[inv]]$label, "]")
      )
    }
  }
  out[c("A6", "A5", "A4", "B6", "B5", "B4")]
})

RULE_NAMES <- names(STRESS_RULES)

# ── Active rule: any of RULE_NAMES. Governs the single-column
#    convenience outputs (vowel_cat, vowel_class, stressed_position).
#    All six rules are computed regardless, so changing this does not
#    lose information — see pipeline/run_pipeline.R for which stage
#    to re-run.
ACTIVE_RULE <- "A6"

stopifnot(
  "ACTIVE_RULE must be one of A6 A5 A4 B6 B5 B4" =
    ACTIVE_RULE %in% RULE_NAMES
)

rule_full    <- function(rule = ACTIVE_RULE) STRESS_RULES[[rule]]$full
rule_reduced <- function(rule = ACTIVE_RULE) STRESS_RULES[[rule]]$reduced

# Backward-compatible aliases. The legacy root scripts and older
# analyses still call these; new code should use rule_full/rule_reduced.
active_strong <- function(rule = ACTIVE_RULE) rule_full(rule)
active_weak   <- function(rule = ACTIVE_RULE) rule_reduced(rule)

# ── Stress assignment ───────────────────────────────────────────
# Given an ordered vector of IPA vowel labels, return the 1-based
# index of the stressed syllable, or NA.
#
# NA means two different things and the caller must distinguish them:
#   under default A, NA = no vowel was classifiable at all
#   under default B, NA = this word has no full vowel and is therefore
#                         analysed as having NO stressed syllable, so
#                         every syllable in it is Unstressed (not
#                         missing). apply_stress_rule() handles this.

assign_stress <- function(vowel_labels, rule = ACTIVE_RULE) {
  r    <- STRESS_RULES[[rule]]
  full <- which(vowel_labels %in% r$full)
  if (length(full) > 0) return(max(full))
  if (r$default == "B") return(NA_integer_)        # stressless by design
  red  <- which(vowel_labels %in% r$reduced)
  if (length(red) > 0) return(min(red))
  NA_integer_
}

# Apply one rule across a whole dataframe.
# df must have columns: word_id, sidx (1-based), vowel_label (IPA).
#
# A NA target yields "Unstressed" for every syllable of that word
# rather than NA, so rule-B columns carry the same number of usable
# rows as rule-A columns and model fits stay comparable.
apply_stress_rule <- function(df, rule = ACTIVE_RULE) {
  col <- paste0("stress_rule_", rule)
  df %>%
    dplyr::group_by(word_id) %>%
    dplyr::mutate(
      .target = assign_stress(vowel_label[order(sidx)], rule),
      !!col   := dplyr::if_else(!is.na(.target) & sidx == .target,
                                "Stressed", "Unstressed")
    ) %>%
    dplyr::ungroup() %>%
    dplyr::select(-.target)
}

# Adds stress_rule_A6, _A5, _A4, _B6, _B5, _B4.
apply_all_stress_rules <- function(df) {
  for (rule in RULE_NAMES) df <- apply_stress_rule(df, rule)
  df
}

# ── Vowel category F / R / L, by inventory ──────────────────────
# F = full, R = reduced, L = loan-only vowel (excluded from analysis).
#
# Keyed by INVENTORY ("6"/"5"/"4"), not by rule name: the default
# placement has no bearing on how a vowel quality is classified, so
# A6 and B6 share one categorization.
#
# IPA only. The previous version also listed Cyrillic and
# Latin-with-breve graphemes, but every call site passes vowel_label,
# which is IPA, so those entries were unreachable -- and inconsistent
# (Cyrillic ы was absent from inventory 6's F list while present in
# 5's and 4's R lists, which would have silently returned NA for it).
# If you ever need to classify orthographic characters, transliterate
# first with transliterate_word() and classify the IPA.

VOWEL_CATEGORY_RULES <- lapply(VOWEL_INVENTORIES, function(inv) list(
  F = inv$full,
  R = inv$reduced,
  L = c("o", "ɔ")          # /o/ occurs only in Russian loans
))

# `inventory` is "6", "5" or "4"; a rule name like "A6" is also
# accepted and its inventory taken.
.as_inventory <- function(x) {
  if (x %in% names(VOWEL_INVENTORIES)) return(x)
  if (x %in% RULE_NAMES) return(STRESS_RULES[[x]]$inventory)
  stop("not an inventory or rule name: ", x)
}

classify_vowel <- function(v, inventory = ACTIVE_RULE) {
  cats <- VOWEL_CATEGORY_RULES[[.as_inventory(inventory)]]
  dplyr::case_when(
    v %in% cats$F ~ "F",
    v %in% cats$R ~ "R",
    v %in% cats$L ~ "L",
    TRUE          ~ NA_character_
  )
}

# Word-level category string (e.g. "FR", "FFF") from an ordered
# vector of IPA vowel labels.
word_category_string <- function(vowel_labels, inventory = ACTIVE_RULE) {
  cats <- classify_vowel(vowel_labels, inventory)
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
  chuvash_voice = list(            # ← was "mfa"
    type   = "spoken",
    source = "Chuvash Voice — HuggingFace: alexantonov/chuvash_voice",
    aligner = "MFA 3.4, Vox Communis chuvash_mfa acoustic model",
    dict    = "Vox Communis chuvash_cv_mfa pronunciation dictionary"
  ),
  common_voice_chuvash = list(     # ← was "vox"
    type   = "spoken",
    source = "Mozilla Common Voice (Chuvash subset)",
    aligner = "MFA 3.4, Vox Communis chuvash_mfa acoustic model",
    dict    = "Vox Communis chuvash_cv_mfa pronunciation dictionary"
  ),
  zheltov = list(
    type   = "written",
    source = "Zheltov (1875) wordlist",
    aligner = "none — lexical data only"
  ),
  mono = list(
    type   = "written",
    source = "Chuvash monolingual text corpus (HuggingFace)",
    aligner = "none — lexical data only"
  )
)

CORPUS_COLORS <- c(
  "chuvash_voice"        = "#1B9E77",   # ← was "mfa"
  "common_voice_chuvash" = "#D95F02",   # ← was "vox"
  "zheltov"              = "#7570B3",
  "mono"                 = "#E7298A"
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

RULE_LABELS <- setNames(
  vapply(STRESS_RULES, `[[`, character(1), "label"),
  RULE_NAMES
)

# Colour by default placement: the A rules and the B rules are the two
# competing analyses, so they should read as two families in figures.
RULE_COLORS <- c(
  A6 = "#08519C", A5 = "#3182BD", A4 = "#6BAED6",   # blues  = default A
  B6 = "#A50F15", B5 = "#DE2D26", B4 = "#FB6A4A"    # reds   = default B
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
  "t͡ɕ", "t͡ʃ", "d͡ʒ", "t͡s",
  # Plain-text affricates
  #
  # "tɕ" is the one that actually occurs in this data: CONSONANT_TO_IPA maps
  # Chuvash ч -> "tɕ". It was missing from this list, so tokenize_ipa() split
  # the affricate into "t" + "ɕ" and syllabify_ipa() then put the /t/ in one
  # syllable's coda and the /ɕ/ in the next syllable's onset -- splitting a
  # single phoneme across a syllable boundary. 12-18% of word types per corpus
  # contain the sequence, and it left 8,529 vowel rows (2.97% of the spoken
  # data) marked syllable_coda = "closed" with a "coda" that was half an
  # affricate. syllable_coda is a fixed effect in every acoustic model, the
  # basis of the `weight` candidate rule, and the evidence for the minimal-word
  # generalisation, so this was not cosmetic.
  "tɕ",
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
# ── IPA vowel nuclei ─────────────────────────────────────────────────
IPA_VOWELS <- c(
  "a", "ɑ", "æ",
  "e", "ɛ",
  "ø", "œ",           # Chuvash ӗ → ø
  "ə", "ɘ", "ɵ",
  "i", "ɪ", "ɨ",
  "o", "ɔ",
  "u", "ʊ", "y", "ʉ", # Chuvash ӳ/ӱ → y ; Chuvash ы → ʉ
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
  "t͡ɕ" = 2L, "t͡s" = 2L, "t͡ʃ" = 2L, "d͡ʒ" = 2L,
  "tɕ"  = 2L,                      # Chuvash ч — was missing
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