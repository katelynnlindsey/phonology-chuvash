"""Step 3. OCP-Place (Frisch, Pierrehumbert & Broe 2004 style O/E): consonant pairs C1 V C2 separated by exactly one
vowel (C1 = consonant immediately before the vowel, C2 = immediately after). Place classes:
LAB {p m ʋ (+ʲ)}, COR_OBS {t tʲ s sʲ ʃ ɕ tɕ ts tʃ}, COR_SON {l lʲ r rʲ n nʲ}, DOR {k x xʲ}, PAL {j}.
O/E = observed / (row total * column total / N), per type set; Poisson bootstrap over types (B=400).
Identity split: homorganic pairs split into identical (same segment, palatalisation ignored) vs non-identical.
Stops: p t tʲ k ; 'homorganic stops' = p-p, t-t, k-k cross-vowel pairs.
Sets: Zheltov types (all; native-only = no о ё ф ц щ ъ б г д ж з, primary), mono_dict types, mono_freq5 types (SENS)."""
import sys, os, numpy as np, pandas as pd
sys.path.insert(0, os.path.dirname(__file__))
from common import *
rng = np.random.default_rng(3)
LOAN = set("оёфцщъбгджз")
PLACE = {}
for s in ["p", "m", "ʋ"]: PLACE[s] = "LAB"
for s in ["t", "s", "ʃ", "ɕ", "tɕ", "ts", "tʃ"]: PLACE[s] = "COR_OBS"
for s in ["l", "r", "n"]: PLACE[s] = "COR_SON"
for s in ["k", "x"]: PLACE[s] = "DOR"
PLACE["j"] = "PAL"
STOP = {"p", "t", "k"}
def base(s): return s.replace("ʲ", "") if s != "ʲ" else None
def cvc(segs):
    out = []
    for i in range(1, len(segs) - 1):
        if segs[i] in VSET and segs[i-1] not in VSET and segs[i+1] not in VSET:
            a, b = base(segs[i-1]), base(segs[i+1])
            if a in PLACE and b in PLACE: out.append((a, b))
    return out
zt = pd.read_csv(os.path.join(OUT, "types_zheltov.csv")); mt = pd.read_csv(os.path.join(OUT, "types_mono.csv"))
def prep(d):
    d = d[d.word_label_IPA.notna()].copy(); d["segs"] = d.word_label_IPA.map(tokenize)
    d["loan"] = d.word_label.str.lower().map(lambda w: any(c in LOAN for c in str(w))); return d
zt, mt = prep(zt), prep(mt)
sets = {"zheltov_native_types": zt[~zt.loan], "zheltov_all_types": zt, "mono_dict_native_types": mt[(mt.in_wordlist == True) & ~mt.loan],
        "mono_freq5_native_types_SENS": mt[(mt.corpus_freq >= 5) & ~mt.loan]}
CL = ["LAB", "COR_OBS", "COR_SON", "DOR", "PAL"]
res, seg_res = [], []
for name, d in sets.items():
    P = [(ti, a, b) for ti, s in enumerate(d.segs) for a, b in cvc(s)]
    P = pd.DataFrame(P, columns=["ti", "c1", "c2"]); P["p1"] = P.c1.map(PLACE); P["p2"] = P.c2.map(PLACE)
    P["ident"] = P.c1 == P.c2
    nT = len(d)
    def oe_all(w):
        N = w.sum(); M = pd.crosstab(P.p1, P.p2, values=w, aggfunc="sum").reindex(index=CL, columns=CL).fillna(0)
        E = np.outer(M.sum(1), M.sum(0)) / N; out = {}
        for i, a in enumerate(CL):
            for j, b in enumerate(CL): out[(a, b, "all")] = M.iloc[i, j] / E[i, j] if E[i, j] > 0 else np.nan
        # homorganic split identical vs non-identical (expected for each = E_homorganic * share under independence of segments)
        seg = pd.crosstab(P.c1, P.c2, values=w, aggfunc="sum").fillna(0); r = seg.sum(1); c = seg.sum(0)
        Eseg = np.outer(r, c) / N; Eseg = pd.DataFrame(Eseg, index=seg.index, columns=seg.columns)
        for a in CL:
            segs_a = [s for s in seg.index if PLACE[s] == a]; cols_a = [s for s in seg.columns if PLACE[s] == a]
            O_id = sum(seg.loc[s, s] for s in segs_a if s in cols_a); E_id = sum(Eseg.loc[s, s] for s in segs_a if s in cols_a)
            O_h = seg.loc[segs_a, cols_a].values.sum(); E_h = Eseg.loc[segs_a, cols_a].values.sum()
            out[(a, a, "identical")] = O_id / E_id if E_id > 0 else np.nan
            out[(a, a, "nonidentical")] = (O_h - O_id) / (E_h - E_id) if E_h - E_id > 0 else np.nan
        # stops
        st = [s for s in seg.index if s in STOP]; stc = [s for s in seg.columns if s in STOP]
        O = seg.loc[st, stc]; E = Eseg.loc[st, stc]
        homo = sum(O.loc[s, s] for s in st if s in stc); Ehomo = sum(E.loc[s, s] for s in st if s in stc)
        out[("STOP", "STOP", "homorganic(identical)")] = homo / Ehomo
        out[("STOP", "STOP", "heterorganic")] = (O.values.sum() - homo) / (E.values.sum() - Ehomo)
        out[("_N", "_N", "pairs")] = N
        return out, seg, Eseg
    est, seg, Eseg = oe_all(np.ones(len(P)))
    B = []
    for _ in range(400):
        w = rng.poisson(1.0, nT)[P.ti.values].astype(float); B.append(oe_all(w)[0])
    for k, v in est.items():
        bs = np.array([b[k] for b in B], dtype=float)
        res.append(dict(set=name, c1_class=k[0], c2_class=k[1], subset=k[2], OE=v, lo=np.nanpercentile(bs, 2.5), hi=np.nanpercentile(bs, 97.5),
                        n_pairs=len(P), n_types=nT))
    if name == "zheltov_native_types":
        S = (seg / Eseg).round(3); S.to_csv(os.path.join(OUT, "ocp_segment_OE_zheltov_native.csv"))
        seg.to_csv(os.path.join(OUT, "ocp_segment_counts_zheltov_native.csv"))
    print(name, len(P), flush=True)
R = pd.DataFrame(res); R.to_csv(os.path.join(OUT, "ocp_place_OE.csv"), index=False)
for name in sets:
    x = R[(R.set == name) & (R.subset == "all")].pivot(index="c1_class", columns="c2_class", values="OE").round(2)
    print(name); print(x.to_string())
print(R[R.subset != "all"].round(3).to_string())
