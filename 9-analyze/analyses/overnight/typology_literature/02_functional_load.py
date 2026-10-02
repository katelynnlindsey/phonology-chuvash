"""Step 2. Entropy-based functional load (Hockett 1955; Surendran & Niyogi 2006 formulation):
FL(x,y) = [H(L) - H(L_{x=y})] / H(L), L = distribution over word types weighted by token frequency.
Computed on IPA segment strings (tokenised like config tokenize_ipa) so ⟨ы⟩=ʉ, ⟨ӑ⟩=ɵ, ⟨ӗ⟩=ø, ⟨ӳ⟩=y regardless of
Latin/Cyrillic homoglyphs. Sets: mono in_wordlist types w/ token freq (primary); mono freq>=5 types (sensitivity,
includes inflected forms); Zheltov types (unweighted, H over uniform types).
Minimal pairs: Zheltov types (deduplicated on IPA after homoglyph folding), and mono in_wordlist.
Bootstrap: FL CI by multinomial resampling of tokens (B=200) for the primary set."""
import sys, os, itertools, unicodedata, numpy as np, pandas as pd
sys.path.insert(0, os.path.dirname(__file__))
from common import *
rng = np.random.default_rng(7)
HOMO = {"ă": "ӑ", "ĕ": "ӗ", "ç": "ҫ", "Ă": "Ӑ", "Ĕ": "Ӗ", "Ç": "Ҫ"}
zt = pd.read_csv(os.path.join(OUT, "types_zheltov.csv")); mt = pd.read_csv(os.path.join(OUT, "types_mono.csv"))
# homoglyph census
def census(s):
    c = pd.Series(list("".join(s.dropna()))); c = c[c.map(lambda ch: ch.isalpha() and not ("\u0400" <= ch <= "\u04FF"))]
    return c.value_counts()
cz, cm = census(zt.word_label), census(mt[mt.in_wordlist == True].word_label)
pd.concat({"zheltov": cz, "mono_in_wordlist": cm}, axis=1).fillna(0).astype(int).to_csv(os.path.join(OUT, "fl_homoglyph_census.csv"))
zt["word_norm"] = zt.word_label.map(lambda w: "".join(HOMO.get(c, c) for c in str(w)))
print("zheltov types with homoglyph:", (zt.word_norm != zt.word_label).mean().round(4), "dup after fold:", zt.word_norm.duplicated().sum())
def prep(d):
    d = d[d.word_label_IPA.notna()].copy()
    d["segs"] = d.word_label_IPA.map(lambda s: tuple(tokenize(s)))
    d = d[~d.segs.map(lambda s: "o" in s)]                 # loan vowel types out
    return d
zt, mt = prep(zt), prep(mt)
md = mt[mt.in_wordlist == True]; m5 = mt[mt.corpus_freq >= 5]
CONTRASTS = [("a","ɵ"),("e","ø"),("u","y"),("ʉ","u"),("ʉ","i"),("ɵ","ø"),("u","ʉ"),("a","e"),("ʉ","ɵ"),("ʉ","ø"),
             ("i","e"),("i","y"),("u","ɵ"),("y","ø"),("a","u"),("i","ø"),("e","y")]
REF_C = [("s","ɕ"),("p","t"),("t","k"),("l","r"),("ʃ","s"),("tʲ","t")]
def H(freqs):
    p = freqs / freqs.sum(); return -(p * np.log2(p)).sum()
def fl_table(segs, w, pairs):
    key0 = pd.Series(w, index=["\x01".join(s) for s in segs]).groupby(level=0).sum()
    H0 = H(key0.values); out = {}
    for x, y in pairs:
        merged = ["\x01".join(y if c == x else c for c in s) for s in segs]
        k = pd.Series(w, index=merged).groupby(level=0).sum()
        out[(x, y)] = (H0 - H(k.values)) / H0
    return out, H0
rows = []
for name, d, weighted in [("mono_dict_tokens", md, True), ("mono_freq5_tokens_SENS", m5, True), ("zheltov_types", zt.drop_duplicates("word_label_IPA"), False)]:
    w = d.corpus_freq.fillna(0).values.astype(float) if weighted else np.ones(len(d))
    keep = w > 0; segs = list(d.segs[keep]); w = w[keep]
    fl, H0 = fl_table(segs, w, CONTRASTS + REF_C)
    boots = {}
    if name == "mono_dict_tokens":
        N = int(w.sum()); p = w / w.sum()
        for b in range(200):
            wb = rng.multinomial(N, p).astype(float); kk = wb > 0
            fb, _ = fl_table([s for s, k in zip(segs, kk) if k], wb[kk], CONTRASTS + REF_C)
            for c, v in fb.items(): boots.setdefault(c, []).append(v)
    for (x, y), v in fl.items():
        lo, hi = (np.percentile(boots[(x, y)], [2.5, 97.5]) if boots else (np.nan, np.nan))
        rows.append(dict(set=name, x=x, y=y, kind="vowel" if (x, y) in CONTRASTS else "consonant_ref", FL=v, FL_lo=lo, FL_hi=hi,
                         H_bits=H0, n_types=len(segs), n_tokens=w.sum()))
    print(name, "H0", round(H0, 3), flush=True)
FLT = pd.DataFrame(rows); FLT.to_csv(os.path.join(OUT, "functional_load.csv"), index=False)
# minimal pairs
def minimal_pairs(d, wcol=None):
    recs = {}
    for segs, f in zip(d.segs, d[wcol] if wcol else itertools.repeat(1)):
        for k, s in enumerate(segs):
            if s in VSET:
                key = segs[:k] + ("_",) + segs[k + 1:]
                recs.setdefault(key, {}).setdefault(s, 0); recs[key][s] += f
    cnt = {}
    for key, vs in recs.items():
        for a, b in itertools.combinations(sorted(vs), 2):
            c = cnt.setdefault((a, b), [0, 0.0]); c[0] += 1; c[1] += min(vs[a], vs[b])
    return cnt
mp_rows = []
for name, d, wcol in [("zheltov_types", zt.drop_duplicates("word_label_IPA"), None), ("mono_dict", md, "corpus_freq"), ("mono_freq5_SENS", m5, "corpus_freq")]:
    cnt = minimal_pairs(d, wcol)
    for (a, b), (n, wmin) in cnt.items():
        mp_rows.append(dict(set=name, x=a, y=b, n_minimal_pairs=n, sum_min_token_freq=wmin if wcol else np.nan))
MP = pd.DataFrame(mp_rows); MP.to_csv(os.path.join(OUT, "minimal_pairs_vowels.csv"), index=False)
# vowel type frequencies for normalisation
vf = []
for name, d in [("zheltov_types", zt), ("mono_dict", md)]:
    c = pd.Series([v for s in d.segs for v in s if v in VSET]).value_counts(); vf.append(c.rename(name))
pd.concat(vf, axis=1).to_csv(os.path.join(OUT, "fl_vowel_counts.csv"))
p = FLT[FLT.set == "mono_dict_tokens"].sort_values("FL", ascending=False)
print(p[["x", "y", "kind", "FL", "FL_lo", "FL_hi"]].round(5).to_string())
print(FLT.pivot_table(index=["x", "y"], columns="set", values="FL").round(5).to_string())
mpp = MP.pivot_table(index=["x", "y"], columns="set", values="n_minimal_pairs").fillna(0).astype(int)
print(mpp.sort_values("zheltov_types", ascending=False).to_string())
