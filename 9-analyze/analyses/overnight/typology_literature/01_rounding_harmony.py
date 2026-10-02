"""Step 1. Rounding (labial) harmony: O/E co-occurrence of rounded vowels across adjacent syllables,
within backness classes. Datasets: Zheltov types; dictionary-attested monolingual types (in_wordlist),
type- and token-weighted; sensitivity: all mono types freq>=5 (includes inflected forms; fragments possible);
native-only subsets (crude loan flag from segmental track: any of о ё ф ц щ ъ б г д ж з).
Treatments: A rounded={u,y}; B rounded={u,y,ɵ,ø} (config VOWEL_ROUND, Krueger 1961).
CIs: Poisson bootstrap over word types (B=400) for every cell; Woolf CI for type-level ORs too.
"""
import sys, os, numpy as np, pandas as pd
sys.path.insert(0, os.path.dirname(__file__))
from common import *
rng = np.random.default_rng(20261001)
LOAN = set("оёфцщъбгджз")

zt = pd.read_csv(os.path.join(OUT, "types_zheltov.csv"))
mt = pd.read_csv(os.path.join(OUT, "types_mono.csv"))
def prep(d):
    d = d[d.word_label_IPA.notna()].copy()
    d["segs"] = d.word_label_IPA.map(tokenize)
    d["has_o"] = d.segs.map(lambda s: "o" in s)          # loan vowel OW: exclude whole type
    d["loan"] = d.word_label.str.lower().map(lambda w: any(c in LOAN for c in w))
    d = d[~d.has_o]
    d["vseq"] = d.segs.map(lambda ss: [x for x in ss if x in VSET])
    return d
zt, mt = prep(zt), prep(mt)
md = mt[mt.in_wordlist == True]
m5 = mt[mt.corpus_freq >= 5]
sets = {"zheltov_types": (zt, False), "mono_dict_types": (md, False), "mono_dict_tokens": (md, True),
        "mono_freq5_types_SENS": (m5, False), "mono_freq5_tokens_SENS": (m5, True),
        "zheltov_native_types": (zt[~zt.loan], False), "mono_dict_native_tokens": (md[~md.loan], True)}

def pairs(d, first_only=False):
    rows = []
    for ti, (vs, f) in enumerate(zip(d.vseq, d.corpus_freq.fillna(0))):
        rng_k = range(min(1, len(vs) - 1)) if first_only else range(len(vs) - 1)
        for k in rng_k:
            rows.append((ti, vs[k], vs[k + 1], f))
    return pd.DataFrame(rows, columns=["ti", "v1", "v2", "w"])

def table(P, rset, w):
    r1 = P.v1.isin(rset).values; r2 = P.v2.isin(rset).values
    return r1, r2

res = []; vtab = []
for name, (d, tokw) in sets.items():
    for scope in ["all_adjacent", "syl1_to_syl2"]:
        P = pairs(d, scope == "syl1_to_syl2")
        P["b1"] = P.v1.isin(BACK); P["b2"] = P.v2.isin(BACK)
        P = P[P.b1 == P.b2]                                   # harmonic-backness pairs only
        P["cls"] = np.where(P.b1, "back", "front")
        P["h2"] = np.where(P.v2.isin(HIGH), "high", "nonhigh")
        # full vowel x vowel tables for the figure/appendix
        if scope == "syl1_to_syl2":
            wt = P.w if tokw else 1
            vt = P.assign(wt=wt).groupby(["cls", "v1", "v2"]).wt.sum().reset_index(); vt["set"] = name; vtab.append(vt)
        ntypes = d.shape[0]
        for trt, rset in [("A_round_uy", ROUND_FULL_ONLY), ("B_round_uy_reduced", ROUND_CONFIG)]:
            for cls in ["back", "front"]:
                for tgt in ["high", "nonhigh", "any"]:
                    S = P[(P.cls == cls) & ((P.h2 == tgt) | (tgt == "any"))]
                    if trt.startswith("A") and tgt == "nonhigh":
                        continue                              # no rounded non-high target under A
                    r1 = S.v1.isin(rset).values; r2 = S.v2.isin(rset).values
                    w = S.w.values.astype(float) if tokw else np.ones(len(S))
                    def stats(wv):
                        a = wv[r1 & r2].sum(); b = wv[r1 & ~r2].sum(); c = wv[~r1 & r2].sum(); dd = wv[~r1 & ~r2].sum()
                        n = a + b + c + dd
                        if min(a + b, c + dd, a + c) <= 0: return [np.nan] * 4
                        p_r1 = a / (a + b); p_u1 = c / (c + dd); oe = a / ((a + b) * (a + c) / n)
                        lor = np.log((a + .5) * (dd + .5) / ((b + .5) * (c + .5)))
                        return [p_r1, p_u1, oe, lor]
                    est = stats(w)
                    # Poisson bootstrap over types
                    ti = S.ti.values; boots = []
                    for _ in range(400):
                        pw = rng.poisson(1.0, ntypes)[ti]
                        boots.append(stats(w * pw))
                    B = np.array(boots, dtype=float)
                    lo, hi = np.nanpercentile(B, 2.5, axis=0), np.nanpercentile(B, 97.5, axis=0)
                    res.append(dict(set=name, scope=scope, treatment=trt, backness=cls, target_height=tgt,
                                    n_pairs=len(S), n_types=S.ti.nunique(), weight_total=w.sum(),
                                    n_R1=int(r1.sum()), n_R1R2=int((r1 & r2).sum()),
                                    P_R2_given_R1=est[0], P_R2_given_R1_lo=lo[0], P_R2_given_R1_hi=hi[0],
                                    P_R2_given_U1=est[1], P_R2_given_U1_lo=lo[1], P_R2_given_U1_hi=hi[1],
                                    OE_RR=est[2], OE_RR_lo=lo[2], OE_RR_hi=hi[2],
                                    logOR=est[3], logOR_lo=lo[3], logOR_hi=hi[3]))
    print(name, "done", flush=True)
R = pd.DataFrame(res)
R.to_csv(os.path.join(OUT, "rounding_harmony_OE.csv"), index=False)
pd.concat(vtab).to_csv(os.path.join(OUT, "rounding_harmony_vowel_pairs_syl1_syl2.csv"), index=False)
print(R[(R.scope == "syl1_to_syl2")][["set", "treatment", "backness", "target_height", "n_pairs", "P_R2_given_R1", "P_R2_given_U1", "OE_RR", "OE_RR_lo", "OE_RR_hi"]].round(3).to_string())
