# Re-extraction specification

*2026-09-26. Replaces `7-extract/contours/vowels/time-series_f0-int.praat`.*

The alignment does not need redoing — the contour and new-FAVE extractions
already come from one alignment (verified: 100.0% of contour vowel intervals
match the `6-annotate` ARPAbet grids, 2,024 intervals checked across both
corpora). What needs redoing is the **measurement**, for three reasons, and
while the objects are open it costs nothing to also take the consonants.

## What was wrong

**1. Intensity was measured on excised vowels.** The old script ran
`Extract part ... rectangular` on each vowel and then `To Intensity` on the
excerpt. Praat emits no intensity sample until a full 3.2/floor-second window
fits inside the sound, so with a 100 Hz floor the first and last ~32 ms of every
vowel were undefined — and the script wrote undefined as `0`. That is the source
of the 71% zero rate across the 20 step columns, of steps 1, 2, 19 and 20 being
zero for 100% of vowels, and of the valid-step count correlating with duration
at r = 0.93.

**2. The pitch floor moved with duration.** When a vowel was shorter than
6.4/floor the script raised the floor to `6.4/dur + 1` for intensity and
`ceiling(3/dur) + 1` for pitch. Short vowels were therefore analysed with a
shorter window than long ones. Duration is the other dependent variable in this
study, so that is a confound, not a nuisance.

**3. f0 was read off a PitchTier stylised to 2 semitones**, after 10 Hz
smoothing and interpolation. Two semitones is about 25 Hz at 200 Hz, against the
1 Hz JND the draft cites. In the sample checked, steps 10 and 11 carry an
identical value in 7.9% of vowels purely from stylisation.

## What the new script does

`extract_phones.py`, two passes, parselmouth.

**Pass `floors`** estimates a pitch floor and ceiling per speaker from that
speaker's own f0, using Hirst's (2011) two-pass constants — floor = 0.72 × q15,
ceiling = 1.9 × q65 — pooled across that speaker's recordings, with a
corpus-wide fallback for speakers with fewer than three files. Output:
`floors.csv` with `speaker_id, n_files, q15, q65, pitch_floor, pitch_ceiling,
from_pooled_estimate`.

**Pass `measure`** builds **one** `Pitch` and **one** `Intensity` object per
recording, at that speaker's fixed floor and ceiling, and reads values at each
phone's time points. Because the analysis window is filled by surrounding audio,
a phone's edges are measurable and the only undefined samples are genuinely
unvoiced.

It emits one row per non-silent phone — **consonants included** — with the 20
step values for f0 and intensity, midpoint and summary statistics, and the
boundary context needed for the prosodic questions: word and utterance extent,
word index by start time, preceding and following pause duration, relative
position in the utterance, and word-initial / word-final / utterance-final
flags. FAVE's bracket attributes (`sidx`, `sN`, `pos`, `oc`) are carried through
where the grid has them.

Step *k* sits at (*k* − 0.5)/20 of the phone, spanning 2.5%–97.5% and symmetric
about the midpoint. The old script used *k*/21, which spans 4.76%–95.24%.

## Validation

Run on 30 Chuvash Voice recordings (519 vowels, 741 consonants) and compared
against the same vowels in the old contour output:

| | old | new |
|---|---|---|
| intensity steps undefined | 71% of cells; 100% at steps 1, 2, 19, 20 | **0.00–0.39%** |
| r(valid intensity steps, duration) | 0.93 | **0.016** |
| `int_midpoint` finite | 100% by construction (2 samples) | 99.8% (20 samples) |
| r(`int_midpoint`, duration) | −0.063 | −0.307 |

Against the old measure on the same vowels: **r = 0.998**, mean difference
+0.03 dB. That is the reassuring result — the midpoint measure adopted on
2026-09-25 was already right, and what the re-extraction recovers is everything
*away* from the midpoint, which was previously unusable. New raw f0 against old
stylised f0 correlates at 0.840.

## Running it

~0.10 s per recording, single core, on 2026 laptop hardware. All 49,583
recordings:

| cores | wall time |
|---|---|
| 1 | 83 min |
| 16 | 5 min |
| 32 | 3 min |

