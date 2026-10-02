#!/usr/bin/env python3
"""Free exploration of PBase beyond pbase_comparison.py: five questions about
Chuvash vs Eastern Mari and the Turkic six, using two PBase files the original
script staged but never used (ipa2allfeatures.csv, grouping-diagnosis.csv) and
a consonant-inventory comparison it never ran.

Q1  Feature-space (not symbol-identity) vowel distance: is "no Turkic language
    is close" robust to PBase's length-as-separate-phoneme coding and to
    treating near-identical vowel qualities (ɨ vs ɯ) as non-matches?
Q2  Consonant-inventory nearest neighbours (never computed in the original
    script, which did vowels only). Does the genealogical signal show up in
    consonants even though Q1/the original script locate the vowel signal in
    Mari?
Q3  All 7 Uralic languages in PBase, ranked for vowel similarity to Chuvash:
    does closeness track geography (Volga-Kama) or Uralic membership generally?
Q4  Gemination/degemination (Brohan & Mielke 2018 grouping labels): does any
    Turkic or Uralic-neighbour language in PBase show this, given Chuvash's
    own corpus shows it as a heavy synchronic process?
Q5  Global search, across all 629 languages (not just the 6 Turkic + Mari
    comparanda), for a rule that both outputs schwa and applies word-finally
    -- the closest possible structural match to Chuvash's own configuration.

Inputs   9-analyze/data/pbase/{pb_languages,pb_patterns,ipa2allfeatures,
         grouping-diagnosis}.csv
         9-analyze/config/phonology_params.R (consonant inventory, read by eye)
Outputs  9-analyze/output/pbase_feature_vowel_distance.csv
         9-analyze/output/pbase_consonant_neighbours.csv
         9-analyze/output/pbase_uralic_areal_gradient.csv
         9-analyze/output/pbase_gemination_typology.csv
         9-analyze/output/pbase_global_schwa_reduction_search.csv
         9-analyze/output/fig_vowel_vs_consonant_rank.png
         9-analyze/output/pbase_free_exploration_findings.md
"""
from __future__ import annotations

import csv
import os
import unicodedata

import numpy as np
import pandas as pd

REPO = os.environ.get("CHV_REPO", ".")
PB = os.path.join(REPO, "9-analyze/data/pbase")
OUT = os.path.join(REPO, "9-analyze/output")

VOWEL_CHARS = set("iɪyʏɨʉɯueøɘɵɤoəɛœɜɞʌɔæɐaɶɑɒ")

# Chuvash inventories, as used throughout pbase_comparison.py (literal reading
# of ⟨ӗ⟩=ø; strict reading folds both reduced vowels to schwa) and
# config/phonology_params.R CONSONANT_TO_IPA (native lexicon, no inherited
# voicing contrast).
CHV_V_LITERAL = ["a", "e", "i", "u", "y", "ø", "ə", "ɯ"]
CHV_V_STRICT = ["a", "e", "i", "u", "y", "ə", "ɯ"]
CHV_C_NATIVE = {"p", "t", "tɕ", "k", "s", "ʃ", "ɕ", "x", "m", "n", "ʋ", "l", "j", "r"}


def read_table(path: str) -> pd.DataFrame:
    with open(path, encoding="utf-8") as fh:
        head = fh.readline()
    sep = "\t" if head.count("\t") > head.count(",") else ","
    kw = {"quoting": csv.QUOTE_NONE} if sep == "\t" and '"' not in head else {}
    df = pd.read_csv(path, sep=sep, keep_default_na=False, na_values=[""],
                      engine="python", on_bad_lines="skip", **kw)
    df.columns = [str(c).strip().strip('"') for c in df.columns]
    return df.loc[:, [c for c in df.columns if not c.startswith("Unnamed")]]


def seg_set(s) -> set:
    if not isinstance(s, str):
        return set()
    return {x.strip() for x in s.replace(";", ",").split(",") if x.strip()}


def vowels_of(inv: set) -> set:
    return {s for s in inv if s and s[0] in VOWEL_CHARS and len(s) <= 2}


