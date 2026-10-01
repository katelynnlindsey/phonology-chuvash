# =============================================================================
# matched_vowel_sets.R                                            2026-09-29
#
# THE CORPUS ANALOGUE OF A CONTROLLED FRAME-SENTENCE EXPERIMENT.
#
# The experimental design this imitates: put target words of different
# phonological shapes into an otherwise identical carrier utterance. If stress
# is NOT word-final it should move through the word with the shape and be
# visible in the phonetics; if stress IS word-final it lands on the last
# syllable whatever the shape.
#
# Two observational approximations are available here, and they control
# DIFFERENT things. Both are exported so the design can be chosen deliberately.
#
#   (1) CARRIER FRAMES -- hold the neighbouring words fixed, vary the target.
#       Controls utterance position, local segmental context and phrasing BY
#       DESIGN rather than by modelling, which is the whole difficulty in the
#       final-stress question (see analyses/final_syllable_prominence.R).
#       Does NOT control the target's vowel content.
#
#   (2) MATCHED VOWEL SETS ("anagrams") -- words of the same length containing
#       the SAME MULTISET of vowels in a DIFFERENT ORDER. e.g. for {a,a,ɵ}:
#           каланӑ  /aaɵ/  rightmost full vowel in syllable 2
#           ҫавӑнпа /aɵa/  rightmost full vowel in syllable 3
#           ӑнланса /ɵaa/  rightmost full vowel in syllable 3
#       Controls the target's vowel content BY CONSTRUCTION, which matters
#       enormously here: intrinsic duration and intensity differ sharply by
#       vowel, and the vowel configuration IS what a quality-driven rule keys
#       on, so residualising it away in a regression over-controls the very
#       prediction being tested. With the multiset held fixed there is nothing
#       to residualise -- only the ORDER differs.
#       Does NOT control utterance position or the consonants.
#
# The two predictions come apart cleanly in (2): a rightmost-full-vowel rule
# puts the prominence peak on a DIFFERENT syllable across members of one set,
# a word-final rule puts it on the last syllable for every member.
#
# Outputs
#   output/matched_vowel_sets.csv       every candidate set and its members
#   output/carrier_frames.csv           every candidate frame and its targets
# =============================================================================

suppressMessages(library(data.table))
OUT <- "output"
FULL <- c("a","e","i","u","y")

v <- as.data.table(readRDS("data/leveled/vowels_spoken_annotated.rds"))
v <- v[!is.na(vowel_label) & !is.na(sidx) & !is.na(sN) & !is.na(word_id)]
# word TYPES, from word tokens whose every syllable carries a measured vowel
wd <- v[, .(seq = paste(vowel_label[order(sidx)], collapse = ""),
            n_syl = .N, sN = sN[1]), by = .(word_id, word_label)]
wd <- wd[n_syl == sN & sN >= 2L & sN <= 4L]
ty <- wd[, .(tokens = .N), by = .(word_label, seq, sN)]
ty[, multiset := vapply(strsplit(seq, ""),
                        function(x) paste(sort(x), collapse = ""), character(1))]
ty[, full_pos := vapply(strsplit(seq, ""), function(x) {
     p <- which(x %in% FULL); if (!length(p)) NA_integer_ else max(p) }, integer(1))]
ty[, is_final_full := as.integer(full_pos == sN)]

sets <- ty[, .(orders = uniqueN(seq), types = .N, tokens = sum(tokens),
               full_positions = uniqueN(full_pos),
               dissociates = uniqueN(full_pos) >= 2L),
           by = .(multiset, sN)][orders >= 2L]
out <- merge(ty, sets[, .(multiset, sN, orders, types, tokens_in_set = tokens,
                          full_positions, dissociates)],
             by = c("multiset", "sN"))
setorder(out, -dissociates, -tokens_in_set, multiset, full_pos, -tokens)
fwrite(out, file.path(OUT, "matched_vowel_sets.csv"))

cat(sprintf("\nmatched-vowel sets: %d | word types %s | tokens %s\n",
            nrow(sets), format(sum(sets$types), big.mark=","),
            format(sum(sets$tokens), big.mark=",")))
d <- sets[dissociates == TRUE]
cat(sprintf("of which DISSOCIATING (rightmost full vowel in >= 2 positions):\n"))
cat(sprintf("  %d sets | %s types | %s tokens\n", nrow(d),
            format(sum(d$types), big.mark=","), format(sum(d$tokens), big.mark=",")))
cat("\nlargest dissociating sets:\n")
print(d[order(-tokens)][1:10, .(multiset, sN, orders, types, tokens)])

# ── carrier frames ──────────────────────────────────────────────────────
w <- as.data.table(readRDS("data/leveled/words_spoken_annotated.rds"))
w <- w[!is.na(widx) & !is.na(wN) & !is.na(word_label)][order(file_name, widx)]
w[, prev_w := shift(word_label, 1, type = "lag"),  by = file_name]
w[, next_w := shift(word_label, 1, type = "lead"), by = file_name]
m <- w[!is.na(prev_w) & !is.na(next_w)]
fr <- m[, .(targets = uniqueN(word_label), tokens = .N, lengths = uniqueN(sN)),
        by = .(prev_w, next_w)][targets >= 3L & lengths >= 2L]
fwrite(fr[order(-targets)], file.path(OUT, "carrier_frames.csv"))
cat(sprintf("\ncarrier frames (both neighbours fixed, >=3 targets, >=2 lengths):\n"))
cat(sprintf("  %s frames | %s target tokens\n", format(nrow(fr), big.mark=","),
            format(sum(fr$tokens), big.mark=",")))
cat("\n✓ matched_vowel_sets.R complete\n")
