"""Transparent orthographic classifier for Russian loans in Chuvash word labels.

Overnight 2026-10-01, contact_phonology track. Evaluated against a hand-annotated stratified
sample (output/overnight_2026-10-01/contact_phonology/loan_handannotation.csv); precision/recall
in loan_classifier_eval.csv. Every decision is a named, inspectable feature; nothing is learned.

Usage
-----
    from loan_classifier import loan_features, classify_loan, classify_series
    classify_loan("учитель")            # -> dict(label=..., evidence=[...], ...)
    df = classify_series(pd.Series(words))   # one row per word, feature columns + labels

Labels returned (all booleans; the word is lower-cased and Latin homoglyphs folded first)
----------------------------------------------------------------------------------------
loan_full        any feature of the FULL feature set fires (best recall; uses vowel letters)
loan_vowelblind  any CONSONANT/PHONOTACTIC feature fires -- never looks at vowel letters.
                 Use this one for analyses OF vowels (loan /o/, harmony), where a
                 vowel-letter flag would be circular.
loan_crude       the Segmental track's flag: any of о ё ф ц щ ъ б г д ж з
loan_pipeline    replica of config/phonology_params.R::is_loan() (RUSSIAN_SEQS + ENGLISH_SEQS on
                 the upper-cased word; Cyrillic part = б г д о ж ц ф з ё щ; also any Latin letter)

Features
--------
C_LET      a consonant letter native Chuvash orthography does not use: б г д ж з ф ц щ ъ
V_LET      о or ё (the loan vowel)                                    [vowel letter]
INIT_CC    word-initial consonant cluster (Chuvash native words begin with at most one C)
INIT_R     word-initial р (Turkic *#r- avoidance; native r-initial words are very rare)
FINAL_GEM  word-final -сс/-лл in a word with no ӑ ӗ ӳ ҫ (класс, пресс, металл); native
           word-final doubled letters are expressives (хашш, чӑрр), excluded
HIATUS     two adjacent full-vowel letters from а и о у ы э (iotated е ё ю я = j+V excluded;
           ӑ ӗ excluded)                                                [vowel letters]
NONINIT_E  э anywhere but word-initially (поэт, дуэль)                 [vowel letter]
RU_SUFFIX  a Russian derivational ending, optionally followed by Chuvash suffix material:
           -тель, -ист, -изм, -ика, -ция/-ци-, -ость, -ство, -ский/-ская/-ское [contain vowels]
"""
import re

HOMOGLYPHS = str.maketrans({"\u0103": "ӑ", "\u0115": "ӗ", "\u00e7": "ҫ", "\u0102": "Ӑ",
                            "\u0114": "Ӗ", "\u00c7": "Ҫ", "\u00ad": None})
_CONS = "бвгджзйклмнпрстфхцчшщҫ"
_VOW = "аеёиоуыэюяӑӗӳ"
PATTERNS = {
    "C_LET": re.compile(r"[бгджзфцщъ]"),
    "V_LET": re.compile(r"[оё]"),
    "INIT_CC": re.compile(rf"^[{_CONS}][ьъ]?[{_CONS}]"),
    "INIT_R": re.compile(r"^р"),
    # only -сс/-лл and only in words without Chuvash-only letters: native word-final doubled
    # letters are expressives (хашш, чӑрр, шатӑрр) or text fragments (палл, пулнн)
    "FINAL_GEM": re.compile(r"^[^ӑӗӳҫ]*(сс|лл)$"),
    # ӑ ӗ (reduced) and ӳ excluded: native compounds/fragments (иӗм) produce hiatus with them
    "HIATUS": re.compile(r"[аиоуыэ][аиоуыэ]"),
    "NONINIT_E": re.compile(r"(?<=.)э"),
    # -ика only word-finally or before ӑ (техника, техникӑпа): medial ика hits native никам
    "RU_SUFFIX": re.compile(r"(тель|ист|изм|ик[аи]$|икӑ|ци[яиейю]|ость|ств[оаи]|ск(ий|ая|ое))"),
}
CLITICS = {"ҫке", "ҫкӗ", "и"}
VOWEL_FEATURES = {"V_LET", "HIATUS", "NONINIT_E", "RU_SUFFIX"}
FULL_SET = list(PATTERNS)
VOWELBLIND_SET = [f for f in PATTERNS if f not in VOWEL_FEATURES]
_CRUDE = re.compile(r"[оёфцщъбгджз]")
_PIPE_CYR = re.compile(r"[БГДОЖЦФЗЁЩ]")
_LATIN = re.compile(r"[A-Z]")


def normalise(word):
    return str(word).translate(HOMOGLYPHS).lower().strip()


def loan_features(word):
    w = normalise(word)
    # hyphenated compounds/reduplications: evaluate each part (INIT_* per part)
    # The native clitics -ҫке/-ҫкӗ and -и, and single-letter parts (шӑпӑр-р), are not evaluated
    # for the word-initial features (they made INIT_CC/INIT_R fire on юратмастчӗ-ҫке, шӑпӑр-р).
    parts = [p for p in w.split("-") if p]
    feats = {f: False for f in PATTERNS}
    for p in parts or [w]:
        for f, rx in PATTERNS.items():
            if f in ("INIT_CC", "INIT_R") and (len(p) < 2 or p in CLITICS):
                continue
            if rx.search(p):
                feats[f] = True
    return feats


def classify_loan(word):
    f = loan_features(word)
    w = normalise(word)
    up = str(word).translate(HOMOGLYPHS).upper()
    return {
        "word": w,
        **f,
        "loan_full": any(f[k] for k in FULL_SET),
        "loan_vowelblind": any(f[k] for k in VOWELBLIND_SET),
        "loan_crude": bool(_CRUDE.search(w)),
        "loan_pipeline": bool(_PIPE_CYR.search(up) or _LATIN.search(up)),
        "evidence": [k for k in FULL_SET if f[k]],
    }


def classify_series(words):
    """words: iterable of strings -> pandas DataFrame (one row per input word, same order)."""
    import pandas as pd
    rows = [classify_loan(w) for w in words]
    df = pd.DataFrame(rows)
    df["evidence"] = df["evidence"].map(lambda e: "+".join(e))
    return df
