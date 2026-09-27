# Extraction provenance: which TextGrids, which settings, what the 12.5% was

*Generated 2026-09-26. Corrects item (a) of `repo_audit_2026-09-25.md`.*

## Correction: the 12.50% of FAVE points that matched no contour interval are not lost data

The 2026-09-25 audit listed this as the largest recoverable loss in the pipeline
and estimated 86,129 recoverable vowels. **That was wrong.** The unmatched rows
are not vowels.

new-FAVE emits a point row for every interval it is handed, including silence.
Sampling 500 recordings per corpus:

| corpus | FAVE point rows | non-target labels |
|---|---|---|
| Chuvash Voice | 9,196 | 1,476 (16.05%) — `SIL` 14.77%, `OW` 1.28% |
| Common Voice | 4,478 | 45 (1.00%) — `OW` 1.00% |

`SIL` is silence. `OW` is the loan vowel /o/, which `VOWEL_CATEGORY_RULES`
classifies as `L` and excludes by design. These sampled rates — 16.05% and 1.00% — are close to, but not the same
statistic as, the 15.50% / 1.23% unmatched-join rates in the 2026-09-25 audit:
those were computed over every row of the joined table, these over a 500-file
sample of the raw FAVE output. They agree in direction and magnitude, which is
what identifies the cause — Chuvash Voice utterances are long and contain labelled
pauses, Common Voice clips do not. And the arithmetic closes: 703,582 raw point
rows − 615,634 target vowels = 87,948, which is the unmatched count to the row.
Cleaning step 01 ("target vowels only") would have dropped every one of them.

**No vowels are missing. No re-extraction is needed on this account.**

## The two extractions come from one alignment

Verified directly against the TextGrids, on 60 Common Voice and 60 Chuvash Voice
recordings:

| contour intervals compared against | exact match |
|---|---|
| `6-annotate/*/recoded_textgrids` (ARPAbet, what new-FAVE read) | **100.0%** (618/618 CV, 1406/1406 ChV) |
| `1-raw_data/common_voice_chuvash/textgrids_VOX` | 6.6% |

Both `time-series_f0-int.praat` and `recode_textgrid_ARPABET.py` read the same
`to_process/` directory on the original machine, so the f0/intensity contours and
the FAVE formant measurements describe identical intervals.

### `1-raw_data/common_voice_chuvash/textgrids_VOX` is a different alignment and is not used

17,023 files against 17,329 in the ARPAbet set; 16,858 shared. Where both exist
the segmentations differ substantially — only 37 of 60 sampled files have the
same phone count, and no file has all boundaries within 10 ms. Example,
`common_voice_cv_27596519`: the VOX grid places `v ʌ l` in the first 120 ms and
then 1.29 s of silence; the ARPAbet grid places 700 ms of leading silence and
`V AH1 L` from 0.700 s. Nothing in the analysis reads this directory. It should
be labelled as a third-party alignment that was superseded, or removed.

**It is, however, useful.** It is an independent alignment of the same audio by a
different model, so per-boundary agreement between the two is a free,
hand-checking-free index of alignment confidence on 16,858 Common Voice
recordings. See `alignment_confidence.md`.

### The contour output directories are swapped

- `7-extract/contours/vowels/common_voice_chuvash/contours_output.csv` contains
  `utterance_*` — **Chuvash Voice**
- `7-extract/contours/vowels/chuvash_voice/contours_output.csv` contains
  `common_voice_cv_*` — **Common Voice**

No analysis is affected: `01_load_raw.R` derives `corpus` from the filename
prefix, not the directory. But the directories should be renamed before anyone
reads the tree.

## Settings recovered from `time-series_f0-int.praat`

This answers the `[specify]` in draft Table 2 and explains the intensity defect.

| parameter | value |
|---|---|
| pitch floor / ceiling | **100 / 800 Hz** |
| pitch algorithm | filtered autocorrelation, time step 0.01 s, 15 candidates |
| silence / voicing threshold | 0.09 / 0.5 |
| octave, octave-jump, voiced-unvoiced cost | 0.055 / 0.35 / 0.14 |
| octave jumps killed | yes |
| smoothing | 10 Hz, then interpolated |
| stylisation | **2 semitones** |
| measurement points | 20, at *k*/21 of the vowel, so 4.76%–95.24% |

### Consequences

1. **The intensity zeros are structural, not missing data.** Each vowel is
   excised (`Extract part ... rectangular`) and `To Intensity` is run on the
   excerpt. Praat's intensity window is 3.2/floor seconds and it emits no sample
   until a full window fits, so with a 100 Hz floor the first and last ~32 ms of
   every vowel are undefined. The script writes undefined as `0`. This is exactly
   the symmetric pattern observed: steps 1, 2, 19, 20 zero for 100% of vowels,
   steps 10 and 11 never zero, valid-step count correlating with duration at
   r = 0.93.
2. **The effective pitch floor is duration-dependent.** When a vowel is shorter
   than 6.4/floor the script raises the floor to `6.4/dur + 1` for intensity and
   to `ceiling(3/dur) + 1` for pitch. Short vowels are therefore analysed with a
   shorter analysis window — a duration-dependent bias baked into the values
   themselves, not just into which steps are defined. Since duration is the other
   dependent variable, this is not a nuisance.
3. **f0 is read off a stylised PitchTier.** 10 Hz smoothing, interpolation, then
   2 ST stylisation. Two semitones is roughly 12% of f0 — about 25 Hz at 200 Hz —
   against the 1 Hz JND the draft cites from Gandour (1978). Adjacent steps
   frequently carry identical values. Any claim resting on small f0 differences
   should not use this column.
4. **Steps 10 and 11 fall at 47.6% and 52.4%**, so `int_midpoint` (their mean)
   sits at exactly 50.0% of the vowel. The measure adopted on 2026-09-25 is
   correctly centred.
5. The header comment says "disyllabic words only"; the code filter is
   `total_vowels_in_word > 0`, so monosyllables are included.
6. `vowel_category` / `word_category` in the contour CSV hardcode inventory 6
   (ɛ and ʌ reduced, ɯ full). They are recomputed in R and should be ignored.

## If re-extracting

The intensity and f0 problems are worth a re-run; the alignment is not.

- **Do not excise the vowel.** Compute one `Intensity` and one `Pitch` object per
  recording and read values at the vowel's time points. This removes the
  duration-dependent window, the edge undefineds and the rectangular-window edge
  effects, and is much faster — one analysis per file instead of one per vowel.
- **Fix the floor and ceiling per speaker**, or at least per sex, from a first
  pass over that speaker's f0 distribution. A single 100–800 Hz setting spans
  implausible ranges for both.
- **Keep the raw pitch track** as well as any stylised version, and record which
  samples are interpolated.
- **Extract all phone intervals, not only vowels.** Consonant durations are
  needed for the gemination question and cost nothing extra once the objects are
  built.
- **Carry the boundaries through**: phone start/end, word start/end, utterance
  start/end and following-pause duration, so final lengthening and phrase
  position are measurable without a second pass.
