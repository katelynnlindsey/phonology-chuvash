# Overnight report: Chuvash between Turkic and the Volga — 2026-10-01/02

Four research tracks ran overnight: sociophonetics, contact phonology, segmental acoustics, and typology & literature.
They covered 23 research questions. Each track's full write-up is in its directory as `FINDINGS.md`, with a chronological `NOTEBOOK.md` beside it.
This report gathers the answers, sets out the cross-track story, and lists what I need from you.
Every number below was read from a CSV the tracks saved. I spot-checked about twenty of them against the files myself.

**How the night went.** Segmental acoustics ran at full depth. The other three tracks lost most of the night. A conda
environment install waits for your approval, and with nobody awake the calls simply sat. I then made the same
mistake myself and lost another six hours. The three tracks were rerun at about 03:50 with a no-install rule and
finished in 42–54 minutes each, so their depth is lower than planned. Each one says what it did not reach.
The full account is in `RUN_NOTEBOOK.md`. Nothing outside `9-analyze/analyses/overnight/` and
`9-analyze/output/overnight_2026-10-01/` was modified, and nothing was committed.

---

## 1. The ten things I learned

1. **Chuvash obstruent lenition is real, productive and acoustically robust.** Stops between vowels or after a sonorant
   are voiced through about 60% of their closure, against 3–14% for geminates, post-obstruent and post-pause stops. The
   pattern holds in both corpora and for every Common Voice speaker tested: V_V exceeds post-pause in 53 of 53 speakers.
   This is the distribution Savelyev (2020) describes, and he attributes it to a Mari substratum. (That content was read in a draft PDF; check the published chapter and its Kangasmaa-Minn 1998: 222 sub-citation before citing.)
2. **Geminates block lenition actively, and Russian loans are exempt.** At matched closure duration, geminates carry 30–39 ms less
   voicing into the closure. So their voicelessness is not just an aerodynamic consequence of being long. V_V stops are
   voiced 65–66% in native words but 22% in loans (Chuvash Voice), and the loans the letter flag misses (машина, учитель) are just as unlenited.
3. **Vowels lengthen before geminates (+3–6% obstruent, +12–14% sonorant), and the following vowel is not shortened.**
   That is the Sakha/Japanese pattern, not Finnic foot isochrony and not Italian-style compensatory shortening.
4. **Harmony leakage is morphology, not loanwords.** Native words alone are only 74.6–78.6% one-backness. About
   two thirds of native disharmony is a back stem plus one of about twelve invariant front suffixes (-рӗ/-чӗ, -сем, -не, -ӗ, -ри/-ти …).
   Exempting those suffixes gives 92–93%.
5. **The Mari-like final reduced-vowel pattern is near-categorical in stems.** After a back vowel, the stem-final reduced
   vowel is ⟨ӑ⟩ in 99.0% (Chuvash Voice) and 95.6% (Common Voice) of tokens, and in 97.4% of native Zheltov citation forms. The 36.5% "leak" found earlier is
   almost entirely inflectional suffixes. This sharpens the PBase Mari parallel considerably.
6. **Chuvash has no labial harmony of either neighbouring type.** A syllable-2 high back vowel is /u/ about 90% of the time
   whether syllable 1 is rounded or not. There is neither the Turkish/Kirghiz high-vowel type nor Eastern Mari's
   stress-controlled mid-vowel rounding. Chuvash shares Mari's *stress algorithm* but not the rounding harmony that Mari builds on it.
7. **The stress literature supports Rule A's shape and says nothing about Rule B.** Eastern/Meadow Mari is "rightmost full vowel,
   else initial" (Gordon 2011, citing Vaysman 2009). Schiering & van der Hulst (2010) suggest Chuvash may owe its
   quality-sensitive stress to its Uralic neighbours. Hill Mari defaults differently, to the rightmost *non-final* syllable. The only
   source for a stressless default is Chuvash-internal: Dobrovolsky (1999).
8. **Chuvash Voice `voice_main` is very probably not an adult male.** It holds 73.6% of all vowels, not 69% (that figure was pre-rebuild).
   Its formant spacing (ΔF 1,221 Hz, F3 3,005 Hz) exceeds every Common Voice male and every low-f0 voice.
9. **`voice_main` barely uses f0 for stress, and this distorts pooled f0 results.** It shows +0.04 to +0.14 semitones on predicted-stressed
   vowels, against +0.55 to +0.61 in the other voices. Pooling with it shrinks the f0 effect to +0.18 to +0.20 semitones and **flips the B5-vs-A6 ordering on f0**.
   Duration is the one cue that every speaker uses (55 of 74 speakers individually significant, none negative).
