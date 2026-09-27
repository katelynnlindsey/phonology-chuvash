#!/usr/bin/env python3
"""Flatten the Chuvash Voice pre-recode TextGrids into one phone-level CSV.

Why the *pre-recode* grids: 5-recode/chuvash_phonology.py collapses nine of the
fourteen long consonants to singletons, so geminate length is unrecoverable
downstream.  The pre-recode grids in 1-raw_data/chuvash_voice/textgrids carry
the long labels (lː nː ɕː tː sː kː rː ʃː pː mː χː vː tsː jː) and agree with the
recoded grids on 100% of interval boundaries, so durations measured here are the
same durations the rest of the pipeline sees.

Common Voice is deliberately excluded: its only pre-recode grids
(1-raw_data/common_voice_chuvash/textgrids_VOX) are a different third-party
alignment — 18.9% boundary agreement with the grids the measurements come from.

Output columns are one row per non-silence phone, with the orthographic word it
falls inside and enough context to test gemination and mora hypotheses:
position in word, neighbouring phones, and whether the phone is intervocalic.

Usage:  python build_phone_table.py --repo <path> [--out <csv>]
"""
import argparse, csv, glob, os, re, sys

SIL = {"sil", "sp", "spn", "", "<eps>", "silence", "SIL"}

# Aligner IPA (MFA chuvash_mfa) -> the config's IPA.  MUST stay in sync with
# ALIGNER_IPA_TO_CONFIG in 9-analyze/config/phonology_params.R, which is
# authoritative.
#
# BUG FIXED 2026-09-27: this had 'ɛ': 'e'. The aligner writes ⟨ӗ⟩ (the reduced
# front vowel, this config's /ø/) as ɛ and ⟨е⟩ as e — stage 5 confirms it by
# classing ɛ as WEAK and e as STRONG. Mapping ɛ to e therefore pooled the
# reduced front vowel with the full one, left /ø/ absent from the phone table
# entirely, and silently put every ⟨ӗ⟩ token into the full-vowel class. That
# invalidated the word-final weight model and the mora test, both of which
# select on the reduced-vowel set.
ALIGNER_TO_CONFIG = {"ɑ": "a", "ɛ": "ø", "ʌ": "ɵ", "ɯ": "ʉ"}
VOWELS = set("aeiuyoɵøʉ") | {"ɑ", "ɛ", "ʌ", "ɯ"}


def parse_textgrid(path):
    """Return {tier_name: [(xmin, xmax, label), ...]} for an interval grid."""
    with open(path, encoding="utf-8") as fh:
        txt = fh.read()
    tiers, cur = {}, None
    name_re = re.compile(r'name\s*=\s*"([^"]*)"')
    xmin_re = re.compile(r"xmin\s*=\s*([0-9.eE+-]+)")
    xmax_re = re.compile(r"xmax\s*=\s*([0-9.eE+-]+)")
    text_re = re.compile(r'text\s*=\s*"((?:[^"]|"")*)"', re.S)
    for block in re.split(r"item \[\d+\]:", txt)[1:]:
        m = name_re.search(block)
        if not m:
            continue
        cur = m.group(1)
        rows = []
        for iv in re.split(r"intervals \[\d+\]:", block)[1:]:
            a, b, t = xmin_re.search(iv), xmax_re.search(iv), text_re.search(iv)
            if a and b and t:
                rows.append((float(a.group(1)), float(b.group(1)),
                             t.group(1).replace('""', '"').strip()))
        tiers[cur] = rows
    return tiers


def strip_length(lab):
    return lab.replace("ː", "").replace(":", "")


def is_vowel(lab):
    return strip_length(lab) in VOWELS


def to_config(lab):
    base = strip_length(lab)
    return ALIGNER_TO_CONFIG.get(base, base)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--out", default=None)
    ap.add_argument("--limit", type=int, default=None)
    a = ap.parse_args()

    gdir = os.path.join(a.repo, "1-raw_data/chuvash_voice/textgrids")
    files = sorted(glob.glob(os.path.join(gdir, "*.TextGrid")))
    if a.limit:
        files = files[: a.limit]
    out = a.out or os.path.join(a.repo, "7-extract/reextract",
                                "phones_chuvash_voice.csv")
    cols = ["file_name", "corpus", "word_label", "widx", "n_words",
            "word_start", "word_end", "word_nphone",
            "phone_raw", "phone", "long", "pidx", "start", "end", "duration",
            "prev_phone", "next_phone", "prev_is_vowel", "next_is_vowel",
            "intervocalic", "pos_in_word", "is_vowel"]
    n_rows = 0
    with open(out, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(cols)
        for fi, path in enumerate(files):
            tiers = parse_textgrid(path)
            if "phones" not in tiers or "words" not in tiers:
                continue
            fname = os.path.basename(path).replace(".TextGrid", "")
            phones = [p for p in tiers["phones"] if p[2] not in SIL]
            words = [x for x in tiers["words"] if x[2] not in SIL]
            n_words = len(words)
            # phone sequence including silences, for neighbour lookup
            seq = tiers["phones"]
            idx_of = {(round(s, 6), round(e, 6)): i for i, (s, e, _) in enumerate(seq)}
            for wi, (ws, we, wlab) in enumerate(words, start=1):
                inside = [p for p in phones if p[0] >= ws - 1e-6 and p[1] <= we + 1e-6]
                for pi, (s, e, lab) in enumerate(inside, start=1):
                    j = idx_of.get((round(s, 6), round(e, 6)))
                    prv = seq[j - 1][2] if j not in (None, 0) else ""
                    nxt = seq[j + 1][2] if j is not None and j + 1 < len(seq) else ""
                    prv = "" if prv in SIL else prv
                    nxt = "" if nxt in SIL else nxt
                    pv, nv = (is_vowel(prv) if prv else False), (is_vowel(nxt) if nxt else False)
                    pos = ("only" if len(inside) == 1 else
                           "initial" if pi == 1 else
                           "final" if pi == len(inside) else "medial")
                    w.writerow([fname, "chuvash_voice", wlab, wi, n_words,
                                f"{ws:.4f}", f"{we:.4f}", len(inside),
                                lab, to_config(lab),
                                int("ː" in lab or ":" in lab), pi,
                                f"{s:.4f}", f"{e:.4f}", f"{(e - s) * 1000:.2f}",
                                to_config(prv) if prv else "",
                                to_config(nxt) if nxt else "",
                                int(pv), int(nv), int(pv and nv),
                                pos, int(is_vowel(lab))])
                    n_rows += 1
            if (fi + 1) % 5000 == 0:
                print(f"  {fi + 1}/{len(files)} files, {n_rows} rows", flush=True)
    print(f"wrote {n_rows} rows for {len(files)} files -> {out}")


if __name__ == "__main__":
    sys.exit(main())
