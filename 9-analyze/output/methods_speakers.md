# Speaker metadata: what exists, and the random-effect structure

## The draft's "Num. groups: speaker_id = 108" is nearly right, and recoverable

Before 2026-09-25 `speaker_id` was **100% missing for Common Voice** and had a
single value for Chuvash Voice, so a speaker random effect looked
unsupportable and `stress_rule_comparison.R` switched to `file_name` with a
note that `speaker_id` was "mostly unfilled".

The cause was a dropped column, not missing data. `01_load_raw.R` read the
Common Voice TSV but `select()`ed only `sentence`, `age`, `gender`, `accents`
and `variant` — discarding `client_id` and `speaker_id`, which the TSV does
carry (109 distinct values, 0 missing). The only other source of speaker
identity, the HuggingFace parquet metadata, keys on file names of the form
`utterance_NNNNNN`, which only Chuvash Voice uses, so Common Voice matched
nothing.

Both columns are now read, and every one of the 14,617 Common Voice
recordings in the analysed data matches a TSV row.

| corpus | recordings | speakers | vowels | % speaker missing |
|---|---|---|---|---|
| Chuvash Voice | 26,720 | 1 | 211,798 | 8.41 |
| Common Voice | 14,617 | 104 | 69,157 | 0.00 |
| **total** | **41,337** | **105** | **280,955** | **6.34** |

105 speakers, covering 263,135 of 280,955 vowels (93.7%). The draft's 108 is
close enough that it plainly came from a version of the pipeline that did read
these columns.

## But the design is severely unbalanced, and that is the real limitation

Reporting "105 speakers" without the imbalance would be misleading:

- The single Chuvash Voice speaker contributes **193,978 vowels — 74% of all
  speaker-labelled vowels, 69% of the whole dataset.**
- **5 speakers account for 90%** of labelled vowels.
- The median speaker contributes **51 vowels**; **69 of 105 contribute fewer
  than 100**.

A random intercept for speaker is estimable but its variance is determined
almost entirely by one talker, and 69 speakers contribute too little to shift
it. Any between-speaker generalisation rests on effectively a handful of
talkers.

## Recommended random-effect structure

Recordings nest within speakers, and both matter: `file_name` captures
recording-session effects (microphone, room, level) that `speaker_id` does not.

```r
(1 | speaker_id) + (1 | file_name) + (1 | word_label)
```

fitted on the 93.7% of vowels with a speaker id. Keep `file_name` even with
`speaker_id` present — with one speaker covering 22,500 recordings, the
recording term is doing most of the work of controlling for session variation.

If a model fails to converge, drop `speaker_id` before `file_name`: the
recording term is better identified, and `file_name` was the sole grouping in
all results computed before 2026-09-25.

## Suggested Limitations text

> Speaker identity is available for 105 talkers covering 93.7% of the analysed
> vowels (104 in Common Voice, one in Chuvash Voice; the remaining 6.3% of
> vowels lack speaker metadata). The design is strongly unbalanced: the single
> Chuvash Voice talker contributes 69% of all vowel tokens and five talkers
> account for 90% of speaker-labelled tokens, while the median talker
> contributes 51 vowels and 69 of the 105 contribute fewer than 100. Models
> therefore include random intercepts for speaker, recording and word, but
> between-speaker variance is estimated from an effectively small number of
> talkers and results should not be read as establishing cross-speaker
> generality. Age is unavailable for Chuvash Voice entirely and gender is
> missing for 8–18% of tokens depending on corpus, so neither is used as a
> predictor.

Numbers regenerate from `output/speaker_coverage.csv` and
`output/speaker_clips.csv` via `analyses/data_profile.R`.
