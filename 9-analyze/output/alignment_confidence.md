# Alignment confidence without hand-checking every file

*Written 2026-09-26 in answer to: "I automatically aligned the transcripts but I
did not hand check them, so I'm trying to be conservative. Do you have a better
idea?"*

Yes. The short version: **stop using exclusion as a proxy for confidence, and
measure confidence directly.** Being conservative is right; dropping 45–47% of
the data is not the way to do it, because the current filter is not conservative
in the statistical sense — it is biased in a direction that matters.

## Why the current filter is worse than it looks

Cleaning step 06 removes a polysyllabic word entirely if any one of its vowels
failed an earlier filter: 162,689 vowels in Chuvash Voice and 55,273 in Common
Voice, 45–47% of what reaches it. Almost all of the loss cascades from step 05.

Step 05 applies Tukey 1.5×IQR fences to duration, F1 and F2. Two problems:

1. **The fences are computed within vowel × corpus.** The comment at line 85
   says "within vowel × stress × corpus", but the code at line 230 groups by
   `label, corpus` only. Stressed vowels are longer, so they populate the upper
   tail; trimming a pooled distribution removes stressed tokens preferentially.
   The filter is correlated with the dependent variable.
2. **The fences are not computed within speaker.** One speaker supplies 69% of
   all vowels, so the fences are effectively his, and the other 104 speakers are
   trimmed against a distribution that is not theirs.

Step 06 then propagates each such removal to the whole word. A word is discarded
not because its alignment is doubtful but because one of its vowels was long —
which is what stress does.

So the filter is not neutral caution. It is a stress-correlated, speaker-
correlated deletion of 45% of the evidence.

## What to do instead

### 1. Score every vowel, discard nothing

Five signals are available without listening to anything.

**(a) Cross-alignment boundary agreement — free, and you already have it.**
`1-raw_data/common_voice_chuvash/textgrids_VOX` is an independent alignment of
the same audio by a different model (Vox Communis). It is not used anywhere in
the pipeline and was previously assumed stale. It covers 16,858 of the Common
Voice recordings. For every phone present in both, the absolute difference in
onset and offset is a direct, model-external index of how well-determined that
boundary is. Where two independent aligners put a boundary within 20 ms of each
other, it is very unlikely to be wrong; where they differ by 300 ms, the
segment is suspect regardless of how plausible its formants look. This gives a
labelled confidence variable on a third of the corpus at zero cost.

**(b) `smooth_error`, already in every FAVE points file.** new-FAVE's
formant-tracking smoothing error is a per-vowel measurement-quality index. It is
currently discarded at load. It should be carried through and used — it
separates "the vowel is unusual" from "the measurement is unreliable", which the
IQR filter cannot do.

**(c) Dictionary provenance.** Words aligned from a G2P-generated pronunciation
rather than a dictionary entry carry more risk. `4-align/.../add_oovs_to_dict/`
has `oovs_found_chuvash_cv.txt` and `chuvash_cv_with_oovs.dict`; a boolean
`pron_from_g2p` per word token follows directly.

**(d) Per-phone duration z-score, within phone and within speaker.** A 140 ms
/ɵ/ is unremarkable for one speaker and extreme for another. This is what step 05
should have been computing. Keep it as a covariate rather than a fence.

**(e) MFA's own alignment score,** if you re-run. MFA 3.x reports per-utterance
and per-word log-likelihood; `mfa validate` surfaces utterances the model fit
poorly. Since you are re-extracting anyway, exporting these costs one flag.

### 2. Calibrate with a small stratified hand-check

Sample ~250 vowels stratified across the confidence score — say five strata,
50 each — and check those by ear and by spectrogram. Two hours of work. It buys
you a **measured** error rate per stratum, so the paper can say "boundary error
exceeded 25 ms in 3% of high-confidence tokens and 31% of low-confidence
tokens" instead of "alignments were not hand-checked". For a *Language*
reviewer that difference is large: the first is a validated pipeline with a
quantified limitation, the second is an unquantified risk.

Stratify on the cross-alignment disagreement from (a) where it exists, since
that is the signal most likely to be picking up real misalignment.

### 3. Change the exclusion to a flag, and report both

Replace the step-06 deletion with a column:

- `word_complete` — all syllables of this word survived the earlier filters
- `align_confidence` — the composite score from (a)–(e)

Then run the primary models on **all** vowels, with the speaker, file and word
random effects already in place, and add `align_confidence` as a covariate. Run
the complete-words-only subset as a robustness check and report both in the
paper. If the effect is real it will survive; if it depends on the filter, you
need to know that, and so does the reviewer.

This is strictly more conservative than the current design, because it makes the
sensitivity of the result to the filter visible instead of assuming it away.

### 4. Fix step 05 whether or not you do the rest

At minimum, compute the fences within `vowel × speaker` rather than
`vowel × corpus`, and never within a grouping that pools stressed and unstressed
tokens. Better: replace the hard fences with the z-score covariate from (d), and
drop only physically impossible values (the absolute bounds in step 03 already
do this).

## Expected effect

Steps 05 and 06 currently remove 217,962 vowels between them. Most of those are
ordinary tokens of ordinary words. Recovering them roughly doubles the analysed
data, and — more important for this paper — removes a filter whose selectivity is
correlated with stress from between the data and every reported coefficient.
