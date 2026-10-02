"""Extract PBase rows bearing on rounding (labial) harmony for Turkish, Kirghiz, Eastern Mari.
pb_patterns.csv is TAB-separated; 3 malformed rows are skipped (21,791 good rows)."""
import pandas as pd, csv, re
ROOT="/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze"
OUT=ROOT+"/output/overnight_2026-10-01/typology_literature"
p=pd.read_csv(ROOT+"/data/pbase/pb_patterns.csv",sep="\t",on_bad_lines="skip",dtype=str)
assert len(p)==21791
L=p[p.language.isin(["Turkish","Kirghiz","Cheremis, Eastern (Mari)"])].copy()
ROUND=set("yuøoɵʉ")
def has_round(s): return isinstance(s,str) and any(c in s for c in "yuøo")
txt=L[["description_OLD","notes","morphological"]].fillna("").agg(" ".join,axis=1)
kw=txt.str.contains(r"round|labial|harmon|after X|vowel",case=False,regex=True)
cols=["language","type","I","O","L1","R0","R1","domain","description_OLD","morphological","notes","sources","rule_ID"]
sel=L[kw | L.I.map(has_round) | L.O.map(has_round)][cols]
sel.to_csv(OUT+"/pbase_rounding_rows.csv",index=False)
print(sel.groupby("language").size())
for _,r in sel.iterrows():
    print(r.language[:8],"|",r.type,"|",str(r.I)[:25],"->",str(r.O)[:20],"|",str(r.description_OLD)[:90],"|",str(r.morphological)[:50])
