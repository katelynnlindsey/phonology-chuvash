# The monolingual corpus and the minimal-word generalisation

*Generated 2026-09-26. Supersedes the monolingual column of Table `tab:min` in the draft.*

## The question

The draft reports, for each vowel, the proportion of monosyllabic words in which
that vowel stands in an open syllable. The claim is that the reduced vowels
/ø ɵ ʉ/ do not occur there — a minimal-word effect. The wordlist gives a clean
result. The monolingual corpus, as published, contradicts it: /ø/ appears in an
open monosyllable in 28.1% of types, the highest rate of any vowel.

The two sources disagreed because of two independent defects. Neither is
linguistic.

## Defect 1 — the corpus's open monosyllables are word fragments

310 monosyllabic types in the corpus have a reduced vowel in an open syllable,
covering 184,979 tokens. **None of them is attested in the wordlist.** The most
frequent are

| type | IPA | occurrences |
|---|---|---|
| нӑ | /nɵ/ | 17,003 |
| тӑ | /tɵ/ | 12,398 |
| лӑ | /lɵ/ | 11,814 |
| нӗ | /nø/ | 10,985 |
| ҫӗ | /ɕø/ | 8,104 |
| чӗ | /tɕø/ | 7,681 |

These are Chuvash suffixes — the past participle -нӑ/-нӗ, the past copula -чӗ,
the adjectiviser -лӑ/-лӗ — not words. The same thing happens with full vowels
(не 33,413, ра 23,177, са 18,188, ле 12,329), which is what identifies the
cause: the corpus's *token stream* contains pieces of words.

Three artifacts in the source texts produce them, all visible in the raw
parquet:

1. **De-hyphenation failure at line breaks.** `йышӑн­ нӑ`, `вил- се`, `Ас­ лӑ`,
   `ил­ нӗ`. 5,698 of 300,000 sampled sentences (1.9%) carry a soft hyphen
   (U+00AD). The token regex in `02_clean.R` includes neither the hyphen nor the
   soft hyphen, so both halves became separate word types.
2. **Letter-spaced emphasis** (разрядка): `ӗ ҫ е р нӗ` for *ӗҫернӗ*, each letter
   its own token.
3. **Russian passages** left in place: `вы` (3,092) is Russian *вы* 'you'.

`repair_line_breaks()` in `config/phonology_params.R` now fixes (1) before
tokenisation. (2) and (3) are not repairable by rule, and they are the reason
the corpus cannot carry a type-level phonotactic claim on its own: the fragments
are phonotactically legal Chuvash syllables, so no phonotactic filter can
separate them from real words. Only attestation can.

## Defect 2 — a homoglyph mismatch between the two corpora

The wordlist is typed with **Latin** homoglyphs where the corpus and the spoken
data use **Cyrillic**:

| as typed | codepoint | should be | codepoint | occurrences |
|---|---|---|---|---|
| ă | U+0103 LATIN SMALL LETTER A WITH BREVE | ӑ | U+04D1 | 12,166 |
| ĕ | U+0115 LATIN SMALL LETTER E WITH BREVE | ӗ | U+04D7 | 6,478 |
| ç | U+00E7 LATIN SMALL LETTER C WITH CEDILLA | ҫ | U+04AB | 2,824 |

**63.5% of wordlist types contain at least one.** In almost every font the two
sets are visually indistinguishable, which is why this survived inspection.

`transliterate_word()` maps both forms, so `word_label_IPA` was always correct.
But every *string* join on the orthographic label failed silently for those
words:

- `in_mono_corpus` for the wordlist read 19.8%; the true figure is **69.4%**
- `corpus_freq` was NA for **all 323** breve-containing monosyllabic types,
  against 20 of 615 others

Because ӑ and ӗ *are* the reduced vowels, the missingness in the frequency
covariate was perfectly confounded with the contrast under study, and
`log_corpus_freq_smoothed` entered those words into the models as maximally
rare. `normalise_orthography()` now folds the homoglyphs at load, and
`assert_orthography()` stops the pipeline if one reaches a join.

## Result

With both defects repaired, the corpus reproduces the wordlist:

| vowel | | wordlist, types | corpus, attested types | corpus, attested tokens | corpus, all types (as published) |
|---|---|---|---|---|---|
| a | full | 4.0 | 4.1 | 39.3 | 17.1 |
| e | full | 5.7 | 6.0 | 60.8 | 19.8 |
| i | full | 7.5 | 7.7 | 43.7 | 20.1 |
| u | full | 9.5 | 9.6 | 17.4 | 12.7 |
| y | full | 15.4 | 17.8 | 52.0 | 15.8 |
| ʉ | reduced | 0.0 | 0.0 | 0.0 | 9.7 |
| ø | reduced | 0.0 | 0.0 | 0.0 | 28.1 |
| ɵ | reduced | 1.1 | 1.2 | 1.6 | 11.6 |

The type columns agree to within 0.1–2.4 points. The only open monosyllables
with a reduced vowel that survive attestation are ӑ and хӑ, the same two the
wordlist lists.

## What to report

The corpus's contribution is **token frequency**, not type inventory. Restricting
its type inventory to attested words makes it non-independent of the wordlist, so
a "corpus types" column is not corroboration — it is the wordlist counted again.

Recommended: state the generalisation from the wordlist (types), and use the
corpus for the token column, which is genuinely new information and shows that
the gap is not an artifact of rare words. Note that /y/ is the counterexample
among the full vowels at 15.4% of types, and that /ɵ/ is not categorically
excluded — 1.1% of wordlist types and 1.2% of attested corpus types.

## Files

- `minimal_word_diagnosis.csv` — the table above
- `mono_open_monosyllable_types.csv` — all 1,430 unattested open monosyllabic
  corpus types with frequencies, 308 of them with a reduced vowel
- `fig_minimal_word_diagnosis.png` — four-panel figure
