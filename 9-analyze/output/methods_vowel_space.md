# The vowel space: rounding, and how many categories it supports

*2026-09-26. `analyses/vowel_space.R` plus the clustering in
`fig_vowel_clustering.png`. n = 213,477 vowels in non-palatal contexts,
85 speakers, Lobanov-normalised within speaker.*

Speaker term: `speaker` is the Common Voice `client_id` where it exists and the
inferred Chuvash Voice `voice_label` otherwise (see
`methods_speaker_structure.md`). Speakers with fewer than 20 tokens are dropped,
because a z-score over fewer is noise; that leaves 85 of 115.
Non-palatal excludes vowels adjacent to /j ɕ ʃ tɕ ʒ/, 76.1% of the data.

## Rounding

A global ordering on F3−F2 cannot test rounding, because that distance is also a
function of backness. Rounding is identified only *within* a height/backness
pair, where the rounded member should show both a lower F2 and a lower F3:

| pair | ΔF2 (z) | ΔF3 (z) | verdict |
|---|---|---|---|
| /y/ vs /i/ | −0.540 | −0.697 | rounded |
| /ø/ vs /e/ | −0.558 | −0.379 | rounded |
| /u/ vs /ʉ/ | −0.353 | −0.347 | rounded |
| /ɵ/ vs /a/ | −0.212 | **+0.013 (z = 0.97)** | **not rounded** |

`VOWEL_ROUND` in the config asserts {y, ø, u, ɵ}. Three of the four hold. **/ɵ/
does not**: its F2 is lower than /a/'s, but its F3 is not, which is what backness
alone predicts. ⟨ӑ⟩ should be described as a back or central *unrounded* reduced
vowel, and `VOWEL_ROUND` should drop it.

## How many vowel categories does the acoustics support?

Gaussian mixtures on normalised F1/F2/F3, non-palatal contexts, k = 3…12.

**BIC does not answer this question.** It falls monotonically to the largest k
tested, in both context sets — the familiar failure mode where extra components
model within-category non-Gaussianity rather than new categories. Reporting a
BIC-optimal k here would be an artifact.

What is informative is **agreement with the phonemic eight**, which peaks *below*
eight and falls away:

| components | 4 | 5 | 6 | 8 | 10 | 12 |
|---|---|---|---|---|---|---|
| adjusted Rand | 0.468 | 0.466 | **0.475** | 0.339 | 0.301 | 0.275 |
| adjusted mutual information | 0.466 | 0.452 | 0.461 | 0.420 | 0.407 | 0.395 |

At six components the eight phonemes fall into groups that share a modal
component: **{e, i, ø}** and **{u, ʉ, ɵ}**, with /a/ and /y/ separate.

## Pairwise separability

Balanced accuracy of a quadratic discriminant on F1/F2/F3, 5-fold
cross-validated. 0.50 is chance:

| pair | accuracy |
|---|---|
| /i/ ~ /y/ | **0.518** |
| /ʉ/ ~ /ɵ/ | **0.527** |
| /y/ ~ /ø/ | 0.567 |
| /u/ ~ /ʉ/ | 0.582 |
| /e/ ~ /y/ | 0.645 |
| /e/ ~ /ø/ | 0.693 |
| /e/ ~ /i/ | 0.721 |
| /a/ vs anything | 0.81–0.98 |

Two consequences for the argument.

**/ʉ/ and /ɵ/ are acoustically the same vowel in this data** (0.527). The case
for treating ⟨ы⟩ as reduced — inventory 5, and so rule B5 — has so far rested
entirely on written-corpus distribution: ʉ never in an open monosyllable,
89.5% initial-restricted. This is independent acoustic support for the same
grouping, and it is worth having, because the distributional argument and the
acoustic argument can fail independently.

**/y/ and /i/ are not distinguishable** (0.518), even in non-palatal contexts.
/y/ is the rarest native vowel at 0.7–0.9% of tokens. The Q1 argument calls it
full on the strength of a 15.4% open-monosyllable rate over 52 wordlist
monosyllables. That distributional claim stands, but it should not be
supported by an appeal to /y/ being a distinct acoustic target here, because
it is not one.

## The caveat that belongs in the same paragraph

Separability tracks duration: r = 0.70 across the eight vowels. The
reduced vowels are the short ones, and a single formant measurement on a 70 ms
vowel is noisier than on a 90 ms vowel. Some of the merging is therefore
measurement, not phonology, and this design cannot separate the two. What it
can say is that whatever distinguishes /ʉ/ from /ɵ/, or /y/ from /i/, is not
recoverable from a point measurement of F1–F3 at this sample size — which is
itself the relevant fact for a listener-oriented argument.

The other standing limitation applies here too: one speaker supplies about 69%
of all vowels, so the normalised space is largely that speaker's.

## Files

- `vowel_space_means.csv`, `rounding_models.csv`, `rounding_contrasts.csv`
- `clustering_comparison.csv`, `clustering_bic.csv`, `clustering_confusion.csv`
- `vowel_separability.csv`, `vowel_separability_vs_duration.csv`
- `vowels_normalised.csv` — row-level export the shift analysis reads
- `fig_vowel_chart.png`, `fig_vowel_clustering.png`
