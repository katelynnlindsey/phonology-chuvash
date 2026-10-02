"""Overnight 2026-10-01, segmental_acoustics track.

Per-phone acoustic voicing / intensity measures for every phone interval in the
raw MFA TextGrids (which keep geminates as e.g. 'tː'), for both spoken corpora.

Measures (all on the WHOLE utterance sound, never on excised segments, so no
edge-window artefact of the kind documented in reextraction_spec.md):
  * Praat autocorrelation pitch, 5 ms step, floor 75 / ceiling 600 Hz, two
    settings:  'def' = Praat defaults (silence 0.03, voicing 0.45)
               'sen' = sensitive (silence 0.01, voicing 0.30) -- detects a
                        voicing bar ~30-40 dB below the utterance peak
    -> vf_<set>_all  : fraction of frames inside the interval that are voiced
       vf_<set>_mid  : same, middle 50% of the interval only (less edge bleed,
                       less exposure to the +/-10 ms MFA boundary error)
       vic_<set>_ms  : voicing into closure: ms of continuously voiced frames
                       from the left edge
  * low-band energy (60-400 Hz Butterworth band, 10 ms Hann frames, 5 ms step),
    dB re full scale:  lb_mean, lb_min  (voicing-bar strength, threshold-free)
  * broadband intensity (Praat To Intensity, min pitch 100 -> 32 ms window, 5 ms
    step, computed on the whole file):  int_mean, int_max, int_mid,
    int_peak_rel = int_max - max(int at left edge, int at right edge)
  * utterance articulation rate: vowels per second of non-silent speech.

Usage: python extract_voicing.py <corpus> <listfile> <outcsv>
  listfile: one basename per line. Rows are appended per file; files already in
  the output (by file_name) are skipped, so a crash loses at most one file.
"""
import sys, os, csv, math
import numpy as np
import parselmouth
from scipy.signal import butter, sosfiltfilt

ROOT = "/Users/kate/Documents/GitHub/phonology-chuvash/"
PATHS = {
    "common_voice_chuvash": (ROOT + "1-raw_data/common_voice_chuvash/textgrids_VOX/",
                             ROOT + "3-convert/common_voice_chuvash/converted_audio/"),
    "chuvash_voice": (ROOT + "1-raw_data/chuvash_voice/textgrids/",
                      ROOT + "1-raw_data/chuvash_voice/audio_transcripts/"),
}
VOWELS = {"ɑ", "e", "ʌ", "ɛ", "i", "u", "ɯ", "y", "o"}
SILENCE = {"sil", "", "sp", "<eps>", "spn"}


def parse_textgrid(path):
    tiers, cur, xmin, xmax = {}, None, None, None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            s = line.strip()
            if s.startswith("name ="):
                cur = s.split("=", 1)[1].strip().strip('"'); tiers[cur] = []
            elif s.startswith("xmin =") and cur is not None:
                xmin = float(s.split("=")[1])
            elif s.startswith("xmax =") and cur is not None:
                xmax = float(s.split("=")[1])
            elif s.startswith("text =") and cur is not None:
                lab = s.split("=", 1)[1].strip().strip('"')
                tiers[cur].append((xmin, xmax, lab))
    return tiers


def frame_stats(ts, vals, a, b):
    m = (ts >= a) & (ts < b)
    return vals[m]


