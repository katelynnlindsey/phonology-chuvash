# -*- coding: utf-8 -*-
"""
recode_textgrids.py  —  RECODE stage
Replaces IPA phone labels from MFA output with ARPAbet equivalents.
Does NOT add syllable structure or stress information — that is the
job of annotate_textgrids.py.

Run this AFTER forced alignment, BEFORE annotation.

Input:   <corpus>/to_process/<basename>.TextGrid      (IPA labels from MFA)
Output:  <corpus>/recoded_textgrids/<basename>_recoded.TextGrid

Usage:
    python recode_textgrid_arpabet.py
"""

import os
import sys
import textgrid

from chuvash_phonology import IPA_TO_ARPABET, read_textgrid_robust

# ── Configuration ─────────────────────────────────────────────────────────────
BASE_CORPUS_PATH = r"C:\Users\profk\Documents\GitHub\phonology-chuvash\extract"
CORPORA          = ["chuvash_voice", "common_voice_chuvash"]
OUTPUT_SUFFIX    = "_arpabet"


def recode_phones_tier(tg: textgrid.TextGrid, mapping: dict) -> bool:
    """
    Replace every IPA label in the 'phones' tier with its ARPAbet equivalent.
    Labels absent from the mapping are left unchanged (with a stderr warning).
    Returns True if the phones tier was found.
    """
    phones_tier = tg.getFirst('phones')
    if phones_tier is None:
        print("  Warning: no 'phones' tier found.", file=sys.stderr)
        return False

    for interval in phones_tier.intervals:
        raw = interval.mark.strip()
        if raw == '':
            continue

        key       = raw.lower()
        new_label = mapping.get(key)

        if new_label is None:
            print(f"  Warning: IPA symbol '{raw}' not in mapping — left unchanged.",
                  file=sys.stderr)
            new_label = raw

        interval.mark = new_label  # e.g. 'ɑ' → 'AA', 'sil' → 'SIL'

    return True


def recode_single_textgrid(input_path: str, output_path: str) -> bool:
    """Recode one TextGrid. Returns True on success."""
    tg = read_textgrid_robust(input_path)
    if tg is None:
        return False
    recode_phones_tier(tg, IPA_TO_ARPABET)
    tg.write(output_path)
    return True


def process_corpus(corpus_dir: str) -> None:
    input_dir  = os.path.join(corpus_dir, "to_process")
    output_dir = os.path.join(corpus_dir, "recoded_textgrids")
    os.makedirs(output_dir, exist_ok=True)

    if not os.path.isdir(input_dir):
        print(f"Warning: '{input_dir}' not found. Skipping.", file=sys.stderr)
        return

    basenames = {
        os.path.splitext(f)[0]
        for f in os.listdir(input_dir)
        if os.path.splitext(f)[1].lower() == '.textgrid'
        and not f.startswith(('.', '__'))
    }
    print(f"  Found {len(basenames)} TextGrids.")

    done = 0
    for base in sorted(basenames):
        out_path = os.path.join(output_dir, f"{base}{OUTPUT_SUFFIX}.TextGrid")
        if os.path.exists(out_path):
            done += 1
            continue

        src = os.path.join(input_dir, f"{base}.TextGrid")
        if not os.path.exists(src):
            src = os.path.join(input_dir, f"{base}.textgrid")
        if not os.path.exists(src):
            print(f"  Warning: no TextGrid found for '{base}'.", file=sys.stderr)
            continue

        print(f"  Recoding '{base}'...")
        if recode_single_textgrid(src, out_path):
            done += 1

    print(f"  Recoded: {done} TextGrids → '{output_dir}'")


if __name__ == "__main__":
    for corpus in CORPORA:
        print(f"\n── Corpus: {corpus} ──")
        process_corpus(os.path.join(BASE_CORPUS_PATH, corpus))
    print("\nrecode_textgrids.py finished.")