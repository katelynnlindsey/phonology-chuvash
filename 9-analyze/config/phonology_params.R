# config/phonology_params.R
# ================================================================
# CENTRAL CONFIGURATION FILE
# Edit this file to change phonological assumptions.
# All pipeline scripts and analyses source this file.
# A change here propagates everywhere without touching analysis code.
# ================================================================

# ════════════════════════════════════════════════════════════════
# FINDINGS AND STANDING HYPOTHESES                     rev. 2026-10-01
#
# A register of what the project has established, what it has withdrawn, and
# the traps that have cost real results. Every entry names the canonical output
# so nothing here has to be taken on trust. Nothing in this block is executed.
#
# ── THE THREE CUES, AND WHAT EACH ONE TRACKS ────────────────────
# Kate's criterion: stress correlates with LONGER duration, HIGHER intensity
# and HIGHER pitch. A trend the other way may show a syllable behaving
# idiosyncratically but must not be called stress.
#   DURATION tracks the RULE.    Best-identified result in the project.
#   INTENSITY tracks POSITION.   Peaks on syllable 2 in 13 of 14 class x length
#                                cells; null for designation under the strict
#                                specification. No effect anywhere in 36 models
#                                reaches the 3 dB JND (Moore 2007); the largest
#                                is B6 at 1.335 dB.
#   f0 tracks WORD-INITIAL position and BOUNDARIES. Peaks on syllable 1 at
#                                every word length; no syllable-2 peak.
#   -> output/step_vowel_stratified.csv, position_cell_means.csv,
#      f0_position_cell_means.csv, full_word_rule_models.csv
#
# ── THE HEADLINE DURATION RESULT ────────────────────────────────
# With strata = (word length x syllable index x TARGET VOWEL), the within-word
# duration step UP INTO the rule's designated syllable is +21.32 ms (t 17.2)
# and the step out of it −13.58 ms (t −5.9). Non-circular: designation depends
# on vowels to the RIGHT of the step, which are in neither the step nor the
# strata. Clears Hirsh's (1959) 10 ms JND. Survives restriction to words with
# no suffix parsed: +19.12 ms (t 11.3).
#   -> output/step_vowel_stratified.csv, morph_stress_test.csv
#
# ── WHICH DEFAULT: A OR B ───────────────────────────────────────
# Two of three cues favour B (stressless when no full vowel):
#   duration  B5 first   (full_word_rule_models.csv)
#   f0        B6/B5/B4 first, both control sets  (f0_rule_models.csv)
#   intensity A6 first   (full_word_rule_models.csv)
# Independent supports for B: default_adjudication.R (inventory-5 f0 −2.524 Hz,
# t −4.17) and monosyllable_default_test.R.
#
# ── WITHDRAWN, AND MUST NOT BE REINSTATED ───────────────────────
#  * total_intensity and peak_intensity as prominence measures. Use
#    int_midpoint (mean of intensity steps 10 and 11). A 161.90 "dB" effect in
#    an early draft was a sum over 20 steps.
#  * The mora / zero-vs-one-mora conclusion. Needs designed elicitation.
#  * The claim that F3 confirms Krueger's high back row — circular, see the
#    VOWEL_ROUND block below.
#  * Three scripts superseded in full, with ⚠⚠ headers: rule_conflict_models.R,
#    rule_conflict_robustness.R, rule_conflict_extended.R.
#   -> output/SUPERSEDED.md, script_currency_audit.md
#
# ── IDENTIFICATION: WHAT CANNOT BE TESTED, AND WHY ──────────────
#  * `final` is UNTESTABLE against a linear position trend: 1{sidx == sN} is
#    IDENTICAL to syl_final on all 574,344 rows (phi = 1.0000). It becomes
#    identified only when position is entered NONPARAMETRICALLY, because the
#    predicate is then a deterministic but NONLINEAR function of position.
#  * `initial` is NOT IDENTIFIED under nonparametric position at all —
#    1{sidx == 1} is the complement of the factor(sidx) dummies (rank 14 of 15).
#    lmer drops collinear columns SILENTLY; rank-check before trusting any fit.
#  * The within-cell designation test is IMPOSSIBLE for the A/B family in
#    word-final position: a final syllable is designated iff its own vowel is
#    full, so stratifying on vowel leaves zero variation. Only a sonority rule
#    can be tested there.
#   -> output/rule_final_collinearity.csv, final_prominence_rule_ranking.csv
#
# ── CONTROLS THAT DESTROY WHAT THEY ARE MEANT TO TEST ───────────
#  * Any model with vowel_label as an ADDITIVE covariate cannot test an A/B
#    rule, because designation is DEFINED on vowel fullness. The shape-class
#    "controlled" model has this property, which is why its failure to
#    reproduce the leftward duration walk is not evidence against the rule.
#    STRATIFY on the vowel instead of adjusting for it.
#  * Word-final position: the f0 elevation (+6.11 Hz) REVERSES SIGN at the
#    utterance edge (+10.82 Hz word-internal, −21.41 Hz utterance-final). That
#    is a boundary tone; lexical stress cannot flip sign with utterance
#    position. Duration's +11.70 ms is boundary lengthening for the same
#    reason.
#   -> output/f0_endpoint_test.csv, shape_peak_match.csv
#
# ── THREE COMPLETENESS FIGURES THAT MUST NEVER BE CONFLATED ─────
#   61.1%  (185,087 of 303,139) word tokens with n_syl_present == sN
#   49.7%  (150,704 of 303,139) word tokens with word_complete == TRUE
#   51.3%  share of VOWEL ROWS (of 574,344) whose word is complete
# Any design conditioning on word shape must filter on word_complete and use
# the pipeline's sN, never a count of surviving rows.
#
# ── MEASUREMENT GRANULARITY ─────────────────────────────────────
# Vowel duration is quantised at 10 ms by the extraction grid, which happens to
# equal Hirsh's duration JND. A short word can therefore have every syllable at
# an identical duration, making "first syllable above the word's own mean"
# undefined for 5.5-9.7% of disyllabic tokens. which.max() breaks ties
# LEFTWARD, which biases any per-token peak statistic toward the designated
# syllable — count strict maxima only.
#
# ── f0 ──────────────────────────────────────────────────────────
# f0_mid = mean of f0_step10 and f0_step11 (the exact analogue of
# int_midpoint), in semitones relative to the SPEAKER's own median. 98.1% of
# vowels usable; 3,518 octave outliers (|st| > 12) removed. Within-speaker
# normalisation makes the open question about the Chuvash Voice dominant
# speaker's sex MOOT downstream. Gandour's (1978) 1 Hz JND is 0.079 semitones
# at this corpus's 217.9 Hz median.
#   -> output/f0_measure_diagnostics.csv
#
# ── MORPHOLOGY ──────────────────────────────────────────────────
# No corpus carries morphological annotation; the parse is INDUCED from string
# recurrence over 430,008 monolingual types, on the PHONEMIC form and using NO
# vowel-quality information (which would make it circular with the shape
# classes). Only suffixes of >= 2 phonemes are parsed, because string
# recurrence cannot distinguish a single-phoneme suffix from a stem-final
# phoneme; the monomorphemic class is therefore really "no confident parse".
# The reference suffix list in analyses/morph_validation.R HAS NOT BEEN CHECKED
# BY A SPECIALIST and needs Kate's review.
#   -> output/methods_morphology.md
#
# ── SHAPE CLASSES ───────────────────────────────────────────────
# Defined by from_end = sN − (position of the rightmost full vowel), NOT by
# strict F/R strings, and computed under both the 5-full and 6-full
# inventories. Adding /ʉ/ ⟨ы⟩ to the full set moves 2.1% of word tokens, almost
# all of them disyllables leaving the stressless class for the
# initially-stressed one.
#   -> output/shape_class_counts.csv
#
# ── THE SONORITY RULES ──────────────────────────────────────────
# SON's case rests on FORMULATION, not fit: B5 leads three of four
# subset x control combinations and SON ranks below the A/B family on all three
# cues. The de Lacy/Kenstowicz hierarchy is recovered from the spoken data
# threshold-free (peripherality class 8/8, whole hierarchy rho = +0.970), which
# is what makes the rule non-circular — not its model fit.
#   -> output/sonority_note.md, sonority_peripherality.csv
#
# ── RULE_NAMES CONTAINS AN ALIAS ────────────────────────────────
# Ten entries, nine distinct rules: SON is an alias of SON_F. Any script
# fitting one model per rule must use setdiff(RULE_NAMES, "SON") or it fits a
# duplicate and mis-states its own n.
#
# ── STILL OPEN ──────────────────────────────────────────────────
#  * The mora hypothesis — designed elicitation only.
#  * ⟨ӑ⟩'s rounding — lip video or another articulatory measure only.
#  * hand_check_sample.csv (250 vowels) needs Kate's ears.
#  * Is the Chuvash Voice dominant speaker male (225.7 Hz) or is the metadata
#    wrong? Moot for the analyses, not for reporting an absolute f0.
# ════════════════════════════════════════════════════════════════

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

