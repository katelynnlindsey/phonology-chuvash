# analyses/geminating_stems.R
# ================================================================
# The пулӑ ~ пулли class: nouns of the shape C F C Ṙ whose stem surfaces with
# a long consonant before a vowel-initial suffix.
#
# R port of analyses/geminating_stems.py, same logic. This one needs no Python
# and is the version to use; the .py is marked SUPERSEDED.
#
# THEY DO NOT AGREE EXACTLY, and an earlier version of this header wrongly said
# they did — the claim was written before either had been run against the
# other. Confirmed geminating stems: **R finds 65, Python 62.** The three R
# adds are качӑ, тӑрӑ and ҫӳлӗ; the difference is a character-encoding one, not
# a logic one (ҫ is U+04AB, and the Python normalisation missed it). R is
# correct here.
#
#   source(here::here("9-analyze", "analyses", "geminating_stems.R"))
#
# HOW THE CLASS IS IDENTIFIED, AND WHY NOT THE OBVIOUS WAY
# --------------------------------------------------------
# The obvious search takes every word ending in a reduced vowel and asks
# whether a geminate form exists. That fails twice over: it accepts accidental
# string matches, it only ever looks for one suffix, and -- worst -- it leaves
# both sides of the comparison dominated by suffix-shaped words (-лӑ, -нӑ, -тӑ
# participles and adjectives whose final reduced vowel is a suffix vowel, not
# a stem vowel) to different degrees: 64.9% of the candidates against 97.5% of
# the comparison class. What that measures is stem-shaped versus suffix-shaped
# words, not fleeting versus stable vowels.
#
# This script inverts the search. The geminate is directly observable in the
# orthography, so it enumerates ATTESTED forms containing a written geminate,
# strips the suffix, and asks whether the bare noun exists. The revealing
# suffixes are then discovered rather than assumed.
#
# Three false-positive classes still get through, and the plural removes them:
#
#   (a) CVC stems taking a possessive.  кун 'day' -> кунӗ -> кунне, so кунӗ
#       looks like a CFCR noun with a geminating stem, but its ӗ is a suffix.
#   (b) verb stems taking -нӑ/-нӗ.  те- 'say' -> тенӗ.
#   (c) words that merely contain a geminate: Раҫҫей, саккун (Russian loans),
#       паллӑ 'known', валли 'for', хыҫҫӑн 'after'.
#
# The plural settles whether the final reduced vowel is stem-final or a suffix:
#
#       пулӑ 'fish' -> пулӑсем     the vowel survives: stem-final
#       кун  'day'  -> кунсем      no vowel: кунӗ's ӗ was a suffix
#
# Outputs (identical names to the Python version)
#   output/geminating_stems.csv          one row per candidate stem
#   output/geminating_slots.csv          suffixes that reveal the geminate
#   output/geminating_stems_control.csv  every wordlist CFCR/CRCR type
# ================================================================

source(here::here("9-analyze", "analyses", "00_session_setup.R"))
library(data.table)

OUT <- PATHS$output_dir

FULL_L <- strsplit("аеиуӳыоэюя", "")[[1]]   # о and э loan-only; ю я = /ju ja/
RED_L  <- c("ӑ", "ӗ")
VOW_L  <- c(FULL_L, RED_L)
CONS_L <- strsplit("бвгджзйклмнпрстфхцчшщҫ", "")[[1]]
BACKH  <- c("а", "о", "у", "ы", "ӑ")
PLURALS <- c("сем", "сен", "семпе", "сене", "сенче")

cls <- function(ch) fifelse(ch %in% VOW_L, "V",
                     fifelse(ch %in% CONS_L, "C", "?"))
chars <- function(x) strsplit(x, "", fixed = TRUE)

# normalise_orthography() maps the Zheltov wordlist's Latin homoglyphs
# (ă U+0103, ĕ U+0115, ç U+00E7) onto Cyrillic ӑ ӗ ҫ. Skipping it is how
# 63.5% of wordlist types silently failed to join.
# mono_clean.rds names the word column `token`, not `word_label`; zheltov_clean
# names it `word`. Both differ from the spoken tables' `word_label`.
mono_t <- as.data.table(mono)[, .(w = normalise_orthography(tolower(token)),
                                  corpus_freq)]