def consonants_of(inv: set) -> set:
    return {s for s in inv if s and s[0] not in VOWEL_CHARS and s != "ʔ" and len(s) <= 4}


def strip_diacritics(s: str) -> str:
    d = unicodedata.normalize("NFD", s)
    out = "".join(c for c in d if unicodedata.category(c) != "Mn")
    return unicodedata.normalize("NFC", out.replace("ː", "").replace("ˑ", ""))


def jacc(a, b) -> float:
    a, b = set(a), set(b)
    return len(a & b) / max(len(a | b), 1)


def to_num(v):
    return {"+": 1.0, "-": 0.0, "x": 0.5}.get(v, np.nan)


def feat_dist(v1: np.ndarray, v2: np.ndarray) -> float:
    both = ~(np.isnan(v1) | np.isnan(v2))
    if not both.any():
        return np.nan
    return float(np.sqrt(np.sum((v1[both] - v2[both]) ** 2)) / np.sqrt(both.sum()))


def _feature_table(feat: pd.DataFrame, cols: list[str]) -> pd.DataFrame:
    feat2 = feat.set_index("ipa")
    feat2 = feat2[~feat2.index.duplicated(keep="first")]
    return feat2[cols].map(to_num)


def _rank_by_feature_distance(lang: pd.DataFrame, fvec: pd.DataFrame,
                               chv_syms: list[str]) -> pd.DataFrame:
    def vec(sym):
        if sym in fvec.index:
            return fvec.loc[sym].values.astype(float)
        base = strip_diacritics(sym)
        return fvec.loc[base].values.astype(float) if base in fvec.index else None

    chv_vecs = [v for v in (vec(s) for s in chv_syms) if v is not None]
    rows = []
    for _, r in lang.iterrows():
        vvecs = [v for v in (vec(s) for s in r.vinv) if v is not None]
        if not vvecs or not chv_vecs:
            continue
        d1 = [min(feat_dist(cv, lv) for lv in vvecs) for cv in chv_vecs]
        d2 = [min(feat_dist(lv, cv) for cv in chv_vecs) for lv in vvecs]
        rows.append(dict(language=r.language, family=r.family,
                          n_vowels_matched=len(vvecs),
                          feature_distance=round((np.mean(d1) + np.mean(d2)) / 2, 4)))
    out = pd.DataFrame(rows).sort_values("feature_distance").reset_index(drop=True)
    out["rank"] = out.feature_distance.rank(method="min").astype(int)
    return out


def q1_feature_distance(lang: pd.DataFrame, feat: pd.DataFrame) -> pd.DataFrame:
    """Nearest-neighbour vowel-quality distance, robust to length coding and
    to near-identical qualities being written with different IPA symbols.
    Reports the primary ranking (SPE features, literal ⟨ӗ⟩=ø reading) plus two
    robustness checks: an independent feature system (Halle & Clements) and
    the strict (ə=ə) reading of the two reduced vowels."""
    spe_cols = ["SPE.high", "SPE.low", "SPE.back", "SPE.round", "SPE.tense"]
    hc_cols = ["HC.high", "HC.low", "HC.back", "HC.round", "HC.tense"]
    fvec_spe = _feature_table(feat, spe_cols)
    fvec_hc = _feature_table(feat, hc_cols)

    primary = _rank_by_feature_distance(lang, fvec_spe, CHV_V_LITERAL)
    hc_check = _rank_by_feature_distance(lang, fvec_hc, CHV_V_LITERAL)
    strict_check = _rank_by_feature_distance(lang, fvec_spe, CHV_V_STRICT)

    out = primary.merge(
        hc_check[["language", "rank"]].rename(columns={"rank": "rank_HC_system"}),
        on="language", how="left")
    out = out.merge(
        strict_check[["language", "feature_distance", "rank"]].rename(
            columns={"feature_distance": "feature_distance_strict_reading",
                     "rank": "rank_strict_reading"}),
        on="language", how="left")
    return out


