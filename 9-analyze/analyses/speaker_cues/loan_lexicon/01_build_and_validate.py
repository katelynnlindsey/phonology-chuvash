"""Build loan_flags_by_word.csv and score it against the overnight hand labels (final rules).
Run in env `python` after 00_export_leveled_words.R:
    python 01_build_and_validate.py
Writes (output/speaker_cues_2026-10-02/loan_lexicon/): loan_flags_by_word.csv, loan_flags_spoken_preclean_types.csv,
loan_lexicon_validation_rerun.csv (final + loan_full rows; the session file loan_lexicon_validation.csv also carries v1),
lexicon_newflag_audit_summary.csv is recomputed from lexicon_newflag_audit.csv (labels fixed in that file).
"""
import sys, numpy as np, pandas as pd
sys.path.insert(0, "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/analyses/speaker_cues/loan_lexicon")
from lexicon_loan_flag import LexiconFlagger, prep, lc, ROOT, OV

OUT = f"{ROOT}/output/speaker_cues_2026-10-02/loan_lexicon"
RX = r"[а-яёӑӗӳҫ\-]+"
lf = LexiconFlagger()

# ---- populations ------------------------------------------------------------------------------------------------
lev = pd.read_parquet(f"{OUT}/cache/leveled_word_tokens.parquet")
ph = pd.read_csv("/Users/kate/Documents/GitHub/phonology-chuvash/7-extract/reextract/phones_chuvash_voice.csv",
                 usecols=["file_name", "word_label", "widx"]).drop_duplicates(["file_name", "widx"])
raw = pd.read_csv(f"{OV}/intermediate/raw_vowels_compact.csv", usecols=["file_name", "corpus", "word_label", "word_start"])
cv = raw[raw.corpus == "common_voice_chuvash"].drop_duplicates(["file_name", "word_start", "word_label"])
pop = pd.concat([ph.assign(corpus="CH")[["word_label", "corpus"]], cv.assign(corpus="CV")[["word_label", "corpus"]]])
pop["w"] = pop.word_label.map(lc.normalise); pop = pop[pop.w.str.fullmatch(RX)]
P = pop.groupby("w").agg(n=("w", "size"), n_ch=("corpus", lambda s: (s == "CH").sum())).reset_index()
assert len(P) == 35420 and P.n.sum() == 331544, (len(P), P.n.sum())
pc = lc.classify_series(P.w)
P = pd.concat([P, pc[["C_LET", "loan_full", "loan_crude"]]], axis=1)
def prefix_init(word):  # pre-fix INIT_* behaviour that defined the overnight design stratum S3
    parts = [p for p in lc.normalise(word).split("-") if p]
    return any(lc.PATTERNS["INIT_CC"].search(p) or lc.PATTERNS["INIT_R"].search(p) for p in parts)
P["dstratum"] = np.select([P.C_LET, P.loan_crude, P.loan_full | (~P.loan_full & P.w.map(prefix_init)), P.n >= 20],
                          ["S1", "S2", "S3", "S4"], "S5")
Nh = P.groupby("dstratum").size().to_dict(); Th = P.groupby("dstratum").n.sum().to_dict()
assert Nh == {"S1": 2280, "S2": 1812, "S3": 898, "S4": 2367, "S5": 28063}, Nh
P["key"] = P.w.map(prep)
F = {k: lf.flag(k) for k in set(P.key) | set(lev.word_label.map(prep))}
P["loan_lexicon"] = P.key.map(lambda k: F[k]["loan_lexicon"]); P["lexicon_match"] = P.key.map(lambda k: F[k]["match"])
P["loan_combined"] = P.loan_full | P.loan_lexicon
P.rename(columns={"w": "word", "n": "n_tokens_spoken"}).assign(n_cv=lambda d: d.n_tokens_spoken - d.n_ch)[
    ["word", "n_tokens_spoken", "n_ch", "n_cv", "loan_full", "loan_lexicon", "loan_combined", "lexicon_match"]
].to_csv(f"{OUT}/loan_flags_spoken_preclean_types.csv", index=False)

# ---- leveled word_label table -------------------------------------------------------------------------------------
lab = lev.groupby("word_label").size().rename("n_tokens").reset_index(); lab["key"] = lab.word_label.map(prep)
fl = lc.classify_series(lab.word_label)
lab["loan_full"] = fl.loan_full.values; lab["loan_full_evidence"] = fl.evidence.values
def stem_of(k):
    r = F[k]
    if r["loan_lexicon"]: return r["stem"]
    out = []
    for p in [x for x in k.split("-") if x]:
        nps = lf.native_parses(p)
        if nps: out.append(nps[0]); continue
        s = p
        for _ in range(4):
            for x in __import__("lexicon_loan_flag").SUF:
                if len(x) >= 2 and s.endswith(x) and len(s) - len(x) >= 3: s = s[:-len(x)]; break
            else: break
        out.append(s)
    return "-".join(out)