# ── 1b. ORTHOGRAPHIC NORMALISATION ──────────────────────────────
# The Zheltov wordlist is typed with LATIN homoglyphs where the
# monolingual corpus and the spoken corpora use Cyrillic:
#
#     ă  U+0103  LATIN SMALL LETTER A WITH BREVE     for  ӑ  U+04D1
#     ĕ  U+0115  LATIN SMALL LETTER E WITH BREVE     for  ӗ  U+04D7
#     ç  U+00E7  LATIN SMALL LETTER C WITH CEDILLA   for  ҫ  U+04AB
#
# 63.5% of wordlist types contain at least one. transliterate_word()
# maps both forms, so word_label_IPA was always correct — but every
# *string* join on the orthographic label silently failed for those
# words. That is why in_mono_corpus read 19.8% for Zheltov when the
# measured figure after the fix is 69.2%, and why corpus_freq was NA for all 323
# breve-containing monosyllabic types against 20 of 615 others.
# Since ӑ and ӗ ARE the reduced vowels, the missingness in the
# frequency covariate was perfectly confounded with the phonological
# contrast under study.
#
# Normalise every orthographic word label at load, in every corpus.
ORTHOGRAPHY_HOMOGLYPHS <- c(
  "\u0103" = "\u04d1",   # ă → ӑ
  "\u0115" = "\u04d7",   # ĕ → ӗ
  "\u00e7" = "\u04ab",   # ç → ҫ
  "\u0102" = "\u04d0",   # Ă → Ӑ
  "\u0114" = "\u04d6",   # Ĕ → Ӗ
  "\u00c7" = "\u04aa"    # Ç → Ҫ
)