def q2_consonant_neighbours(lang: pd.DataFrame) -> pd.DataFrame:
    chv_norm = {strip_diacritics(s) for s in CHV_C_NATIVE}
    rows = []
    for _, r in lang.iterrows():
        cinv_raw = r.cinv
        cinv_norm = {strip_diacritics(s) for s in cinv_raw}
        rows.append(dict(language=r.language, family=r.family, location=r.location,
                          n_consonants=len(cinv_raw),
                          jaccard_raw=round(jacc(cinv_raw, CHV_C_NATIVE), 4),
                          jaccard_norm=round(jacc(cinv_norm, chv_norm), 4),
                          n_shared_norm=len(cinv_norm & chv_norm)))
    out = pd.DataFrame(rows)
    out["rank_raw"] = out.jaccard_raw.rank(ascending=False, method="min").astype(int)
    out["rank_norm"] = out.jaccard_norm.rank(ascending=False, method="min").astype(int)
    return out.sort_values("rank_norm").reset_index(drop=True)


def q3_uralic_gradient(lang: pd.DataFrame) -> pd.DataFrame:
    uralic = lang.loc[lang.family.astype(str).str.contains("URALIC", case=False, na=False)]
    chv_lit, chv_str = set(CHV_V_LITERAL), set(CHV_V_STRICT)
    rows = []
    for _, r in uralic.iterrows():
        rows.append(dict(language=r.language, location=r.location,
                          n_vowels=len(r.vinv), vowels=" ".join(sorted(r.vinv)),
                          jaccard_literal=round(jacc(r.vinv, chv_lit), 4),
                          jaccard_strict=round(jacc(r.vinv, chv_str), 4)))
    out = pd.DataFrame(rows).sort_values("jaccard_literal", ascending=False)
    return out.reset_index(drop=True)


def q4_gemination(grp: pd.DataFrame, lang: pd.DataFrame) -> pd.DataFrame:
    gem = grp[grp.Label.isin(["Gemination", "Degemination"])].copy()
    return gem.merge(lang[["language", "family", "location"]],
                      left_on="Language", right_on="language", how="left")


def q5_global_schwa_search(grp: pd.DataFrame, lang: pd.DataFrame) -> pd.DataFrame:
    rl = grp.groupby(["Language", "iso", "ruleid"])["Label"].apply(set).reset_index()
    desc = grp[["Language", "ruleid", "Description"]].drop_duplicates()
    oschwa = rl[rl.Label.map(lambda s: "O=ə" in s)].merge(desc, on=["Language", "ruleid"], how="left")
    oschwa["is_word_final"] = oschwa.Label.map(lambda s: "Word Final" in s)
    return oschwa.merge(lang[["language", "family"]], left_on="Language",
                         right_on="language", how="left").drop(columns=["language"])


def main() -> None:
    lang = read_table(f"{PB}/pb_languages.csv")
    pat = read_table(f"{PB}/pb_patterns.csv")  # noqa: F841 (kept for provenance/parity with pbase_comparison.py)
    feat = read_table(f"{PB}/ipa2allfeatures.csv")
    grp = read_table(f"{PB}/grouping-diagnosis.csv")

    lang["inv"] = lang["core inventory"].map(seg_set)
    lang["vinv"] = lang.inv.map(vowels_of)
    lang["cinv"] = lang.inv.map(consonants_of)

    os.makedirs(OUT, exist_ok=True)
    q1_feature_distance(lang, feat).to_csv(f"{OUT}/pbase_feature_vowel_distance.csv", index=False)
    q2_consonant_neighbours(lang).to_csv(f"{OUT}/pbase_consonant_neighbours.csv", index=False)
    q3_uralic_gradient(lang).to_csv(f"{OUT}/pbase_uralic_areal_gradient.csv", index=False)
    q4_gemination(grp, lang).to_csv(f"{OUT}/pbase_gemination_typology.csv", index=False)
    q5_global_schwa_search(grp, lang).to_csv(f"{OUT}/pbase_global_schwa_reduction_search.csv", index=False)
    print("wrote 5 tables to", OUT)


if __name__ == "__main__":
    main()
