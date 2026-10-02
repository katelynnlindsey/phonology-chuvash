"""Lexicon-based Russian-loan flag for Chuvash word labels (final rules, 2026-10-02, speaker_cues/loan_lexicon).

A word (or each part of a hyphenated word) is flagged when a stem obtained by stripping a chain of listed Chuvash
suffixes is a Russian word form (wordfreq 3.1.1 'large' Russian list, ё→е folded), subject to guards and three
evidence-based native-collision vetoes. See output/speaker_cues_2026-10-02/loan_lexicon/NOTEBOOK.md for the design
history (v1 pre-registered → final) and FINDINGS.md for validation.

    from lexicon_loan_flag import LexiconFlagger
    lf = LexiconFlagger()              # loads wordfreq + overnight Chuvash frequency table + Zheltov headwords
    lf.flag("машинӑна")                # -> dict(loan_lexicon=True, stem='машинӑ', match='машина', ...)

Requires env `python` (wordfreq installed) and the overnight contact-phonology caches.
"""
import math, re, sys
from functools import lru_cache
from collections import defaultdict

ROOT = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze"
OV = f"{ROOT}/output/overnight_2026-10-01/contact_phonology"
sys.path.insert(0, f"{ROOT}/analyses/overnight/contact_phonology")
import loan_classifier as lc  # noqa: E402

# ---- parameters (fixed before validation; see NOTEBOOK) ---------------------------------------------------------
Z0 = 3.0          # Russian Zipf floor for a lexicon match (>= 1 per million)
MINLEX = 4        # Chuvash stem length floor for a lexicon match
MIN_STRIP_STEM = 3
MAX_CHAIN = 4
DELTA = 1.23      # X1: 99th pct of Zipf_cv - Zipf_ru over 1,402 distinct matches of letter-flagged loans (outside annotation)
Z_HEAD = 2.0      # a >=4-letter Zheltov headword spelled as a Russian word (Zipf >= 2) is not native evidence ...
                  # ... unless it is Chuvash-dominant by the X1 criterion

# ---- suffixes: REF from analyses/morph_validation.R (IPA) -> orthography, + overnight invariant list + past allomorphs
REF_IPA = ["sem","ɵm","øm","ɵmɵr","ømør","ɵr","ør","ø","i","ɵn","øn","n","a","e","na","ne","ta","te","ra","re","tɕe","tɕi",
  "tan","ten","ran","ren","ntɕen","pa","pe","ʃɵn","ʃøn","sene","sen","sempe","sentɕen","sente","senpe",
  "ma","me","sa","se","nɵ","nø","rø","rɵm","røm","ɵp","øp","at","et","akan","eken","ɕɕø","tɕtɕø","mast","mest","mar",
  "lɵ","lø","sɵr","sør","lɵx","løx","u","y","lan","len"]
I2O = [("tɕ","ч"),("ɕ","ҫ"),("ʃ","ш"),("ɵ","ӑ"),("ø","ӗ"),("a","а"),("e","е"),("i","и"),("u","у"),("y","ӳ"),
       ("s","с"),("m","м"),("n","н"),("r","р"),("t","т"),("p","п"),("l","л"),("x","х"),("k","к")]
def ipa2orth(s):
    for a, b in I2O: s = s.replace(a, b)
    return s
REF_ORTH = [ipa2orth(s) for s in REF_IPA]
INVARIANT = ["рӗ","чӗ","сем","сен","сене","не","ӗ","ри","ти","хи","ки","ҫҫӗ","рӗҫ","ӗн","ни","асси","ччӗ"]
ALLOMORPHS = ["тӑм","тӗм","тӑмӑр","тӗмӗр","тӑр","тӗр","тӑн","тӗн","чӑм","чӗм","чӑр","чӗр","чӗҫ","тӗҫ","тӑҫ"]
SUF = sorted(set(REF_ORTH) | set(INVARIANT) | set(ALLOMORPHS), key=len, reverse=True)
CONS = set("бвгджзйклмнпрстфхцчшщҫ")
KIND_RANK = {"id":0,"ьӑ>я":1,"ӑ>а":1,"ӗ>е":1,"Vй>Vя":1,"+ь":2,"+а":3,"+я":3}


def prep(w):
    return lc.normalise(w).replace("ё", "е")


@lru_cache(maxsize=None)
def seg(t, k=MAX_CHAIN):
    if t == "": return True
    if k == 0: return False
    return any(t.endswith(x) and seg(t[:-len(x)], k - 1) for x in SUF if len(x) <= len(t))


def splits(w):
    return [(w[:i], w[i:]) for i in range(len(w), MIN_STRIP_STEM - 1, -1) if seg(w[i:])]


