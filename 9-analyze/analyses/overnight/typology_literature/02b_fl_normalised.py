"""Step 2b. Minimal pairs per 1,000 occurrences of the rarer vowel (Zheltov, mono_dict), and a summary table."""
import pandas as pd, os
OUT="/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/typology_literature"
mp=pd.read_csv(os.path.join(OUT,"minimal_pairs_vowels.csv")); vc=pd.read_csv(os.path.join(OUT,"fl_vowel_counts.csv"),index_col=0)
fl=pd.read_csv(os.path.join(OUT,"functional_load.csv"))
fl=fl[~((fl.x=="u")&(fl.y=="ʉ"))]  # duplicate of ʉ/u
key=lambda a,b: tuple(sorted((a,b)))
rows=[]
for _,r in fl[fl.kind=="vowel"].iterrows():
    k=key(r.x,r.y); d={"contrast":f"{k[0]}/{k[1]}"}
    for s in ["mono_dict_tokens","mono_freq5_tokens_SENS","zheltov_types"]:
        v=fl[(fl.set==s)&(fl.x==r.x)&(fl.y==r.y)].FL; d["FL_"+s]=float(v.iloc[0])
    for s,vs in [("zheltov_types","zheltov_types"),("mono_dict","mono_dict")]:
        m=mp[(mp.set==s)&(mp.x==k[0])&(mp.y==k[1])].n_minimal_pairs; n=int(m.iloc[0]) if len(m) else 0
        d["MP_"+s]=n; d["MP_per1000_rarer_"+s]=1000*n/min(vc.loc[k[0],vs],vc.loc[k[1],vs])
    rows.append(d)
T=pd.DataFrame(rows).drop_duplicates("contrast")
T["rank_FL_mono_dict"]=T.FL_mono_dict_tokens.rank(ascending=False).astype(int)
T.sort_values("FL_mono_dict_tokens",ascending=False).to_csv(os.path.join(OUT,"functional_load_summary.csv"),index=False)
print(T.sort_values("FL_mono_dict_tokens",ascending=False).round(5).to_string())
