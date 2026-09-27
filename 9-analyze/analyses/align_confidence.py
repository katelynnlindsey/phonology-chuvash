#!/usr/bin/env python3
"""Score every vowel for alignment confidence, without listening to anything.

Implements (a)-(d) of output/alignment_confidence.md. (e), MFA's own
per-utterance log-likelihood, needs a re-run of the aligner and is left for the
cluster job.

The point is not to discard low-confidence tokens. It is to (i) make the
sensitivity of each reported result to alignment quality visible, and (ii)
stratify a small hand-check so the paper can quote a *measured* boundary-error
rate per stratum instead of saying the alignments were not hand-checked.

Components
----------
(a) Cross-alignment deviation, Common Voice only.
    1-raw_data/common_voice_chuvash/textgrids_VOX is an independent Vox
    Communis alignment of the same audio, used nowhere in the pipeline; it
    covers 16,858 of the 17,329 recordings. For each vowel interval in the
    alignment the study actually uses, we find the VOX interval that overlaps
    it most and record |Δonset| + |Δoffset| in ms. Two independent models
    agreeing to within 20 ms is strong evidence the boundary is right;
    300 ms apart means the segment is suspect however plausible its formants
    look.

    A nearest-boundary distance is also recorded. It is systematically
    smaller and optimistic — in a dense boundary sequence something is always
    close by — so it is reported as a floor, not used in the score.

(b) smooth_error, new-FAVE's per-vowel formant-tracking smoothing error. This
    separates "the vowel is unusual" from "the measurement is unreliable",
    which an IQR fence on the formants themselves cannot.

(c) pron_from_g2p. Words absent from the Vox Communis dictionary were aligned
    from a rule-generated pronunciation and carry more risk.
    4-align/.../add_oovs_to_dict/oovs_found_chuvash_cv.txt lists them.

(d) |duration z| within phone × speaker. This is what cleaning step 05 should
    have computed; kept as a covariate, never as a fence.

The composite is the mean of the available components after each is mapped to
a within-corpus percentile, with higher = more confident. It is a heuristic
ordering, and it is only worth what the hand-check says it is worth — which is
the point of the stratified sample this script also draws.

Usage:
    python align_confidence.py --repo <path> [--sample-n 250] [--strata 5]
"""
import argparse, glob, os, re, sys
import numpy as np
import pandas as pd

SIL = {"sil", "sp", "spn", "", "<eps>", "silence", "SIL"}
ARPABET_VOWELS = {"AA", "IY", "UX", "EY", "EH", "IX", "UW", "AH", "OW"}

# 6-annotate writes vowel labels as e.g. "AA1 [sidx=2/sN=2/pos=final/oc=open]"
# — the ARPAbet symbol, a stress digit, and a bracketed annotation. Strip to
# the symbol before testing membership.
_ARPA_RE = re.compile(r"^\s*([A-Z]{2})\d?")


def arpabet_symbol(label):
    m = _ARPA_RE.match(label)
    return m.group(1) if m else None


def parse_textgrid(path):
    with open(path, encoding="utf-8") as fh:
        txt = fh.read()
    tiers = {}
    name_re = re.compile(r'name\s*=\s*"([^"]*)"')
    xmin_re = re.compile(r"xmin\s*=\s*([0-9.eE+-]+)")
    xmax_re = re.compile(r"xmax\s*=\s*([0-9.eE+-]+)")
    text_re = re.compile(r'text\s*=\s*"((?:[^"]|"")*)"', re.S)
    for block in re.split(r"item \[\d+\]:", txt)[1:]:
        m = name_re.search(block)
        if not m:
            continue
        rows = []
        for iv in re.split(r"intervals \[\d+\]:", block)[1:]:
            a, b, t = xmin_re.search(iv), xmax_re.search(iv), text_re.search(iv)
            if a and b and t:
                rows.append((float(a.group(1)), float(b.group(1)),
                             t.group(1).replace('""', '"').strip()))
        tiers[m.group(1)] = rows
    return tiers