def measure_file(corpus, base, w):
    tgdir, audir = PATHS[corpus]
    tg = parse_textgrid(tgdir + base + ".TextGrid")
    snd = parselmouth.Sound(audir + base + ".wav")
    if snd.n_channels > 1:
        snd = snd.convert_to_mono()
    sr = snd.sampling_frequency
    x = snd.values[0]
    p_def = snd.to_pitch_ac(time_step=0.005, pitch_floor=75, pitch_ceiling=600)
    p_sen = snd.to_pitch_ac(time_step=0.005, pitch_floor=75, pitch_ceiling=600,
                            silence_threshold=0.01, voicing_threshold=0.30)
    tdef = p_def.xs(); vdef = p_def.selected_array["frequency"] > 0
    tsen = p_sen.xs(); vsen = p_sen.selected_array["frequency"] > 0
    inten = snd.to_intensity(minimum_pitch=100, time_step=0.005, subtract_mean=False)
    ti = inten.xs(); iv = inten.values[0]
    # low band energy
    sos = butter(4, [60, 400], btype="band", fs=sr, output="sos")
    xl = sosfiltfilt(sos, x)
    hop, win = int(0.005 * sr), int(0.010 * sr)
    hann = np.hanning(win)
    nfr = max(1, (len(xl) - win) // hop + 1)
    idx = np.arange(nfr)[:, None] * hop + np.arange(win)[None, :]
    fr = xl[idx] * hann
    lb = 10 * np.log10(np.mean(fr ** 2, axis=1) + 1e-12)
    tlb = (np.arange(nfr) * hop + win / 2) / sr

    words = [(a, b, l) for a, b, l in tg["words"]]
    phones = [(a, b, l) for a, b, l in tg["phones"]]
    # articulation rate
    speech = sum(b - a for a, b, l in phones if l not in SILENCE)
    nv = sum(1 for a, b, l in phones if l in VOWELS)
    rate = nv / speech if speech > 0 else float("nan")
    # assign phones to words by containment (midpoint)
    wid = []
    for a, b, l in phones:
        mid = (a + b) / 2; k = -1
        for j, (wa, wb, wl) in enumerate(words):
            if wa <= mid < wb:
                k = j; break
        wid.append(k)
    rows = []
    for i, (a, b, l) in enumerate(phones):
        k = wid[i]
        wl = words[k][2] if k >= 0 else ""
        d = b - a
        q1, q3 = a + d / 4, b - d / 4
        r = {"file_name": base, "corpus": corpus, "pidx_utt": i, "phone": l,
             "start": round(a, 4), "end": round(b, 4), "dur_ms": round(1000 * d, 2),
             "widx": k, "word_label": wl,
             "prev_phone": phones[i - 1][2] if i > 0 else "#",
             "next_phone": phones[i + 1][2] if i + 1 < len(phones) else "#",
             "prev_same_word": int(i > 0 and wid[i - 1] == k and k >= 0),
             "next_same_word": int(i + 1 < len(phones) and wid[i + 1] == k and k >= 0),
             "art_rate": round(rate, 3)}
        for tag, tt, vv in (("def", tdef, vdef), ("sen", tsen, vsen)):
            f_all = frame_stats(tt, vv, a, b)
            f_mid = frame_stats(tt, vv, q1, q3)
            r[f"vf_{tag}_all"] = round(f_all.mean(), 3) if len(f_all) else ""
            r[f"vf_{tag}_mid"] = round(f_mid.mean(), 3) if len(f_mid) else ""
            if len(f_all):
                run = 0
                for v in f_all:
                    if v: run += 1
                    else: break
                r[f"vic_{tag}_ms"] = 5 * run
            else:
                r[f"vic_{tag}_ms"] = ""
        l_all = frame_stats(tlb, lb, a, b)
        r["lb_mean"] = round(float(np.mean(l_all)), 2) if len(l_all) else ""
        r["lb_min"] = round(float(np.min(l_all)), 2) if len(l_all) else ""
        i_all = frame_stats(ti, iv, a, b)
        if len(i_all):
            r["int_mean"] = round(float(np.mean(i_all)), 2)
            r["int_max"] = round(float(np.max(i_all)), 2)
            r["int_mid"] = round(float(np.interp((a + b) / 2, ti, iv)), 2)
            edge = max(np.interp(a, ti, iv), np.interp(b, ti, iv))
            r["int_peak_rel"] = round(float(np.max(i_all) - edge), 2)
        else:
            r["int_mean"] = r["int_max"] = r["int_peak_rel"] = ""
            r["int_mid"] = round(float(np.interp((a + b) / 2, ti, iv)), 2)
        rows.append(r)
    return rows


FIELDS = ["file_name", "corpus", "pidx_utt", "phone", "start", "end", "dur_ms", "widx",
          "word_label", "prev_phone", "next_phone", "prev_same_word", "next_same_word",
          "art_rate", "vf_def_all", "vf_def_mid", "vic_def_ms", "vf_sen_all", "vf_sen_mid",
          "vic_sen_ms", "lb_mean", "lb_min", "int_mean", "int_max", "int_mid", "int_peak_rel"]

if __name__ == "__main__":
    corpus, listfile, out = sys.argv[1:4]
    bases = [l.strip() for l in open(listfile) if l.strip()]
    done = set()
    if os.path.exists(out):
        with open(out, encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                done.add(row["file_name"])
    new = not os.path.exists(out)
    errs = 0
    with open(out, "a", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS)
        if new: w.writeheader()
        for n, base in enumerate(bases):
            if base in done: continue
            try:
                rows = measure_file(corpus, base, w)
                w.writerows(rows); fh.flush()
            except Exception as e:
                errs += 1
                sys.stderr.write(f"ERR {base}: {e}\n")
            if n % 500 == 0:
                sys.stderr.write(f"{n}/{len(bases)} errs={errs}\n"); sys.stderr.flush()
    sys.stderr.write(f"DONE {len(bases)} errs={errs}\n")