10. **Reduced vowels compress about four times more than full vowels as a speaker speeds up.** The interaction is −0.066 log units
    [−0.085, −0.047] across 56 speakers, and it holds without `voice_main`. That is the behaviour expected of vowels without a mora.

---

## 2. The cross-track answer: Turkic base + Volga-Kama overlay?

The overnight hypothesis holds up, with one important refinement. Chuvash's *segmental system and morphology* look
Turkic, and the parallels with Mari concentrate in **prosody and in the realisation of the weak (reduced/lenis) series**.
The historical literature, however, treats at least the vowel reduction as a two-way Chuvash–Mari exchange (Agyagási 2019), so
"overlay" may be the wrong metaphor. "Co-developed in contact" fits the sources better.

| feature | mainstream Turkic | Eastern Mari | Chuvash (tonight) | reading |
|---|---|---|---|---|
| vowel qualities | 8-vowel front/back/round | has ə | ties with Turkish, Kirghiz, Tuvan **and** Mari in feature space | neutral; the schwa is the difference |
| consonant inventory | — | — | Tuvan ranks 6th/629, Mari 181st | Turkic |
| backness harmony | yes | yes | yes, leaky only through invariant suffixes | Turkic (agglutinative) |
| labial harmony | yes (high vowels) | yes (mid suffix vowels, stress-controlled) | **none** | neither; Bulgharic particularity |
| backness-conditioned final reduction | no schwa rules at all | /e, ø/ → ə / __#, blocked after a back vowel | near-categorical in stems (97–99%) | **Mari** (only PBase match among 629 languages) |
| stress | word-final | rightmost full, else initial (Meadow) | rightmost full (A or B) | **Mari-shaped**; default unresolved |
| intervocalic lenition | not as described | similar historical distribution (Savelyev, citing Kangasmaa-Minn) | confirmed, with geminate blocking and loan exemption | **attributed to Mari**; untested on Mari |
| geminate timing | Sakha: V1 longer, V2 shorter | ? | V1 longer, V2 not shorter | Turkic-like (Sakha); not Finnic |
| reduced-vowel deletion | — | /ə/ → 0 | <1% between voiceless obstruents; sonorant contexts untested | not detected at this depth |
| OCP-place | — | — | strong and gradient, Arabic-type subclass split | universal; uninformative |

![Chuvash's vowel system ranks near Eastern Mari; its consonant system ranks near Tuvan (from yesterday's PBase work)]({{artifact:art_3b4bd932-38b4-416b-af54-fd2c70b30078}})

---

## 3. Track by track

### 3.1 Segmental acoustics (full depth)
Every TextGrid in both corpora was measured with Praat: 2.08M phone intervals. Files failing a full-vowel voicing alignment
check were dropped: 12.4% of Common Voice and 1.0% of Chuvash Voice. Hand checks matched on 7 of 8 tokens; the eighth exposed Common Voice words aligned into digital silence.

| question | answer | confidence |
|---|---|---|
| Can closure voicing be measured? | Yes. Vowels 97% / 90% voiced, post-pause sibilants 2–5% | high (CH), medium (CV) |
| Is intervocalic lenition real? | Yes, three tiers: V_V/R_V ≈0.6; geminate, O_V, post-pause ≈0.03–0.14; cross-word and pre-consonantal intermediate (0.16–0.43). Categorical word-internally, **gradient across word boundaries**. Place gradient p 76% > t 65% > k 56% > tɕ 32% | high |
| Do geminates block it? | Yes, actively: 30–39 ms less voicing at matched duration | high |
| Finnic-type quantity? | No. V1 is longer before geminates and V2 is not shortened | medium-high |
| Mari-type reduced-vowel deletion? | Voiceless reduced vowels between voiceless obstruents: ӑ 0.47%, ӗ 0.17%, /i/ 0.58%. This looks like ordinary devoicing. 8.5–11.8% of ӑ/ӗ sit on the 30-ms aligner floor, concentrated after sonorants and in fast speech | medium; **sonorant contexts not assessed** |

