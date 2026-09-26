#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Re-extract f0, intensity and durations for EVERY phone, from whole recordings.

Replaces 7-extract/contours/vowels/time-series_f0-int.praat. Three changes matter:

  1. No excision. The old script ran `Extract part ... rectangular` on each vowel
     and then `To Intensity` on the excerpt. Praat emits no intensity sample until
     a full 3.2/floor-second window fits inside the sound, so the first and last
     ~32 ms of every vowel were undefined and were written as 0 -- 71% of all step
     cells. Here one Pitch and one Intensity object is built per recording and
     values are read at each phone's time points, so a phone's edges are covered
     by the surrounding audio and the only undefined samples are genuinely
     unvoiced.

  2. Fixed floor and ceiling per speaker. The old script raised the pitch floor
     for short vowels (`6.4/dur + 1`), which made the analysis window a function
     of duration -- the other dependent variable. Pass 1 here estimates a floor
     and ceiling per speaker from that speaker's own f0 distribution (Hirst 2011),
     writes them to a table, and pass 2 uses them unchanged for every phone.

  3. All phones, not only vowels. Consonant durations are needed for the
     gemination and moraic questions and cost nothing once the objects are built.
     Word, utterance and pause boundaries are carried through so that final
     lengthening and phrase position are measurable without a second pass.

Usage
-----
  # pass 1 -- per-speaker pitch range (one Pitch object per file)
  python extract_phones.py floors \\
      --audio-dir .../audio --audio-ext .wav \\
      --textgrid-dir .../recoded_textgrids --textgrid-suffix _arpabet \\
      --speaker-map speakers.csv --out floors.csv --jobs 32

  # pass 2 -- measurements
  python extract_phones.py measure \\
      --audio-dir .../audio --audio-ext .wav \\
      --textgrid-dir .../recoded_textgrids --textgrid-suffix _arpabet \\
      --floors floors.csv --corpus chuvash_voice \\
      --out-dir out/ --jobs 32 --resume

`speakers.csv` needs columns file_name,speaker_id. Without it each recording is
treated as its own speaker -- acceptable for Common Voice, wrong for Chuvash
Voice, so supply the map there.

Output: out/phones_<corpus>_<shard>.csv, one row per phone interval, plus
out/manifest_<corpus>.csv recording which files completed.

Requires: praat-parselmouth, pandas, numpy.
"""

import argparse
import csv
import math
import os
import re
import sys
import traceback
from concurrent.futures import ProcessPoolExecutor, as_completed

import numpy as np
import pandas as pd
import parselmouth
from parselmouth.praat import call

SILENCE = {"", "sil", "SIL", "<eps>", "sp", "spn", "SP", "<sil>"}
N_STEPS = 20
# Step k sits at (k - 0.5)/N of the phone, so the 20 points are symmetric about
# the midpoint and span 2.5%-97.5%. The old script used k/(N+1), which spans
# 4.76%-95.24% -- workable, but asymmetric relative to any midpoint measure.
STEP_PROPS = [(k - 0.5) / N_STEPS for k in range(1, N_STEPS + 1)]

# Hirst (2011) two-pass constants: floor = 0.72 * q15, ceiling = 1.9 * q65.
FLOOR_FACTOR, CEIL_FACTOR = 0.72, 1.9
FLOOR_MIN, CEIL_MAX = 50.0, 700.0


# --------------------------------- TextGrid ---------------------------------

def parse_textgrid(path):
    """Long-format TextGrid -> {tier_name: [(xmin, xmax, label), ...]}."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    tiers = {}
    for block in re.split(r"item \[\d+\]:", text)[1:]:
        name = re.search(r'name = "([^"]*)"', block)
        if not name:
            continue
        rows = re.findall(
            r'xmin = ([0-9.eE+-]+)\s*\n\s*xmax = ([0-9.eE+-]+)\s*\n\s*text = "([^"]*)"',
            block)
        tiers[name.group(1)] = [(float(a), float(b), c) for a, b, c in rows]
    return tiers


def tier(tiers, want):
    key = next((k for k in tiers if want in k.lower()), None)
    return tiers[key] if key else []


def strip_attrs(label):
    """'AA1 [sidx=3/sN=3/pos=final/oc=open]' -> ('AA1', {'sidx': '3', ...})."""
    base, _, rest = label.partition(" [")
    attrs = {}
    if rest:
        for part in rest.rstrip("]").split("/"):
            if "=" in part:
                k, v = part.split("=", 1)
                attrs[k] = v
    return base.strip(), attrs


