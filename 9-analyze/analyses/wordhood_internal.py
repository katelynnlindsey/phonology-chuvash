#!/usr/bin/env python3
"""Decide which monolingual-corpus types are real words, WITHOUT the wordlist.

WHY
---
The minimal-word analysis asks the same question of two corpora: which vowels
can stand in an open monosyllable. The monolingual corpus answer is
contaminated, because de-hyphenation failures at line breaks, letter-spaced
emphasis and Russian passages leave word FRAGMENTS that are phonotactically
legal open monosyllables (нӑ, тӑ, лӑ, нӗ, ҫӗ, чӗ — 310 types, 184,979 tokens).

The previous fix was to keep only types attested in the Zheltov wordlist. That
works, but it destroys the independence of the two corpora: once the monolingual
list is filtered to Zheltov, the two are answering the same question over the
same vocabulary and agreement is guaranteed rather than informative.

So the filter has to be built from the monolingual corpus alone, and the
wordlist used only afterwards, as a held-out check on how well it worked.

THE IDEA
--------
A free word and a stranded suffix differ in their SYNTACTIC FREEDOM, which is
visible in raw text without any lexicon:

  1. sentence-initial position — a suffix cannot start a sentence
  2. position after punctuation — a suffix cannot follow a comma or dash
  3. capitalisation — a fragment is never capitalised except by accident
  4. breadth of left context — a free word takes many different preceding
     words; a suffix takes the stems it attaches to
  5. harmony agreement with the preceding token — Chuvash suffixes agree in
     backness with their stem, so a stranded suffix's vowel is predicted by
     the preceding token's vowels. A free word's vowel cannot be.
  6. re-attachment WITHIN the monolingual corpus — if `previous + candidate`
     is itself an attested type of this corpus, the candidate is likely a
     piece of it. This is the re-attachment test with the wordlist removed
     from it.

Criteria 1-3 are the decisive ones and they are close to categorical. 4-6 are
graded and are reported alongside.

Outputs
  9-analyze/output/wordhood_internal.csv   one row per type, all six measures
  9-analyze/output/wordhood_validation.csv agreement with Zheltov, held out
"""
from __future__ import annotations

import argparse
import math
import os
import re
import unicodedata
from collections import Counter, defaultdict

import pyarrow.parquet as pq

VOWELS = set("аеиоуыэюяӑӗӳ")
BACK_V = set("аоуыӑ")          # back/hard harmony class
FRONT_V = set("еиэюяӗӳ")       # front/soft harmony class
CONS = set("бвгджзйклмнпрстфхцчшщҫъь")
LETTERS = VOWELS | CONS
# Sentence-internal boundaries after which a suffix cannot stand.
PUNCT = set(".,!?:;—–-«»\"'()[]…")
SOFT_HYPHEN = "\u00ad"


def norm(tok: str) -> str:
    """NFC, lowercase, Latin homoglyphs mapped to Cyrillic."""
    s = unicodedata.normalize("NFC", tok).lower()
    for a, b in (("\u0103", "ӑ"), ("\u0115", "ӗ"), ("\u00e7", "ҫ")):
        s = s.replace(a, b)
    return s


def harmony_of(word: str) -> str | None:
    """Backness class of a word's last non-neutral vowel."""
    for ch in reversed(word):
        if ch in BACK_V:
            return "back"
        if ch in FRONT_V and ch != "и":     # /i/ is harmonically neutral
            return "front"
    return None


