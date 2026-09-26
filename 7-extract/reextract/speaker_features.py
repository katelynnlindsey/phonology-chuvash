#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Per-recording acoustic speaker features, for estimating voice structure.

Chuvash Voice ships no speaker identity. It is believed to be mostly one
speaker with an unknown number of others, which matters because that corpus
supplies ~69% of all analysed vowels and the random-effects structure depends
on how many voices are actually in it.

This computes a cheap, speaker-discriminative feature vector per recording:
f0 quantiles and spread (the strongest single cue), a long-term average
spectrum in 500 Hz bands up to 8 kHz (voice quality and vocal-tract length),
and mean harmonics-to-noise ratio. Cluster these, and validate the clustering
against Common Voice, where `client_id` gives ground truth.

  python speaker_features.py --audio-dir DIR --audio-ext .wav \\
      --out features.csv --jobs 8 [--limit N]
"""

import argparse
import os
import sys
import traceback
from concurrent.futures import ProcessPoolExecutor, as_completed

import numpy as np
import pandas as pd
import parselmouth
from parselmouth.praat import call

LTAS_BANDWIDTH = 500.0
LTAS_MAX = 8000.0


def features(audio_path):
    snd = parselmouth.Sound(audio_path)
    dur = snd.get_total_duration()
    if dur < 0.3:
        return None
    row = {"duration_s": dur}

    pitch = call(snd, "To Pitch", 0.0, 60.0, 700.0)
    f0 = pitch.selected_array["frequency"]
    f0 = f0[f0 > 0]
    if f0.size < 10:
        return None
    for q in (5, 15, 50, 85, 95):
        row[f"f0_q{q}"] = float(np.percentile(f0, q))
    row["f0_sd"] = float(np.std(f0))
    row["f0_prop_voiced"] = float(f0.size) / max(len(pitch.selected_array["frequency"]), 1)

    ltas = call(snd, "To Ltas", LTAS_BANDWIDTH)
    n_bands = int(LTAS_MAX // LTAS_BANDWIDTH)
    vals = []
    for b in range(n_bands):
        lo, hi = b * LTAS_BANDWIDTH, (b + 1) * LTAS_BANDWIDTH
        vals.append(call(ltas, "Get mean", lo, hi, "energy"))
    vals = np.array([np.nan if v is None else float(v) for v in vals])
    # Normalise out overall level; shape is the speaker cue, loudness is not.
    if np.isfinite(vals).sum() >= n_bands - 2:
        vals = vals - np.nanmean(vals)
    for b, v in enumerate(vals):
        row[f"ltas_{int(b * LTAS_BANDWIDTH)}"] = float(v) if np.isfinite(v) else np.nan

    harm = call(snd, "To Harmonicity (cc)", 0.01, 75.0, 0.1, 1.0)
    hnr = call(harm, "Get mean", 0, 0)
    row["hnr"] = float(hnr) if hnr is not None and np.isfinite(hnr) else np.nan
    return row


def _worker(task):
    stem, path = task
    try:
        f = features(path)
        return (stem, f, None) if f else (stem, None, "too short or unvoiced")
    except Exception:
        return stem, None, traceback.format_exc(limit=2)


def imap(fn, tasks, jobs):
    if jobs and jobs > 1:
        try:
            with ProcessPoolExecutor(max_workers=jobs) as pool:
                futures = [pool.submit(fn, t) for t in tasks]
                for fut in as_completed(futures):
                    yield fut.result()
            return
        except (PermissionError, OSError, NotImplementedError) as exc:
            print(f"  [warn] process pool unavailable ({exc}); serial",
                  file=sys.stderr, flush=True)
    for t in tasks:
        yield fn(t)


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--audio-dir", required=True)
    p.add_argument("--audio-ext", default=".wav")
    p.add_argument("--out", required=True)
    p.add_argument("--jobs", type=int, default=1)
    p.add_argument("--limit", type=int, default=0)
    args = p.parse_args()

    names = sorted(fn for fn in os.listdir(args.audio_dir)
                   if fn.lower().endswith(args.audio_ext.lower()))
    if args.limit:
        names = names[: args.limit]
    tasks = [(fn[: -len(args.audio_ext)], os.path.join(args.audio_dir, fn))
             for fn in names]
    print(f"{len(tasks)} recordings", flush=True)

    rows, failed = [], 0
    for i, (stem, f, err) in enumerate(imap(_worker, tasks, args.jobs), 1):
        if f is None:
            failed += 1
        else:
            f["file_name"] = stem
            rows.append(f)
        if i % 2000 == 0:
            print(f"  {i}/{len(tasks)}  ok={len(rows)}  failed={failed}", flush=True)
    df = pd.DataFrame(rows)
    cols = ["file_name"] + [c for c in df.columns if c != "file_name"]
    df[cols].to_csv(args.out, index=False)
    print(f"wrote {args.out}: {len(df)} rows x {len(cols)} cols, {failed} failed")


if __name__ == "__main__":
    main()
