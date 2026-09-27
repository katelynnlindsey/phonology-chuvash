#!/usr/bin/env python3
"""Gemination in BOTH corpora, for the places stage 5 does not collapse.

Correcting an earlier claim. I said Common Voice could not contribute to the
gemination question, on the grounds that its only pre-recode grids are a
different third-party alignment. That is true for the eight places stage 5
collapsed onto their singletons — those are recoverable only from the Chuvash
Voice pre-recode grids. But it is wrong as a general statement: the long
consonants stage 5 never had in its map passed straight through into the
grids the study actually uses, in BOTH corpora.

Census of long labels in the used (6-annotate) grids, 1,500 files each:

    Chuvash Voice   ɕː 160   ʃː 43   χː 13   vː 1
    Common Voice    ɕː 200   ʃː 29

So /ɕː/ and /ʃː/ can be measured in both corpora off the same alignment the
rest of the study uses, which gives the length contrast a cross-speaker
replication it otherwise lacks — Chuvash Voice is one speaker, and that was
the standing limitation on every gemination number.

/ɕː/ looked like the most useful case available: the third-largest
long-consonant class in Chuvash Voice (3,525 long tokens, behind /lː/ at
7,385 and /nː/ at 3,631) and the one with the biggest long-to-singleton ratio,
1.71. It turns out not to be usable in Common Voice — see the floor check
below — and /ʃː/ carries the replication instead.

Usage:  python gemination_cross_corpus.py --repo <path>
"""
import argparse, glob, os, re, sys
import numpy as np
import pandas as pd

SIL = {"sil", "sp", "spn", "", "<eps>", "silence", "SIL"}

# The places that survive stage 5, and the trap in comparing them.
#
# Stage 5 maps SINGLETONS to ARPAbet but has no entry for the long forms, so
# in the used grids a long consonant appears as IPA while its own singleton
# appears as ARPAbet: long 'ʃː' sits beside singleton 'SH', not beside 'ʃ'.
# Matching on the IPA base alone therefore finds long tokens and no singletons
# at all, and the ratio is uncomputable. /ɕ/ is the sole exception — it has no
# ARPAbet equivalent, so both its forms stay IPA.
#
# LONG_TO_SINGLETON pairs each surviving long label with the label its
# singleton actually carries.
LONG_TO_SINGLETON = {
    "ɕː": "ɕ",     # both IPA: no ARPAbet symbol for the alveolo-palatal
    "ʃː": "SH",
    "χː": "HH",    # NOTE: 'HH' pools /χ/ and /h/; Chuvash х is /χ/ and the
                   # language has no native /h/, so the pooling is harmless
    "vː": "V",
    "jː": "J",
    "tsː": "ts",
}
SINGLETON_LABELS = set(LONG_TO_SINGLETON.values())
LONG_LABELS = set(LONG_TO_SINGLETON)
VOWEL_ARPA = {"AA", "IY", "UX", "EY", "EH", "IX", "UW", "AH", "OW"}
_ARPA_RE = re.compile(r"^\s*([A-Z]{2})\d?")


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


def is_vowel(lab):
    m = _ARPA_RE.match(lab)
    return bool(m and m.group(1) in VOWEL_ARPA)