![Lenition is strongest word-internally in V_V and R_V (panel a's title says 'only', but cross-word and pre-consonantal positions are intermediate, 0.16–0.43); geminates devoice at every duration]({{artifact:art_06ffdb47-3669-45e7-9481-b2d004f59bbb}})

![Vowel duration before geminates, singletons and clusters]({{artifact:art_26e45cfb-f0d4-4210-af35-62ef4a0cdf8b}})

### 3.2 Sociophonetics
| question | answer | confidence |
|---|---|---|
| Is voice_main female? | Very probably not an adult male. ΔF 1,221 Hz vs 948–1,047 Hz for Chuvash Voice's own low-f0 voices on the same channel; log₁₀ LR 1.9–10.4 favouring the female-like group | medium-high |
| Is voice_main representative? | Duration effects survive fully. Intensity is pulled down (0.39 vs 0.69–0.75 dB). **f0 does not survive pooling.** Vowel configuration is the same but the scale is expanded (vowel-space area at the 81st percentile) | high / medium |
| Apparent-time age change? | Inconclusive. Reduced-vowel dispersion rises with age (+0.10/decade, CI touching 0, n = 23). ⟨ы⟩ position shows no trend, but with 15 vs 8 speakers only differences above 1.2 between-speaker SDs were detectable | low |
| Viryal dialect evidence? | The 'Верхний' speaker's /u/ is more open as predicted (rank 5 of 49), but rests on 7 clean tokens. The IQR filter removed an [o]-like ун | low |
| Individual cue weighting? | Duration is universal. Intensity varies (τ 0.53 dB, as large as the mean). f0 is **0.51 st weaker in high-f0 voices**, which suggests cue trading. 17 of 74 voices meet your three-cue criterion individually | high / medium |
| Rate × reduction? | Reduced vowels compress about four times more than full vowels. Group differences depend on the rate measure | high / low |

![Duration is a stress cue for every voice; f0 is weak in high voices and almost absent in voice_main (star)]({{artifact:art_d810df21-adbc-42c4-bf5c-c52fba39e4b1}})

![voice_main's vocal-tract cues against Common Voice speakers]({{artifact:art_ca3d5c98-18d5-4a8e-b4d7-3f9a9fb20486}})

### 3.3 Contact phonology
| question | answer | confidence |
|---|---|---|
| Can loans be classified? | Letter flags are nearly 100% precise; the problem is recall. Adding six phonotactic features raises type recall from 0.78 to 0.92. Token recall stays at about 0.63, because nativised loans and names carry no orthographic signal. `is_loan()` is circular for vowel work (44% of flagged types are flagged only by о/ё); a vowel-blind variant is provided | high / medium |
| What drives disharmony? | Invariant suffixes. Loans are only 4–10% of disharmonic tokens | high (direction) |
| Where is loan /o/? | On ⟨ӑ⟩ in polysyllables for 18 of 18 speakers. In monosyllables (Russian-stressed) it is a distinct back rounded mid vowel | medium-high / medium |
| Do loans follow Chuvash stress? | Provisional. The Russian-stressed syllable is about 10% longer but not louder and not higher, i.e. a retained Russian durational correlate. Loan final syllables lack part of native final lengthening (−13%) | low–medium |
| Loan voicing with the better classifier? | The effect is robust and slightly larger (−0.38 CH, −0.31 CV) | high |

![Disharmony is suffixal; back-context final ⟨ӗ⟩ is inflectional; loan /o/ sits on ⟨ӑ⟩; newly detected loans resist lenition]({{artifact:art_6aa8e291-eb8e-4f70-bd9a-cfd499951c2f}})

### 3.4 Typology & literature
| question | answer | confidence |
|---|---|---|
| Labial harmony? | None productive. There is a weak front-series lexical attraction (/y/, /ø/ → /y/, O/E 3.0 in Zheltov) that fades to 1.06 in inflected forms | high / medium |
| Functional load of the vowel contrasts? | a/ɵ and e/ø carry the most load among full–reduced pairs. ⟨ы⟩ is rare but **fully contrastive** with /u/ and ⟨ӑ⟩ per occurrence (94–96 minimal pairs per 1,000 occurrences). The 5-vowel analysis implies a back-only height contrast among reduced vowels (ɵ vs ʉ, 84 pairs) | medium; not a test of inventory |
| OCP-place? | Strong and gradient: labial O/E 0.13–0.17, dorsal 0.26–0.44, coronals weakest; coronal obstruents and coronal sonorants form separate classes (the Arabic pattern). This is a **new descriptive fact** for Chuvash | high |
| The Mari stress parallel? | Real for Meadow Mari and Rule A. Hill Mari differs. The only Rule-B source is Dobrovolsky (1999). Gordon's wording implies a morphological condition in Mari ("non-derived words") that is not yet checked | high / medium |
| Bibliography | 52 verified entries (48 by DOI, 4 by retrieved URL), plus an unverified-leads list (Hayes 1995, Vaysman 2009, Krueger 1961 and others) | high (bibliographic) |

![Rounding of a syllable-2 high vowel follows backness, not V1 rounding]({{artifact:art_07d990df-8bd6-48f5-978b-f3d10ca5aeb8}})

![OCP-place observed/expected by place class]({{artifact:art_1ec23534-7bd3-406d-a0b3-45601d2864dc}})

---

## 4. Things that affect the manuscript now

These came out of the night's work and touch numbers or methods you are already using.

1. **f0 rule comparison.** `master_rule_comparison.csv` reports f0 stress effects of 0.46–0.52 st on all data. The
   sociophonetics track gets 0.18–0.20 st under a different position control, and shows that the B5-vs-A6 f0 ordering flips depending on whether
   `voice_main` is included. The "two of three cues favour B" argument rests partly on f0, so the f0 column needs a speaker-level or
   voice_main-excluded rerun before it is cited. *This is the most consequential item in this report.*
2. **voice_main is 73.6% of analysed vowels**, not 69%. Its gender label is very probably wrong.
3. **`02_clean.R` removes every `is_loan()` word**, so the leveled data are letter-native only. Loans spelled with native letters
   (машина, учитель, класс) remain. A `loan_full` flag is now available
   (`analyses/overnight/contact_phonology/loan_classifier.py`).
4. **The "Chuvash harmony is leaky" sentence should say why**: invariant suffixes. Native stems with alternating suffixes are about 92–93% harmonic.
5. **The P6 Mari parallel can be stated more strongly**, at the stem level (97–99%).
6. **New descriptive facts available for the paper**: geminate-blocked, loan-exempt lenition with a gradient postlexical
   extension; pre-geminate lengthening; OCP-place; the absence of labial harmony; reduced-vowel rate compression.
7. **`speech_rate` divides by whole-clip duration including edge silence.** The span-based rate correlates with it at r = 0.83, but group effects differ between the two.
8. **The IQR outlier filter may remove dialectal tokens.** Keep this in mind for any sociophonetic use.

---

## 5. Questions for Kate

Grouped by what each one needs from you. The most consequential come first in each group.

### Decisions
1. **f0 spec.** Should f0-based stress claims and the master rule table be rerun at speaker level or without `voice_main`? Which f0 position control is canonical (the master table's nonparametric one or the fast spec)?
2. **Loans in the stress analyses.** Exclude `loan_full` words (catching машина-type loans that `is_loan()` misses), or keep loans as a flagged stratum?
3. **What counts as a loan.** Should Russian-form names (Иван, Петров) and old nativised loans (шкул, сӗтел, салтак, пӑшал) count as loans? Tonight they do.
4. **Framing the Mari parallel.** Should it be presented as support for Rule A's *shape* only, given that no Mari variety has a stressless default and Hill Mari defaults differently?
5. **⟨ы⟩.** Is a back-only height contrast among reduced vowels (ɵ vs ʉ, 84 minimal pairs) acceptable under the 5-vowel analysis?
6. **Cross-word lenition.** Is cross-word (V#_V) lenition, at about half strength and gradient, worth its own point (a categorical lexical rule plus gradient postlexical coarticulation)?
7. **Pipeline changes.** Should the pipeline measure speech rate over the vowel span? Should OW (loan /o/) rows be kept in a side table? Should the IQR filter be relaxed for dialect work? Should the Common Voice VOX alignment QC (`file_alignment_qc.csv`) be adopted elsewhere?
8. **Disk.** The overnight directory is about 870 MB, mostly regenerable per-phone extractions and caches (~300 MB segmental, ~370 MB contact). Commit, compress, or git-ignore? Nothing has been committed.

### Things only you or the documentation can answer
9. Who recorded `voice_main`? Can the Chuvash Voice documentation confirm the speaker's sex?
10. Do you have Vaysman (2009), Lehiste et al. (2005, *Meadow Mari Prosody*) or Hayes (1995) to hand? They are needed to check whether the Mari initial default is restricted to non-derived words.
11. Is there a source on Hill Mari stress, or on which Mari variety borders Chuvashia? (The track's guess, that it is Hill Mari, is unsourced.)
12. Is there an etymological list of Viryal-/o/ ~ standard-/u/ items?
13. PBase gives Eastern Mari's reference as Harms (1962) *Estonian Grammar*, which looks like a metadata error. Should PBase Mari rows be cited only through Sebeok & Ingemann or Kangasmaa-Minn?

### Listening and checking (quick)
14. Listen to the Common Voice clips of cv_60 ('Верхний') and of cv_76, cv_108, cv_68 and cv_77 for [o] in ⟨у⟩ words.
15. Have a native speaker re-check `contact_phonology/loan_handannotation.csv` (440 rows; 26 marked probable/unsure).
16. Hand-place boundaries on about 200 pre-geminate vowels, to rule out an alignment artefact behind the sonorant-geminate lengthening.

### Elicitation targets (for your informant)
17. Reduced vowels between sonorants (-рӑ-, -лӑ-, -нӑ-) at slow and fast rate. Mari-type syncope would occur here, and the corpora cannot diagnose it.
18. Stressed loan /o/ against ⟨ӑ⟩ (*том* vs a ⟨ӑ⟩ monosyllable), and whether unstressed loan о reduces to ⟨ӑ⟩.
19. Stress in suffixed loans (учи́тельсем vs учительсе́м).
20. Whether ⟨ӑ/ӗ⟩ labialise after rounded vowels (Savelyev 2020), which orthography cannot show.
21. The informant's dialect region (Viryal vs Anatri). This bears on #12–14 and on the earlier ⟨ы⟩-rounding remark.
22. Longer term: Mari recordings measured with the same lenition script. Without them, Savelyev's substratum attribution cannot be tested.

### Resources
23. Could a Russian stress dictionary (e.g. one derived from Zaliznyak) be added? It would replace the suffix proxy in the loan-stress test.
24. For future unattended runs: pre-approve, or pre-install, `pyreadr` in the `python` environment, so that overnight work never waits on an install approval.

---

## 6. New questions the night raised

- **Cue trading by voice group.** High-f0 voices use less f0 and more duration for stress. Is that a sex difference, a recording-style effect, or a measurement artefact?
- Is voice_main's weak f0 cue a property of read audiobook prosody, with phrase intonation overriding word stress? This can be tested on phrase-medial words only.
- Are the invariant suffixes (-рӗ, -сем, -ӗ, -ри/-ти) historically harmonising? That would decide whether the leak is old Turkic or a later development.
- Does stem-level final ⟨ӑ⟩/⟨ӗ⟩ conditioning (97–99%) match Mari's rule quantitatively in a Mari corpus?
- Is ⟨ӑ⟩'s low F2, i.e. a rounded [ŏ]-type quality, what attracts loan /o/? That would make the mapping rounding-based rather than reduction-based.
- Front-series rounding attraction: a lexical residue of Proto-Turkic harmony, or Anatri secondary labialisation?
- Does lenition apply as strongly at morpheme boundaries (suffix-initial -па/-та/-ка) as stem-internally?
- Do older speakers have more dispersed reduced vowels in an age-balanced sample?
- Is the 17-of-74 three-cue figure a per-speaker power limit, or are intensity and f0 optional stress cues in Chuvash?

## 7. Not assessed tonight

- Reduced-vowel deletion between sonorants, and in spontaneous speech (both corpora are read speech).
- The Khanty geminate comparison (no durational sources retrieved).
- Loan /o/ apparent-time change (OW rows are excluded from the leveled data) and loan /o/ rounding (no F3/lip analysis).
- The Chuvash stress rule in loans independently of the final syllable (collinear in 94% of loan rows).
- Cross-language OCP and rounding baselines from Turkish, Tatar or Mari corpora.
- Content of Hayes 1995, Vaysman 2009, Krueger 1961, Kenstowicz 1997 (original) and Lehiste et al. 2005 (bibliographic records only, or not found).
- The all-data full random-effect fits for intensity and f0 (the fast spec stands in; it matched within 0.006–0.033 units wherever both exist).

## 8. Where everything is

| what | path (repo-relative) |
|---|---|
| this report | `9-analyze/output/overnight_2026-10-01/MORNING_REPORT.md` / `.html` |
| run log | `9-analyze/output/overnight_2026-10-01/RUN_NOTEBOOK.md` |
| per-track findings and notebooks | `9-analyze/output/overnight_2026-10-01/<track>/FINDINGS.md`, `NOTEBOOK.md` |
| scripts | `9-analyze/analyses/overnight/<track>/` |
| loan classifier | `9-analyze/analyses/overnight/contact_phonology/loan_classifier.py` |
| bibliography | `typology_literature/bibliography.md`, `.bib`, `unverified_leads.md` |
| voicing token tables | `segmental_acoustics/voicing_tokens.csv.gz`, `extraction/` |