SOFT_HYPHEN <- "\u00ad"

# Fold the Latin homoglyphs onto Cyrillic and drop soft hyphens.
# Idempotent; safe to apply to already-Cyrillic corpora.
normalise_orthography <- function(x) {
  x <- stringr::str_replace_all(x, stringr::fixed(SOFT_HYPHEN), "")
  for (from in names(ORTHOGRAPHY_HOMOGLYPHS)) {
    x <- stringr::str_replace_all(
      x, stringr::fixed(from), ORTHOGRAPHY_HOMOGLYPHS[[from]]
    )
  }
  x
}

# Hard stop if a homoglyph reaches a table that will be joined on.
assert_orthography <- function(x, where = "orthographic labels") {
  bad <- names(ORTHOGRAPHY_HOMOGLYPHS)
  hits <- vapply(
    bad, function(ch) sum(stringr::str_detect(x, stringr::fixed(ch)), na.rm = TRUE),
    integer(1)
  )
  if (any(hits > 0)) {
    stop(sprintf(
      "Latin homoglyphs survived normalisation in %s: %s",
      where,
      paste(sprintf("%s x%d", bad[hits > 0], hits[hits > 0]), collapse = ", ")
    ), call. = FALSE)
  }
  invisible(TRUE)
}

# ── 1c. LINE-BREAK REPAIR (running text only) ───────────────────
# The monolingual corpus is drawn from digitised print. Three
# segmentation artifacts survive into it, all of which manufacture
# open monosyllables that are not words:
#
#   (1) de-hyphenation failure — "йышӑн­ нӑ", "вил- се", "Ас­ лӑ".
#       The token regex in 02_clean.R does not include the hyphen or
#       the soft hyphen, so BOTH halves become separate word types.
#   (2) letter-spaced emphasis (разрядка) — "ӗ ҫ е р нӗ" for ӗҫернӗ.
#   (3) Russian passages left in place.
#
# (1) is repairable here. (2) and (3) are not, and are the reason the
# corpus cannot carry a type-level phonotactic claim on its own —
# see output/minimal_word_diagnosis.md.
repair_line_breaks <- function(txt) {
  # soft hyphen at a line break, with or without the following space
  txt <- stringr::str_replace_all(txt, "(\\S)\u00ad\\s+", "\\1")
  txt <- stringr::str_replace_all(txt, stringr::fixed(SOFT_HYPHEN), "")
  # hard hyphen at a line break: no space BEFORE it, whitespace after.
  # A spaced dash (" - ") has a space before and is left alone, as are
  # genuine compounds (ҫурт-йӗр), which have no space after.
  txt <- stringr::str_replace_all(txt, "(\\S)-\\s+(?=\\S)", "\\1")
  txt
}

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

