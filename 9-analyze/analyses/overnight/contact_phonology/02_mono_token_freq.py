"""Token frequencies of word forms in the monolingual corpus (pre-cleaning sentences, mono_raw).
Lower-cased, homoglyphs folded, soft hyphens removed; tokens = maximal runs of Cyrillic letters
(incl. Chuvash ӑ ӗ ӳ ҫ) and internal hyphens. Output: cache/mono_token_freq.parquet"""
import re, collections, pyarrow.parquet as pq, pandas as pd
C = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/contact_phonology/cache/"
HG = str.maketrans({"\u0103": "ӑ", "\u0115": "ӗ", "\u00e7": "ҫ", "\u0102": "Ӑ", "\u0114": "Ӗ", "\u00c7": "Ҫ", "\u00ad": None})
tok = re.compile(r"[а-яёӑӗӳҫ]+(?:-[а-яёӑӗӳҫ]+)*")
cnt = collections.Counter()
pf = pq.ParquetFile(C + "mono_raw.parquet")
for i, b in enumerate(pf.iter_batches(batch_size=200_000, columns=["chv"])):
    for s in b.column(0).to_pylist():
        if s:
            cnt.update(tok.findall(s.translate(HG).lower()))
    print(i, len(cnt), flush=True)
df = pd.DataFrame(cnt.items(), columns=["word", "mono_freq"])
df.to_parquet(C + "mono_token_freq.parquet", index=False)
print(len(df), df.mono_freq.sum())