mono_t <- mono_t[, .(freq = sum(corpus_freq)), by = w]
mono_t <- mono_t[vapply(chars(w), function(cc) all(cls(cc) != "?"), logical(1))]
FREQ <- setNames(mono_t$freq, mono_t$w)
wl <- unique(normalise_orthography(tolower(as.data.table(zheltov)$word)))
wl <- wl[vapply(chars(wl), function(cc) all(cls(cc) != "?"), logical(1))]
cat(sprintf("\nmonolingual types usable: %d | wordlist types: %d\n",
            length(FREQ), length(wl)))

freq_of <- function(x) { v <- FREQ[x]; v[is.na(v)] <- 0; as.numeric(v) }

# ── step 1: attested forms with a written geminate after C V ────────────
gem_re <- paste0("^([", paste(CONS_L, collapse = ""), "])",
                 "([", paste(VOW_L, collapse = ""), "])",
                 "([", paste(CONS_L, collapse = ""), "])\\3(.+)$")
cand <- mono_t[freq >= 2L & grepl(gem_re, w)]
cand[, `:=`(root = sub(gem_re, "\\1\\2\\3", w), suf = sub(gem_re, "\\4", w))]
cand <- cand[vapply(chars(suf), function(cc) cc[1] %in% VOW_L, logical(1))]
cat(sprintf("attested geminate forms: %d, over %d distinct roots\n",
            nrow(cand), uniqueN(cand$root)))

# ── step 2: does the bare noun exist, and is its vowel stem-final? ──────
predicted_bare <- function(root)
  paste0(root, vapply(chars(root),
                      function(cc) if (any(cc %in% BACKH)) "ӑ" else "ӗ",
                      character(1)))
st <- cand[, .(n_geminate_forms = .N,
               geminate_freq_total = sum(freq),
               geminate_forms = paste0(
                 head(paste0(w, "(", freq, ")"), 6)[order(-head(freq, 6))],
                 collapse = ";"),
               revealing_suffixes = paste(head(suf[order(-freq)], 6),
                                          collapse = ";")),
           by = root][order(-geminate_freq_total)]
st[, bare_predicted := predicted_bare(root)]
st[, bare_alt := paste0(root, fifelse(endsWith(bare_predicted, "ӑ"), "ӗ", "ӑ"))]
st[, bare_attested := fifelse(freq_of(bare_predicted) > 0, bare_predicted,
                       fifelse(freq_of(bare_alt) > 0, bare_alt, NA_character_))]
st[, bare_freq_mono := freq_of(bare_attested)]
st[, bare_in_wordlist := as.integer(!is.na(bare_attested) &
                                      bare_attested %in% wl)]
st[, bare_shape := vapply(seq_len(.N), function(i) {
  b <- bare_attested[i]
  if (is.na(b) || nchar(b) != 4L) return("other")
  cc <- chars(b)[[1]]
  if (!(cc[1] %in% CONS_L) || !(cc[3] %in% CONS_L) ||
      !(cc[4] %in% RED_L)) return("other")
  if (cc[2] %in% FULL_L) "CFCR" else if (cc[2] %in% RED_L) "CRCR" else "other"
}, character(1))]
st[, plural_with_vowel := rowSums(sapply(PLURALS, function(p)
  freq_of(paste0(fifelse(is.na(bare_attested), bare_predicted,
                         bare_attested), p))))]
st[, plural_without_vowel := rowSums(sapply(PLURALS,
                                            function(p) freq_of(paste0(root, p))))]
st[, root_free_freq := freq_of(root)]
st[, final_vowel := fifelse(plural_with_vowel + plural_without_vowel >= 5,
                     fifelse(plural_with_vowel > plural_without_vowel,
                             "stem-final", "suffix"),
                     fifelse(root_free_freq >= 50, "suffix", "unclear"))]