def cross_alignment(repo, verbose=True):
    """|Δonset| + |Δoffset| against the independent VOX alignment, per vowel."""
    used = sorted(glob.glob(os.path.join(
        repo, "6-annotate/common_voice_chuvash/recoded_textgrids/*.TextGrid")))
    vox_by = {os.path.basename(p)[:-9]: p for p in glob.glob(os.path.join(
        repo, "1-raw_data/common_voice_chuvash/textgrids_VOX/*.TextGrid"))}
    rows, n_matched = [], 0
    for i, p in enumerate(used):
        stem = os.path.basename(p)[:-9].replace("_arpabet", "")
        vp = vox_by.get(stem)
        if vp is None:
            continue
        n_matched += 1
        a = [x for x in parse_textgrid(p).get("phones", []) if x[2] not in SIL]
        b = [x for x in parse_textgrid(vp).get("phones", []) if x[2] not in SIL]
        if not a or not b:
            continue
        bnds = np.array(sorted({x[0] for x in b} | {x[1] for x in b}))
        bs = np.array([x[0] for x in b])
        be = np.array([x[1] for x in b])
        for (s, e, lab) in a:
            if arpabet_symbol(lab) not in ARPABET_VOWELS:
                continue
            ov = np.minimum(be, e) - np.maximum(bs, s)
            j = int(np.argmax(ov))
            if ov[j] <= 0:                     # no overlapping VOX interval
                dev = np.nan
            else:
                dev = (abs(bs[j] - s) + abs(be[j] - e)) * 1000.0
            near = (np.min(np.abs(bnds - s)) +
                    np.min(np.abs(bnds - e))) * 1000.0
            rows.append((stem, round(s, 4), round(e, 4),
                         arpabet_symbol(lab), dev, near))
        if verbose and (i + 1) % 4000 == 0:
            print(f"  {i + 1}/{len(used)} grids, {len(rows)} vowels", flush=True)
    d = pd.DataFrame(rows, columns=["stem", "start", "end", "arpabet",
                                    "xalign_dev_ms", "xalign_nearest_ms"])
    if verbose:
        print(f"cross-alignment: {n_matched:,} recordings matched, "
              f"{len(d):,} vowel intervals scored")
    return d


def g2p_words(repo):
    p = os.path.join(repo, "4-align", "Chuvash Voice (lab to TEXTGRID)",
                     "add_oovs_to_dict", "oovs_found_chuvash_cv.txt")
    if not os.path.exists(p):
        return set()
    return {w.strip().lower() for w in open(p, encoding="utf-8") if w.strip()}


