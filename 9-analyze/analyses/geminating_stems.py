#!/usr/bin/env python3
"""Identify the geminating-stem class: nouns of the shape C V C Ṙ whose stem
surfaces with a long consonant before a vowel-initial suffix.

пулӑ 'fish' ~ пулли '(its) fish'; ҫӗнӗ 'new' ~ ҫӗнни 'the new one'.

WHY THIS SCRIPT EXISTS
----------------------
An earlier attempt identified the class the wrong way round: it took every type
ending in a reduced vowel and asked whether `stem + C + C + и` happened to be
attested.  That over-generates (it accepts any accidental string match) and it
under-generates (it only ever looks for one suffix, -и).  Worse, it left both
sides of the comparison dominated by suffix-shaped words -- -лӑ, -нӑ, -тӑ
participles and adjectives whose final reduced vowel is a suffix vowel rather
than a stem vowel -- and it left them dominated to *different* degrees:
**64.9%** of the 94 candidate types where the geminate form was attested, against
**97.5%** of the 983 comparison types where it was not.  So the contrast that
test actually measured was stem-shaped versus suffix-shaped words, not
fleeting versus stable vowels.  The morphology, not the phonology, drove the
result.

This script inverts the search.  **The geminate is directly observable in the
orthography**, so it enumerates attested word forms that contain a written
geminate, strips the suffix, and asks whether the corresponding bare noun
exists.  Three things follow:

  * the diagnostic is an attested form, not a hypothesised one;
  * the suffixes that reveal the geminate are *discovered* rather than assumed,
    so the script reports which paradigm slots actually do the work;
  * restricting the bare noun to exactly C V C Ṙ (four letters) excludes the
    suffix-shaped words by construction -- пулнӑ, вырӑнлӑ and the rest are five
    letters or more -- which is what makes the class testable at all.

Shape codes for the bare noun, in the `shape` column:
    CFCR   consonant, full vowel, consonant, reduced vowel   -- пулӑ, Kate's target
    CRCR   consonant, reduced vowel, consonant, reduced vowel -- ҫӗнӗ
    other  anything else that still ends in a reduced vowel

Inputs   /tmp/mono_all_types.csv    word_label, corpus_freq  (monolingual corpus)
         /tmp/zheltov_types.csv     word_label               (Zheltov wordlist)
         7-extract/reextract/phones_chuvash_voice.csv        (spoken tokens)
Outputs  9-analyze/output/geminating_stems.csv        one row per candidate stem
         9-analyze/output/geminating_slots.csv        suffixes that reveal it
         9-analyze/output/geminating_stems_spoken.csv spoken token counts
"""
from __future__ import annotations

import argparse
import os
import re
import unicodedata
from collections import Counter, defaultdict

import pandas as pd

FULL = set("аеиуӳыоэюя")          # о and э are loan-only; ю я are /ju ja/
REDUCED = set("ӑӗ")
VOWELS = FULL | REDUCED
CONS = set("бвгджзйклмнпрстфхцчшщҫ")
# Chuvash writes the palatal fricative ҫ and the affricate ч as single letters,
# so a letter-level shape test is 1:1 with segments for every relevant word.
BACK_HARMONY = set("аоуыӑ")        # a stem with one of these takes ӑ, else ӗ


def norm(s: str) -> str:
    """Cyrillic NFC, lowercased, with the Latin homoglyphs mapped back.

    The Zheltov wordlist is typed with Latin ă/ĕ/ç where the corpus uses
    Cyrillic ӑ/ӗ/ҫ; see normalise_orthography() in config/phonology_params.R.
    """
    s = unicodedata.normalize("NFC", str(s)).lower()
    for a, b in (("\u0103", "ӑ"), ("\u0115", "ӗ"), ("\u00e7", "ҫ"),
                 ("\u04d1", "ӑ"), ("\u04d7", "ӗ"), ("\u04ab", "ҫ")):
        s = s.replace(a, b)
    return s


def is_chuvash(s: str) -> bool:
    return bool(s) and all(c in VOWELS or c in CONS or c == "ь" for c in s)


def shape_of(w: str) -> str:
    """Shape code for a four-letter disyllable ending in a reduced vowel."""
    if len(w) != 4:
        return "other"
    c1, v1, c2, v2 = w
    if c1 not in CONS or c2 not in CONS or v2 not in REDUCED:
        return "other"
    if v1 in FULL:
        return "CFCR"
    if v1 in REDUCED:
        return "CRCR"
    return "other"


