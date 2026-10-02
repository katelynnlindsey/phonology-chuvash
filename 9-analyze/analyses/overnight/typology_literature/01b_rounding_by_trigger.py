"""Step 1b. P(V2 rounded | V1 identity) for high and non-high V2 within backness class, syllable 1 -> 2,
with Wilson 95% CIs (types as units). Plus: rounded share of high vowels by syllable position
(initial vs non-initial) -- the positional restriction that drives the result."""
import os, numpy as np, pandas as pd
from statsmodels.stats.proportion import proportion_confint
OUT="/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/typology_literature"
v=pd.read_csv(os.path.join(OUT,"rounding_harmony_vowel_pairs_syl1_syl2.csv"))
rows=[]
for s in ["zheltov_types","mono_dict_types","mono_freq5_types_SENS","mono_freq5_tokens_SENS"]:
    x=v[v.set==s]
    for cls,hi_r,hi_u,lo_r,lo_u in [("back","u","ʉ","ɵ","a"),("front","y","i","ø","e")]:
        for v1 in x[x.cls==cls].v1.unique():
            y=x[(x.cls==cls)&(x.v1==v1)].set_index("v2").wt
            for tgt,r,u in [("high",hi_r,hi_u),("nonhigh_reduced_vs_full",lo_r,lo_u)]:
                k=y.get(r,0); n=k+y.get(u,0)
                lo,hi=proportion_confint(k,n,method="wilson") if (n>0 and "types" in s) else (np.nan,np.nan)
                rows.append(dict(set=s,backness=cls,v1=v1,target=tgt,rounded_v2=r,unrounded_v2=u,k=k,n=n,p=k/n if n else np.nan,lo=lo,hi=hi))
T=pd.DataFrame(rows); T.to_csv(os.path.join(OUT,"rounding_by_trigger.csv"),index=False)
print(T[T.set.isin(["zheltov_types","mono_freq5_types_SENS"])].round(3).to_string())