```bash
REPO=/path/to/phonology-chuvash
cd $REPO/7-extract/reextract
python -m pip install praat-parselmouth pandas numpy

# Chuvash Voice — supply the speaker map, since it is not one speaker per file
python extract_phones.py floors \
    --audio-dir    $REPO/1-raw_data/chuvash_voice/audio_transcripts \
    --audio-ext    .wav \
    --textgrid-dir $REPO/6-annotate/chuvash_voice/recoded_textgrids \
    --textgrid-suffix _arpabet \
    --speaker-map  speakers_chuvash_voice.csv \
    --out floors_chuvash_voice.csv --jobs $SLURM_CPUS_PER_TASK

python extract_phones.py measure \
    --audio-dir    $REPO/1-raw_data/chuvash_voice/audio_transcripts \
    --audio-ext    .wav \
    --textgrid-dir $REPO/6-annotate/chuvash_voice/recoded_textgrids \
    --textgrid-suffix _arpabet \
    --speaker-map  speakers_chuvash_voice.csv \
    --floors floors_chuvash_voice.csv \
    --corpus chuvash_voice --out-dir out/ \
    --jobs $SLURM_CPUS_PER_TASK --resume

# Common Voice — .mp3, one clip per row in the TSV, speaker map from client_id
python extract_phones.py floors \
    --audio-dir    $REPO/1-raw_data/common_voice_chuvash/audio_metadata_Mozilla \
    --audio-ext    .mp3 \
    --textgrid-dir $REPO/6-annotate/common_voice_chuvash/recoded_textgrids \
    --textgrid-suffix _arpabet \
    --speaker-map  speakers_common_voice.csv \
    --out floors_common_voice.csv --jobs $SLURM_CPUS_PER_TASK
# ...then measure, as above, with --corpus common_voice_chuvash
```

`--resume` reads `out/manifest_<corpus>.csv` and skips finished files, so an
interrupted job restarts where it stopped. Failures are collected rather than
fatal; detail lands in `out/errors_<corpus>.log`.

`--jobs 1` forces serial. The script also falls back to serial automatically if
the container refuses to start a process pool.

### Speaker maps

Two columns, `file_name,speaker_id`, no extension on `file_name`. For Common
Voice, `client_id` from `1-raw_data/common_voice_chuvash/audio_metadata_Mozilla/*.tsv`
(recovered in `01_load_raw.R`). For Chuvash Voice, the identity is not in the
metadata — see step 2 of the analysis plan, which estimates it acoustically.
Without a map each recording is treated as its own speaker; that is acceptable
for Common Voice and wrong for Chuvash Voice, where it would fit 29,727
independent pitch ranges to one voice.

## Output schema

One row per non-silent phone.

| group | columns |
|---|---|
| identity | `file_name`, `corpus`, `speaker_id`, `phone_idx`, `phone_label` |
| settings | `pitch_floor`, `pitch_ceiling` |
| timing | `start`, `end`, `duration`, `prev_phone`, `next_phone` |
| word | `word_label`, `word_start`, `word_end`, `word_idx`, `n_words` |
| utterance | `utt_start`, `utt_end`, `rel_utt_position` |
| boundaries | `pause_before`, `pause_after`, `is_word_initial`, `is_word_final`, `is_utt_final` |
| grid attributes | `sidx`, `sN`, `pos`, `oc` |
| contours | `f0_step1`–`f0_step20`, `int_step1`–`int_step20` |
| summaries | `f0_midpoint`, `f0_mean`, `f0_min`, `f0_max`, `int_midpoint`, `int_mean_db`, `int_mean_energy`, `int_max` |
| coverage | `n_f0_valid`, `n_int_valid`, `prop_voiced` |

Undefined is `NA`, never `0`.

Both `int_mean_db` and `int_mean_energy` are emitted: Praat's dB mean averages
decibels, the energy mean averages power and is the physically meaningful one.
They differ most for vowels with a large internal intensity range, so reporting
which one was used matters.

## Folding it back in

The output replaces the contour half of `01_load_raw.R`. The interval join
survives unchanged — `(file_name, start, end)` is still unique and
non-overlapping — but it becomes unnecessary for anything except pairing with
FAVE's formants, since the new table already carries word and syllable context.
Keep the old columns under their existing names for one cycle so the two can be
compared row for row before the old extraction is retired.