# Rounding follows Krueger (1961) and is LEFT AS HE HAS IT for the back
# series, deliberately. The corpus establishes rounding for the two FRONT
# vowels and for NEITHER back one.
#
# The numbers below replace an earlier set that used ONE anchor per harmony
# series (/i/ front, /a/ back), which compared mid ⟨ӗ⟩ against high /i/ and
# mid ⟨ӑ⟩ against low /a/ and so confounded rounding with height. The current
# test uses HEIGHT-MATCHED pairs (output/rounding_contrasts.csv):
#
#   pair                         n        dF3z    z       dF2z     reading
#   /y/ ⟨ӳ⟩  vs /i/ ⟨и⟩      42,478    −0.483  −21.2   −0.457   rounded
#   /ø/ ⟨ӗ⟩  vs /e/ ⟨е⟩     138,558    −0.334  −32.5   −0.537   rounded
#   /u/ ⟨у⟩  vs /ʉ/ ⟨ы⟩      43,065    −0.091   −5.1   −0.144   CONTROL
#   /ɵ/ ⟨ӑ⟩  vs /a/ ⟨а⟩     223,618    +0.107  +11.2   −0.134   undecidable
#
# THE /u/~/ʉ/ ROW IS A POSITIVE CONTROL, NOT A RESULT. It presupposes
# Krueger's description of that pair and therefore CANNOT be cited as evidence
# that ⟨ы⟩ is unrounded or ⟨у⟩ rounded. An early draft committed exactly that
# circularity ("Krueger's high row is confirmed exactly") and it was withdrawn.
# The control's small effect is itself ambiguous between "F3 is a weak cue to
# back rounding" and "these two vowels differ less in rounding than described".
#
# ⟨ӑ⟩ /ɵ/ is undecidable for a structural reason, not a power problem: the
# inventory contains no mid back UNROUNDED vowel to serve as its height-matched
# anchor. Do NOT drop "ɵ" from this vector on the strength of its positive
# dF3z — that sign means there is no valid comparison, not that the vowel is
# unrounded. Settling it needs lip video or another articulatory measure.
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

