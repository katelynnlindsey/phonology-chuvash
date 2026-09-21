# -*- coding: utf-8 -*-
"""
annotate_textgrids.py  —  ANNOTATE stage
Reads recoded TextGrids (ARPAbet labels) and writes annotated TextGrids
with syllable-structure attributes and stress digits on each vowel:

    AA1 [sidx=2/sN=3/pos=medial/oc=closed]

Stress rule (current: Rule A — rightmost strong, else leftmost weak):
    To test a different rule, edit assign_stress() ONLY.
    All other functions are rule-agnostic.

Run AFTER recode_textgrids.py.

Input:   <corpus>/recoded_textgrids/<basename>_recoded.TextGrid
Output:  <corpus>/annotated_textgrids/<basename>_annotated.TextGrid

Usage:
    python annotate_textgrids.py
"""

import os
import sys
import re
from typing import List, Optional, Dict

import textgrid

from chuvash_phonology import (
    ALL_VOWELS_ARPABET,
    STRONG_VOWELS_ARPABET,
    ALL_CONSONANTS_ARPABET,
    read_textgrid_robust,
)

# ── Configuration ─────────────────────────────────────────────────────────────
BASE_CORPUS_PATH = r"C:\Users\profk\Documents\GitHub\phonology-chuvash\extract"
CORPORA          = ["mfa", "vox"]
INPUT_SUFFIX     = "_recoded"
OUTPUT_SUFFIX    = "_annotated"


# ─────────────────────────────────────────────────────────────────────────────
# Step 1  Helper: collect phones inside one word interval
# ─────────────────────────────────────────────────────────────────────────────

def phones_within_word(
    phones_tier: textgrid.IntervalTier,
    wmin: float,
    wmax: float
) -> List[textgrid.Interval]:
    """
    Return phone intervals wholly within [wmin, wmax], skipping SIL and blanks.
    Uses >= / <= so a phone that exactly spans the word boundary is included.
    """
    skip = {'SIL', '<EPS>', ''}
    return [
        p for p in phones_tier.intervals
        if p.mark.strip().upper() not in skip
        and p.minTime >= wmin
        and p.maxTime <= wmax
    ]


# ─────────────────────────────────────────────────────────────────────────────
# Step 2  Syllable structure detection
# ─────────────────────────────────────────────────────────────────────────────

def build_syllable_info(phone_intervals: List[textgrid.Interval]) -> List[dict]:
    """
    Walk the phone sequence and identify vowel nuclei with their properties.

    Open/closed rules applied here:
        V #     → open   (word-final vowel, no coda)
        V C V   → open   (C is onset of the next syllable)
        V C #   → closed (single word-final coda consonant)
        V CC…   → closed (two or more coda consonants)

    Returns a list of dicts (one per vowel/syllable nucleus):
        sidx      : 1-based syllable index within the word
        interval  : the textgrid.Interval object
        arpabet   : base ARPAbet label (e.g. 'AA')
        is_strong : bool
        oc_status : 'open' | 'closed'
        pos_attr  : 'initial' | 'med' | 'final'  (filled after loop)
    """
    syllables: List[dict] = []
    sidx = 0

    for idx, p in enumerate(phone_intervals):
        label = p.mark.strip().upper()
        if label not in ALL_VOWELS_ARPABET:
            continue  # consonant — handled via look-ahead below

        sidx += 1
        coda_count = 0
        look = idx + 1

        while look < len(phone_intervals):
            next_label = phone_intervals[look].mark.strip().upper()
            if next_label in ALL_VOWELS_ARPABET:
                break                                 # next vowel → stop counting coda
            # treat anything non-vowel, non-silence as a consonant
            if next_label not in ('SIL', '<EPS>', ''):
                coda_count += 1
            look += 1

        at_word_end = (look == len(phone_intervals))

        if coda_count >= 2:
            oc = 'closed'
        elif coda_count == 1 and at_word_end:
            oc = 'closed'
        else:
            oc = 'open'

        syllables.append({
            'sidx':      sidx,
            'interval':  p,
            'arpabet':   label,
            'is_strong': label in STRONG_VOWELS_ARPABET,
            'oc_status': oc,
            'pos_attr':  'med',   # placeholder
        })

    # Resolve positional attribute now that total is known
    total = len(syllables)
    for s in syllables:
        if total == 1:
            s['pos_attr'] = 'initial'   # monosyllable counts as initial
        elif s['sidx'] == 1:
            s['pos_attr'] = 'initial'
        elif s['sidx'] == total:
            s['pos_attr'] = 'final'
        # else stays 'med'

    return syllables


# ─────────────────────────────────────────────────────────────────────────────
# Step 3  Stress assignment  ← EDIT THIS FUNCTION TO TEST ALTERNATIVE RULES
# ─────────────────────────────────────────────────────────────────────────────

def assign_stress(syllables: List[dict]) -> Optional[int]:
    """
    Return the 1-based sidx of the stressed syllable, or None if word has
    no vowels.

    Current rule (Rule A):
        Primary stress falls on the rightmost strong vowel.
        If no strong vowel is present, stress falls on the leftmost weak vowel.

    To test Rule B (ʉ treated as weak), change STRONG_VOWELS_ARPABET in
    chuvash_phonology.py and re-run this script without touching anything else.
    """
    strong = [s['sidx'] for s in syllables if s['is_strong']]
    weak   = [s['sidx'] for s in syllables if not s['is_strong']]

    if strong:
        return max(strong)   # rightmost strong vowel
    if weak:
        return min(weak)     # leftmost weak vowel (fallback)
    return None


