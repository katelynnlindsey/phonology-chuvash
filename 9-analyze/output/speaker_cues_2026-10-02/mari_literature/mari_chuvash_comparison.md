# Meadow Mari stress against the Chuvash cue results

Sources: Vaysman (2009), MIT dissertation, §2.3.1, pp. 60–77; Lehiste, Teras, Help, Lippus, Meister, Pajusalu & Viitso (2005), *Meadow Mari Prosody* (LU Suppl. 2).
Chuvash numbers come from `overnight_2026-10-01/sociophonetics/FINDINGS.md` Q5 (`s5_cue_heterogeneity.csv`, `s5_slopes_by_voice_group.csv`).
Mari numbers come from `mari_cue_values.csv` and the two derived tables in this folder. Short quotes with page numbers are in `mari_literature_statements.csv`.

## Bottom line

Meadow Mari has the same ranking of cues as Chuvash: duration first, f0 secondary and unreliable. It also has the same rule shape, Rule A (rightmost full, else initial). It does **not** supply a stressless default. Mari intensity has never been measured in a multi-speaker study. The Chuvash finding that f0 is a weaker cue in high voices cannot be tested from the published Mari tables, so it is "not assessed at this depth" (it is not a negative result).

## 1. Rule shape

| | Meadow Mari | Chuvash (project) |
|---|---|---|
| Underived words | rightmost **underlying** full vowel (Vaysman pp. 62–64; Lehiste et al. p. 14, citing Kangasmaa-Minn 1998: 224) | Rule A / B: rightmost full vowel |
| All-reduced words | initial (Vaysman p. 64; Lehiste et al. p. 94) | A: initial; B: stressless (Dobrovolsky 1999) |
| Morphology | Restricted to underived words. Full-vowel suffixes do not take stress from full-vowel roots (*pašá-lan*). /a/-suffixes beat /e/-suffixes after full+schwa roots. All-schwa roots lose stress to any full-vowel suffix. Schwa suffixes and harmonising o/ö/e suffixes are never stressed (pp. 69–73). | Rules are applied to whole surface words |
| Opacity | An underlying schwa that surfaces as full word-finally (*kínde* /kində/) still counts as reduced (p. 63 fn 21; Lehiste et al. p. 14) | not modelled |

Gordon's (2011) "monomorphemic / non-derived" wording is correct: Vaysman states the rule for underived words only. Her derived-word facts follow from root-cyclic stress plus suffix-vowel sonority. A Rule A match for Chuvash is therefore a match with Mari *roots*. Whether Chuvash suffixed words behave the same way is an open question for the corpus.

## 2. Default for all-reduced words

- **Vaysman:** initial stress. Footnote 22 (p. 64) rejects a Dobrovolsky-style analysis for her dialect, because stressed initial vowels there "exhibit the same characteristics as other stressed vowels". This is a statement with no measurements behind it.
- **Lehiste et al.:** words with only central vowels take initial stress (p. 94). Table 5 (p. 40) provides the only relevant measurement. In Cə.CV disyllables, a stressed initial /ə/ is **101 ms** (n = 52, sd 17). An unstressed initial /ə/ before a stressed final vowel is **46 ms** (n = 41, sd 10). The authors give the ratio as 2.2. The initially stressed Cə.CV items are mostly words ending in *-e* (*čəže, šəže, kəne, čəke*). On Vaysman's analysis these are underlyingly all-schwa, which makes this comparison the Mari analogue of the A vs B configuration. That mapping is my inference (**inferred**). The two sets are different words, stress was judged by one listener, and *kəne* and *čəke* split 4 : 4 across speakers (Table 23, p. 65).
- **Conclusion:** both sources support Rule A's default for Mari, the second with durational evidence. Rule B is still sourced only for Chuvash.

## 3. Cue profile

| Cue | Meadow Mari | Chuvash (74 speakers, A6) | Same? |
|---|---|---|---|
| Duration | "most reliable" correlate (p. 91). Stressed/unstressed in the same position: 1.45 (V1) and 1.48 (V2) in CV.CV (Table 5, p. 40); 1.13–1.68 in Table 24 (p. 66; 8 position × syllable-type × sentence-position cells). Per speaker, >1 in 12/12 speaker × position cells with ≥ 2 final-stress words (range 1.13–2.46; Table 5A, p. 108). Final lengthening outweighs stress (p. 71). | +0.167 log units (≈ +18%), τ = 0.043; 55/74 speakers individually significant, none negative | **Yes**: duration is the cue every speaker uses. Mari magnitudes are larger (ln 1.45 ≈ 0.37), but the design is not comparable (see §4) |
| f0 | "auxiliary" (p. 93); sentence intonation overrides it (p. 92). Derived from Table 25: stressed minus unstressed syllable −1.5 to +4.4 st phrase-finally (7 of 8 cells positive); in sentence-final words +0.9 to +1.8 st with initial stress but −2.2 to −6.3 st with final stress (`mari_f0_semitone_contrasts.csv`) | +0.63 st, τ = 0.41 st; −0.51 st smaller in high-f0 voices | **Qualitatively yes** (secondary and context-dependent). The voice-group effect is not assessed: the Mari tables give female and male group means only (4 + 4 speakers). Phrase-finally, female contrasts are no smaller than male ones (S1 words +3.6 vs −0.0 st; S2 words +3.2 vs +3.9 st) |
| Intensity | **Not measured** (p. 93). Earlier Mari reports, all via Lehiste et al. pp. 23–28, conflict. Gruzov (1960): duration only. Gruzov (1964a): 106–120% relative intensity. Zorina (1982, Hill Mari): not a correlate. Baitchura (1988): intensity follows pitch. Vaysman lists "amplitude" without measurement (p. 62) | +0.58 dB, τ = 0.53 dB | Not assessed for Mari |
| Vowel quality | Unstressed vowels centralise, mostly < 1 Bark; word-final unstressed /o/ shifts 1.4–1.8 Bark in F2 (pp. 84–87) | not in the cue models | — |

## 4. Why magnitudes don't transfer

- **Labels:** Mari stress is *perceived* (one native listener, p. 32); Chuvash stress is *rule-predicted*. Perceived labels may themselves rest on duration, which inflates Mari duration contrasts.
- **Style and position:** Mari is read speech in the frame "I said X, not Y". The authors call it maximally clear (p. 93). Every test word is phrase- or sentence-final, so boundary tones dominate f0. Chuvash speech is read sentences (CV) and news-style reading (CH), with phrase position controlled.
- **Lexical confound:** the Mari stressed/unstressed contrasts compare different words, with no item control, no standard errors and 2–9 tokens per speaker cell.
- **Speaker variation:** Mari speakers disagree on stress placement in 16 of 58 disyllables (p. 64). LV, from Bashkortostan, prefers initial stress (p. 65). Any rule-based Chuvash slope has the same exposure.

## 5. Leads (not verified as primary sources)

- Kovedjajeva (1970: 72–75), via Lehiste et al. p. 17, claims that the whole Meadow Mari stress pattern was borrowed from Ancient Bolgar. This bears directly on the overlay hypothesis.
- Collinder (1965: 42–43), via Lehiste et al. p. 17, describes a final-stress tendency in the easternmost Cheremis dialects, possibly through Turkic influence.