def imap(fn, tasks, jobs):
    """Map `fn` over `tasks`, in a process pool when one can be started.

    Some sandboxes and container images refuse `SC_SEM_NSEMS_MAX`, which makes
    ProcessPoolExecutor unusable. Fall back to serial rather than failing --
    the cluster run will use the pool, a local smoke test does not need it.
    """
    if jobs and jobs > 1:
        try:
            with ProcessPoolExecutor(max_workers=jobs) as pool:
                futures = [pool.submit(fn, t) for t in tasks]
                for fut in as_completed(futures):
                    yield fut.result()
            return
        except (PermissionError, OSError, NotImplementedError) as exc:
            print(f"  [warn] process pool unavailable ({exc}); running serially",
                  file=sys.stderr, flush=True)
    for t in tasks:
        yield fn(t)


def _safe(v):
    if v is None:
        return np.nan
    try:
        v = float(v)
    except (TypeError, ValueError):
        return np.nan
    return np.nan if math.isnan(v) else v


# ---------------------------------- pass 1 ----------------------------------

def file_f0_quantiles(audio_path):
    """Rough f0 distribution with a deliberately wide range. -> (q15, q65)."""
    snd = parselmouth.Sound(audio_path)
    pitch = call(snd, "To Pitch", 0.0, 60.0, 700.0)
    vals = pitch.selected_array["frequency"]
    vals = vals[vals > 0]
    if vals.size < 10:
        return None
    return float(np.percentile(vals, 15)), float(np.percentile(vals, 65))


def _floor_worker(args):
    stem, audio_path = args
    try:
        return stem, file_f0_quantiles(audio_path)
    except Exception:
        return stem, None


def run_floors(args):
    pairs = discover(args)
    spk = speaker_map(args.speaker_map)
    rows = []
    tasks = [(s, a) for s, a, _ in pairs]
    for i, (stem, q) in enumerate(imap(_floor_worker, tasks, args.jobs), 1):
        if q:
            rows.append({"file_name": stem, "speaker_id": spk.get(stem, stem),
                         "q15": q[0], "q65": q[1]})
        if i % 500 == 0:
            print(f"  floors: {i}/{len(tasks)}", flush=True)

    df = pd.DataFrame(rows)
    if df.empty:
        sys.exit("no usable pitch in any file")
    # Pool each speaker's per-file quantiles, then apply the Hirst factors once.
    out = (df.groupby("speaker_id")
             .agg(n_files=("file_name", "size"),
                  q15=("q15", "median"), q65=("q65", "median"))
             .reset_index())
    out["pitch_floor"] = (out.q15 * FLOOR_FACTOR).clip(lower=FLOOR_MIN)
    out["pitch_ceiling"] = (out.q65 * CEIL_FACTOR).clip(upper=CEIL_MAX)
    # Speakers with too few recordings fall back to the corpus-wide estimate.
    thin = out.n_files < args.min_files_per_speaker
    if thin.any() and (~thin).any():
        out.loc[thin, "pitch_floor"] = out.loc[~thin, "pitch_floor"].median()
        out.loc[thin, "pitch_ceiling"] = out.loc[~thin, "pitch_ceiling"].median()
    out["from_pooled_estimate"] = thin.values
    out.to_csv(args.out, index=False)
    print(f"wrote {args.out}: {len(out)} speakers | "
          f"floor {out.pitch_floor.min():.0f}-{out.pitch_floor.max():.0f} Hz | "
          f"ceiling {out.pitch_ceiling.min():.0f}-{out.pitch_ceiling.max():.0f} Hz")


# ---------------------------------- pass 2 ----------------------------------