# ── SON: pure rightmost-to-sonority ─────────────────────────────
# A6-B4 all work by a binary full/reduced split plus a default. This rule
# drops the binary split and the default entirely: the vowels are ranked on a
# single sonority scale, and stress goes to the RIGHTMOST vowel belonging to
# the most sonorous tier the word contains. No word is stressless, and no
# word needs a fallback, because every word contains a vowel from some tier.
#
# The scale is Kate Lindsey's, and it is the paper's thesis stated as a rule:
# if rightmost stress in Chuvash is fundamentally sonority-sensitive, this is
# what the grammar looks like without a full/reduced primitive at all.
#
#   1  a            low
#   2  e            mid front
#   3  i  y  u      high peripheral
#   4  ø  ɵ         mid reduced
#   5  ʉ            high central
#
# Note tier 5 sits BELOW tier 4: /ʉ/ is ranked as the least sonorous vowel in
# the language, under the reduced mid vowels rather than with the other high
# vowels. That is a substantive claim and the reason this rule is not just a
# re-parameterisation of A6-B4 — it cannot be produced by any full/reduced
# partition, because tiers 3 and 5 are both "high" and sit on opposite ends.
SONORITY_TIERS <- list(
  c("a"),
  c("e"),
  c("i", "y", "u"),
  c("ø", "ɵ"),
  c("ʉ")
)

stopifnot(
  "SONORITY_TIERS must partition the eight native vowels exactly once" =
    setequal(unlist(SONORITY_TIERS), setdiff(TARGET_VOWELS_IPA, "o")) &&
    !anyDuplicated(unlist(SONORITY_TIERS))
)

# The tiers above are the classic vocalic sonority hierarchy (de Lacy 2002,
# 2004, 2006; Kenstowicz 1997; Gordon 2006) as it applies to this inventory:
#
#   tier 1  a          low peripheral
#   tier 2  e          mid peripheral
#   tier 3  i y u      high peripheral
#   tier 4  ø ɵ        mid central
#   tier 5  ʉ          high central
#
# Both dimensions are measurable in this corpus and recover these five tiers
# exactly for all eight vowels (analyses/sonority_peripherality.R): height from
# F1, peripherality from convex-hull membership in the speaker's own F1 x F2
# space, on tokens no stress rule calls stressed.
#
# ── The three sonority variants ────────────────────────────────────────
# The A-vs-B question — whether a word with no high-sonority vowel gets stress
# somewhere or gets none at all — is orthogonal to the tier mechanism, so it
# crosses with it exactly as it crosses with the full/reduced inventories.
# CENTRAL_TIERS names the tiers that are "too low to bear stress" under the
# A and B variants; it is tiers 4 and 5, the mid-central and high-central
# vowels, which is the same cut as the full/reduced partition of rule B5 but
# arrived at from the hierarchy rather than stipulated.
CENTRAL_TIERS <- 4:5

STRESS_RULES[["SON_F"]] <- list(
  type = "sonority", subtype = "F", default = NA_character_,
  inventory = NA_character_, tiers = SONORITY_TIERS,
  central_tiers = CENTRAL_TIERS,
  label = paste0("SON-F: rightmost vowel of the most sonorous tier present, ",
                 "always [a > e > i y u > ø ɵ > ʉ]")
)
STRESS_RULES[["SON_A"]] <- list(
  type = "sonority", subtype = "A", default = "A",
  inventory = NA_character_, tiers = SONORITY_TIERS,
  central_tiers = CENTRAL_TIERS,
  label = paste0("SON-A: rightmost vowel of the most sonorous tier present, ",
                 "but LEFTMOST if that tier is mid-central or high-central")
)
STRESS_RULES[["SON_B"]] <- list(
  type = "sonority", subtype = "B", default = "B",
  inventory = NA_character_, tiers = SONORITY_TIERS,
  central_tiers = CENTRAL_TIERS,
  label = paste0("SON-B: rightmost vowel of the most sonorous tier present, ",
                 "but STRESSLESS if that tier is mid-central or high-central")
)

# SON is retained as an alias of SON_F so that earlier output and the
# stress_rule_SON column keep their meaning.
STRESS_RULES[["SON"]] <- STRESS_RULES[["SON_F"]]
STRESS_RULES[["SON"]]$label <- paste0(
  "SON: rightmost vowel of the most sonorous tier present ",
  "[a > e > i y u > ø ɵ > ʉ]  (= SON-F)")

RULE_NAMES <- names(STRESS_RULES)

