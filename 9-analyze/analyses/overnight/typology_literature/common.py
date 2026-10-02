"""Shared helpers for the overnight typology track (2026-10-01).

Tokenisation mirrors config/phonology_params.R::tokenize_ipa (greedy, longest
digraph first, IPA_DIGRAPHS list) so that /tɕ/ and palatalised consonants are
single segments. Vowel symbols are the config's: a e i u y ʉ ø ɵ.
"""
from __future__ import annotations
import os
import pandas as pd

ROOT = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze"
OUT = os.path.join(ROOT, "output/overnight_2026-10-01/typology_literature")

IPA_DIGRAPHS = ["t͡ɕ", "t͡ʃ", "d͡ʒ", "t͡s", "tɕ", "tʃ", "dʒ", "ts",
                "lʲ", "nʲ", "rʲ", "sʲ", "zʲ", "tʲ", "dʲ", "kʲ", "ɡʲ", "gʲ",
                "mʲ", "pʲ", "bʲ", "fʲ", "vʲ", "ʋʲ", "xʲ", "ɣʲ", "ɕʲ"]
_DG = sorted(IPA_DIGRAPHS, key=len, reverse=True)

VOWELS = ["a", "e", "i", "u", "y", "ʉ", "ø", "ɵ"]
VSET = set(VOWELS)
BACK = {"a", "ɵ", "u", "ʉ"}
FRONT = {"e", "ø", "i", "y"}
HIGH = {"i", "y", "u", "ʉ"}
REDUCED = {"ø", "ɵ"}
# two rounding treatments
ROUND_FULL_ONLY = {"u", "y"}               # reduced vowels unrounded
ROUND_CONFIG = {"u", "y", "ɵ", "ø"}        # config VOWEL_ROUND (Krueger 1961)

# Cyrillic vowel letters for the orthographic functional-load work
CYR = {"а": "a", "е": "e", "и": "i", "у": "u", "ӳ": "y", "ы": "ʉ",
       "ӗ": "ø", "ӑ": "ɵ"}


def tokenize(s: str) -> list[str]:
    segs, i = [], 0
    if not isinstance(s, str):
        return segs
    while i < len(s):
        for dg in _DG:
            if s.startswith(dg, i):
                segs.append(dg)
                i += len(dg)
                break
        else:
            segs.append(s[i])
            i += 1
    return segs


def load_types():
    """Zheltov types and dictionary-attested monolingual types.

    Returns (zheltov, mono_dict). mono_dict = monolingual types with
    in_wordlist == TRUE, carrying corpus_freq (token counts).
    """
    zt = pd.read_csv(os.path.join(OUT, "types_zheltov.csv"))
    mt = pd.read_csv(os.path.join(OUT, "types_mono.csv"))
    md = mt[mt.in_wordlist == True].copy()
    for d in (zt, md):
        d["segs"] = d.word_label_IPA.map(tokenize)
        d["vseq"] = d.segs.map(lambda ss: [x for x in ss if x in VSET])
    return zt, md
