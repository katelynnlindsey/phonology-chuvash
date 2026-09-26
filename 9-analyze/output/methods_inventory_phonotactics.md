# Segment inventory and phonotactics

*2026-09-26. Source: `analyses/inventory_phonotactics.R`.*

The written half of the inventory is tokenised from each word type's IPA and
weighted by corpus frequency. The spoken half is read off the aligner's own
phone tier in `1-raw_data/*/textgrids` — the pre-recode grids, because the
recode step collapses most geminates.

Two notations are in play and had to be reconciled. The MFA dictionary
transcribes four of the eight vowels differently from `transliterate_word()`:
ɑ ɛ ʌ ɯ against a ø ɵ ʉ. `ɯ` was absent from `IPA_VOWELS`, which classified
20,259 aligner-labelled ы tokens as consonants. `ALIGNER_IPA_TO_CONFIG` and
`from_aligner_ipa()` in the config now translate, and `ɯ` has been added.

## Vowels

Eight native vowels plus loan /o/. Their token shares agree closely across all
three corpora, which is the basic check that the transliteration and the
aligner agree about what is in these texts:

| | a | e | i | u | y | ʉ | ø | ɵ | o |
|---|---|---|---|---|---|---|---|---|---|
| wordlist | 30.3 | 14.7 | 8.7 | 11.2 | 0.9 | 3.0 | 14.5 | 16.4 | — |
| monolingual | 28.3 | 17.2 | 9.3 | 11.0 | 0.7 | 2.9 | 14.3 | 15.8 | — |
| spoken | 30.5 | 18.3 | 9.4 | 9.9 | 0.8 | 2.5 | 12.7 | 13.7 | 1.8 |

/y/ is by far the rarest native vowel at 0.7–0.9% of vowel tokens, which is
worth remembering when reading the minimal-word result: its 15.4% open-syllable
rate rests on 52 wordlist monosyllables.

## Consonants

20 consonant places, of which **14 are attested long**. Long consonants are
1.7–2.0% of all phone tokens, 33,315 in total. The rate varies sharply by
consonant:

| | /lː/ | /ɕː/ | /ʃː/ | /sː/ | /nː/ | /kː/ | /tː/ | /rː/ | /pː/ | /mː/ | /xː/ | /ʋː/ | /ts ː/ | /jː/ |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| long, % of that consonant | 10.2 | 8.3 | 4.1 | 3.9 | 3.6 | 2.9 | 2.6 | 1.4 | 0.9 | 0.4 | 0.4 | 0.2 | 0.2 | 0.01 |
| n | 10,226 | 4,907 | 1,223 | 3,131 | 5,350 | 2,142 | 3,269 | 1,762 | 672 | 272 | 271 | 80 | 8 | 2 |

`5-recode/chuvash_phonology.py` maps `tː lː pː mː nː rː sː kː` to the plain
consonant, so 26,832 of those tokens are indistinguishable from singletons in
the recoded grids. The five that survive — `ɕː ʃː χː vː jː` — survive only
because they are absent from the map. Three further segments were never recoded
at all and sit in the grids as raw IPA: `ɕ` (54,017), `tʃ` (37,423) and `ts`
(3,058); the map's key for the affricate is `t͡ʃ` with a U+0361 tie bar, while
the grids carry plain `tʃ`.

For the gemination analysis, use `1-raw_data/chuvash_voice/textgrids`. Its
token count matches the recoded set exactly (1,424,952) and its boundaries are
identical, so it is a direct substitution. The Common Voice raw copy is a
different alignment and cannot be substituted that way.

## Syllable shapes

Share of syllables, counting each syllable of each distinct word type once:

| shape | wordlist | monolingual | spoken |
|---|---|---|---|
| CV | 36.9 | 48.1 | 50.6 |
| CVC | 53.7 | 42.6 | 41.9 |
| V | 2.4 | 2.8 | 2.3 |
| VC | 2.7 | 2.6 | 2.5 |
| CVCC | 3.0 | 2.2 | 1.7 |
| CCV / CCVC | 0.8 | 1.0 | 0.6 |

Over 90% of syllables are CV or CVC in every corpus. Complex onsets are
under 1% and are concentrated in loanwords and, in the monolingual corpus, in
the segmentation artifacts documented in `minimal_word_diagnosis.md`. This is
the distributional support for the syllabifier's one-consonant onset rule, and
it is the reason the sonority-based maximisation described in the draft's
Methods would be wrong for Chuvash (see `methods_syllabification.md`).

The wordlist's higher CVC share is a citation-form effect: it lists uninflected
stems, which end in a consonant more often than running text does.

## Word edges

| | begins with a vowel | ends with a vowel |
|---|---|---|
| wordlist | 17.5% | 44.6% |
| monolingual | 17.3% | 51.3% |
| spoken | 14.3% | 51.2% |

Words begin with a consonant five times out of six but end in a vowel about half
the time. That asymmetry matters for the stress argument: the rightmost
syllable is open in roughly half of all words, so a coda-sensitive rule has
something to bite on in the other half.

## Medial clusters

| consonants between two vowels | 1 | 2 | 3 | 4+ |
|---|---|---|---|---|
| wordlist | 42.7 | 54.0 | 3.2 | 0.1 |
| monolingual | 50.5 | 46.5 | 2.8 | 0.1 |
| spoken | 53.9 | 43.7 | 2.3 | 0.1 |

The most frequent two-consonant clusters are `ntɕ`, `ll`, `nt`, `nn`, `rl`,
`rt`, `tt`, `ns`, `ss`, `lt`, `rm`, `rs`. Four of the top twelve — `ll nn tt
ss`, a third of those word types — are orthographic geminates. In the written
corpora a geminate *is* a CC sequence, so the written and spoken records of
gemination are the same fact recorded two ways, which is what makes the
alternation test in step 11 possible on both.

## Files

- `inventory_segments.csv`, `inventory_geminates.csv`, `inventory_spoken_phones.csv`
- `phonotactics_syllable_shapes.csv`, `phonotactics_clusters.csv`, `phonotactics_edges.csv`
- `fig_inventory.png`, `fig_phonotactics.png`
