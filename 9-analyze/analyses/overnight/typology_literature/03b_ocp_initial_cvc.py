"""Step 3b. OCP-Place restricted to the word-initial #C1 V1 C2 sequence (almost always root-internal), to separate
the root-level constraint from cross-morpheme pairs. Zheltov types and mono_freq5 (SENS). Numpy bootstrap B=1000."""
import sys, os, numpy as np, pandas as pd
sys.path.insert(0, os.path.dirname(__file__))
from common import *
import importlib.util
spec = importlib.util.spec_from_file_location("o", os.path.join(os.path.dirname(__file__), "03_ocp_place.py"))
PLACE = {"p":"LAB","m":"LAB","ʋ":"LAB","t":"COR_OBS","s":"COR_OBS","ʃ":"COR_OBS","ɕ":"COR_OBS","tɕ":"COR_OBS","ts":"COR_OBS","tʃ":"COR_OBS",
         "l":"COR_SON","r":"COR_SON","n":"COR_SON","k":"DOR","x":"DOR","j":"PAL"}
CL = ["LAB","COR_OBS","COR_SON","DOR","PAL"]; rng = np.random.default_rng(11)
rows = []
for name, path, filt in [("zheltov_types_initialCVC", "types_zheltov.csv", None), ("mono_freq5_types_initialCVC_SENS", "types_mono.csv", 5)]:
    d = pd.read_csv(os.path.join(OUT, path), usecols=["word_label_IPA", "corpus_freq"])
    if filt: d = d[d.corpus_freq >= filt]
    P = []
    for w in d.word_label_IPA.dropna():
        s = [x.replace("ʲ", "") for x in tokenize(w)]
        if len(s) >= 3 and s[0] in PLACE and s[1] in VSET and s[2] in PLACE: P.append((s[0], s[2]))
    P = pd.DataFrame(P, columns=["c1", "c2"]); a = P.c1.map(PLACE).map(CL.index).values; b = P.c2.map(PLACE).map(CL.index).values
    ident = (P.c1 == P.c2).values
    def oe(w):
        M = np.zeros((5, 5)); np.add.at(M, (a, b), w); N = M.sum(); E = np.outer(M.sum(1), M.sum(0)) / N
        out = (M / E).ravel().tolist()
        return out
    est = oe(np.ones(len(P))); B = np.array([oe(rng.poisson(1, len(P)).astype(float)) for _ in range(1000)])
    lo, hi = np.percentile(B, 2.5, 0), np.percentile(B, 97.5, 0)
    for i in range(5):
        for j in range(5):
            k = i * 5 + j; rows.append(dict(set=name, c1_class=CL[i], c2_class=CL[j], OE=est[k], lo=lo[k], hi=hi[k],
                                             O=int(((a == i) & (b == j)).sum()), O_identical=int(((a == i) & (b == j) & ident).sum()), n_pairs=len(P)))
R = pd.DataFrame(rows); R.to_csv(os.path.join(OUT, "ocp_place_OE_initialCVC.csv"), index=False)
for n in R.set.unique():
    print(n, R[R.set == n].n_pairs.iloc[0]); print(R[R.set == n].pivot(index="c1_class", columns="c2_class", values="OE").round(2).to_string())
    print(R[(R.set == n) & (R.c1_class == R.c2_class)][["c1_class", "OE", "lo", "hi", "O", "O_identical"]].round(3).to_string())
