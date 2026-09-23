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
      .target = assign_stress(label[order(sidx)], rule),
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