st[, geminate_consonant := vapply(chars(root), function(cc) cc[3], character(1))]
st[, stem_vowel := vapply(chars(root), function(cc) cc[2], character(1))]
st[, confirmed := as.integer(!is.na(bare_attested) &
                               bare_shape %in% c("CFCR", "CRCR") &
                               bare_in_wordlist == 1L &
                               final_vowel == "stem-final" &
                               geminate_freq_total >= 10)]
setcolorder(st, c("root", "bare_predicted", "bare_attested", "bare_shape",
                  "bare_freq_mono", "bare_in_wordlist", "final_vowel",
                  "plural_with_vowel", "plural_without_vowel",
                  "root_free_freq", "geminate_consonant", "stem_vowel",
                  "n_geminate_forms", "geminate_freq_total",
                  "geminate_forms", "revealing_suffixes", "confirmed"))
fwrite(st[order(-confirmed, -geminate_freq_total)],
       file.path(OUT, "geminating_stems.csv"))
cat(sprintf("confirmed members: %d\n", sum(st$confirmed)))
cat("\nby shape of the bare form:\n")
print(st[, .(n_roots = .N, gem_tokens = sum(geminate_freq_total)),
         by = bare_shape][order(-n_roots)])
cat("\nconfirmed, top 15 by geminate frequency:\n")
print(st[confirmed == 1L][order(-geminate_freq_total)][1:15,
      .(bare_attested, bare_shape, bare_freq_mono, geminate_freq_total,
        plural_with_vowel, plural_without_vowel)])

# ── step 3: which paradigm slots reveal the geminate? ───────────────────
sl <- cand[root %in% st[confirmed == 1L, root],
           .(tokens = sum(freq), n_stems = uniqueN(root)), by = suf
           ][order(-tokens)]
setnames(sl, "suf", "suffix")
fwrite(sl, file.path(OUT, "geminating_slots.csv"))
cat("\nsuffixes that reveal the geminate, top 10:\n"); print(sl[1:10])

# ── step 4: is there a non-geminating control class? ───────────────────
# Every wordlist CFCR/CRCR type ending in a reduced vowel, classified the same
# way. The question is whether any of them FAIL to geminate.
four <- wl[nchar(wl) == 4L]
ctl <- data.table(bare = four)
ctl <- ctl[vapply(chars(bare), function(cc)
  cc[1] %in% CONS_L && cc[3] %in% CONS_L && cc[4] %in% RED_L &&
    cc[2] %in% VOW_L, logical(1))]
ctl[, root := substr(bare, 1, 3)]
ctl[, shape := vapply(chars(bare), function(cc)
  if (cc[2] %in% FULL_L) "CFCR" else "CRCR", character(1))]
ctl[, final_c := vapply(chars(bare), function(cc) cc[3], character(1))]
ctl[, bare_freq := freq_of(bare)]
ctl[, plural_with_vowel := rowSums(sapply(PLURALS, function(p) freq_of(paste0(bare, p))))]
ctl[, plural_without_vowel := rowSums(sapply(PLURALS, function(p) freq_of(paste0(root, p))))]
ctl[, root_free_freq := freq_of(root)]
ctl[, final_vowel := fifelse(plural_with_vowel + plural_without_vowel >= 5,
                      fifelse(plural_with_vowel > plural_without_vowel,
                              "stem-final", "suffix"),
                      fifelse(root_free_freq >= 50, "suffix", "unclear"))]
ctl[, geminates := as.integer(root %in% st$root)]
fwrite(ctl, file.path(OUT, "geminating_stems_control.csv"))
cat(sprintf("\nwordlist CFCR/CRCR types ending in a reduced vowel: %d\n", nrow(ctl)))
print(dcast(ctl[, .N, by = .(final_vowel, geminates)],
            final_vowel ~ geminates, value.var = "N", fill = 0))
cat("\nAmong types whose reduced vowel is stem-final, how many do NOT geminate?\n")
print(ctl[final_vowel == "stem-final", .N, by = geminates])
cat("\n✓ geminating_stems.R complete\n")