def collect(repo, corpus, limit=None):
    pat = os.path.join(repo, "6-annotate", corpus, "recoded_textgrids",
                       "*.TextGrid")
    files = sorted(glob.glob(pat))
    if limit:
        files = files[:limit]
    rows = []
    for i, p in enumerate(files):
        tiers = parse_textgrid(p)
        ph = tiers.get("phones", [])
        keep = [(s, e, l) for (s, e, l) in ph if l not in SIL]
        for j, (s, e, lab) in enumerate(keep):
            if lab in LONG_LABELS:
                place, is_long = LONG_TO_SINGLETON[lab], 1
            elif lab in SINGLETON_LABELS:
                place, is_long = lab, 0
            else:
                continue
            prv = keep[j - 1][2] if j > 0 else ""
            nxt = keep[j + 1][2] if j + 1 < len(keep) else ""
            rows.append((corpus, os.path.basename(p)[:-9], place, is_long,
                         round((e - s) * 1000, 2),
                         int(bool(prv) and is_vowel(prv)),
                         int(bool(nxt) and is_vowel(nxt))))
        if (i + 1) % 8000 == 0:
            print(f"  {corpus}: {i + 1}/{len(files)} grids, {len(rows)} rows",
                  flush=True)
    return pd.DataFrame(rows, columns=["corpus", "file_name", "phone", "long",
                                       "duration", "prev_v", "next_v"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--limit", type=int, default=None)
    a = ap.parse_args()
    out = os.path.join(a.repo, "9-analyze", "output")

    d = pd.concat([collect(a.repo, c, a.limit) for c in
                   ("chuvash_voice", "common_voice_chuvash")],
                  ignore_index=True)
    print(f"\ncollected {len(d):,} target-consonant tokens")

    d.to_csv(os.path.join(out, "gemination_cross_corpus_tokens.csv"),
             index=False)

    # The two alignments have DIFFERENT minimum interval durations, so the
    # floor has to be detected per corpus rather than assumed: Chuvash Voice
    # bottoms out at 30 ms (5.8% of phones), Common Voice at 10 ms (19.2%).
    floors = d.groupby("corpus").duration.min().to_dict()
    print("\ndetected per-corpus duration floor (ms):", floors)

    # Intervocalic only, as in gemination_models.csv, so the two analyses are
    # comparable.
    iv = d[(d.prev_v == 1) & (d.next_v == 1) & (d.duration > 0)]
    rows = []
    for (corpus, phone), g in iv.groupby(["corpus", "phone"]):
        fl = floors[corpus]
        lg, sh = g[g.long == 1], g[g.long == 0]
        if len(lg) < 20 or len(sh) < 20:
            continue
        # A long consonant pinned to the floor was clipped, not measured.
        # Report the share, and also the ratio with those tokens removed, so a
        # place that fails in one corpus does not silently poison the other.
        at_floor = (lg.duration <= fl)
        lg_ok = lg[~at_floor]
        rows.append(dict(
            corpus=corpus, phone=phone, n_long=len(lg), n_short=len(sh),
            median_long=lg.duration.median(), median_short=sh.duration.median(),
            ratio=round(lg.duration.median() / sh.duration.median(), 3),
            mean_long=round(lg.duration.mean(), 1),
            mean_short=round(sh.duration.mean(), 1),
            floor_ms=fl,
            pct_long_at_floor=round(100 * at_floor.mean(), 1),
            n_long_off_floor=len(lg_ok),
            median_long_off_floor=(lg_ok.duration.median()
                                   if len(lg_ok) else np.nan),
            ratio_off_floor=(round(lg_ok.duration.median() /
                                   sh.duration.median(), 3)
                             if len(lg_ok) >= 20 else np.nan),
            measurable=bool(at_floor.mean() < 0.40)))
    r = pd.DataFrame(rows).sort_values(["phone", "corpus"])
    r.to_csv(os.path.join(out, "gemination_cross_corpus.csv"), index=False)
    print("\n== long vs singleton, intervocalic, in the USED alignment of both corpora ==")
    print(r.to_string(index=False))

    # The replication question: does the ratio agree across corpora?
    print("\n== median ratio by corpus (measurable places only) ==")
    ok = r[r.measurable]
    if len(ok):
        print(ok.pivot(index="phone", columns="corpus",
                       values="ratio").to_string())
    bad = r[~r.measurable]
    if len(bad):
        print("\nexcluded as clipped at the alignment floor:")
        for _, x in bad.iterrows():
            print(f"  {x.corpus} /{x.phone}ː/: {x.pct_long_at_floor:.1f}% of "
                  f"{x.n_long} long tokens at {x.floor_ms:.0f} ms")
    print("\nChuvash Voice is one speaker; Common Voice is ~104. A ratio that")
    print("agrees across the two is not a property of one person's speech.")


if __name__ == "__main__":
    sys.exit(main())
