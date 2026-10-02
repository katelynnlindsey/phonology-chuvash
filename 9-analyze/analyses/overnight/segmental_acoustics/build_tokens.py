"""Overnight 2026-10-01, segmental_acoustics.  Build analysis tables from the
per-phone extraction (extraction/phones_*.csv).

Outputs (in OUT):
  /tmp/segac_phones_all.pkl  scratch pickle of every phone row (not kept)
  obstruent_tokens.csv.gz  one row per obstruent token with position class,
                           neighbouring vowel measures and word-level stress
  vowel_tokens.csv.gz      one row per vowel token with flanking-segment info
                           (for the fleeting-vowel step)
"""
import glob, os
import numpy as np, pandas as pd

ROOT = "/Users/kate/Documents/GitHub/phonology-chuvash/"
OUT = ROOT + "9-analyze/output/overnight_2026-10-01/segmental_acoustics/"
EXT = OUT + "extraction/"

VOWELS = {"ɑ", "e", "ʌ", "ɛ", "i", "u", "ɯ", "y", "o"}
REDUCED = {"ʌ", "ɛ"}
FULL6 = {"ɑ", "e", "i", "u", "y", "ɯ"}       # inventory 6 (ACTIVE_RULE A6); o = loan
SON_BASE = {"m", "n", "l", "r", "j", "v"}
OBS_BASE = {"p", "t", "k", "tʃ", "ts", "s", "ʃ", "ɕ", "χ", "f", "b", "d", "g", "ʒ"}
PAUSE = {"sil", "#", "", "<eps>"}
BAD = {"spn"}


def base(l):
    return l[:-1] if l.endswith("ː") else l


def klass(l):
    if l in PAUSE: return "P"
    if l in BAD: return "X"
    if l in VOWELS: return "V"
    b = base(l)
    if b in SON_BASE: return "R"
    if b in OBS_BASE: return "O"
    return "X"


