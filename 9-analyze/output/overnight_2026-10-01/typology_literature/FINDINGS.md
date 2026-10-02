# Typology & literature — findings (overnight 2026-10-01)

Scripts: `9-analyze/analyses/overnight/typology_literature/`. Outputs: this directory. Every number below is read
from a CSV in this directory. Written-corpus data only (no acoustics in this track). Type sets: **Zheltov** = 18,984
wordlist types (primary); **mono_dict** = monolingual types with `in_wordlist` (13,139 types; *not independent of
Zheltov* — they are Zheltov's vocabulary, the mono corpus only adds token weights); **mono_freq5** = all monolingual
types with frequency ≥ 5 (116,464 types; includes inflected forms, which the lemma list lacks, but also possible
fragments — used only as a labelled sensitivity set). Types containing the loan vowel /o/ were dropped.

---

## Q1. Is there rounding (labial) harmony in Chuvash?

**Test.** For every adjacent vowel pair inside a word whose two vowels share backness (back {a ɵ u ʉ}, front {e ø i y}),
the rate at which V2 is rounded after a rounded vs an unrounded V1, and O/E for the rounded–rounded cell. Two treatments:
A = rounded {u, y}; B = rounded {u, y, ɵ, ø} (the config's `VOWEL_ROUND`, after Krueger 1961). Poisson bootstrap over
types (400 reps) for all CIs; Wilson CIs for per-trigger rates. Syllable 1→2 and all adjacent pairs.

**Answer. No Turkish/Kirghiz-type labial harmony. Rounding of a non-initial high vowel follows its *backness*, not
the rounding of the preceding vowel: back high V2 is /u/ ~90% of the time whatever precedes it, front high V2 is /i/
~94% after unrounded vowels. The one residue is a front-series lexical attraction (/y/, /ø/ → /y/) that is weak in
inflected forms. The reduced vowels show no rounding agreement at all.** This is the pattern Savelyev (2020)
describes: suffixes alternate only by backness (/a/–/e/, /ə̂/–/ə/, /u/–/ü/), with no rounded/unrounded opposition in
reduced vowels outside the first syllable.

**Key numbers** (syllable 1 → 2, Zheltov types; `rounding_by_trigger.csv`):
- *Back, high V2 = u vs ʉ.* P(V2 = u) after **a** 0.878 [0.833, 0.912] (n = 270), after **ʉ** (unrounded) 0.926
  [0.766, 0.979] (n = 27), after **u** 0.958 [0.916, 0.980] (n = 167), after **ɵ** 1.00 (n = 63). Turkish
  (PBase A11115/A11116: unrounded vowels "generally only followed by other unrounded vowels") predicts ≈ 0 after a/ʉ.
  O/E rounded–rounded, treatment A: 1.04 [1.01, 1.08] — statistically above 1 but tiny (`rounding_harmony_OE.csv`).
  /ʉ/ ⟨ы⟩ is almost absent from syllable 2 (42 of ~12,000 back syllable-2 vowels in Zheltov;
  `rounding_harmony_vowel_pairs_syl1_syl2.csv`) — a positional restriction, not a harmony effect.
- *Front, high V2 = y vs i.* P(V2 = y) after **e** 0.058 [0.030, 0.110] (n = 138), **i** 0.043 [0.020, 0.090]
  (n = 140), **y** 0.500 [0.307, 0.693] (n = 22), **ø** 0.412 [0.321, 0.509] (n = 102). In mono_freq5 (inflected forms)
  the same rates are 0.056 / 0.065 / **0.112** [0.081, 0.153] (n = 295) / **0.224** [0.200, 0.250] (n = 1,077): the
  attraction survives but shrinks by a factor of 2–4. Treatment-A O/E for front-high (syllable 1→2) is 3.00 [1.70, 4.47] in Zheltov (n = 402 pairs) and 1.06 [0.77, 1.37] in mono_freq5 (n = 4,213). For all adjacent pairs it is 1.79 [1.05, 2.47] vs 0.94 [0.67, 1.24] (`rounding_harmony_OE.csv`).
- *Reduced V2 (treatment B's non-high target: ɵ vs a, ø vs e).* P(V2 = ɵ) after **a** 0.414, after **u** 0.422 —
  identical; after **ɵ** 0.560. P(ø) after **y** 0.356 vs after **i** 0.477. So the treatment-B "rounding" O/E > 1
  (back 1.07, front 1.09) is reduced-after-reduced clustering (ɵ…ɵ, ø…ø), not rounding agreement: a rounded *full* V1
  does not raise the rate of a following reduced vowel.
- Results are unchanged on the native-only subset (no о ё ф ц щ ъ б г д ж з; `rounding_harmony_OE.csv`,
  `zheltov_native_types`).

**Typological contrast** (PBase rows, `pbase_rounding_rows.csv`):
- *Turkish:* four-way high-suffix harmony (i/y/ɨ/u; triggers u,o → u, y,ø → y) and stem-internal statements that unrounded vowels are
  followed by unrounded vowels and rounded vowels by rounded or low ones (A11107–A11116).
- *Kirghiz:* the same four-way high-suffix rule (A4907–A4910). Low suffix vowels also round, giving [o] after /o/ (A4911–A4912).
- *Eastern Mari:* suffix mid vowels three-way e/o/ø — [o] after u,o; [ø] after y,ø; [e] after i,e,a (rules 5541–5544).
  That is rounding harmony on **mid** vowels, which Chuvash does not have either.
- **Chuvash therefore lacks labial harmony in both of the forms its neighbours have.** It has neither the Turkic
  high-vowel type nor the Mari mid-vowel type. On this feature it is not Mari-like; the absence is a Chuvash/Bulgharic
  particularity.

**Confidence:** high for the absence of productive labial harmony; medium for the front-series attraction (small n in
Zheltov; halved in inflected forms).
**Caveats.** Orthographic data: ⟨ӑ ӗ⟩ may be phonetically labialised after rounded vowels (Savelyev 2020 says so) without
the spelling showing it. The written test cannot detect sub-phonemic rounding; the acoustic rounding tests
(`rounding_contrasts.csv`) are the place for that. ⟨у/ӳ⟩ in syllable 2 are often the backness-alternating deverbal suffix
-у/-ӳ, which is rounded by lexical specification. That is itself the diagnostic: a rounded suffix after unrounded stems
is what labial harmony forbids. The PBase Mari rows carry no `sources`, and `pb_languages.csv` gives the Mari
reference as Harms (1962) *Estonian Grammar*. That looks like a PBase metadata error, so treat the PBase Mari rows as
unverified until checked against Sebeok & Ingemann or Kangasmaa-Minn.
**Files:** `rounding_harmony_OE.csv`, `rounding_by_trigger.csv`, `rounding_harmony_vowel_pairs_syl1_syl2.csv`,
`pbase_rounding_rows.csv`; scripts `01_rounding_harmony.py`, `01b_rounding_by_trigger.py`, `01a_pbase_rounding_rows.py`.

---

## Q2. Functional load of the vowel contrasts, and what it says about the 5- vs 6-full-vowel inventory

**Method.** Entropy-based functional load, FL(x,y) = [H(L) − H(L with x = y)] / H(L), where H is the entropy of the
token-frequency distribution over word types (Hockett's measure as formulated by Surendran & Niyogi). The measure is
computed on IPA segment strings, so ⟨ы⟩ = ʉ, ⟨ӑ⟩ = ɵ, ⟨ӗ⟩ = ø, ⟨ӳ⟩ = y whatever script was typed. Sets: mono_dict
(13,139 types, tokens as weights; primary), mono_freq5 (sensitivity, 116k types incl. inflected forms) and Zheltov
(type-uniform). Minimal pairs are counted on Zheltov types (deduplicated on IPA) and mono_dict. Six consonant contrasts
are included for scale.
*Homoglyphs:* the leveled tables are already folded at load. A census of non-Cyrillic letters finds 3 Latin ⟨c⟩ in
Zheltov labels and none in mono_dict (`fl_homoglyph_census.csv`). Folding ă/ĕ/ç changed 0 types and created 0 duplicates.

**Answer.** The full–reduced contrasts of the low/mid series carry the most load among the reduced-vowel contrasts:
a/ɵ (FL 0.0052; 1,277 Zheltov minimal pairs) and e/ø (0.0010; 292). In absolute terms ⟨ы⟩ /ʉ/ and ⟨ӳ⟩ /y/ have the
lowest loads, comparable to or below consonant contrasts such as ʃ/s, because they are the two rarest vowels
(876 and 1,035 occurrences in Zheltov vs 16,863 for a). **Normalised for rarity, /ʉ/ is not marginal.** It has 94 (u/ʉ)
and 96 (ɵ/ʉ) Zheltov minimal pairs per 1,000 occurrences, as many as a/ɵ (105), so ⟨ы⟩ contrasts robustly with both
⟨у⟩ and ⟨ӑ⟩. **FL cannot decide the inventory question.** It measures how much a distinction is used, not which
prosodic class a vowel belongs to. What it does constrain:
1. /ʉ/ is neither an allophone of /u/ nor a variant of /ɵ/. Both contrasts are robust per occurrence.
2. Under the 5-vowel analysis (ʉ reduced), the reduced series would have a height contrast (ɵ vs ʉ) on the back side
   only, carried by 84 minimal pairs, with no front counterpart (ø vs a high front reduced vowel does not exist). That
   asymmetry is a structural cost the 5-vowel analysis has to accept. The 6-vowel analysis (ʉ full, paired with y as
   the two rare high vowels) has no such cost. The point is suggestive, not decisive.
3. /y/ ⟨ӳ⟩ (reduced under inventory 4) has the same profile as /ʉ/: rare (FL u/y 0.00028, i/y 0.00029) but
   contrastive per occurrence (43–83 minimal pairs per 1,000). Rarity therefore does not single out ⟨ы⟩.

**Key numbers** (`functional_load_summary.csv`; FL mono_dict / mono_freq5 / Zheltov; minimal pairs Zheltov):
| contrast | FL mono_dict | FL mono_freq5 | FL Zheltov | MP Zheltov | MP per 1,000 rarer V |
|---|---|---|---|---|---|
| a/e | 0.0080 | 0.0041 | 0.0010 | 71 | 10.5 |
| a/u | 0.0060 | 0.0040 | 0.0029 | 363 | 82.8 |
| a/ɵ | 0.0052 | 0.0041 | 0.0104 | 1,277 | 105.0 |
| u/ɵ | 0.0021 | 0.0021 | 0.0021 | 280 | 63.8 |
| ø/ɵ | 0.0017 | 0.0013 | 0.0016 | 90 | 13.9 |
| e/ø | 0.0010 | 0.0023 | 0.0023 | 292 | 45.1 |
| e/i | 0.0009 | 0.0029 | 0.0006 | 76 | 21.1 |
| u/ʉ | 0.0008 | 0.0006 | 0.0006 | 82 | 93.6 |
| y/ø | 0.0005 | 0.0007 | 0.0006 | 86 | 83.1 |
| ɵ/ʉ | 0.0004 | 0.0004 | 0.0006 | 84 | 95.9 |
| u/y | 0.0003 | 0.0004 | 0.0004 | 45 | 43.5 |
| i/ʉ | 0.0002 | 0.0002 | 0.0001 | 15 | 17.1 |
Consonant scale (mono_dict): l/r 0.0037, p/t 0.0032, t/k 0.0022, s/ɕ 0.0013, ʃ/s 0.0007, tʲ/t 0.0001 (`functional_load.csv`).
Backness contrasts (a/e, i/ʉ, ø/ɵ) have few minimal pairs per occurrence, because harmony limits them mostly to
monosyllables.

**Confidence:** medium for the rankings and the rarity-normalised conclusion. **Not assessed** as evidence for either
inventory: FL is not a test of prosodic class.
**Caveats.** The bootstrap CIs in `functional_load.csv` resample tokens. With millions of tokens they are
uninformatively narrow (±1%) and omit lexical sampling error. The honest uncertainty is the spread across the three
sets. Ranks at the top (a/ɵ, a/u, u/ɵ) are stable, but a/e moves by a factor of 8 between sets: it is
monosyllable-driven, so high-frequency function words dominate the token-weighted value. mono_dict is Zheltov's
vocabulary and is therefore not independent of it. The minimal-pair count makes no distinction between lexical and
inflectional pairs. Loan-vowel types (/o/) were excluded.
**Files:** `functional_load.csv`, `functional_load_summary.csv`, `minimal_pairs_vowels.csv`, `fl_vowel_counts.csv`,
`fl_homoglyph_census.csv`; scripts `02_functional_load.py`, `02b_fl_normalised.py`.

---

## Q3. Is there an OCP-Place restriction on consonants across a vowel?

**Method.** Frisch, Pierrehumbert & Broe (2004)-style O/E for C1 V C2 sequences, i.e. consonants separated by exactly
one vowel, with no cluster on either side. Place classes: LAB {p m ʋ}, COR_OBS {t s ʃ ɕ tɕ ts tʃ}, COR_SON {l r n},
DOR {k x}, PAL {j}. Palatalisation is ignored. Expected counts come from the row × column marginals. Two scopes:
(i) every C V C in the word; (ii) the word-initial #C V C only, which is almost always root-internal and so removes
cross-morpheme pairs. CIs: Poisson bootstrap over types (400 reps for scope i, 1,000 for scope ii). The homorganic cells
are split into identical vs non-identical consonants. Stops (p t k) are split into homorganic (necessarily identical
here) vs heterorganic.

**Answer. Yes. Chuvash has a strong, gradient OCP-Place effect of the Arabic type.** Homorganic pairs are
under-represented in every place class and heterorganic pairs sit near or above 1. The effect is strongest for
labials (O/E ≈ 0.13–0.17), then dorsals (0.26–0.44), and weakest for coronals. Coronal obstruents and coronal
sonorants behave as **separate** classes: COR_OBS × COR_SON ≈ 1.0–1.2, the same subclass split reported for Arabic.
Identical homorganic stops are avoided: O/E 0.75 [0.70, 0.79] against 0.97 for heterorganic stops in Zheltov.
In the full-word scope, identical coronal obstruents are not avoided (identical 0.99 vs non-identical 0.47), and
this is the only class where identity is exempt. Suffix consonants (e.g. t…t across a morpheme boundary) are the
likely source. The root-initial scope was not split by identity, so that explanation is untested (**not assessed**).

**Key numbers** (`ocp_place_OE.csv`, `ocp_place_OE_initialCVC.csv`):
| homorganic O/E [95% CI] | all CVC, Zheltov (42,852 pairs, 18,978 types) | initial #CVC, Zheltov (15,773) | initial #CVC, mono_freq5 (92,903) |
|---|---|---|---|
| LAB | 0.17 [0.15, 0.20] | 0.13 [0.10, 0.15] | 0.15 [0.14, 0.16] |
| DOR | 0.26 [0.23, 0.30] | 0.44 [0.38, 0.50] | 0.34 [0.32, 0.37] |
| COR_OBS | 0.61 [0.58, 0.63] | 0.65 [0.62, 0.68] | 0.68 [0.67, 0.70] |
| COR_SON | 0.80 [0.78, 0.81] | 0.55 [0.48, 0.61] | 0.58 [0.55, 0.60] |
| PAL (j…j) | 0.49 [0.29, 0.71] | 0.29 [0.15, 0.44] | 0.09 [0.06, 0.13] |
Heterorganic cells range from 0.75 to 1.76; most fall between 1.0 and 1.5. Stops in all-CVC Zheltov: identical homorganic
0.75 [0.70, 0.79] vs heterorganic 0.97 [0.93, 1.00]. In mono_dict the figures are 0.62 vs 1.06, and in mono_freq5 0.71 vs 1.08.
Among coronal sonorants the identical pairs (r…r, l…l, n…n) drive the effect: identical 0.12 vs non-identical 1.10
in all-CVC Zheltov.

**Typological reading.** Similar-place avoidance is a near-universal statistical tendency (Pozdniakov & Segerer 2007;
see bibliography). Its presence therefore says nothing about Turkic vs Volga-Kama affiliation, and it is not evidence
for the areal-overlay hypothesis in either direction. What is worth reporting is the profile: labials strongest,
coronals weakest, and sonorant vs obstruent coronals split into separate classes. That profile matches the
Arabic/Muna pattern, and it is a new descriptive fact for Chuvash, which none of the retrieved sources mentions.

**Confidence:** high (consistent across 4 type sets and 2 scopes; CIs tight).
**Caveats.** These are orthographic/IPA type counts, not root lists. The all-CVC scope mixes in suffix consonants,
and the root-initial scope is the cleaner one. Expected counts are marginal-based, with no correction for position
or syllable structure. The crude loan flag removes only 6 Zheltov types (the transliteration maps б д г onto p t k),
so loans are effectively included. No comparable Mari or Turkic O/E figures were computed, because PBase does not
encode co-occurrence statistics; a cross-language comparison is **not assessed**.
**Files:** `ocp_place_OE.csv`, `ocp_place_OE_initialCVC.csv`, `ocp_segment_OE_zheltov_native.csv`,
`ocp_segment_counts_zheltov_native.csv`; scripts `03_ocp_place.py`, `03b_ocp_initial_cvc.py`.

---

## Q4. Is the Mari–Chuvash stress parallel real, and what do the sources say about the all-reduced default?

**Method.** web_search for primary and secondary statements, with every DOI checked against CrossRef
(`crossref_verified.csv`: 51 DOIs looked up directly, 49 resolving, 2 returning 404. The two failures are Savelyev 2014 and Protassova et al. 2014, both listed in `unverified_leads.md`. One resolving DOI was dropped as the wrong paper. Metadata recorded). "Verified" below means one of
two things. Either the bibliographic record resolves on CrossRef, or, for works with no DOI, a stable URL to the
full text was retrieved. For a claim about content, I record whether the claim was read in the work itself or in a
secondary source quoting it.

**Answer.**
1. **The parallel is real for Eastern/Meadow Mari and standard Chuvash under Rule A.** Gordon (2011, Blackwell
   Companion ch. 39, DOI verified; content read in the chapter PDF) states that Eastern Mari stress falls on the rightmost
   full (non-schwa) vowel in monomorphemic roots, and otherwise on the initial syllable in non-derived words with only
   reduced vowels. He cites Vaysman (2009: 62–64). For Chuvash, Schiering & van der Hulst (2010, DOI verified; content read)
   classify the system as LAST/FIRST with full vowels counting as heavy, citing Krueger 1961 and Hayes 1995. They
   suggest Chuvash may owe its quality-sensitive stress to its Uralic neighbours, possibly through mutual Chuvash–Cheremis influence.
   This is the shape of the project's Rule A.
2. **Mari is not uniform. The variety in western Mari El has a different default.** Walker (ROA-172 PDF, no DOI;
   content read) cites Itkonen (1955: 28) and Hayes (1995: 297) for *Western* Cheremis (Hill Mari): stress falls on the
   rightmost non-final strong syllable, and if there is none, on the rightmost non-final syllable even when the final
   syllable is strong. That is a default-to-same, non-final system, unlike Chuvash in two respects. Chuvash allows final
   stress (Rule A/B both stress a final full vowel), and its default is not the penult. Walker also lists *Eastern* Cheremis as having
   stress variants, one of which (rightmost strong non-final, else leftmost) resembles Classical Arabic. So "Mari =
   Rule A" holds only for the Meadow/Eastern standard, and even there with a non-finality variant.
3. **The stressless default (Rule B) has exactly one source, and it is Chuvash-internal.** Dobrovolsky (1999, ICPhS 14,
   pp. 539–542; no DOI; full-text PDF on the IPA site, content read) argues on acoustic grounds that Chuvash has **no
   default stress**. In his account the initial prominence of all-reduced words is an intonational downturn, and only last-full-vowel
   stress exists in the grammar. Hyman (2005 PhonLab report, DOI verified; published as Hyman 2006 *Phonology* 23,
   DOI verified) treats this as a possible counterexample to obligatory headedness. Kate's AMP handout (Lindsey,
   "Solving Chuvash stress with sonority-sensitive feet", URL retrieved) adopts the stressless analysis, citing
   Dobrovolsky. **No retrieved source describes a stressless default for any Mari variety.** On the
   literature, then, the Mari parallel supports Rule A's *shape* (rightmost full, else initial). It offers nothing for Rule B
   either way.
4. **Direction of influence is contested in the historical literature.** Agyagási (2019, *Chuvash Historical Phonetics*, DOI
   verified) proposes code-copying of vowel reduction in both directions: Late Proto-Mari first-syllable reduction
   copied from Middle Chuvash, and Middle Chuvash second-syllable reduction copied from Late Proto-Mari. This is
   known only from a secondary summary (a review excerpt on ResearchGate). The reviewer finds the bidirectional
   account unclear on the original motivation. Culver (2021, on Chuvash–Mari shared lexemes; ResearchGate, no DOI found)
   and Culver (2022, *FUF*, DOI verified) contest details. For the overlay hypothesis, the reduced-vowel system itself
   may be a joint Chuvash–Mari product rather than a Mari feature imposed on Chuvash.
5. **Corollary for Q1.** Gordon (2011), citing Vaysman (2009), describes Eastern Mari rounding harmony as propagating
   rightward *from the stressed vowel*: the 3sg possessive is [e] after an unrounded stressed vowel and [ø]/[o] after a
   rounded one. Chuvash has no counterpart (Q1). The two languages therefore share the stress algorithm but not the
   stress-controlled rounding harmony that Mari builds on it.

**What could not be verified** (`unverified_leads.md`):
- **Hayes (1995)**, *Metrical Stress Theory* (U. Chicago Press). No DOI on CrossRef. The p. 297 Cheremis discussion and
  the Chuvash classification are known only through Walker and Schiering & van der Hulst. Page numbers were not checked.
- **Kenstowicz (1994)** "Sonority-driven stress" (ms./ROA). Not found on CrossRef. **Kenstowicz (1997)** "Quality-sensitive
  stress", *Rivista di Linguistica* 9(1): 157–188 (no DOI; citation details from Dialnet/Semantic Scholar), reprinted
  2004 (DOI verified, pp. 191–201). The abstract says lower > higher and peripheral > central. **Whether it discusses Mari or
  Chuvash was not verified.**
- **Walker (1996)** "Prominence-driven stress" and "Mongolian stress, licensing, and factorial typology": ROA-172 PDFs retrieved,
  no DOI. *Caution:* the Wiley 2004 reader chapter "Unbounded Stress and Factorial Typology" (10.1002/9780470756171.ch10) is by
  **Baković**, not Walker. A first-pass CrossRef hit had suggested otherwise. Walker (2000) as a separate publication was not located.
- **de Lacy (2002)** dissertation (UMass; no DOI). **de Lacy (2004)** (*Phonology* 21: 145–199, verified) has as its empirical focus
  **Nganasan and Kiriwina**, not Mari or Chuvash (abstract read). de Lacy (2006, 2007) verified bibliographically, content
  regarding Mari not checked.
- **Vaysman (2009)** MIT dissertation (no DOI). Content known only via Gordon (2011) and Shih & de Lacy (2019).
- **Krueger (1961)** *Chuvash Manual*. No DOI. Bibliographic details (Indiana Uralic & Altaic Series 7) are not verified here.
- **Itkonen (1955)**, *Acta Linguistica Hungarica* 5: 21–34. Cited consistently by WALS and others, but not found on CrossRef.
- **Sebeok & Ingemann (1961)** *An Eastern Cheremis Manual*. Only reviews of it have DOIs (verified, but they are reviews).
- **Lehiste et al. (2005)** *Meadow Mari Prosody* (LU Suppl. 2): DOI verified. Its statements on the all-reduced
  default were not read.

**Confidence:** high that the Eastern Mari and Chuvash Rule-A descriptions match. Medium on dialect variation (Hill Mari
known only second-hand). High that no source found gives Mari a stressless default. That is a negative from a bounded
search (≈25 web searches, 80 CrossRef queries), so read it as "not found", not "does not exist".
**Caveats.** Gordon's wording ("monomorphemic roots", "non-derived words") implies a morphological condition in Mari that
the Chuvash rules do not have. This is worth checking in Vaysman before the parallel is stated without qualification.
The Hill Mari area (western Mari El, right bank of the Volga) is, by my geographic knowledge, the Mari area nearest
Chuvashia. If so, the closest contact variety is the one whose default differs. **This adjacency is not sourced here.**
**Files:** `crossref_verified.csv`, `crossref_hits.json`, `crossref_hits2.json`, `crossref_queries*.json`,
`unverified_leads.md`; scripts `04_crossref_lookup.py`, `04b_crossref_verify.py`.

---

## Q5. Verified annotated bibliography

**Answer.** `bibliography.md` and `bibliography.bib` contain **52 verified entries**. 48 were resolved by DOI (of 51 DOIs tried: 49 resolved; 2 returned 404 and went to the leads list; 1 resolving DOI was the wrong paper) on CrossRef,
with metadata copied from the record, not typed. 4 have no DOI and were verified by retrieving the document URL:
Dobrovolsky 1999 and 1995 (ICPhS), Walker ROA-172, and Kate's AMP handout. Each entry is tagged with the depth of
checking: 11 *content checked*, 1 *content via secondary source* (Agyagási 2019), 40 *record only*. Topics: Volga-Kama
Sprachbund (5), Chuvash historical phonology (2), Chuvash phonology/dialects (3), Chuvash stress (1), stress typology
incl. Mari/Rule B (16), Mari phonology (8), Turkic harmony/reduced vowels (6), rounding-harmony typology (3), Chuvash
sociolinguistics and bilingualism (3), methods/OCP (8). `unverified_leads.md` lists about 25 items that could not be
verified, among them Hayes 1995, Kenstowicz 1994/1997 (original), Vaysman 2009, Krueger 1961, Itkonen 1955, Sebeok &
Ingemann 1961, and Savelyev 2014 (DOI does not resolve on CrossRef).

**Gaps** (not found in a bounded search, not shown to be absent): an acoustic study of Chuvash–Russian bilingual phonetics;
an acoustic study of Tatar/Bashkir reduced vowels; any source giving a Mari variety a stressless default.

**Confidence:** high for bibliographic accuracy of the listed entries. Annotations marked *record only* describe
relevance, not content.
**Caveats.** Two corrections came out of verification. The Wiley reader chapter on unbounded stress is by Baković, not
Walker. The Oxford Guide "Mari" chapter is by Saarinen. A guessed DOI for Shih & de Lacy (2019) was wrong and has been
dropped. BibTeX keys are machine-generated (`Surname+year_key`). CrossRef's capitalisation was kept as given
(e.g. an all-caps Van Pareren title).
**Files:** `bibliography.md`, `bibliography.bib`, `unverified_leads.md`, `crossref_verified.csv`; script
`05_build_bibliography.py`.

---

## Synthesis for the overarching hypothesis (Turkic base + Volga-Kama/Mari overlay)

- **Against a Mari overlay in harmony:** Chuvash has neither Turkic high-vowel labial harmony nor the stress-controlled
  mid-vowel rounding harmony of Eastern Mari (Q1). Its backness-only harmony is Turkic in kind; the loss of labial harmony
  is a Bulgharic particularity, not a Mari feature.
- **For the overlay in stress, with a qualification:** the full/reduced stress algorithm matches Meadow/Eastern Mari (Q4).
  But Hill Mari has a different default, and the historical literature (Agyagási 2019) treats reduction as a two-way
  Chuvash↔Mari exchange. The project's Rule A vs Rule B question cannot be settled from Mari. The only Rule-B source
  is Chuvash-internal (Dobrovolsky 1999).
- **Neutral:** OCP-Place (Q3) is near-universal. Functional load (Q2) does not adjudicate the inventory question,
  though it shows ⟨ы⟩ is a robust, rare phoneme, not a marginal one.