def measure_file(audio_path, tg_path, corpus, speaker_id, floor, ceiling):
    """One row per non-silent phone interval."""
    tiers = parse_textgrid(tg_path)
    phones = tier(tiers, "phone")
    words = tier(tiers, "word")
    if not phones:
        return []

    snd = parselmouth.Sound(audio_path)
    total_dur = snd.get_total_duration()

    # One analysis per recording. Both objects take the same floor so that the
    # intensity window (3.2/floor) and the pitch window are commensurable.
    pitch = call(snd, "To Pitch", 0.0, floor, ceiling)
    intensity = call(snd, "To Intensity", floor, 0.0, "yes")

    speech = [(a, b) for a, b, l in phones if strip_attrs(l)[0] not in SILENCE]
    utt_start = speech[0][0] if speech else 0.0
    utt_end = speech[-1][1] if speech else total_dur

    real_words = [(a, b, l) for a, b, l in words if l.strip() not in SILENCE]
    # Index words by start time, so the key is unique however often a label repeats.
    word_starts = {round(a, 6): i + 1 for i, (a, b, l) in enumerate(real_words)}

    stem = os.path.basename(audio_path).rsplit(".", 1)[0]
    rows = []
    phone_idx = 0
    for j, (start, end, raw_label) in enumerate(phones):
        label, attrs = strip_attrs(raw_label)
        if label in SILENCE:
            continue
        phone_idx += 1
        dur = end - start

        w_start = w_end = None
        w_label = ""
        for a, b, l in real_words:
            if start >= a - 1e-6 and end <= b + 1e-6:
                w_start, w_end, w_label = a, b, l
                break

        prev_iv = phones[j - 1] if j > 0 else None
        next_iv = phones[j + 1] if j + 1 < len(phones) else None
        pause_before = ((prev_iv[1] - prev_iv[0])
                        if prev_iv and strip_attrs(prev_iv[2])[0] in SILENCE else 0.0)
        pause_after = ((next_iv[1] - next_iv[0])
                       if next_iv and strip_attrs(next_iv[2])[0] in SILENCE else 0.0)

        row = {
            "file_name": stem,
            "corpus": corpus,
            "speaker_id": speaker_id,
            "pitch_floor": floor,
            "pitch_ceiling": ceiling,
            "phone_idx": phone_idx,
            "phone_label": label,
            "start": start, "end": end, "duration": dur,
            "prev_phone": strip_attrs(prev_iv[2])[0] if prev_iv else None,
            "next_phone": strip_attrs(next_iv[2])[0] if next_iv else None,
            "word_label": w_label,
            "word_start": w_start, "word_end": w_end,
            "word_idx": word_starts.get(round(w_start, 6)) if w_start is not None else None,
            "n_words": len(real_words),
            "utt_start": utt_start, "utt_end": utt_end,
            "rel_utt_position": ((start - utt_start) / (utt_end - utt_start)
                                 if utt_end > utt_start else np.nan),
            "pause_before": pause_before,
            "pause_after": pause_after,
            "is_word_initial": bool(w_start is not None and abs(start - w_start) < 1e-6),
            "is_word_final": bool(w_end is not None and abs(end - w_end) < 1e-6),
            "is_utt_final": bool(abs(end - utt_end) < 1e-6),
        }
        for k in ("sidx", "sN", "pos", "oc"):
            row[k] = attrs.get(k)

        times = [start + p * dur for p in STEP_PROPS]
        f0 = [_safe(call(pitch, "Get value at time", t, "Hertz", "linear")) for t in times]
        inten = [_safe(call(intensity, "Get value at time", t, "cubic")) for t in times]
        for k, (a, b) in enumerate(zip(f0, inten), 1):
            row[f"f0_step{k}"] = a
            row[f"int_step{k}"] = b

        mid = 0.5 * (start + end)
        row["f0_midpoint"] = _safe(call(pitch, "Get value at time", mid, "Hertz", "linear"))
        row["int_midpoint"] = _safe(call(intensity, "Get value at time", mid, "cubic"))
        # Praat's dB mean averages decibels; the energy mean is the physically
        # meaningful one. Keep both and let the analysis choose.
        row["int_mean_db"] = _safe(call(intensity, "Get mean", start, end, "dB"))
        row["int_mean_energy"] = _safe(call(intensity, "Get mean", start, end, "energy"))
        row["int_max"] = _safe(call(intensity, "Get maximum", start, end, "parabolic"))
        row["f0_mean"] = _safe(call(pitch, "Get mean", start, end, "Hertz"))
        row["f0_min"] = _safe(call(pitch, "Get minimum", start, end, "Hertz", "parabolic"))
        row["f0_max"] = _safe(call(pitch, "Get maximum", start, end, "Hertz", "parabolic"))
        row["n_f0_valid"] = int(np.sum(~np.isnan(f0)))
        row["n_int_valid"] = int(np.sum(~np.isnan(inten)))
        row["prop_voiced"] = row["n_f0_valid"] / N_STEPS
        rows.append(row)
    return rows


def _measure_worker(task):
    stem, audio_path, tg_path, corpus, speaker_id, floor, ceiling = task
    try:
        return stem, measure_file(audio_path, tg_path, corpus, speaker_id,
                                  floor, ceiling), None
    except Exception:
        return stem, [], traceback.format_exc(limit=3)


