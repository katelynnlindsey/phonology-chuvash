# Who is in Chuvash Voice

*2026-09-26. Method and result for `speaker_structure.csv`.*

Chuvash Voice ships no speaker identity, and it supplies 211,798 of the 280,955
analysed vowels — 75%. Whether that is one voice or many decides whether
`(1|speaker_id)` is doing anything in the models, and it decides how the
corpus's contribution should be described in the paper. The working assumption
has been "mostly one person plus an unknown number of others". This measures it.

## Method

Per recording: f0 at the 5th, 15th, 50th, 85th and 95th percentiles plus its
standard deviation and proportion voiced; a long-term average spectrum in
sixteen 500 Hz bands to 8 kHz, mean-centred so that the *shape* rather than the
recording level carries the information; and mean harmonics-to-noise ratio.
24 features, computed by `7-extract/reextract/speaker_features.py` on all
29,860 Chuvash Voice and 20,392 Common Voice recordings.

Features are standardised and reduced to 14 principal components (95% of
variance) in a space **fitted on Common Voice**, where `client_id` gives ground
truth for 109 speakers. Within that space, the distribution of pairwise
distances between recordings of the same speaker is compared against pairs from
different speakers, and the threshold is set where the false-accept and
false-reject rates are equal: **5.67**, at an equal error rate of 0.30.

The same threshold then drives average-linkage agglomerative clustering on both
corpora, on 8,000-recording subsamples, and every Chuvash Voice recording is
assigned to the nearest resulting centroid.

An equal error rate of 0.30 means these features are weak at deciding any
individual pair. The comparison below does not depend on pairwise accuracy — it
depends on the method behaving differently on a corpus with many speakers than
on a corpus with one, which is exactly what the Common Voice arm establishes.

## Result

| | clusters found | largest cluster | clusters ≥1% |
|---|---|---|---|
| Common Voice (102 speakers in the subsample) | 78 | 34.8% | 5 |
| Chuvash Voice | **11** | **99.4%** | **1** |

Extending the Chuvash Voice clustering to all 29,860 recordings by nearest
centroid puts **93.4%** in the dominant cluster and 1,970 recordings (6.6%) in
ten minor ones.

So: Chuvash Voice is one speaker for somewhere between 93% and 99% of its
recordings, and the method that resolves a 102-speaker corpus into 78 clusters
resolves this one into essentially a single cluster.

The minor clusters are not noise. Four of them sit far below the dominant
voice's f0 and together cover 564 recordings:

| cluster | recordings | median f0 | median HNR |
|---|---|---|---|
| dominant | 27,890 | 225.6 Hz | 13.8 dB |
| voice_4 | 703 | 144.4 Hz | 7.4 dB |
| voice_1 | 495 | 201.1 Hz | 15.3 dB |
| voice_2 | 390 | 251.1 Hz | 12.5 dB |
| voice_3 | 163 | 182.9 Hz | 10.3 dB |
| voice_5 | 68 | 124.2 Hz | 11.5 dB |
| voice_8 | 33 | 107.8 Hz | 13.1 dB |
| voice_7 | 15 | 109.6 Hz | 6.4 dB |

A 100 Hz gap in median f0 between the dominant voice and `voice_5`, `voice_7`
and `voice_8` is not within-speaker variation. There are at least three or four
additional speakers, most of them plausibly male against a female dominant
voice.

## What follows for the analysis

**Use `voice_label`, not one constant, as the Chuvash Voice speaker term.** The
current `speaker_id` for this corpus is a single value, so `(1|speaker_id)`
absorbs nothing within it; with the inferred labels the term has 11 levels and
the 6.6% that is not the dominant voice stops being pooled with it.

**Supply it to the re-extraction as the speaker map**, so per-speaker pitch
floors are estimated per voice rather than per recording.

**Report it as an estimate, with its error rate.** The right sentence for the
paper is that Chuvash Voice is dominated by a single speaker who supplies about
93% of its recordings, with a small number of additional voices identified
acoustically — not that it has 11 speakers. The cluster count is a lower bound
on distinct voices and an upper bound on nothing.

**It does not fix the imbalance.** One speaker still supplies roughly 69% of all
vowels in the study. That is a limitation to state, not to model away.

## Files

- `speaker_structure.csv` — one row per Chuvash Voice recording: `voice_label`,
  median f0, f0 sd, HNR, duration
- `speaker_structure_validation.csv` — the Common Voice calibration
- `fig_speaker_structure.png`