lab["stem"] = lab.key.map(stem_of)
for c, src in [("loan_lexicon", "loan_lexicon"), ("lexicon_match", "match"), ("lexicon_variant", "kind"),
               ("lexicon_suffix_chain", "chain"), ("lexicon_zipf_ru", "z_ru"), ("lexicon_zipf_cv", "z_cv"),
               ("native_exception_rule", "veto"), ("native_exception_match", "veto_match")]:
    lab[c] = lab.key.map(lambda k: F[k][src])
lab["loan_combined"] = lab.loan_full | lab.loan_lexicon
lab["lexicon_zipf_ru"] = lab.lexicon_zipf_ru.astype(float).round(2); lab["lexicon_zipf_cv"] = lab.lexicon_zipf_cv.astype(float).round(2)
h = pd.read_csv(f"{OV}/loan_handannotation.csv"); lab["in_handannotation"] = lab.key.isin(set(h.w.map(prep)))
req = ["word_label", "n_tokens", "stem", "loan_lexicon", "loan_full", "loan_combined", "lexicon_match"]
v1 = pd.read_csv(f"{OUT}/loan_flags_by_word.csv", usecols=["word_label", "loan_lexicon_v1"]) if \
    "loan_lexicon_v1" in pd.read_csv(f"{OUT}/loan_flags_by_word.csv", nrows=1).columns else None
if v1 is not None: lab = lab.merge(v1, on="word_label", how="left")   # v1 (pre-registered) flag kept from the session run
lab = lab[req + [c for c in lab.columns if c not in req and c != "key"]]
assert len(lab) == lev.word_label.nunique() and lab.n_tokens.sum() == len(lev)
lab.to_csv(f"{OUT}/loan_flags_by_word.csv", index=False)

# ---- validation (design-based, reproduces overnight loan_full estimates exactly) --------------------------------------
H = h.copy(); H["key"] = H.w.map(prep); H["n"] = H.n_ch + H.n_cv; H["S"] = H.stratum.str[:2]; H["grp"] = H.S + "_" + H.design
H["gold_R"] = H.gold == "R"; H["gold_RU"] = H.gold.isin(["R", "U"]); H["loan_full"] = H.loan_full_pred.astype(bool)
H["loan_lexicon"] = H.key.map(lambda k: lf.flag(k)["loan_lexicon"]); H["loan_combined"] = H.loan_full | H.loan_lexicon
def estimates(df, pred, gold):
    tt = dict(tp=0., pp=0., gp=0.); kt = dict(tp=0., pp=0., gp=0.)
    for s, g in df[df.design == "SRS"].groupby("S"):
        c, y, n = g[pred], g[gold], g.n
        tt["tp"] += Nh[s] * (c & y).mean(); tt["pp"] += Nh[s] * c.mean(); tt["gp"] += Nh[s] * y.mean()
        if s in ("S1", "S2", "S3"):
            kt["tp"] += Nh[s] * (n * (c & y)).mean(); kt["pp"] += Nh[s] * (n * c).mean(); kt["gp"] += Nh[s] * (n * y).mean()
    for s, g in df[df.design != "SRS"].groupby("S"):
        c, y = g[pred], g[gold]
        kt["tp"] += Th[s] * (c & y).mean(); kt["pp"] += Th[s] * c.mean(); kt["gp"] += Th[s] * y.mean()
    return {u: dict(precision=t["tp"] / t["pp"] if t["pp"] else np.nan, recall=t["tp"] / t["gp"]) for u, t in [("type", tt), ("token", kt)]}
e = estimates(H, "loan_full", "gold_R")
assert abs(e["type"]["precision"] - 0.985339373903106) < 1e-9 and abs(e["token"]["recall"] - 0.6338799606293887) < 1e-9
rows = []
rng = np.random.default_rng(20261002); groups = [g for _, g in H.groupby("grp")]
for gold in ["gold_R", "gold_RU"]:
    for clf in ["loan_lexicon", "loan_full", "loan_combined"]:
        e = estimates(H, clf, gold); bt = []
        for b in range(2000):
            bs = pd.concat([g.iloc[rng.integers(0, len(g), len(g))] for g in groups]); eb = estimates(bs, clf, gold)
            bt.append([eb["type"]["precision"], eb["type"]["recall"], eb["token"]["precision"], eb["token"]["recall"]])
        bt = np.array(bt)
        for j, (u, m) in enumerate([("type", "precision"), ("type", "recall"), ("token", "precision"), ("token", "recall")]):
            rows.append(dict(gold_def=gold, classifier=clf, unit=u, metric=m, estimate=round(e[u][m], 4),
                             ci95_lo=round(np.nanpercentile(bt[:, j], 2.5), 4), ci95_hi=round(np.nanpercentile(bt[:, j], 97.5), 4)))
pd.DataFrame(rows).to_csv(f"{OUT}/loan_lexicon_validation_rerun.csv", index=False)
print(pd.DataFrame(rows).query("gold_def=='gold_R'").to_string())