def predicted_bare(root: str) -> str:
    """Bare noun for a root, with the reduced vowel chosen by harmony."""
    return root + ("ӑ" if any(c in BACK_HARMONY for c in root) else "ӗ")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--mono", default="/tmp/mono_all_types.csv")
    ap.add_argument("--zheltov", default="/tmp/zheltov_types.csv")
    ap.add_argument("--min-geminate-freq", type=int, default=2,
                    help="a geminate form must occur at least this often to "
                         "count as attested; 1 admits typos")
    args = ap.parse_args()
    out = os.path.join(args.repo, "9-analyze/output")

    mono = pd.read_csv(args.mono)
    mono["w"] = mono.word_label.map(norm)
    mono = mono[mono.w.map(is_chuvash)]
    freq = mono.groupby("w").corpus_freq.sum().to_dict()

    zh = pd.read_csv(args.zheltov)
    zh["w"] = zh.word_label.map(norm)
    wordlist = set(zh.loc[zh.w.map(is_chuvash), "w"])

    # ── step 1: every attested form with a written geminate after C V ────────
    # C V C C ...  with the two consonants identical.  This is the observable
    # diagnostic; everything else is derived from it.
    gem_re = re.compile(
        r"^([" + "".join(CONS) + r"])([" + "".join(VOWELS) + r"])"
        r"([" + "".join(CONS) + r"])\3(.*)$")
    hits = defaultdict(Counter)      # root -> Counter of suffix strings
    for w, f in freq.items():
        if f < args.min_geminate_freq:
            continue
        m = gem_re.match(w)
        if not m:
            continue
        c1, v1, c2, suf = m.groups()
        if not suf or suf[0] not in VOWELS:
            continue             # the geminate must be followed by a vowel
        hits[c1 + v1 + c2][suf] += f

    # ── step 2: does the bare noun exist? ───────────────────────────────────
    #
    # Attestation of the bare form is necessary but nowhere near sufficient.
    # The search also matches three things that are not the target class:
    #
    #   (a) CVC monosyllabic stems taking a possessive.  кун 'day' -> кунӗ
    #       'his day' -> кунне (dative), so кунӗ looks like a CFCR noun whose
    #       stem geminates, but its final ӗ is the possessive suffix and the
    #       lexical stem is the monosyllable кун.
    #   (b) verb stems taking the past participle -нӑ/-нӗ.  те- 'say' -> тенӗ.
    #       This is the morphological confound that wrecked the first attempt.
    #   (c) words that simply contain a geminate with no alternation at all --
    #       Раҫҫей 'Russia', саккун 'law' (both Russian loans), паллӑ 'known',
    #       and the postpositions валли 'for' and хыҫҫӑн 'after'.  Here the
    #       "bare form" (раҫӑ, сакӑ, палӑ, валӑ, хыҫӑ) is a phantom whose
    #       handful of corpus hits are typos.
    #
    # What separates the target class is whether the final reduced vowel
    # belongs to the STEM or is a suffix, and the plural settles it:
    #
    #       пулӑ 'fish'  -> пулӑсем     the vowel survives: it is stem-final
    #       кун  'day'   -> кунсем      no vowel: кунӗ's ӗ was a suffix
    #
    # So compare freq(root + Ṙ + сем) against freq(root + сем), and check
    # whether the bare root is a free word in its own right.
    PLURALS = ("сем", "сен", "семпе", "сене", "сенче")
    rows = []
    for root, sufs in hits.items():
        bare = predicted_bare(root)
        # the other reduced vowel, in case harmony is not what decides it
        alt = root + ("ӗ" if bare.endswith("ӑ") else "ӑ")
        bare_attested = bare if freq.get(bare, 0) else (
            alt if freq.get(alt, 0) else None)
        pl_with = sum(freq.get((bare_attested or bare) + p, 0)
                      for p in PLURALS)
        pl_without = sum(freq.get(root + p, 0) for p in PLURALS)
        root_free = freq.get(root, 0)
        if pl_with + pl_without >= 5:
            vowel = ("stem-final" if pl_with > pl_without else "suffix")
        elif root_free >= 50:
            vowel = "suffix"          # the bare root stands alone as a word
        else:
            vowel = "unclear"
        rows.append(dict(
            root=root,
            bare_predicted=bare,
            bare_attested=bare_attested,
            bare_freq_mono=freq.get(bare_attested, 0) if bare_attested else 0,
            bare_in_wordlist=int(bool(bare_attested) and
                                 bare_attested in wordlist),
            bare_shape=shape_of(bare_attested) if bare_attested
            else "no bare form",
            geminate_consonant=root[-1],
            stem_vowel=root[1],
            root_free_freq=root_free,
            plural_with_vowel=pl_with,
            plural_without_vowel=pl_without,
            final_vowel=vowel,
            n_geminate_forms=len(sufs),
            geminate_freq_total=int(sum(sufs.values())),
            geminate_forms=";".join(
                f"{root}{root[-1]}{s}({n})"
                for s, n in sufs.most_common(6)),
            revealing_suffixes=";".join(s for s, _ in sufs.most_common(6)),
        ))
    st = pd.DataFrame(rows)
    # A confirmed member of the class needs all four:
    #   the bare form is attested and is four letters ending in a reduced vowel;
    #   the bare form is in the curated wordlist, i.e. it is a lexical item and
    #     not a corpus artefact;
    #   the plural keeps the reduced vowel, so the vowel is stem-final;
    #   the geminate is attested often enough not to be a typo.
    st["confirmed"] = ((st.bare_attested.notna()) &
                       (st.bare_shape.isin(["CFCR", "CRCR"])) &
                       (st.bare_in_wordlist == 1) &
                       (st.final_vowel == "stem-final") &
                       (st.geminate_freq_total >= 10)).astype(int)
    st = st.sort_values(["confirmed", "geminate_freq_total"],
                        ascending=[False, False])
    st.to_csv(os.path.join(out, "geminating_stems.csv"), index=False)

    # ── step 3: which paradigm slots reveal the geminate? ───────────────────
    slot = Counter()
    slot_types = defaultdict(set)
    for root, sufs in hits.items():
        if st.loc[st.root == root, "confirmed"].iloc[0] != 1:
            continue
        for s, n in sufs.items():
            slot[s] += n
            slot_types[s].add(root)
    sl = pd.DataFrame([dict(suffix=s, tokens=n, n_stems=len(slot_types[s]))
                       for s, n in slot.most_common()])
    sl.to_csv(os.path.join(out, "geminating_slots.csv"), index=False)

    # ── step 4: how much spoken data is there per stem? ─────────────────────
    ph = pd.read_csv(os.path.join(
        args.repo, "7-extract/reextract/phones_chuvash_voice.csv"),
        usecols=["file_name", "word_label", "widx", "corpus"])
    tok = ph.drop_duplicates(["file_name", "widx"]).copy()
    tok["w"] = tok.word_label.map(norm)
    conf = st[st.confirmed == 1]
    bare_set = set(conf.bare_attested)
    gem_forms = {}
    for _, r in conf.iterrows():
        for s in hits[r.root]:
            gem_forms[r.root + r.root[-1] + s] = r.bare_attested
    cnt = tok.w.value_counts()
    sp = []
    for _, r in conf.iterrows():
        gf = [f for f, b in gem_forms.items() if b == r.bare_attested]
        sp.append(dict(bare=r.bare_attested, bare_shape=r.bare_shape,
                       geminate_consonant=r.geminate_consonant,
                       spoken_bare_tokens=int(cnt.get(r.bare_attested, 0)),
                       spoken_geminate_tokens=int(sum(cnt.get(f, 0)
                                                      for f in gf))))
    spd = (pd.DataFrame(sp).sort_values("spoken_bare_tokens", ascending=False)
           if sp else pd.DataFrame())
    spd.to_csv(os.path.join(out, "geminating_stems_spoken.csv"), index=False)

    # ── report ─────────────────────────────────────────────────────────────
    print(f"attested geminate forms found: {len(hits)} distinct roots")
    print(f"of which the bare noun is attested and four letters: "
          f"{int(st.confirmed.sum())}")
    print("\nby shape of the bare form:")
    print(st.groupby("bare_shape").agg(
        n_roots=("root", "size"),
        gem_tokens=("geminate_freq_total", "sum")
        ).sort_values("n_roots", ascending=False).to_string())
    print("\nCFCR stems, by the geminating consonant:")
    c = st[st.bare_shape == "CFCR"]
    print(c.groupby("geminate_consonant").agg(
        n=("root", "size"), gem_tokens=("geminate_freq_total", "sum"),
        bare_tokens=("bare_freq_mono", "sum")
        ).sort_values("n", ascending=False).to_string())
    print("\nfinal reduced vowel, stem-final vs suffix, among CFCR/CRCR:")
    print(st[st.bare_shape.isin(["CFCR", "CRCR"])]
          .groupby(["bare_shape", "final_vowel"]).size().to_string())
    print("\nCONFIRMED members, top 25 by geminate frequency:")
    ok = st[st.confirmed == 1]
    print(ok.head(25)[["bare_attested", "bare_shape", "geminate_forms",
                       "bare_freq_mono", "plural_with_vowel",
                       "plural_without_vowel"]].to_string(index=False,
                                                          max_colwidth=46))
    print("\nREJECTED by the plural test though otherwise CFCR (top 12) -- "
          "these are possessives on CVC stems or participles:")
    bad = st[(st.bare_shape.isin(["CFCR", "CRCR"])) &
             (st.final_vowel == "suffix")]
    print(bad.head(12)[["bare_attested", "root_free_freq",
                        "plural_with_vowel", "plural_without_vowel",
                        "geminate_forms"]].to_string(index=False,
                                                     max_colwidth=40))
    print("\nsuffixes that reveal the geminate (top 12):")
    print(sl.head(12).to_string(index=False))
    if len(spd):
        print(f"\nspoken tokens available: "
              f"{int(spd.spoken_bare_tokens.sum())} bare, "
              f"{int(spd.spoken_geminate_tokens.sum())} geminate, over "
              f"{len(spd)} stems")
        print(spd.head(15).to_string(index=False))


if __name__ == "__main__":
    main()