# ── Active rule: any of RULE_NAMES. Governs the single-column
#    convenience outputs (vowel_cat, vowel_class, stressed_position).
#    All six rules are computed regardless, so changing this does not
#    lose information — see pipeline/run_pipeline.R for which stage
#    to re-run.
ACTIVE_RULE <- "A6"

stopifnot(
  "ACTIVE_RULE must be one of RULE_NAMES" =
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
  r <- STRESS_RULES[[rule]]

  # The sonority rules have no full/reduced primitive: walk the tiers from
  # most to least sonorous and act on the first tier the word contains.
  #
  #   SON_F  rightmost member of that tier, whatever the tier
  #   SON_A  rightmost, but LEFTMOST when the tier is mid- or high-central
  #   SON_B  rightmost, but NO STRESS when the tier is mid- or high-central
  #
  # SON_F/A/B therefore differ only in words whose most sonorous vowel is
  # /ø ɵ ʉ/, which is what makes them the sonority analogue of the A-vs-B
  # contrast rather than three re-parameterisations of one rule.
  if (!is.null(r$type) && r$type == "sonority") {
    central <- if (is.null(r$central_tiers)) integer(0) else r$central_tiers
    sub <- if (is.null(r$subtype)) "F" else r$subtype
    for (i in seq_along(r$tiers)) {
      hit <- which(vowel_labels %in% r$tiers[[i]])
      if (length(hit) == 0) next
      if (i %in% central) {
        if (sub == "B") return(NA_integer_)        # stressless by design
        if (sub == "A") return(min(hit))           # leftmost of a central tier
      }
      return(max(hit))                             # rightmost otherwise
    }
    return(NA_integer_)                            # no classifiable vowel
  }

  full <- which(vowel_labels %in% r$full)
  if (length(full) > 0) return(max(full))
  if (r$default == "B") return(NA_integer_)        # stressless by design
  red  <- which(vowel_labels %in% r$reduced)
  if (length(red) > 0) return(min(red))
  NA_integer_
}

# ── The full word's vowel sequence ──────────────────────────────────────
# Stress is a property of the WORD, so a rule has to see every syllable the
# word has — not only the syllables that survived cleaning. Two distinct bugs
# follow from using the surviving rows instead, and both are fixed here.
#
#   (1) WRONG SYLLABLE CHOSEN. For a three-syllable /i.e.a/ word with only
#       syllables 1 and 2 measured, a rightmost-full rule run on the surviving
#       pair picks /e/ in syllable 2. The word's actual rightmost full vowel is
#       /a/ in syllable 3, which is unmeasured — so the correct labelling is
#       that syllables 1 and 2 are both UNSTRESSED and the word contributes no
#       stressed row at all.
#
#   (2) INDEX/SIDX MISMATCH. assign_stress() returns a position in the vector
#       it was handed. apply_stress_rule() then compared that position against
#       `sidx`. Those coincide only when the surviving syllables are
#       1, 2, ... n with no gaps. For a word with surviving sidx {1, 3} a
#       target of 2 means "the second surviving vowel", i.e. sidx 3 — but the
#       comparison `sidx == 2` matches nothing, so the word silently lost its
#       stressed row.
#
# word_label_IPA_syllabified carries the whole word, dot-separated, and is
# present on the vowels, syllables and words tables. Extracting one vowel per
# syllable from it reproduces sN exactly (checked on 40,000 word tokens: 100%,
# no unparsable syllables), so it is a sound basis for the full sequence.
full_vowel_sequence <- function(syllabified) {
  vapply(strsplit(as.character(syllabified), ".", fixed = TRUE), function(sy) {
    if (!length(sy) || anyNA(sy)) return(NA_character_)
    v <- vapply(sy, function(s) {
      ch <- tokenize_ipa(s)
      hit <- ch[ch %in% TARGET_VOWELS_IPA]
      if (length(hit) >= 1L) hit[1] else NA_character_
    }, character(1), USE.NAMES = FALSE)
    paste(v, collapse = "-")
  }, character(1))
}