def pctile(s, higher_is_better):
    """Map to a within-group percentile in [0,1]; NaN stays NaN."""
    r = s.rank(pct=True, na_option="keep")
    return r if higher_is_better else 1.0 - r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--sample-n", type=int, default=250)
    ap.add_argument("--strata", type=int, default=5)
    a = ap.parse_args()
    out = os.path.join(a.repo, "9-analyze", "output")

    v = pd.read_csv(os.path.join(out, "vowels_for_confidence.csv"),
                    low_memory=False)
    print(f"vowels: {len(v):,}")

    # ── (a) cross-alignment, Common Voice ─────────────────────────────
    xa = cross_alignment(a.repo)
    xa.to_csv(os.path.join(out, "cross_alignment_deviation.csv"), index=False)
    v["stem"] = v.file_name.astype(str)
    v["start_r"] = v.start.round(4)
    v["end_r"] = v.end.round(4)
    v = v.merge(xa[["stem", "start", "end", "xalign_dev_ms",
                    "xalign_nearest_ms"]]
                .rename(columns={"start": "start_r", "end": "end_r"}),
                on=["stem", "start_r", "end_r"], how="left")
    cv = v.corpus == "common_voice_chuvash"
    print(f"cross-alignment joined to {int(v.xalign_dev_ms.notna().sum()):,} "
          f"of {int(cv.sum()):,} Common Voice vowels "
          f"({100 * v.loc[cv, 'xalign_dev_ms'].notna().mean():.1f}%)")

    # ── (c) dictionary provenance ─────────────────────────────────────
    oov = g2p_words(a.repo)
    v["pron_from_g2p"] = v.word_label.astype(str).str.lower().isin(oov)
    print(f"pron_from_g2p: {100 * v.pron_from_g2p.mean():.1f}% of vowel tokens")

    # ── (d) |duration z| within phone x speaker ───────────────────────
    v["spk"] = v.speaker_id.fillna("unknown_" + v.corpus.astype(str))
    g = v.groupby(["vowel_label", "spk"]).duration
    v["dur_z"] = ((v.duration - g.transform("mean")) /
                  g.transform("std").replace(0, np.nan))
    v["abs_dur_z"] = v.dur_z.abs()

    # ── composite ─────────────────────────────────────────────────────
    comps = {"xalign_dev_ms": False, "smooth_error": False,
             "abs_dur_z": False}
    parts = []
    for c, hib in comps.items():
        if c in v.columns:
            v["p_" + c] = v.groupby("corpus")[c].transform(
                lambda s: pctile(s, hib))
            parts.append("p_" + c)
    v["p_g2p"] = np.where(v.pron_from_g2p, 0.0, 1.0)
    parts.append("p_g2p")
    v["align_confidence"] = v[parts].mean(axis=1, skipna=True)
    v["conf_n_components"] = v[parts].notna().sum(axis=1)
    print("\ncomponents per row:")
    print(v.conf_n_components.value_counts().sort_index().to_string())

    # ── strata ────────────────────────────────────────────────────────
    # Strata are computed WITHIN CORPUS, deliberately. Only Common Voice has
    # the cross-alignment component, so a Chuvash Voice score and a Common
    # Voice score are built from different components and are not on the same
    # scale; pooling them would order by corpus as much as by quality.
    # pron_from_g2p also differs sharply by corpus (39.7% vs 5.4%), because the
    # OOV list was generated against the Chuvash Voice transcripts.
    v["conf_stratum"] = (v.groupby("corpus").align_confidence
                          .transform(lambda s: pd.qcut(
                              s, a.strata,
                              labels=[f"Q{i+1}" for i in range(a.strata)])))
    prof = v.groupby(["corpus", "conf_stratum"], observed=True).agg(
        n=("align_confidence", "size"),
        confidence=("align_confidence", "mean"),
        xalign_dev_ms=("xalign_dev_ms", "median"),
        smooth_error=("smooth_error", "median"),
        abs_dur_z=("abs_dur_z", "median"),
        pct_g2p=("pron_from_g2p", lambda s: 100 * s.mean()),
        pct_iqr_flag=("iqr_outlier_any", lambda s: 100 * s.mean()),
        median_duration=("duration", "median")).round(4)
    prof.to_csv(os.path.join(out, "align_confidence_strata.csv"))
    print("\n== confidence strata ==")
    print(prof.to_string())

    keep = ["file_name", "corpus", "spk", "word_id", "word_label",
            "vowel_label", "sidx", "sN", "start", "end", "duration",
            "smooth_error", "xalign_dev_ms", "xalign_nearest_ms",
            "pron_from_g2p", "dur_z", "abs_dur_z", "align_confidence",
            "conf_stratum", "iqr_outlier_any", "word_complete",
            "syllable_coda", "stress_rule_A6", "stress_rule_B5",
            "int_midpoint"]
    v[keep].to_csv(os.path.join(out, "align_confidence.csv"), index=False)
    print(f"\nalign_confidence.csv: {len(v):,} rows")

    # ── sensitivity of the headline results by stratum ────────────────
    sensitivity(v, out)

    # ── stratified hand-check sample ──────────────────────────────────
    hand_check_sample(v, out, a.repo, a.sample_n)


def mh_odds(df, expo, prom, stratum="word_id"):
    """Mantel-Haenszel odds ratio, same estimand as the clogit in R."""
    s = df.groupby(stratum).apply(
        lambda g: pd.Series({
            "a": int(((g[expo] == 1) & (g[prom] == 1)).sum()),
            "b": int(((g[expo] == 1) & (g[prom] == 0)).sum()),
            "c": int(((g[expo] == 0) & (g[prom] == 1)).sum()),
            "d": int(((g[expo] == 0) & (g[prom] == 0)).sum())}),
        include_groups=False)
    n = s.a + s.b + s.c + s.d
    n = n.replace(0, np.nan)
    R = (s.a * s.d / n).sum()
    S = (s.b * s.c / n).sum()
    return np.nan if (R == 0 or S == 0) else R / S


