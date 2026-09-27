# Are the monolingual fragments really suffixes?

*2026-09-27. Answers the objection that "absent from the wordlist" is weak
evidence. Two independent tests, both on the raw parquet.*

The claim under test: the 310 open-monosyllable types with a reduced vowel in the
monolingual corpus (184,979 tokens, headed by `нӑ` 17,003, `тӑ` 12,398, `лӑ`
11,814, `нӗ` 10,985) are not Chuvash words but pieces of words, produced by
de-hyphenated line breaks and letter-spaced emphasis in the source texts.

Dictionary absence is consistent with that but does not establish it — a wordlist
of 18,984 types will be missing real words. These two tests do not depend on the
wordlist's coverage.

## Test 1 — vowel harmony with the *preceding* token

Chuvash suffixes come in back and front shapes chosen by the harmony class of
the stem: -нӑ/-нӗ, -лӑ/-лӗ, -тӑ/-тӗ, -ра/-ре, -са/-се. If these tokens are
suffixes that have been split off, the choice between the two shapes must track
the harmony class of the token immediately before them. **An independent word's
vowel cannot depend on the harmony class of the word before it.**

Back-harmonic vowels are а ӑ у ы; front are е ӗ ӳ и. For each pair, the
percentage of occurrences whose preceding token is back-harmonic:

| allomorphs | n | before the BACK form | before the FRONT form | difference |
|---|---|---|---|---|
| -са / -се | 11,452 | 88.2% | 24.8% | 63.4 |
| -ла / -ле | 11,226 | 91.3% | 8.4% | 82.9 |
| -ра / -ре | 10,092 | 77.6% | 9.3% | 68.2 |
| -нӑ / -нӗ | 9,339 | **96.9%** | 12.3% | 84.6 |
| -лӑ / -лӗ | 6,752 | 95.5% | 27.4% | 68.0 |
| -тӑ / -тӗ | 5,133 | 68.2% | 20.8% | 47.4 |
| -ча / -че | 4,376 | 81.0% | 3.2% | 77.9 |
| -ҫа / -ҫе | 1,960 | 80.2% | 8.7% | 71.5 |

Every pair shows the dependency, at 47 to 85 percentage points, over 60,330
occurrences. For the past participle -нӑ/-нӗ it is all but categorical.

## Test 2 — re-attachment, against a random baseline

Glue each fragment back onto the token that actually precedes it and ask whether
the result is a real word. The control is the same fragments glued to a *randomly
chosen* preceding token, which measures how often any two adjacent Chuvash tokens
happen to concatenate into a word.

| | forms a wordlist type | forms a corpus type (freq ≥ 5) |
|---|---|---|
| glued to the actual preceding token | **11.7%** | **40.0%** |
| glued to a random preceding token | 1.1% | 10.7% |
| ratio | **10.6×** | 3.7× |

Token-weighted, 22.0% of fragment occurrences form an attested wordlist word and
63.9% form a corpus type. The commonest reconstructions are ordinary words:
`мари` 1,618, `вара` 731, `кала` 719, `тӑрӑ` 523, `ӗҫле` 513, `йӗрке` 485.

The wordlist figure is a floor, since the wordlist holds citation forms and most
reconstructions are inflected.

## Conclusion

The fragments behave like suffixes on two counts that have nothing to do with
dictionary coverage: their vowel is selected by the preceding word's harmony
class, and re-attaching them to that word restores a real word an order of
magnitude more often than chance. They are not words, and the monolingual
corpus's type inventory cannot be used for a claim about what a possible Chuvash
word looks like.

`repair_line_breaks()` now fixes the hyphenation case before tokenisation.
Letter-spaced emphasis and Russian passages are not repairable by rule, which is
why the `in_wordlist` restriction is still needed for any type-level claim.

Files: `fragment_suffix_evidence.csv`, `fig_suffix_evidence.png`.