def variants(s):
    """orthographic adaptations of Russian stems in Chuvash inflection"""
    v = [(s, "id")]
    if s.endswith("ьӑ"): v.append((s[:-2] + "я", "ьӑ>я"))          # кухньӑ-на  < кухня
    elif s.endswith("ӑ"): v.append((s[:-1] + "а", "ӑ>а"))          # машинӑ-на  < машина
    if s.endswith("ӗ"): v.append((s[:-1] + "е", "ӗ>е"))
    if s.endswith("ий") or s.endswith("ей"): v.append((s[:-1] + "я", "Vй>Vя"))   # пенсий-ӗ, аллей-
    if s[-1] in CONS: v += [(s + "ь", "+ь"), (s + "а", "+а")]       # учител-ӗ < учитель; машин-и < машина
    if s.endswith("и"): v.append((s + "я", "+я"))                    # пенси < пенсия
    return v


class LexiconFlagger:
    def __init__(self):
        import wordfreq, pandas as pd
        ru = defaultdict(float)
        for k, f in wordfreq.get_frequency_dict("ru", wordlist="large").items():
            k2 = k.lower().replace("ё", "е")
            if re.fullmatch(r"[а-я]+", k2): ru[k2] += f
        self.RU = dict(ru)
        mono = pd.read_parquet(f"{OV}/cache/mono_token_freq.parquet")
        mono["w"] = mono.word.map(prep)
        self.CVF = mono.groupby("w").mono_freq.sum().to_dict(); self.CVTOT = int(mono.mono_freq.sum())
        zh = pd.read_parquet(f"{OV}/cache/zheltov_raw.parquet")
        self.ZH = {x for x in zh.word.map(prep) if re.fullmatch(r"[а-яӑӗӳҫ]+", x)}
        self.NATROOT = {x for x in self.ZH if self._is_natroot(x)}
        self.loan_spelling = lru_cache(maxsize=None)(self._loan_spelling)
        self.native_parses = lru_cache(maxsize=None)(self._native_parses)

    def zru(self, s):
        f = self.RU.get(s, 0.0); return math.log10(f) + 9 if f > 0 else 0.0

    def zcv(self, s):
        f = self.CVF.get(s, 0); return math.log10(f / self.CVTOT) + 9 if f > 0 else 0.0

    def _is_natroot(self, x):
        if len(x) < 2 or x not in self.ZH or lc.classify_loan(x)["loan_full"]: return False
        if len(x) >= MINLEX and self.zru(x) >= Z_HEAD and not (self.zcv(x) - self.zru(x) > DELTA): return False
        return self.zru(x) < Z0 or (len(x) <= 3 and self.zcv(x) > self.zru(x))

    def _loan_spelling(self, hw):
        """Zheltov headword that is itself a dictionary spelling of a loan (Russian stem + listed suffixes, or -и < -ия)"""
        if hw.endswith("и") and len(hw) >= MINLEX and self.zru(hw + "я") >= Z0: return True
        return any(len(s) >= MINLEX and self.zru(s) >= Z0 for s, t in splits(hw))

    def _native_parses(self, part):
        return tuple(part[:i] for i in range(len(part), 1, -1)
                     if part[:i] in self.NATROOT and seg(part[i:]) and not self.loan_spelling(part[:i]))

    def candidates(self, part):
        out = []
        nps = self.native_parses(part)
        for s, t in splits(part):
            for m, kind in variants(s):
                if m not in self.RU: continue
                zr, zc = self.zru(m), self.zcv(m)
                X1 = (zc - zr) > DELTA
                X2 = m.endswith("е") and max(self.zru(m[:-1] + "а"), self.zru(m[:-1] + "я")) > zr
                nr = next((h for h in nps if h != m), None)
                out.append(dict(stem=s, chain=t, match=m, kind=kind, z_ru=zr, z_cv=zc,
                                guard_ok=len(s) >= MINLEX and zr >= Z0, X1=X1, X2=X2, X3=nr is not None, native_root=nr))
        return out

    def flag(self, word):
        """-> dict(loan_lexicon, stem, match, kind, chain, z_ru, veto) ; veto = rules that removed the best guard-passing match"""
        key = prep(word)
        best = None; vetoed = None
        for p in [x for x in key.split("-") if x]:
            for c in self.candidates(p):
                if not c["guard_ok"]: continue
                c["rank"] = (-len(c["stem"]), KIND_RANK[c["kind"]], -c["z_ru"])
                if not (c["X1"] or c["X2"] or c["X3"]):
                    if best is None or c["rank"] < best["rank"]: best = c
                elif vetoed is None or c["rank"] < vetoed["rank"]:
                    vetoed = c
        if best is not None:
            return dict(loan_lexicon=True, stem=best["stem"], match=best["match"], kind=best["kind"], chain=best["chain"],
                        z_ru=best["z_ru"], z_cv=best["z_cv"], veto=None, veto_match=None)
        veto = None if vetoed is None else "+".join(k for k in ("X1", "X2", "X3") if vetoed[k])
        return dict(loan_lexicon=False, stem=None, match=None, kind=None, chain=None, z_ru=None, z_cv=None,
                    veto=veto, veto_match=None if vetoed is None else vetoed["match"])
