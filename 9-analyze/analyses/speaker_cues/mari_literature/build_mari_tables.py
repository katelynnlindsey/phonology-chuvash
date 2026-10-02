"""Build the Mari acoustic-cue tables from the hand transcription of Lehiste et al. (2005).

Input : output/speaker_cues_2026-10-02/mari_literature/mari_transcribed_tables.json
        (values copied from page images of the monograph; printed page = PDF page + 2)
Output: mari_cue_values.csv                    every transcribed value, long format, with table and printed page
        mari_table23_stress_placement.csv       speakers' stress placement on 16 variable disyllables (Table 23, p. 65)
        mari_speaker_duration_contrasts.csv     per-speaker stressed/unstressed duration contrasts (derived from Table 5A, p. 108)
        mari_f0_semitone_contrasts.csv          stressed-minus-unstressed F0 in semitones (derived from Table 25, p. 67)

Derived quantities are ours, not the authors'. They compare group means across different lexical items
(words stressed on S1 vs words stressed on S2) and carry no standard errors.
Run: python build_mari_tables.py   (pandas only)
"""
import json, math, os
import pandas as pd

OUT = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/speaker_cues_2026-10-02/mari_literature"
raw = json.load(open(os.path.join(OUT, "mari_transcribed_tables.json")))

# 1. all transcribed values
pd.DataFrame(raw["rows"]).to_csv(os.path.join(OUT, "mari_cue_values.csv"), index=False)

# 2. Table 23: stress placement by speakers
t23 = pd.DataFrame(raw["T23"], columns=["word", "PF_S1_n", "PF_S2_n", "SF_S1_n", "SF_S2_n"])
t23["source"] = "Lehiste et al. 2005, Table 23, p. 65"
t23.to_csv(os.path.join(OUT, "mari_table23_stress_placement.csv"), index=False)

# 3. per-speaker duration contrasts, full-vowel CV.CV words (Table 5A)
sex = raw["sex"]
der = []
for pos, d in raw["A5"].items():
    for spk, cells in d.items():
        _, (n1, v1s, v2u, r1), _, (n2, v1u, v2s, r2) = cells
        has = n2 > 0
        der.append(dict(
            sentence_position=pos, speaker=spk, sex=sex[spk], N_S1_words=n1, N_S2_words=n2,
            V1_stressed_ms=v1s, V1_unstressed_ms=v1u, V2_stressed_ms=v2s, V2_unstressed_ms=v2u,
            V1_stressed_over_unstressed=round(v1s / v1u, 2) if has else None,
            V2_stressed_over_unstressed=round(v2s / v2u, 2) if has else None,
            V1V2_ratio_S1_words=r1, V1V2_ratio_S2_words=r2 if has else None,
            log2_ratio_S1_over_S2=round(math.log2(r1 / r2), 2) if has else None,
            source="derived from Lehiste et al. 2005, Table 5A, p. 108"))
pd.DataFrame(der).to_csv(os.path.join(OUT, "mari_speaker_duration_contrasts.csv"), index=False)

# 4. F0 contrasts in semitones (Table 25): vowel F0 = mean of beginning and end values
st = lambda a, b: 12 * math.log2(a / b)
f0 = []
for pos, syl, g, n1, m1, s1, n2, m2, s2 in raw["T25"]:
    a1, a2 = (m1[0] + m1[1]) / 2, (m1[2] + m1[3]) / 2   # S1-stressed words: V1 stressed, V2 unstressed
    b1, b2 = (m2[0] + m2[1]) / 2, (m2[2] + m2[3]) / 2   # S2-stressed words: V1 unstressed, V2 stressed
    f0.append(dict(
        sentence_position=pos, syllables=syl, sex=g, N_S1=n1, N_S2=n2,
        within_word_S1words_stressed_minus_unstressed_st=round(st(a1, a2), 2),
        within_word_S2words_stressed_minus_unstressed_st=round(st(b2, b1), 2),
        V1_stressed_minus_unstressed_across_words_st=round(st(a1, b1), 2),
        V2_stressed_minus_unstressed_across_words_st=round(st(b2, a2), 2),
        mean_F0_Hz=round((a1 + a2 + b1 + b2) / 4),
        source="derived from Lehiste et al. 2005, Table 25, p. 67"))
pd.DataFrame(f0).to_csv(os.path.join(OUT, "mari_f0_semitone_contrasts.csv"), index=False)
print("rows", len(raw["rows"]), "speaker rows", len(der), "f0 rows", len(f0))
