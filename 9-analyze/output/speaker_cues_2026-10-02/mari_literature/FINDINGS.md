# FINDINGS — mari_literature (2026-10-02)

**Source substitution.** The attached Vaysman PDF is front matter only (pp. 1–10, no Mari content). Every Vaysman statement below comes from the full open-access dissertation on MIT DSpace (hdl 1721.1/47830; cover dated 22 Oct 2008, versus 15 Sept 2008 on the excerpt; same TOC pagination). Lehiste et al. (2005) page numbers are printed pages (= PDF page + 2).

## Step 1. Vaysman's Mari stress statements

**Answer.**
- **Dialect.** Eastern (Meadow) Mari, recorded in 2002 fieldwork on the border of Nizhny Novgorod region and Mari El (p. 60). One stress per word (p. 62).
- **Rule.** "In underived words, the stress falls on the rightmost full (non-schwa) vowel" (p. 62).
  - What counts is the underlying vowel: underlying schwas that surface as full vowels word-finally still count as reduced (p. 63 fn 21; e.g. *kínde*, *šö́rtö*).
- **All-reduced default.** In all-schwa roots, "the stress is placed on the leftmost syllable" (p. 64; e.g. *pə́rəs* 'cat').
  - Vaysman classes this as default-to-opposite, but the contrast is short full vs short reduced vowels, not weight (p. 65 fn 23).
- **No stressless default.** Footnote 22 (p. 64) cites Dobrovolsky (1999) on Chuvash and rejects that analysis for her dialect: there, stressed initial vowels "exhibit the same characteristics as other stressed vowels".
- **Restriction to non-derived words: yes.** Gordon's (2011) wording is accurate. Suffixes behave as follows (pp. 69–73):
  1. Full-vowel suffixes do not take stress from roots containing a full vowel (*pašá-lan*, *šö́r-län*).
  2. All-schwa roots lose stress to any full-vowel suffix (*rəwəž-lán*, *rəwəž-gé*).
  3. After full + schwa roots, /a/-suffixes (Dat. *-lan*, *-la*, *-na*, *-da*) attract stress, but /e/-suffixes (Com. *-ge*, Abl. *-eč*, Car. *-de*) do not.
  4. Schwa suffixes and harmonising o/ö/e suffixes are never stressed.
  5. Her analysis ranks ALIGN-R(σ́, Root) above ALIGN-R(σ́, PWd).
- **Variants.** Stress variants are not discussed for this dialect. She points to Itkonen (1955), Ristinen (1960), Sebeok & Ingemann (1961) and, for Northwest Mari, Ivanov & Tuzharov (1970) (p. 65).
- **Cues (impressionistic, no measurement method).** "fundamental frequency, amplitude, and especially duration", with stress adding c. 120 ms to a 70 ms unstressed vowel (p. 62).

**Key numbers:** +c. 120 ms on 70 ms (p. 62); 16 verified quotes in `mari_literature_statements.csv`.

**Confidence:** high for what the dissertation says.

**Caveats:**
- One dialect, one fieldwork season, no speaker count reported.
- The cue statement and the footnote-22 rebuttal of Dobrovolsky are not backed by reported measurements.

**Files:** `mari_literature_statements.csv`.

## Step 2. Lehiste et al. (2005) acoustic findings

**Answer.**
- **Rule assumed.** The "common claim" (p. 14, citing Kangasmaa-Minn 1998: 224): last full vowel, else initial. The authors add that final mid vowels can be reduced allophones, which then shift stress leftward.
  - Stress location was not assumed in the analysis. It was judged by one native speaker through repeated listening (p. 32).
- **Materials.**
  - 8 speakers: 4 F (EI, ST, LV, NK), 4 M (AA, JT, VN, VA), born 1963–1981. Six come from Mari El, LV from Bashkortostan, VN from Perm region; all were living in Estonia.
  - 100 test words of 1–4 syllables in the read frame "I said …, not …", each in phrase-final and sentence-final position, giving 1600 tokens. Recorded 2000 and 2004 and measured in Praat.
  - Measures: segment durations, F0 at vowel onset and offset, F1–F3.
- **Is stress acoustically marked?** Yes, but not unambiguously (p. 72).
- **Duration** is "the most reliable phonetic correlate of stress" (p. 91).
  - Stressed vowels are longer than unstressed ones in the same position: 110 vs 76 ms in V1 and 197 vs 133 ms in V2 of CV.CV words, ratios 1.45 and 1.48 (Table 5, p. 40). In Table 24 the ratio is 1.13–1.68 (p. 66).
  - Unstressed vowels are 58–69% of stressed ones (p. 35–36).
  - But final lengthening is larger than stress lengthening: a stressed initial vowel can be shorter than an unstressed final one (pp. 70–71).