def main():
    parts = sorted(glob.glob(EXT + "phones_*.csv"))
    df = pd.concat([pd.read_csv(p, dtype={"word_label": str}) for p in parts], ignore_index=True)
    df["word_label"] = df["word_label"].fillna("")
    # speakers
    tsv = pd.read_csv(ROOT + "1-raw_data/common_voice_chuvash/audio_metadata_Mozilla/cv_xpf_spkr17.tsv",
                      sep="\t", usecols=["path", "speaker_id", "gender", "age", "accents"])
    tsv["file_name"] = tsv.path.str.replace(r"\.mp3$", "", regex=True)
    tsv["speaker"] = "cv_" + tsv.speaker_id.astype(str)
    ss = pd.read_csv(ROOT + "9-analyze/output/speaker_structure.csv", usecols=["file_name", "voice_label"])
    ss["speaker"] = "ch_" + ss.voice_label
    spk = pd.concat([tsv[["file_name", "speaker"]], ss[["file_name", "speaker"]]]).drop_duplicates("file_name")
    df = df.merge(spk, on="file_name", how="left")
    df = df.sort_values(["file_name", "pidx_utt"]).reset_index(drop=True)
    df["klass"] = df.phone.map(klass)
    df["long"] = df.phone.str.endswith("ː").astype(int)
    df["base"] = df.phone.map(base)
    g = df.groupby("file_name", sort=False)
    for k in ("phone", "klass", "dur_ms", "vf_def_mid", "lb_mean", "int_max", "int_mean"):
        df["prev_" + k if k != "phone" else "prev_ph"] = g[k].shift(1)
        df["next_" + k if k != "phone" else "next_ph"] = g[k].shift(-1)
    df["prev_klass"] = df.prev_klass.fillna("P"); df["next_klass"] = df.next_klass.fillna("P")
    # second neighbours (for V-C-V of a vowel's flanks etc.)
    df["prev2_klass"] = g["klass"].shift(2).fillna("P")
    df["next2_klass"] = g["klass"].shift(-2).fillna("P")
    # word-level: n phones, position, X-containing word, stress (A6)
    wk = ["file_name", "widx"]
    df["in_word"] = (df.widx >= 0) & (df.word_label != "<eps>") & (df.word_label != "")
    w = df[df.in_word].groupby(wk)
    df.loc[df.in_word, "pos_in_word"] = w.cumcount()
    df.loc[df.in_word, "word_nphone"] = w["phone"].transform("size")
    df["_isX"] = df.klass.eq("X"); df["_isV"] = df.klass.eq("V")
    df.loc[df.in_word, "word_has_bad"] = df[df.in_word].groupby(wk)["_isX"].transform("any")
    # vowel index within word, and A6 stressed vowel
    isv = df.klass.eq("V") & df.in_word
    df.loc[isv, "vidx"] = df[isv].groupby(wk).cumcount() + 1
    df.loc[df.in_word, "word_nvowel"] = df[df.in_word].groupby(wk)["_isV"].transform("sum")
    vv = df[isv][wk + ["vidx", "phone"]].copy()
    vv["full"] = vv.phone.isin(FULL6 | {"o"})
    lastfull = vv[vv.full].groupby(wk).vidx.max().rename("a6_full")
    firstred = vv.groupby(wk).vidx.min().rename("a6_first")
    st = pd.concat([lastfull, firstred], axis=1)
    st["stress_vidx_A6"] = st.a6_full.fillna(st.a6_first)
    df = df.merge(st[["stress_vidx_A6"]].reset_index(), on=wk, how="left")
    # utterance position of word
    # last real word in utterance
    lastw = df[df.in_word].groupby("file_name").widx.max().rename("last_widx")
    df = df.merge(lastw.reset_index(), on="file_name", how="left")
    df["utt_final_word"] = (df.widx == df.last_widx).astype(int)
    df["word_final"] = (df.in_word & (df.next_same_word == 0)).astype(int)
    df["word_initial"] = (df.in_word & (df.prev_same_word == 0)).astype(int)
    df.to_pickle("/tmp/segac_phones_all.pkl")  # scratch only; not a deliverable

    # ── obstruent tokens ────────────────────────────────────────────────
    ob = df[(df.klass == "O") & df.in_word].copy()

    def lctx(r):
        if r.prev_same_word == 1:
            return r.prev_klass
        return {"P": "#P", "V": "#V", "R": "#R", "O": "#O"}.get(r.prev_klass, "#X")

    def rctx(r):
        if r.next_same_word == 1:
            return r.next_klass
        return {"P": "P#", "V": "V#", "R": "R#", "O": "O#"}.get(r.next_klass, "X#")

    ob["L"] = [lctx(r) for r in ob.itertuples()]
    ob["R"] = [rctx(r) for r in ob.itertuples()]

    def pos(r):
        L, R = r.L, r.R
        if "X" in L or "X" in R: return "excluded_spn"
        if r.long == 1:
            return "geminate_VV" if (L == "V" and R == "V") else "geminate_other"
        if L in ("#P",):
            return "initial_postpause" if R == "V" else "initial_postpause_preC"
        if L == "#V" and R == "V": return "initial_postV"            # cross-word intervocalic
        if L in ("#R",) and R == "V": return "initial_postR"
        if L == "#O" and R == "V": return "initial_postO"
        if L == "V" and R == "V": return "VV"
        if L == "R" and R == "V": return "RV"
        if L == "O" and R == "V": return "OV"
        if L == "V" and R == "R": return "VR"
        if L == "V" and R == "O": return "VO"
        if L == "V" and R == "P#": return "final_prepause"
        if L == "V" and R == "V#": return "final_preV"             # cross-word intervocalic
        if L == "V" and R in ("O#", "R#"): return "final_preC"
        return "other"

    ob["position"] = [pos(r) for r in ob.itertuples()]
    keep = ["file_name", "corpus", "speaker", "word_label", "widx", "pos_in_word", "word_nphone",
            "word_nvowel", "word_has_bad", "utt_final_word", "phone", "base", "long", "start", "dur_ms",
            "prev_ph", "next_ph", "L", "R", "position", "art_rate",
            "vf_def_all", "vf_def_mid", "vic_def_ms", "vf_sen_all", "vf_sen_mid", "vic_sen_ms",
            "lb_mean", "lb_min", "int_mean", "int_max",
            "prev_dur_ms", "next_dur_ms", "prev_vf_def_mid", "next_vf_def_mid",
            "prev_lb_mean", "next_lb_mean", "prev_klass", "next_klass", "stress_vidx_A6"]
    # vowel index of flanking vowels (to know whether the preceding vowel is stressed)
    vidx = df["vidx"]
    ob["prev_vidx"] = [vidx.iat[i - 1] if i > 0 else np.nan for i in ob.index]
    ob["next_vidx"] = [vidx.iat[i + 1] if i + 1 < len(df) else np.nan for i in ob.index]
    keep += ["prev_vidx", "next_vidx"]
    ob[keep].to_csv(OUT + "obstruent_tokens.csv.gz", index=False)

    # ── vowel tokens ─────────────────────────────────────────────────────
    vw = df[(df.klass == "V") & df.in_word].copy()
    vkeep = ["file_name", "corpus", "speaker", "word_label", "widx", "pos_in_word", "word_nphone",
             "word_nvowel", "word_has_bad", "vidx", "stress_vidx_A6", "utt_final_word",
             "word_initial", "word_final", "phone", "start", "dur_ms", "art_rate",
             "prev_ph", "next_ph", "prev_klass", "next_klass", "prev2_klass", "next2_klass",
             "vf_def_all", "vf_def_mid", "vf_sen_all", "vf_sen_mid", "lb_mean", "int_mean", "int_max",
             "int_mid", "int_peak_rel", "prev_dur_ms", "next_dur_ms", "prev_int_max", "next_int_max",
             "prev_int_mean", "next_int_mean", "prev_vf_def_mid", "next_vf_def_mid",
             "prev_same_word", "next_same_word"]
    vw[vkeep].to_csv(OUT + "vowel_tokens.csv.gz", index=False)
    print(len(df), len(ob), len(vw))
    print(ob.groupby(["corpus", "position"]).size().unstack(0))


if __name__ == "__main__":
    main()