# Target SYLLABLE INDEX (1..sN) for one rule, from the full sequence. Because
# the sequence is in syllable order, the index it returns IS an sidx and can be
# compared to the data's sidx directly.
assign_stress_full <- function(full_seq, rule = ACTIVE_RULE) {
  vapply(strsplit(as.character(full_seq), "-", fixed = TRUE), function(vs) {
    if (!length(vs) || all(is.na(vs))) return(NA_integer_)
    s <- assign_stress(vs, rule)
    if (length(s) && !is.na(s)) as.integer(s) else NA_integer_
  }, integer(1))
}

# Apply one rule across a whole dataframe.
# df must have: word_id, sidx (1-based), vowel_label, and — for the full-word
# behaviour — word_label_IPA_syllabified. Falls back to the surviving-rows
# behaviour with a warning if that column is absent.
#
# A NA target yields "Unstressed" for every syllable of that word rather than
# NA, so rule-B columns carry the same number of usable rows as rule-A columns
# and model fits stay comparable. A target pointing at an UNMEASURED syllable
# likewise yields "Unstressed" everywhere, which is the correct labelling: the
# word's stressed syllable is simply not in the data.
apply_stress_rule <- function(df, rule = ACTIVE_RULE) {
  col <- paste0("stress_rule_", rule)
  if (!"word_label_IPA_syllabified" %in% names(df)) {
    warning("apply_stress_rule(): word_label_IPA_syllabified absent, ",
            "falling back to the surviving-rows behaviour. Targets will be ",
            "wrong for incomplete words. See full_vowel_sequence().",
            call. = FALSE)
    return(df %>%
      dplyr::group_by(word_id) %>%
      dplyr::mutate(
        .target = assign_stress(vowel_label[order(sidx)], rule),
        !!col   := dplyr::if_else(!is.na(.target) & sidx == .target,
                                  "Stressed", "Unstressed")) %>%
      dplyr::ungroup() %>% dplyr::select(-.target))
  }
  df %>%
    dplyr::group_by(word_id) %>%
    dplyr::mutate(
      .full   = full_vowel_sequence(word_label_IPA_syllabified[1]),
      .target = assign_stress_full(.full, rule),
      !!col   := dplyr::if_else(!is.na(.target) & sidx == .target,
                                "Stressed", "Unstressed")
    ) %>%
    dplyr::ungroup() %>%
    dplyr::select(-.target, -.full)
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
    source = "Zheltov (2008) wordlist",
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
  "ɯ",                # the ALIGNER's symbol for ы. 5-recode/chuvash_phonology.py
                      #   transcribes ы as ɯ, this config's g2p as ʉ. Omitting it
                      #   here classified 20,259 aligner-labelled ы tokens as
                      #   consonants. See ALIGNER_IPA_TO_CONFIG below.
  "ʌ", "ɐ"
)

# ── Aligner IPA ↔ this config's IPA ─────────────────────────────────────
# The MFA dictionary and the recoded TextGrids use a different transcription
# of the same eight vowels from the one this config's transliterate_word()
# produces. Anything that reads phone labels straight off a TextGrid must
# translate first, or the two notations will not join.
ALIGNER_IPA_TO_CONFIG <- c(
  "ɑ" = "a", "e" = "e", "i" = "i", "u" = "u", "y" = "y",
  "ɯ" = "ʉ",   # ы
  "ɛ" = "ø",   # ӗ
  "ʌ" = "ɵ",   # ӑ
  "o" = "o",   # loan only
  "tʃ" = "tɕ", # the tie-bar form t͡ʃ never matched, so grids carry plain tʃ
  "χ" = "x",
  "v" = "ʋ"
)

# Translate a vector of aligner phone labels into this config's IPA,
# preserving any length mark. Unknown labels pass through unchanged.
from_aligner_ipa <- function(x) {
  long <- grepl("ː", x, fixed = TRUE)
  base <- sub("ː", "", x, fixed = TRUE)
  out  <- ifelse(base %in% names(ALIGNER_IPA_TO_CONFIG),
                 ALIGNER_IPA_TO_CONFIG[base], base)
  ifelse(long, paste0(out, "ː"), out)
}

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