def run_measure(args):
    pairs = discover(args)
    spk = speaker_map(args.speaker_map)
    floors = pd.read_csv(args.floors, dtype={"speaker_id": str}).set_index("speaker_id")

    os.makedirs(args.out_dir, exist_ok=True)
    manifest_path = os.path.join(args.out_dir, f"manifest_{args.corpus}.csv")
    done = set()
    if args.resume and os.path.exists(manifest_path):
        done = set(pd.read_csv(manifest_path).file_name.astype(str))
        print(f"resuming: {len(done)} files already done")

    default_floor = float(floors.pitch_floor.median())
    default_ceil = float(floors.pitch_ceiling.median())
    tasks = []
    for stem, audio_path, tg_path in pairs:
        if stem in done:
            continue
        sid = str(spk.get(stem, stem))
        if sid in floors.index:
            fl = float(floors.loc[sid, "pitch_floor"])
            ce = float(floors.loc[sid, "pitch_ceiling"])
        else:
            fl, ce = default_floor, default_ceil
        tasks.append((stem, audio_path, tg_path, args.corpus, sid, fl, ce))
    print(f"{len(tasks)} files to measure")

    shard, buf, n_rows, errors = 0, [], 0, []
    while os.path.exists(os.path.join(args.out_dir,
                                      f"phones_{args.corpus}_{shard:04d}.csv")):
        shard += 1
    with open(manifest_path, "a", newline="", encoding="utf-8") as mf:
        mw = csv.writer(mf)
        if not done:
            mw.writerow(["file_name", "n_phones"])
        for i, (stem, rows, err) in enumerate(imap(_measure_worker, tasks, args.jobs), 1):
            if err:
                errors.append((stem, err))
                continue
            buf.extend(rows)
            mw.writerow([stem, len(rows)])
            n_rows += len(rows)
            if len(buf) >= args.shard_rows:
                _flush(buf, args, shard)
                shard += 1
                buf = []
                mf.flush()
            if i % 500 == 0:
                print(f"  measured {i}/{len(tasks)}  rows={n_rows}  "
                      f"errors={len(errors)}", flush=True)
    if buf:
        _flush(buf, args, shard)
    print(f"done: {n_rows} phone rows, {len(errors)} files failed")
    if errors:
        path = os.path.join(args.out_dir, f"errors_{args.corpus}.log")
        with open(path, "w", encoding="utf-8") as fh:
            for stem, err in errors:
                fh.write(f"=== {stem} ===\n{err}\n")
        print(f"  error detail in {path}")


def _flush(buf, args, shard):
    path = os.path.join(args.out_dir, f"phones_{args.corpus}_{shard:04d}.csv")
    pd.DataFrame(buf).to_csv(path, index=False)
    print(f"  wrote {path} ({len(buf)} rows)", flush=True)


# --------------------------------- discovery --------------------------------

def discover(args):
    """[(stem, audio_path, textgrid_path)] for files present in both trees."""
    audio = {}
    for fn in os.listdir(args.audio_dir):
        if fn.lower().endswith(args.audio_ext.lower()):
            audio[fn[: -len(args.audio_ext)]] = os.path.join(args.audio_dir, fn)
    grids = {}
    suf = args.textgrid_suffix + ".TextGrid"
    for fn in os.listdir(args.textgrid_dir):
        if fn.endswith(suf):
            grids[fn[: -len(suf)]] = os.path.join(args.textgrid_dir, fn)
    shared = sorted(set(audio) & set(grids))
    print(f"audio {len(audio)} | textgrids {len(grids)} | usable {len(shared)}")
    if args.limit:
        shared = shared[: args.limit]
    return [(s, audio[s], grids[s]) for s in shared]


def speaker_map(path):
    if not path:
        return {}
    df = pd.read_csv(path, dtype=str)
    return dict(zip(df.file_name, df.speaker_id))


def main():
    p = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in ("floors", "measure"):
        s = sub.add_parser(name)
        s.add_argument("--audio-dir", required=True)
        s.add_argument("--audio-ext", default=".wav")
        s.add_argument("--textgrid-dir", required=True)
        s.add_argument("--textgrid-suffix", default="")
        s.add_argument("--speaker-map", default=None)
        s.add_argument("--jobs", type=int, default=os.cpu_count())
        s.add_argument("--limit", type=int, default=0)
        if name == "floors":
            s.add_argument("--out", required=True)
            s.add_argument("--min-files-per-speaker", type=int, default=3)
        else:
            s.add_argument("--floors", required=True)
            s.add_argument("--corpus", required=True)
            s.add_argument("--out-dir", required=True)
            s.add_argument("--shard-rows", type=int, default=400000)
            s.add_argument("--resume", action="store_true")
    args = p.parse_args()
    (run_floors if args.cmd == "floors" else run_measure)(args)


if __name__ == "__main__":
    main()