- **F0** is an "auxiliary cue" (p. 93) that sentence intonation overrides (p. 92).
  - In sentence-final words, F0 falls through the word, so a final stressed syllable is lower than the preceding unstressed one.
  - My derived contrasts from Table 25: −2.2 to −6.3 st sentence-finally with final stress, −1.5 to +4.4 st phrase-finally.
- **Intensity** was not measured (p. 93).
- **Vowel quality.** Unstressed vowels centralise, mostly by < 1 Bark. Word-final unstressed /o/ moves 1.38–1.82 Bark in F2 (pp. 84–87).
- **Speaker variation.**
  - *Placement:* speakers disagreed on 16 of 58 disyllables (p. 64). LV (Bashkortostan) leans to initial stress (p. 65).
  - *Duration contrast:* per speaker (Table 5A, p. 108), stressed/unstressed duration exceeds 1 in all 12 speaker × position cells with ≥ 2 final-stress words (range 1.13–2.46). The only two values below 1 come from single tokens (VN PF V1 0.88; LV SF 0.96).
  - *F0:* JT's contours are atypical and were excluded from some averages; VN is creaky and near-monotone (pp. 51–60).
- **Speech style.** Read, maximally clear contrastive frame (p. 93). There are no spontaneous data.
- **Prior studies** used 1–3 speakers each (p. 29).
  - Gruzov (1960) found duration only.
  - Zorina (1982, Hill Mari) found that intensity is not a correlate.
  - Baitchura (1988) found that intensity follows pitch, on the initial syllable (pp. 23–28).

**Key numbers:** see above; 343 transcribed values in `mari_cue_values.csv`.

**Confidence:** high for transcription of the read tables; medium for the derived per-speaker and semitone contrasts (my computation).

**Caveats:**
- Stressed and unstressed sets are different words.
- Group means carry no standard errors.
- There are 1–9 tokens per speaker cell.
- Stress labels come from one listener.
- Per-speaker F0 Appendix tables (13A–22A) and formant Appendix tables (23A–29A) were not transcribed.

**Files:** `mari_cue_values.csv`, `mari_transcribed_tables.json`, `mari_table23_stress_placement.csv`, `mari_speaker_duration_contrasts.csv`, `mari_f0_semitone_contrasts.csv`, `fig_mari_cue_profile.png`; script `analyses/speaker_cues/mari_literature/build_mari_tables.py`.

## Step 3. Comparison with Chuvash

**Answer.** Mari shows the same cue ranking as Chuvash: duration is the speaker-general cue, and f0 is secondary and context-bound.
- **Duration.** Mari: > 1 in 12/12 speaker cells. Chuvash: +0.167 log units, 55/74 speakers significant, none negative.
- **F0.** Mari: overridden by sentence intonation. Chuvash: +0.63 st, τ 0.41.
- **Intensity.** Chuvash intensity varies across speakers (τ 0.53 dB). It has no Mari counterpart: it was not measured, and the older single-speaker reports conflict.
- **High-f0 attenuation.** The Chuvash finding (−0.51 st) is **not assessed at this depth** for Mari, because the published tables give only female and male group means for 4 + 4 speakers. Phrase-finally, female contrasts are not smaller than male ones.
- **Rule A shape** matches Mari for **underived** words only. Mari stress is morphologically conditioned and opaque to word-final vocalisation; both properties need checking in Chuvash.
- **Default.** Both Mari sources give initial stress in all-reduced words. Table 5 gives stressed initial /ə/ 101 ms vs unstressed initial /ə/ 46 ms. Treating those items as underlyingly all-reduced is my inference. **Rule B remains sourced only for Chuvash (Dobrovolsky 1999).**

**Confidence:** medium. The qualitative match is clear, but the magnitudes are not comparable: the designs differ in perceived vs rule labels, contrastive phrase-final read frame vs running read speech, and lexical confounds.

**Caveats:**
- The comparison is between a published group study and per-speaker corpus regressions.
- Kovedjajeva's (1970: 72–75) claim that Meadow Mari stress was borrowed from Ancient Bolgar is reported only second-hand (Lehiste et al. p. 17).

**Files:** `mari_chuvash_comparison.md`, `bibliography_additions.bib` (6 entries: Vaysman 2009, Lehiste 2005 [content checked], Zoll 1997, Baković 2004, Lehiste 2003 Erzya, Stifter 2006), `crossref_mari.json`.