# ─────────────────────────────────────────────────────────────────────────────
# Step 4a  Write annotated labels to the phones tier
# ─────────────────────────────────────────────────────────────────────────────

def annotate_phones_tier(
    phones_tier: textgrid.IntervalTier,
    syllables: List[dict],
    stressed_sidx: Optional[int]
) -> None:
    """
    Update vowel interval marks in-place.

    Before:  AA
    After:   AA1 [sidx=2/sN=3/pos=medial/oc=closed]

    Consonants and SIL intervals are not touched.
    """
    total = len(syllables)
    # Map by object identity so there is no ambiguity with identical labels
    syl_by_id: Dict[int, dict] = {id(s['interval']): s for s in syllables}

    for interval in phones_tier.intervals:
        s = syl_by_id.get(id(interval))
        if s is None:
            continue   # consonant or SIL — leave unchanged

        digit = '1' if s['sidx'] == stressed_sidx else '0'
        interval.mark = (
            f"{s['arpabet']}{digit} "
            f"[sidx={s['sidx']}/sN={total}"
            f"/pos={s['pos_attr']}/oc={s['oc_status']}]"
        )


# ─────────────────────────────────────────────────────────────────────────────
# Step 4b  Build a syllabified label for the words tier
# ─────────────────────────────────────────────────────────────────────────────

def build_words_tier_label(
    phone_intervals: List[textgrid.Interval],
    syllables: List[dict],
    stressed_sidx: Optional[int]
) -> str:
    """
    Produce a human-readable syllabified words-tier label, e.g.:
        N.'AA1L.T

    Consonants attach to the preceding vowel's syllable (coda grouping).
    Pre-vocalic consonants attach to the first syllable.
    An apostrophe is inserted before the stressed vowel.
    Syllables are joined with '.'.
    """
    syl_ids = {id(s['interval']) for s in syllables}
    groups: List[List[str]] = []

    for p in phone_intervals:
        label = p.mark.strip().upper()
        if id(p) in syl_ids:
            groups.append([label])        # start a new syllable group
        elif groups:
            groups[-1].append(label)      # coda consonant → attach to last group
        else:
            groups.append([label])        # onset consonant before first vowel

    parts = []
    for i, g in enumerate(groups):
        s_str = ''.join(g)
        if stressed_sidx is not None and (i + 1) == stressed_sidx:
            # Insert apostrophe immediately before the ARPAbet vowel token
            m = re.search(r'[A-Z]{2}[01]', s_str)
            s_str = (s_str[:m.start()] + "'" + s_str[m.start():]
                     if m else "'" + s_str)
        parts.append(s_str)

    return '.'.join(parts)


# ─────────────────────────────────────────────────────────────────────────────
# Top-level: annotate one TextGrid
# ─────────────────────────────────────────────────────────────────────────────

def annotate_single_textgrid(input_path: str, output_path: str) -> bool:
    """Annotate one recoded TextGrid. Returns True on success."""
    tg = read_textgrid_robust(input_path)
    if tg is None:
        return False

    phones_tier = tg.getFirst('phones')
    words_tier  = tg.getFirst('words')

    if phones_tier is None:
        print(f"  Warning: no 'phones' tier in '{os.path.basename(input_path)}'.",
              file=sys.stderr)
        return False

    if words_tier is None or not isinstance(words_tier, textgrid.IntervalTier):
        print(f"  Warning: no 'words' IntervalTier in "
              f"'{os.path.basename(input_path)}'. Writing as-is.", file=sys.stderr)
        tg.write(output_path)
        return True

    for w_interval in words_tier.intervals:
        if w_interval.mark.strip().upper() in ('', 'SIL', '<EPS>'):
            continue

        phones        = phones_within_word(phones_tier,
                                           w_interval.minTime,
                                           w_interval.maxTime)
        if not phones:
            continue

        syllables     = build_syllable_info(phones)
        stressed_sidx = assign_stress(syllables)

        annotate_phones_tier(phones_tier, syllables, stressed_sidx)
        w_interval.mark = build_words_tier_label(phones, syllables, stressed_sidx)

    tg.write(output_path)
    return True


# ─────────────────────────────────────────────────────────────────────────────
# Directory runner
# ─────────────────────────────────────────────────────────────────────────────

def process_corpus(corpus_dir: str) -> None:
    input_dir  = os.path.join(corpus_dir, "recoded_textgrids")
    output_dir = os.path.join(corpus_dir, "annotated_textgrids")
    os.makedirs(output_dir, exist_ok=True)

    if not os.path.isdir(input_dir):
        print(f"Warning: '{input_dir}' not found. "
              "Run recode_textgrids.py first.", file=sys.stderr)
        return

    files = sorted(
        f for f in os.listdir(input_dir)
        if f.endswith(f"{INPUT_SUFFIX}.TextGrid")
        and not f.startswith(('.', '__'))
    )
    print(f"  Found {len(files)} recoded TextGrids.")

    done = 0
    for fname in files:
        base     = fname.replace(f"{INPUT_SUFFIX}.TextGrid", "")
        out_name = f"{base}{OUTPUT_SUFFIX}.TextGrid"
        out_path = os.path.join(output_dir, out_name)
        in_path  = os.path.join(input_dir,  fname)

        if os.path.exists(out_path):
            done += 1
            continue

        print(f"  Annotating '{base}'...")
        if annotate_single_textgrid(in_path, out_path):
            done += 1

    print(f"  Annotated: {done} TextGrids → '{output_dir}'")


if __name__ == "__main__":
    for corpus in CORPORA:
        print(f"\n── Corpus: {corpus} ──")
        process_corpus(os.path.join(BASE_CORPUS_PATH, corpus))
    print("\nannotate_textgrids.py finished.")