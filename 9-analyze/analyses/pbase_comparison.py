#!/usr/bin/env python3
"""Compare the Chuvash corpus against PBase (Mielke; data of 2 October 2022).

WHAT PBASE IS, AND WHAT IT IS NOT
---------------------------------
PBase is a database of *segmental* phonological patterns: 21,791 patterns over
629 languages, each an alternation (type Target/Trigger) or a distributional
restriction (type Distribution).  Three facts bound what it can do for a paper
about stress:

  1. It records no stress patterns.  Zero of the 21,791 patterns name stress or
     accent in any of the four prosody fields (I_prosody, O_prosody, L_prosody,
     R_prosody).  PBase therefore cannot adjudicate a stress rule, and no result
     in this script should be read as evidence for or against one.
  2. Chuvash is absent.  The six Turkic languages in PBase are South
     Azerbaijani, Kirghiz, Turkish, Turkmen, Tuvan and Khakas.  Chuvash -- the
     one Turkic language that split first and the only one with a reduced-vowel
     series -- has no entry.
  3. Its patterns are claims from grammars, not measurements.  A PBase pattern
     is what a describer wrote; the Chuvash figures here are what a corpus does.
     A mismatch can mean Chuvash differs, or that the two are counting
     different things.  Every row below therefore carries the corpus number and
     the PBase claim side by side rather than a pass/fail verdict.

WHAT THIS SCRIPT DOES
---------------------
  A. Ranks all 629 PBase languages by vowel-inventory similarity to Chuvash,
     to find the closest comparanda regardless of genealogy.
  B. Extracts every PBase pattern from the Turkic six and from the closest
     inventory match, restates the distributionally testable ones as a
     statement about Chuvash, and measures it on the corpus.
  C. Tests the one PBase pattern that describes the Chuvash configuration most
     directly -- Mari's /e, ø/ -> [ə] word-finally in polysyllables, blocked
     when the preceding vowel is back.

Inputs   PBase tsv/csv files (paths given on the command line)
         7-extract/reextract/phones_chuvash_voice.csv   (1,424,952 phones)
         9-analyze/output/positional_restrictions.csv
         9-analyze/output/minimal_word_diagnosis.csv
Outputs  9-analyze/output/pbase_inventory_neighbours.csv
         9-analyze/output/pbase_turkic_patterns.csv
         9-analyze/output/pbase_chuvash_tests.csv
         9-analyze/output/pbase_scope.json
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re

import pandas as pd

# ── the Chuvash inventory of this study ────────────────────────────────────
# Config IPA is the notation of 9-analyze/config/phonology_params.R.  PBase
# uses standard IPA, in which the two reduced vowels and the high central vowel
# of Chuvash are written differently; map before comparing.
CHV_V = ["a", "e", "i", "u", "y", "ø", "ɵ", "ʉ"]
# How ⟨ӗ⟩ maps onto standard IPA is genuinely unsettled: this config writes it
# /ø/, the MFA dictionary writes it ɛ, and descriptions that group it with ⟨ӑ⟩
# as a reduced vowel write both as schwas.  The choice changes which PBase
# language comes out closest, so compute the similarity under both readings and
# report both rather than pick one.
#   literal — take the config's symbols at face value: ⟨ӗ⟩ = ø, ⟨ӑ⟩ = ə
#   strict  — treat both reduced vowels as schwas: ⟨ӗ⟩ = ⟨ӑ⟩ = ə
CHV_V_LITERAL = {"a", "e", "i", "u", "y", "ø", "ə", "ɯ"}
CHV_V_STRICT = {"a", "e", "i", "u", "y", "ə", "ɯ"}
BACK = {"a", "ɵ", "u", "ʉ"}
FRONT = {"e", "ø", "y", "i"}
V8 = BACK | FRONT
SILENCE = {"sil", "sp", "spn", ""}
VOWEL_CHARS = set("iɪyʏɨʉɯueøɘɵɤoəɛœɜɞʌɔæɐaɶɑɒ")


def read_table(path: str) -> pd.DataFrame:
    """PBase ships a mix of tab- and comma-separated files, some quoted."""
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


# ── A. inventory neighbours ────────────────────────────────────────────────
def inventory_neighbours(lang: pd.DataFrame) -> pd.DataFrame:
    lang = lang.copy()
    lang["inv"] = lang["core inventory"].map(seg_set)
    lang["vinv"] = lang.inv.map(vowels_of)
    lang["n_segments"] = lang.inv.map(len)
    lang["n_vowels"] = lang.vinv.map(len)
    lang["vowels"] = lang.vinv.map(lambda s: " ".join(sorted(s)))
    for tag, ref in (("literal", CHV_V_LITERAL), ("strict", CHV_V_STRICT)):
        lang[f"jaccard_{tag}"] = lang.vinv.map(
            lambda s, r=ref: round(len(s & r) / max(len(s | r), 1), 4))
        lang[f"n_shared_{tag}"] = lang.vinv.map(lambda s, r=ref: len(s & r))
        lang[f"shared_{tag}"] = lang.vinv.map(
            lambda s, r=ref: " ".join(sorted(s & r)))
    lang["jaccard_mean"] = ((lang.jaccard_literal + lang.jaccard_strict) / 2
                            ).round(4)
    lang["has_schwa"] = lang.vinv.map(lambda s: int("ə" in s))
    lang["is_turkic"] = lang.family.astype(str).str.contains(
        "Turkic", na=False).astype(int)
    keep = ["language", "langcode", "family", "location", "is_turkic",
            "n_segments", "n_vowels", "vowels", "jaccard_mean",
            "jaccard_literal", "n_shared_literal", "shared_literal",
            "jaccard_strict", "n_shared_strict", "shared_strict",
            "has_schwa", "reference"]
    out = lang[[c for c in keep if c in lang.columns]].copy()
    out["rank_literal"] = out.jaccard_literal.rank(ascending=False,
                                                   method="min").astype(int)
    out["rank_strict"] = out.jaccard_strict.rank(ascending=False,
                                                 method="min").astype(int)
    return (out.sort_values(["jaccard_mean", "n_shared_literal"],
                            ascending=False).reset_index(drop=True))


# ── B. the Chuvash corpus measurements ─────────────────────────────────────
def corpus_facts(repo: str) -> dict:
    ph = pd.read_csv(os.path.join(
        repo, "7-extract/reextract/phones_chuvash_voice.csv"))
    out = {"n_phones": int(len(ph))}

    vow = ph[(ph.is_vowel == 1) & (ph.phone.isin(V8))]
    seq = (vow.sort_values(["file_name", "widx", "pidx"])
              .groupby(["file_name", "widx", "word_label"], sort=False)
              .phone.apply(list).reset_index())
    out["n_word_tokens"] = int(len(seq))
    out["n_word_types"] = int(seq.word_label.nunique())

    # B1 vowels after the initial syllable (Tuvan, Azari state this for Vs).
    #
    # NOTE: do NOT use pos_in_word here. That column is the *phone's* position
    # in the word, so a vowel counts as "initial" only when it is the word's
    # first segment -- true of the ~15% of Chuvash words that begin with a
    # vowel and of nothing else. The syllable a vowel sits in is given by its
    # index among the word's vowels, since Chuvash has one vowel per syllable.
    vidx = (vow.sort_values(["file_name", "widx", "pidx"])
               .assign(vi=lambda d: d.groupby(["file_name", "widx"]).cumcount(),
                       nv=lambda d: d.groupby(["file_name", "widx"])
                                     .phone.transform("size")))
    poly_v = vidx[vidx.nv >= 2]
    out["pct_tokens_after_first_syllable"] = (
        poly_v.assign(ni=poly_v.vi > 0)
              .groupby("phone").ni.mean().mul(100).round(1).to_dict())
    out["pct_tokens_in_first_syllable"] = (
        poly_v.assign(fi=poly_v.vi == 0)
              .groupby("phone").fi.mean().mul(100).round(1).to_dict())
    out["n_after_first_syllable"] = (
        poly_v[poly_v.vi > 0].phone.value_counts().to_dict())
    out["n_polysyllabic_vowels"] = int(len(poly_v))

    # B2 vowels of monosyllables (Azari: "occur finally in monosyllabic words")
    mono = seq[seq.phone.map(len) == 1].assign(v=lambda d: d.phone.str[0])
    out["monosyllable_vowel_types"] = (
        mono.drop_duplicates("word_label").v.value_counts().to_dict())
    out["monosyllable_vowel_tokens"] = mono.v.value_counts().to_dict()

    # B3 backness harmony within the word (/i/ optionally neutral)
    def uniform(vs, neutral=()):
        core = [v for v in vs if v not in neutral]
        if len(core) < 2:
            return None
        return all(v in BACK for v in core) or all(v in FRONT for v in core)
    for tag, neu in (("all", ()), ("i_neutral", ("i",))):
        tok = seq.phone.map(lambda v, n=neu: uniform(v, n)).dropna()
        typ = (seq.drop_duplicates("word_label").phone
                  .map(lambda v, n=neu: uniform(v, n)).dropna())
        out[f"harmony_{tag}"] = {
            "pct_uniform_tokens": round(tok.mean() * 100, 1),
            "pct_uniform_types": round(typ.mean() * 100, 1),
            "n_tokens": int(len(tok)), "n_types": int(len(typ))}

    # B4/B5 consonants at the word edges
    con = ph[(ph.is_vowel == 0) & (~ph.phone.isin(SILENCE))]
    for tag, sel in (("initial", ("initial", "only")),
                     ("final", ("final", "only"))):
        vc = con[con.pos_in_word.isin(sel)].phone.value_counts()
        out[f"c_word_{tag}"] = vc.to_dict()
        out[f"c_word_{tag}_common"] = sorted(vc[vc >= 50].index)
        out[f"c_word_{tag}_absent"] = sorted(
            set(con.phone.unique()) - set(vc.index))

    # C  Mari's /e, ø/ -> [ə] / __# in polysyllables, blocked after a back vowel
    poly = seq[seq.phone.map(len) >= 2].copy()
    poly["last"] = poly.phone.str[-1]
    poly["prev_class"] = poly.phone.map(
        lambda L: "back" if L[-2] in BACK else "front")
    ct = pd.crosstab(poly.prev_class, poly.last)
    out["final_vowel_by_prev_class"] = ct.to_dict()
    red = ct.reindex(columns=["ø", "ɵ"]).fillna(0)
    out["final_reduced_by_prev_class_pct"] = (
        red.div(red.sum(axis=1), axis=0).mul(100).round(1).to_dict())
    out["pct_polysyll_ending_reduced"] = round(
        poly.last.isin(["ø", "ɵ"]).mean() * 100, 1)
    # positional profile of each vowel, for the "ə is final-biased" claim
    out["pct_of_tokens_word_final"] = (
        vow.assign(f=(vow.pos_in_word == "final"))
           .groupby("phone").f.mean().mul(100).round(1).to_dict())
    return out


# ── the test table ─────────────────────────────────────────────────────────
def build_tests(facts: dict, pat: pd.DataFrame, comparanda: set) -> pd.DataFrame:
    rows = []

    def add(pbase_lang, pbase_claim, chuvash_test, chuvash_result, verdict,
            note, testable="yes"):
        rows.append(dict(pbase_language=pbase_lang, pbase_claim=pbase_claim,
                         chuvash_test=chuvash_test,
                         chuvash_result=chuvash_result, comparison=verdict,
                         testable=testable, note=note))

    ni = facts["pct_tokens_in_first_syllable"]
    add("Tuvan", "vowels that can occur after the initial syllable: "
        "i y ɨ u e a (and long counterparts); o and ø cannot",
        "% of each vowel's tokens in polysyllables that sit in the first "
        "syllable",
        "; ".join(f"{v} {ni.get(v, 0)}%" for v in CHV_V),
        "differs in which vowels are restricted, not in whether any are",
        "Tuvan restricts the mid round vowels to the initial syllable; Chuvash "
        "restricts the high vowels /ʉ u y/. Both languages confine a subset of "
        "the inventory to the first syllable, so a non-initial vowel "
        "restriction is an areal Turkic property, but in Chuvash it tracks "
        "height, not rounding, and no PBase Turkic language restricts by "
        "height.")

    mt = facts["monosyllable_vowel_types"]
    add("South Azerbaijani", "vowels that occur finally in monosyllabic words: "
        "i ɨ u ø o æ a (y excluded)",
        "distinct word types that are a monosyllable with this vowel",
        "; ".join(f"{v} {mt.get(v, 0)}" for v in CHV_V),
        "Chuvash allows its reduced vowels here, Azari does not have the class",
        "The PBase statement is about which vowels may stand in a "
        "monosyllable. In Chuvash the two reduced vowels do occur in "
        "monosyllables in the spoken corpus but not in the wordlist, which is "
        "the minimal-word asymmetry this paper argues from.")

    h = facts["harmony_i_neutral"]
    ha = facts["harmony_all"]
    add("Tuvan, Turkish", "back vowels occur only in words with back vowels; "
        "front vowels only in words with front vowels",
        "% of polysyllabic word tokens whose vowels are all from one backness "
        "class",
        f"{ha['pct_uniform_tokens']}% of tokens, {ha['pct_uniform_types']}% of "
        f"types; treating /i/ as neutral {h['pct_uniform_tokens']}% and "
        f"{h['pct_uniform_types']}%",
        "Chuvash harmony is substantially leakier than the PBase statement",
        "PBase records Tuvan and Turkish harmony as exceptionless. A quarter "
        "of Chuvash tokens are disharmonic on the surface. Part of this is "
        "loanwords and part is alignment error, so the figure is an upper "
        "bound on genuine disharmony, but it is far from the categorical "
        "statement PBase carries for the other Turkic languages.")

    add("Khakas", "/d/ and /dʒ/ do not occur word-finally",
        "consonants absent from word-final position in the spoken corpus",
        ("none absent" if not facts["c_word_final_absent"]
         else " ".join(facts["c_word_final_absent"])) +
        f"; word-final with n>=50: {' '.join(facts['c_word_final_common'])}",
        "not reproduced: Chuvash restricts no consonant out of final position",
        "Chuvash has no voicing contrast in the native lexicon, so the Khakas "
        "statement has no Chuvash analogue; the corpus's word-final /d/ tokens "
        "are the aligner's realisation of intervocalic /t/ in Russian loans.")

    add("Turkish", "consonants occurring word-initially in native words "
        "(dʒ in only two words)",
        "consonants attested word-initially, and those with fewer than 50 "
        "tokens",
        f"n>=50: {' '.join(facts['c_word_initial_common'])}; rare: " +
        " ".join(k for k, n in facts["c_word_initial"].items() if n < 50),
        "same shape of statement, different rare set",
        "The Turkish claim is that the initial inventory is nearly the whole "
        "consonant inventory with a couple of lexically restricted "
        "exceptions. Chuvash behaves the same way, with /ɡ/ and /ʒ/ as the "
        "rare initials -- both confined to Russian loans.")

    pc = facts["final_reduced_by_prev_class_pct"]
    add("Eastern Mari (Cheremis)",
        "/e, ø/ -> [ə] word-finally in polysyllabic words, except when the "
        "preceding vowel is back",
        "choice of word-final reduced vowel by the backness of the preceding "
        "vowel, in polysyllabic word tokens",
        f"after a front vowel: {pc.get('ø', {}).get('front', 0)}% /ø/, "
        f"{pc.get('ɵ', {}).get('front', 0)}% /ɵ/; after a back vowel: "
        f"{pc.get('ø', {}).get('back', 0)}% /ø/, "
        f"{pc.get('ɵ', {}).get('back', 0)}% /ɵ/",
        "the same conditioning, stated in PBase as a rule and here as a "
        "distribution",
        "This is the closest PBase analogue to the Chuvash configuration, and "
        "it is in the language immediately north of Chuvashia rather than in "
        "any Turkic language. Mari's describer wrote it as a reduction rule "
        "producing [ə] word-finally, blocked after a back vowel; Chuvash has "
        "two reduced vowels in complementary distribution by the same "
        "conditioning factor. Mari is a Uralic language in contact with "
        "Chuvash, so this is a candidate areal feature rather than an "
        "inherited one.")

    add("Eastern Mari (Cheremis)", "/ə/ -> 0 (two separate patterns)",
        "whether Chuvash reduced vowels delete; not answerable from this "
        "corpus", "not tested", "untested",
        "Mari is recorded as deleting its schwa outright. That is the "
        "zero-mora behaviour this paper's fleeting-vowel hypothesis predicts "
        "for a subset of Chuvash reduced vowels. Testing it needs the "
        "designed word list, not this corpus: see minimal_word_diagnosis.md.",
        testable="needs elicitation")

    add("Eastern Mari (Cheremis)", "/e, ə/ -> 0 / __a, a__",
        "whether Chuvash reduced vowels are shorter or absent next to /a/",
        "not tested", "untested",
        "A sonority-driven reduction: the reduced vowel is lost beside the "
        "most sonorous vowel. If Chuvash showed this it would be independent "
        "support for the sonority-sensitive analysis, because it would make "
        "/a/ a trigger as well as a target. Testable on this corpus and worth "
        "adding.", testable="yes, not yet run")

    add("Eastern Mari (Cheremis)", "/i y u o/ may be prolonged word-finally",
        "word-final lengthening of full vowels",
        "measured as a position effect rather than a segmental rule: "
        "word-final syllable +12.3%, and +51.6% in interaction with "
        "utterance-final position (final_lengthening_models.csv)",
        "Chuvash lengthens all vowels finally, not a subset",
        "PBase records this as a segmental alternation restricted to four "
        "vowels. In Chuvash the effect is positional and applies across the "
        "inventory, which is why this paper treats final lengthening as a "
        "confound to be controlled rather than as a phonological rule.")

    df = pd.DataFrame(rows)
    df.insert(0, "test_id", [f"P{i + 1}" for i in range(len(df))])
    return df


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=".")
    ap.add_argument("--pb-languages", required=True)
    ap.add_argument("--pb-patterns", required=True)
    args = ap.parse_args()
    out = os.path.join(args.repo, "9-analyze/output")

    lang = read_table(args.pb_languages)
    pat = read_table(args.pb_patterns)

    pros = [c for c in ("I_prosody", "O_prosody", "L_prosody", "R_prosody")
            if c in pat.columns]
    n_stress = int(pat[pros].apply(
        lambda s: s.astype(str).str.contains("stress|accent", case=False,
                                             na=False)).any(axis=1).sum())

    nb = inventory_neighbours(lang)
    nb.to_csv(os.path.join(out, "pbase_inventory_neighbours.csv"), index=False)

    turkic = set(lang.loc[lang.family.astype(str)
                 .str.contains("Turkic", na=False), "language"])
    closest = set(nb.sort_values("jaccard_literal", ascending=False)
                  .language.head(1)) | set(
        nb.sort_values("jaccard_strict", ascending=False).language.head(1))
    comparanda = turkic | closest
    cols = [c for c in ("language", "iso", "type", "I", "O", "description_OLD",
                        "L3", "L2", "L1", "L0", "R0", "R1", "R2", "R3",
                        "domain", "pos_neg", "morphological", "optionality",
                        "sources") if c in pat.columns]
    tp = pat[pat.language.isin(comparanda)][cols].copy()
    tp["is_closest_inventory"] = tp.language.isin(closest).astype(int)
    tp.to_csv(os.path.join(out, "pbase_turkic_patterns.csv"), index=False)

    facts = corpus_facts(args.repo)
    tests = build_tests(facts, pat, comparanda)
    tests.to_csv(os.path.join(out, "pbase_chuvash_tests.csv"), index=False)

    scope = {
        "pbase_version": "data as of 2 October 2022; CC BY-NC-SA 4.0",
        "n_patterns": int(len(pat)),
        "n_languages": int(len(lang)),
        "pattern_types": pat["type"].value_counts().to_dict(),
        "n_patterns_conditioned_on_stress": n_stress,
        "chuvash_in_pbase": bool((lang.language.astype(str)
                                  .str.contains("Chuvash", case=False)).any()),
        "turkic_languages": sorted(turkic),
        "n_patterns_turkic": int(pat.language.isin(turkic).sum()),
        "closest_inventory_literal": nb.sort_values(
            "jaccard_literal", ascending=False).iloc[0][
            ["language", "family", "jaccard_literal", "vowels"]].to_dict(),
        "closest_inventory_strict": nb.sort_values(
            "jaccard_strict", ascending=False).iloc[0][
            ["language", "family", "jaccard_strict", "vowels"]].to_dict(),
        "best_turkic_rank": nb.loc[nb.is_turkic == 1].sort_values(
            "jaccard_mean", ascending=False).iloc[0][
            ["language", "jaccard_literal", "rank_literal", "rank_strict"]
            ].to_dict(),
        "mari_row": (nb.loc[nb.language.str.contains("Cheremis", na=False)]
                     .iloc[0][["language", "jaccard_literal", "rank_literal",
                               "jaccard_strict", "rank_strict"]].to_dict()
                     if nb.language.str.contains("Cheremis", na=False).any()
                     else None),
        "corpus": facts,
    }
    with open(os.path.join(out, "pbase_scope.json"), "w",
              encoding="utf-8") as fh:
        json.dump(scope, fh, ensure_ascii=False, indent=2, default=str)

    print(f"patterns {len(pat)}  languages {len(lang)}  "
          f"stress-conditioned {n_stress}  chuvash_present "
          f"{scope['chuvash_in_pbase']}")
    print("closest (literal):", scope["closest_inventory_literal"])
    print("closest (strict): ", scope["closest_inventory_strict"])
    print("Mari:", scope["mari_row"])
    print("best Turkic:", scope["best_turkic_rank"])
    print("turkic patterns:", scope["n_patterns_turkic"], "rows ->",
          "pbase_turkic_patterns.csv")
    print(tests[["test_id", "pbase_language", "comparison"]].to_string(
        index=False))


if __name__ == "__main__":
    main()
