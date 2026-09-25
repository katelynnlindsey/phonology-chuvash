# Replacement Methods text: syllabification

## Why the current sentence has to change

The draft's §"Syllable segmentation" says:

> I segmented each word into syllables by first identifying vowel nuclei, then
> assigning onsets and codas according to onset maximization and
> sonority-sequencing principles.

The shipped code does not do this. `.max_onset_size()` in
`config/phonology_params.R` returns `1` for any non-empty cluster and ignores
its `sonority` argument, so exactly one consonant is assigned to each
following onset and the `IPA_SONORITY` table is never consulted.

`analyses/syllabification_audit.R` implements the documented algorithm
alongside the shipped one and compares them on every word type:

| corpus | word types | ≥2 medial C | ≥3 medial C | parsed differently |
|---|---|---|---|---|
| Zheltov wordlist | 18,984 | 73.2% | 5.4% | **25.6%** |
| Monolingual corpus | 408,505 | 80.4% | 7.6% | **26.3%** |
| Spoken corpora | 15,953 | 69.5% | 4.6% | **20.1%** |

**The shipped rule is the linguistically correct one, and the documented
algorithm would be wrong for Chuvash.** Onset maximization by rising sonority
produces complex onsets that Chuvash does not license in native vocabulary:

| word | shipped | documented |
|---|---|---|
| /ajakra/ 'from the side' | a.jak.ra | a.ja.**kr**a |
| /ajɵpla/ 'to blame' | a.jɵp.la | a.jɵ.**pl**a |
| /ajlɵmlɵ/ | aj.lɵm.lɵ | aj.lɵ.**ml**ɵ |
| /ajkaʃni/ | aj.kaʃ.ni | aj.ka.**ʃn**i |

So this is a documentation error, not an analysis error. The fix is to describe
what the code does and say why it is right, rather than to change the code.

## Suggested replacement

> Each word was syllabified from its IPA transliteration. Every vowel heads
> exactly one syllable. Word-initial consonants were assigned to the first
> syllable's onset and word-final consonants to the last syllable's coda. For
> each intervocalic consonant cluster, the rightmost consonant was assigned to
> the following syllable's onset and any remaining consonants to the preceding
> syllable's coda. Because Chuvash does not license complex onsets in native
> vocabulary, this yields the correct V.CV and VC.CV parses without appeal to
> sonority sequencing; 98.6% of intervocalic clusters in the wordlist and 97.6%
> in the spoken corpora are one or two consonants, so cases where a
> sonority-based onset-maximization rule would differ are both rare and, where
> they occur, would incorrectly produce onset clusters such as /kr/ and /pl/.
> Affricates (/t͡ɕ/) were treated as single segments.

Adjust the two percentages if the data are regenerated:
`output/syllabification_clusters.csv`, sizes 1 and 2 summed per corpus.

## A related bug this audit surfaced, now fixed

`CONSONANT_TO_IPA` maps Chuvash ⟨ч⟩ to `tɕ`, but `tɕ` was absent from both
`IPA_DIGRAPHS` and `IPA_SONORITY`. The tokenizer therefore split the affricate
into `t` + `ɕ`, and the syllabifier placed the `/t/` in one syllable's coda and
the `/ɕ/` in the next syllable's onset — splitting a single phoneme across a
syllable boundary. 12–18% of word types per corpus contain the sequence.

Effect on the data, measured before and after the fix:

- 8,529 vowel rows (2.97% of the spoken data) had `syllable_coda = "closed"`
  where the "coda" was half an affricate.
- After adding `tɕ` to `IPA_DIGRAPHS`, `syllable_coda` changed for 2,864 rows
  (0.97%): 2,614 closed → open, 250 open → closed. Totals moved from
  151,447 open / 135,971 closed to 153,698 open / 133,720 closed.
- Apparent three-consonant medial clusters fell from 5.6% to 2.3% of clusters
  in the spoken data, because many were two consonants plus a split affricate.

This matters beyond syllable counts: `syllable_coda` is a fixed effect in every
acoustic model, it defines the `weight` candidate stress rule, and it is the
evidence for the minimal-word generalisation that /ø ʉ ɵ/ require a coda. Any
result computed before 2026-09-25 used the split-affricate parse.
