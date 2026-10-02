"""Russian-attestation counts. The monolingual Chuvash corpus contains Russian passages. A sentence is
classed RUSSIAN if it contains none of the Chuvash-only letters ӑ ӗ ӳ ҫ and >=2 distinct tokens from a
list of Russian function words that are not Chuvash words. Output: cache/russian_sentence_freq.parquet
(word, ru_freq) and a log of how many sentences qualified."""
import re, collections, pyarrow.parquet as pq, pandas as pd
C = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/contact_phonology/cache/"
HG = str.maketrans({"\u0103": "ӑ", "\u0115": "ӗ", "\u00e7": "ҫ", "\u0102": "Ӑ", "\u0114": "Ӗ", "\u00c7": "Ҫ", "\u00ad": None})
RU = set("что это как для его она они был была было были только или если когда уже так все всё очень может при под через чтобы тоже также будет есть нет мы вы он я в и не на с по из от к у о но за".split())
tok = re.compile(r"[а-яёӑӗӳҫ]+(?:-[а-яёӑӗӳҫ]+)*")
chv = re.compile(r"[ӑӗӳҫ]")
cnt = collections.Counter(); nsent = 0; nru = 0
pf = pq.ParquetFile(C + "mono_raw.parquet")
for b in pf.iter_batches(batch_size=200_000, columns=["chv"]):
    for s in b.column(0).to_pylist():
        if not s: continue
        nsent += 1
        s = s.translate(HG).lower()
        if chv.search(s): continue
        t = tok.findall(s)
        if len(RU.intersection(t)) >= 2 and len(t) >= 4:
            nru += 1; cnt.update(t)
pd.DataFrame(cnt.items(), columns=["word", "ru_freq"]).to_parquet(C + "russian_sentence_freq.parquet", index=False)
print("sentences", nsent, "russian", nru, "types", len(cnt))