def tokenise(sentence: str):
    """Yield (token, is_sentence_initial, after_punct, was_capitalised).

    Splits on whitespace, then strips leading/trailing punctuation while
    remembering that it was there — that is the signal being measured.
    """
    raw = sentence.replace(SOFT_HYPHEN, "").split()
    prev_had_trailing_punct = True          # start of sentence counts
    for i, r in enumerate(raw):
        lead = 0
        while lead < len(r) and r[lead] in PUNCT:
            lead += 1
        trail = len(r)
        while trail > lead and r[trail - 1] in PUNCT:
            trail -= 1
        core = r[lead:trail]
        if core:
            was_cap = core[0].isupper()
            t = norm(core)
            if all(c in LETTERS for c in t):
                yield (t, i == 0, prev_had_trailing_punct or lead > 0, was_cap)
        prev_had_trailing_punct = bool(core) and trail < len(r)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--parquet",
                    default="1-raw_data/monolingual_chuvash/train-00000-of-00001.parquet")
    ap.add_argument("--min-freq", type=int, default=5,
                    help="types rarer than this get no context statistics")
    args = ap.parse_args()
    out = os.path.join(args.repo, "9-analyze/output")
    path = os.path.join(args.repo, args.parquet)

    # ── pass 1: the type inventory ─────────────────────────────────────
    freq = Counter()
    pf = pq.ParquetFile(path)
    n_sent = 0
    for batch in pf.iter_batches(batch_size=50_000, columns=["chv"]):
        for s in batch.column("chv").to_pylist():
            if not s:
                continue
            n_sent += 1
            for t, _, _, _ in tokenise(s):
                freq[t] += 1
    print(f"pass 1: {n_sent:,} sentences, {len(freq):,} types, "
          f"{sum(freq.values()):,} tokens")

    # ── pass 2: context statistics ─────────────────────────────────────
    # Only for types at or above min_freq; the rest cannot support a rate.
    track = {t for t, n in freq.items() if n >= args.min_freq}
    print(f"pass 2: tracking {len(track):,} types with freq >= {args.min_freq}")
    init = Counter(); after_p = Counter(); cap = Counter()
    prev_match = Counter(); prev_class_total = Counter()
    reattach = Counter()
    prev_types = defaultdict(set)
    PREV_CAP = 500

    pf = pq.ParquetFile(path)
    for batch in pf.iter_batches(batch_size=50_000, columns=["chv"]):
        for s in batch.column("chv").to_pylist():
            if not s:
                continue
            toks = list(tokenise(s))
            for i, (t, is_init, after, was_cap) in enumerate(toks):
                if t not in track:
                    continue
                if is_init:
                    init[t] += 1
                if after:
                    after_p[t] += 1
                if was_cap:
                    cap[t] += 1
                if i == 0:
                    continue
                prev = toks[i - 1][0]
                if len(prev_types[t]) < PREV_CAP:
                    prev_types[t].add(prev)
                # harmony agreement with the preceding token
                hp, ht = harmony_of(prev), harmony_of(t)
                if hp and ht:
                    prev_class_total[t] += 1
                    if hp == ht:
                        prev_match[t] += 1
                # re-attachment, monolingual-internal
                if freq.get(prev + t, 0) >= 2:
                    reattach[t] += 1

    # ── assemble ───────────────────────────────────────────────────────
    rows = []
    for t in sorted(track):
        n = freq[t]
        npc = prev_class_total[t]
        pt = prev_types[t]
        ent = 0.0
        if pt:
            # normalised entropy of the left-context types we sampled
            ent = math.log(len(pt)) / math.log(min(len(pt) + 1, PREV_CAP) + 1)
        rows.append(dict(
            type=t, freq=n, n_letters=len(t),
            pct_sentence_initial=round(100 * init[t] / n, 4),
            pct_after_punct=round(100 * after_p[t] / n, 4),
            pct_capitalised=round(100 * cap[t] / n, 4),
            n_distinct_prev=len(pt),
            prev_entropy_norm=round(ent, 4),
            pct_prev_harmony_match=round(100 * prev_match[t] / npc, 2)
            if npc else None,
            n_prev_classified=npc,
            pct_reattach_mono=round(100 * reattach[t] / n, 4),
        ))

    import csv as _csv
    cols = list(rows[0].keys())
    with open(os.path.join(out, "wordhood_internal.csv"), "w",
              newline="", encoding="utf-8") as fh:
        w = _csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)
    print(f"wrote wordhood_internal.csv: {len(rows):,} types x {len(cols)} cols")

    # ── a first look: the open monosyllables ───────────────────────────
    mono = [r for r in rows
            if (len(r["type"]) == 2 and r["type"][0] in CONS
                and r["type"][1] in VOWELS)
            or (len(r["type"]) == 1 and r["type"][0] in VOWELS)]
    mono.sort(key=lambda r: -r["freq"])
    print(f"\nopen-monosyllable types at freq >= {args.min_freq}: {len(mono)}")
    print(f"{'type':>6} {'freq':>8} {'init%':>7} {'punct%':>7} {'cap%':>6} "
          f"{'nprev':>6} {'harm%':>6} {'reatt%':>7}")
    for r in mono[:25]:
        print(f"{r['type']:>6} {r['freq']:>8} {r['pct_sentence_initial']:>7.3f} "
              f"{r['pct_after_punct']:>7.3f} {r['pct_capitalised']:>6.2f} "
              f"{r['n_distinct_prev']:>6} "
              f"{(r['pct_prev_harmony_match'] or 0):>6.1f} "
              f"{r['pct_reattach_mono']:>7.2f}")


if __name__ == "__main__":
    main()
