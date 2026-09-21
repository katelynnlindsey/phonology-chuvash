# -*- coding: utf-8 -*-
"""
chuvash_phonology.py
Shared constants and I/O utilities for the Chuvash processing pipeline.
Imported by recode_textgrids.py and annotate_textgrids.py.
No side effects on import.
"""

import os
import sys
import codecs
import tempfile
from typing import Optional

import textgrid


# ── IPA → ARPAbet mapping ─────────────────────────────────────────────────────
# Keys must exactly match IPA symbols produced by MFA in the 'phones' tier.
IPA_TO_ARPABET = {
    # Vowels (IPA key : ARPAbet value)
    'ʌ': 'AH',   # weak
    'ɑ': 'AA',   # strong
    'u': 'UW',   # strong
    'y': 'UX',   # strong
    'ɛ': 'EH',   # weak
    'e': 'EY',   # strong
    'o': 'OW',   # strong (loanword)
    'i': 'IY',   # strong
    'ɯ': 'IX',   # strong
    # Silence / epsilon
    'sil':   'SIL',
    '<eps>': 'SIL',
    # Consonants
    'v':   'V',  'j':   'J',  'n':  'N',  'ʃ': 'SH',
    'p':   'P',  'k':   'K',  'm':  'M',  'r':  'R',
    's':   'S',  't':   'T',  'd':  'D',  'l':  'L',
    'z':   'Z',  'ŋ':  'NG',  'ð': 'DH',  'θ': 'TH',
    'f':   'F',  'w':   'W',  'h': 'HH',  'ʔ':  'Q',
    'b':   'B',  'g':   'G',  'ʒ': 'ZH',  'ɾ': 'DX',
    'χ':  'HH',
    'd͡ʒ': 'JH',  't͡ʃ': 'CH',
    # Geminates → base consonant
    'tː': 'T',  'lː': 'L',  'pː': 'P',  'mː': 'M',
    'nː': 'N',  'rː': 'R',  'sː': 'S',  'kː': 'K',
}

# ── IPA vowel sets (used during recode + as source of truth) ─────────────────
STRONG_VOWELS_IPA = {'ɑ', 'u', 'y', 'e', 'o', 'i', 'ɯ'}
WEAK_VOWELS_IPA   = {'ʌ', 'ɛ'}
ALL_VOWELS_IPA    = STRONG_VOWELS_IPA | WEAK_VOWELS_IPA

# ── ARPAbet vowel sets (used in annotate step, derived automatically) ─────────
STRONG_VOWELS_ARPABET = {IPA_TO_ARPABET[v] for v in STRONG_VOWELS_IPA}
WEAK_VOWELS_ARPABET   = {IPA_TO_ARPABET[v] for v in WEAK_VOWELS_IPA}
ALL_VOWELS_ARPABET    = STRONG_VOWELS_ARPABET | WEAK_VOWELS_ARPABET

# ── ARPAbet consonant labels (used for open/closed coda counting) ─────────────
# Anything that is not a vowel and not silence.
_SILENCE = {'SIL', '<EPS>'}
ALL_CONSONANTS_ARPABET = {
    v for k, v in IPA_TO_ARPABET.items()
    if k not in ALL_VOWELS_IPA and k not in ('sil', '<eps>')
} - _SILENCE


# ── Shared TextGrid I/O ───────────────────────────────────────────────────────

def read_textgrid_robust(path: str) -> Optional[textgrid.TextGrid]:
    """
    Read a TextGrid file, trying several encodings in order.
    Writes a temporary UTF-8 copy before parsing (avoids encoding bugs
    in the textgrid library).

    Returns a textgrid.TextGrid object, or None on failure.
    """
    content = None
    for enc in ('utf-8', 'latin-1', 'cp1252', 'iso-8859-1'):
        try:
            with codecs.open(path, 'r', encoding=enc) as fh:
                text = fh.read()
            if ("File type" in text and "Object class" in text
                    and ("text =" in text or "intervals:" in text)):
                content = text
                break
        except (UnicodeDecodeError, Exception):
            pass

    if content is None:
        print(f"Warning: cannot read '{os.path.basename(path)}' — "
              "no supported encoding matched.", file=sys.stderr)
        return None

    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode='w', delete=False, encoding='utf-8',
            suffix='.TextGrid', newline=''
        ) as tmp:
            tmp.write(content)
            temp_path = tmp.name
        return textgrid.TextGrid.fromFile(temp_path)
    except Exception as e:
        print(f"Error parsing '{os.path.basename(path)}': {e}", file=sys.stderr)
        return None
    finally:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)