def sensitivity(v, out):
    """Do the reported nulls and effects depend on alignment quality?

    Stratification is at the WORD level, not the vowel level. The coda and
    sonority tests are within-word: a word is a stratum and its syllables are
    the units. Splitting vowels across confidence strata would hand each
    subset a partial word and silently redefine "the longest syllable in the
    word". Each word therefore gets the mean confidence of its own vowels, and
    whole words are assigned to strata.
    """
    d = v[(v.sN > 1) & v.duration.notna() & v.int_midpoint.notna() &
          v.vowel_label.notna() & v.syllable_coda.notna()].copy()
    d["has_coda"] = (d.syllable_coda.astype(str).str.lower()
                     .isin(["closed", "coda", "true", "1"])).astype(int)
    d["is_a"] = (d.vowel_label == "a").astype(int)
    d["dur_adj"] = d.duration - d.groupby("vowel_label").duration.transform("mean")
    d["prom"] = (d.dur_adj == d.groupby("word_id").dur_adj.transform("max")).astype(int)

    wconf = d.groupby("word_id").align_confidence.mean()
    d["word_conf"] = d.word_id.map(wconf)
    nq = d.conf_stratum.nunique()
    d["word_stratum"] = pd.qcut(d.word_conf, nq,
                                labels=[f"W{i+1}" for i in range(nq)])
    rows = []
    for st, g in d.groupby("word_stratum", observed=True):
        rows.append(dict(stratum=str(st), n_vowels=len(g),
                         n_words=g.word_id.nunique(),
                         mean_confidence=round(g.word_conf.mean(), 4),
                         median_xalign_dev_ms=g.xalign_dev_ms.median(),
                         odds_coda=mh_odds(g, "has_coda", "prom"),
                         odds_low_vowel=mh_odds(g, "is_a", "prom")))
    rows.append(dict(stratum="all", n_vowels=len(d),
                     n_words=d.word_id.nunique(),
                     mean_confidence=round(d.word_conf.mean(), 4),
                     median_xalign_dev_ms=d.xalign_dev_ms.median(),
                     odds_coda=mh_odds(d, "has_coda", "prom"),
                     odds_low_vowel=mh_odds(d, "is_a", "prom")))
    s = pd.DataFrame(rows).round(4)
    s.to_csv(os.path.join(out, "align_confidence_sensitivity.csv"), index=False)
    print("\n== coda and sonority odds by word-level confidence stratum ==")
    print("(prominence = longest in the word after removing intrinsic duration;")
    print(" whole words assigned to strata by their mean vowel confidence)")
    print(s.to_string(index=False))


def hand_check_sample(v, out, repo, n):
    """Equal-sized sample per stratum, with everything needed to check by ear."""
    per = max(1, n // v.conf_stratum.nunique())
    pool = v[v.xalign_dev_ms.notna() | (v.corpus == "chuvash_voice")]
    s = pd.concat([g.sample(min(per, len(g)), random_state=0)
                   for _, g in pool.groupby("conf_stratum", observed=True)])
    audio = {"chuvash_voice": "1-raw_data/chuvash_voice/audio_transcripts",
             "common_voice_chuvash":
                 "1-raw_data/common_voice_chuvash/audio_metadata_Mozilla"}
    ext = {"chuvash_voice": ".wav", "common_voice_chuvash": ".mp3"}
    s = s.assign(
        audio_path=[os.path.join(audio[c], f + ext[c])
                    for c, f in zip(s.corpus, s.file_name)],
        midpoint=((s.start + s.end) / 2).round(4),
        boundary_ok="", phone_ok="", notes="")
    cols = ["conf_stratum", "align_confidence", "corpus", "file_name",
            "audio_path", "word_label", "vowel_label", "sidx", "sN",
            "start", "end", "midpoint", "duration", "xalign_dev_ms",
            "smooth_error", "pron_from_g2p", "boundary_ok", "phone_ok", "notes"]
    s[cols].sort_values(["conf_stratum", "file_name"]).to_csv(
        os.path.join(out, "hand_check_sample.csv"), index=False)
    print(f"\nhand_check_sample.csv: {len(s)} vowels, "
          f"{per} per stratum, blind columns boundary_ok / phone_ok / notes")
    print(s.groupby("conf_stratum", observed=True).size().to_string())


if __name__ == "__main__":
    sys.exit(main())
