# Sonority in Chuvash: a correction, and the measurement that works

**v4, 2026-09-29.** v3 stands on its main point — the classic hierarchy is
measurable here and Chuvash instantiates its peripheral/central split cleanly —
but four of its numbers were wrong or threshold-assisted, and its claim about
SON's *fit* against B5 does not survive. Everything below is read back from the
regenerated CSVs. The changelog is at the end.

**v1 (superseded on its central conclusion)** said rule SON's tiers were "a
height hierarchy refined by reducedness" and that the refinement was circular,
because full-versus-reduced is established in this project from stress
behaviour. That was wrong, and the error was mine.

## 1. What I got wrong in v1

SON's tiers are

> a > e > {i y u} > {ø ɵ} > ʉ

v1 correctly observed that these depart from pure vowel height on exactly three
vowels — /e/ split from /ø ɵ/ (all mid), /ʉ/ split from /i y u/ (all high) — and
then inferred that the departure *was* the full/reduced distinction. It is not.
The departure is **peripherality**, the second dimension of the standard
vocalic sonority hierarchy:

> low peripheral > mid peripheral > high peripheral > mid central > high central

(de Lacy 2002, 2004, 2006; Kenstowicz 1997; Gordon 2006.) Mapped onto the
Chuvash inventory that hierarchy *is* SON, exactly:

| tier | de Lacy class | Chuvash |
|---|---|---|
| 1 | low peripheral | /a/ ⟨а⟩ |
| 2 | mid peripheral | /e/ ⟨е⟩ |
| 3 | high peripheral | /i y u/ ⟨и ӳ у⟩ |
| 4 | mid central | /ø ɵ/ ⟨ӗ ӑ⟩ |
| 5 | high central | /ʉ/ ⟨ы⟩ |

So SON is not an ad hoc partition and not the full/reduced split wearing a
different hat. It is a published, independently motivated hierarchy applied to
this inventory. That the tier-3/tier-4 boundary happens to coincide with
Chuvash's full/reduced split is a **substantive claim about Chuvash**, not a
circularity — and it is the interesting claim, because it says the language's
phonological vowel classes fall where the universal sonority scale predicts.

## 2. What peripherality is, and whether it can be measured here

A peripheral vowel sits at the **edge** of the vowel space; a central vowel sits
inside it. That is formant geometry, so it is directly measurable. Which
operationalisation you choose decides the answer, so three were tried, on the
**rule-neutral unstressed set** — tokens every candidate stress rule agrees are
unstressed, from the 9 speakers with all eight vowels at n ≥ 20. Using only
unstressed tokens is essential rather than fastidious: stressed vowels are
hyperarticulated and therefore more peripheral, so measuring on all tokens
would let the stress pattern into the measure meant to be independent of it.
Neither F1 nor F2 is used anywhere in this project as a correlate of stress.

**Which rules belong in that intersection is a real choice, and it is now made
explicitly and reported both ways.** Intersecting over the six A/B rules only
(`AB_only`, 280,871 tokens) keeps the measurement clear of the sonority tiers
themselves, since A and B refer to a full/reduced partition rather than to
tiers. Intersecting over all nine (`all_rules`, 244,277 tokens) is stricter but
introduces exactly the circularity `AB_only` avoids: a SON rule stresses the
most sonorous vowel in the word, so excluding its targets removes tokens in a
way correlated with the hierarchy being measured. **It makes no difference** —
every figure below is identical under the two definitions, which is the best
available answer to the worry.

| vowel | de Lacy | centroid distance | backness deviation | % on convex hull | F1 (z) |
|---|---|---|---|---|---|
| /a/ ⟨а⟩ | low periph | 1.260 | 0.554 | **100.0** | +0.779 |
| /e/ ⟨е⟩ | mid periph | 0.697 | 0.674 | **77.8** | −0.478 |
| /i/ ⟨и⟩ | high periph | 0.941 | 0.770 | **100.0** | −0.839 |
| /u/ ⟨у⟩ | high periph | 0.900 | 0.866 | **100.0** | −0.563 |
| /y/ ⟨ӳ⟩ | high periph | 0.726 | 0.464 | **88.9** | −0.862 |
| /ɵ/ ⟨ӑ⟩ | mid central | 0.708 | 0.630 | 11.1 | −0.042 |
| /ø/ ⟨ӗ⟩ | mid central | 0.260 | 0.205 | 11.1 | −0.238 |
| /ʉ/ ⟨ы⟩ | high central | 0.243 | 0.138 | 0.0 | −0.474 |

(`AB_only`; `sonority_peripherality.csv` carries both sets.)

| measure | separates peripheral from central? | clean per speaker |
|---|---|---|
| distance from the vowel-space centroid | **no** — overlap of −0.011; /e/ and /ɵ/ swap | 3 of 9 |
| backness deviation \|F2 − centroid\| | **no** — overlap of −0.166 | 0 of 9 |
| **convex-hull membership** | **yes** — 77.8–100% vs 0–11.1%, gap **66.7** points | **5 of 9** |

**Convex-hull membership works, and it is also the formally correct reading of
"peripheral":** a vowel at the edge of the space is a vertex of its convex
hull. The hull of the Chuvash vowel space is `{a, u, y, i, e}` — precisely de
Lacy's peripheral set — with `{ø, ɵ, ʉ}` inside it.

Both failures are driven by the same two vowels, and neither involves ⟨ӗ⟩.

**Centroid distance** puts ⟨ӑ⟩ /ɵ/ at 0.708 above /e/ at 0.697, so the two
classes overlap and the pair swaps. The centroid of an eight-vowel inventory
sits wherever the inventory is densest: Chuvash has four front vowels, which
pulls it forward and deflates /e/'s distance, while ⟨ӑ⟩ sits alone in the
low-back region and gets an inflated one. The overlap is small (−0.011) but it
is an overlap, and it falls on the class boundary, which is the only place it
matters.

**Backness deviation** overlaps by −0.166, and the boundary cases are again
⟨ӑ⟩ and one peripheral vowel — here /y/, the *lowest* peripheral value at
0.464, against ⟨ӑ⟩ as the highest central at 0.630. This measure collapses the
F1 dimension entirely, so /y/ (front but high) is indistinguishable from a
central vowel with a moderately displaced F2. ⟨ӗ⟩ at 0.205 is not implicated in
either overlap; it is comfortably inside the central range on both measures.

What this means for the paper is that "peripheral" has to be defined as
position at the *edge of the two-dimensional space*, not as displacement along
either axis on its own. Hull membership does that; the other two do not.

## 3. The hierarchy reconstructed from formants alone

Both thresholds that used to enter this reconstruction are gone. The
peripheral/central split is now taken at the **largest gap** in the sorted hull
percentages (it lands at 44.4%), and height is tested as what de Lacy actually
predicts — an **ordering** within each class — rather than as membership in
three bins with hand-chosen F1z break points.

| what is recovered | result |
|---|---|
| peripherality class | **8 of 8 vowels** |
| height ordering within the peripheral class | Spearman ρ = **+0.894** |
| height ordering within the central class | Spearman ρ = **+0.866** |
| whole five-tier hierarchy | Spearman ρ = **+0.970** |

No reference to stress, duration, intensity or f0 enters the reconstruction.

Two cautions on reading this. First, **ρ = +0.970, not +1.000** — v3's perfect
figure came from height bins whose break points had been set against one
particular labelling of the data, so part of the "recovery" was fitted. Second,
do not read the exact-tier-match count (3 of 8) as a score: the reconstruction
is built from a continuous F1z and so takes eight distinct values, while de
Lacy's tiers are tied (/i y u/ are all tier 3, /ø ɵ/ both tier 4). A tied
target cannot be matched exactly by an untied reconstruction; the rank
correlation is the only interpretable summary.

Within the peripheral class the measured F1 order is a > e > u > i > y, so /u/
ranks above /i y/. de Lacy puts all three in one tier, so this is a within-tier
ordering the hierarchy does not predict, not a failure of it — back high vowels
having somewhat higher F1 than front high vowels is ordinary.

So the answer to your question is yes, with a qualification: the **peripherality
dimension** — the part that is not aperture, and the part you were right to
press on — is recovered cleanly and is robust to how the rule-neutral set is
defined. The height dimension is recovered as an ordering at ρ ≈ +0.87–0.89
rather than exactly.

## 4. What this does to the rule comparison

Here v3 was too generous to SON, and the correction matters.

On the **conflict subset** (61,125 of 256,239 polysyllabic word tokens, 23.9%;
144,064 vowels, 9,714 types), SON beats the alternative hierarchies as a stress
rule, which is v3's point and it still holds (`sonority_rule_tests.csv`):

| hierarchy | duration β | % | ΔAIC |
|---|---|---|---|
| duration-derived (circular) | +0.0632 | +6.52 | 0 |
| **SON** = the de Lacy hierarchy | +0.0440 | **+4.50** | 332 |
| intensity-derived | +0.0179 | +1.81 | 674 |
| F1/aperture ranking alone | −0.0068 | −0.68 | 728 |
| height alone | −0.0013 | −0.13 | 736 |

v1 read "height alone predicts nothing" as evidence against a sonority account.
The correct reading is the opposite: **height alone is not the hierarchy.** One
dimension of a two-dimensional scale should not be expected to work, and it
doesn't. The two-dimensional hierarchy does.

**But SON does not beat B5.** v3 said "SON led on duration there too (+2.61%
against B5's +0.56%, ΔAIC 80)", citing `rule_conflict_models.csv` — a file
computed from surviving-row stress labels and now retired. From
`full_word_rule_models.csv`, which uses the pipeline's full-word labels:

| subset | controls | duration ranking (ΔAIC) |
|---|---|---|
| all words | vowel_label | **B5 0** · B4 71 · B6 209 · SON-B 272 · A4 678 · A5 695 · SON-F 734 · A6 777 · SON-A 779 |
| all words | vowel_height | **B5 0** · B4 88 · B6 526 · A4 1912 · A5 1953 · A6 2129 · SON-B 3144 · SON-F 4268 · SON-A 4799 |
| conflict subset | vowel_label | **SON-A 0** · SON-B 6 · A4 182 · B4 206 · B5 206 · A5 222 · A6 268 · B6 299 · SON-F 305 |
| conflict subset | vowel_height | **B5 0** · B6 54 · B4 119 · SON-B 156 · A4 301 · A5 341 · A6 434 · SON-A 806 · SON-F 979 |

B5 is first in three of the four, and it is the only rule whose effect clears
the 10 ms duration JND on the full data (+10.03 ms with vowel identity
controlled, +13.62 ms with vowel height). SON leads in exactly one cell — the
conflict subset under `vowel_label` — and that is also the one ranking that is
unstable between control sets (the two orderings correlate at ρ = +0.083; see
`script_currency_audit.md`). On intensity A6 is first in all four, every SON
rule is last or near-last, and SON-F's coefficient on the conflict subset is
*negative* (−0.55 dB): its designated syllable is quieter, not louder.

**So SON's case cannot be made on fit.** It has to be made on formulation: its
tiers are independently motivated and measurable in this corpus, whereas B5's
full/reduced partition is stipulated. That is a real argument, and the
peripherality result is what backs it — but it should be stated as an argument
about the shape of the analysis, not as a claim that SON predicts the acoustics
better. It does not.

## 5. Limits

- **9 speakers.** Only nine have all eight vowels at n ≥ 20, and one of them is
  Chuvash Voice's single dominant voice supplying most tokens. The aggregate
  separation is clean; the per-speaker replication is partial — hull membership
  separates the two classes with no overlap in **5 of 9** speakers. The
  aggregate result is what the table reports and it should be presented as
  such, not as a within-speaker universal.
- **/e/ is now the weak point**, on the hull in 77.8% of speakers against 100%
  for /a i u/ and 88.9% for /y/. (v3 named /y/ at 66.7%; with corrected labels
  /y/ rises to 88.9% and /e/ falls.) /y/ remains the rarest peripheral vowel at
  3,269 rule-neutral tokens, and /ʉ/ the rarest central at 5,966.
- **The hull is computed on eight points in two dimensions**, where typical
  hulls have 4–6 vertices. "On the hull" is therefore a minority status by
  construction, which is what makes 0–11.1% for the central vowels unsurprising
  and 77.8–100% for the peripheral ones meaningful — but it also means the
  measure is coarse, and a continuous version (distance to the hull boundary)
  would be a better instrument.
- **F3 is ignored.** Rounding lives partly in F3 and ⟨ӳ⟩/⟨ӗ⟩ are rounded, so a
  three-dimensional hull might classify differently.
- The de Lacy classes were assigned by me from the standard descriptions, not
  derived. The test is whether the *measurements* recover those classes, which
  they do — but the class labels are an input.

## 6. What I would put in the paper

1. State the hierarchy with its citations, note that it maps onto the Chuvash
   inventory to give exactly five tiers, and say that this is a prediction
   rather than a stipulation.
2. Report the hull measurement as the phonetic grounding, with the 9-speaker
   and 5-of-9 caveats stated plainly, and say explicitly that the two other
   operationalisations fail. This is the part reviewers will press on, and it is
   better to bound it yourself.
3. Report peripherality as recovered 8 of 8 and the whole hierarchy at
   ρ = +0.970, threshold-free. Do not claim a perfect reconstruction.
4. Do **not** claim SON fits better than B5. Report B5 as the best-fitting rule
   on duration over the full data, note that it is the only candidate clearing
   the duration JND, and make SON's case as one about the formulation of the
   rule rather than its fit — with the peripherality measurement as the reason
   the formulation is available at all.

## Changelog from v3

| v3 said | v4 says | why |
|---|---|---|
| rule-neutral set = 315,531 tokens, six rules | 280,871 (`AB_only`) / 244,277 (`all_rules`) | old figure used surviving-row stress labels; rule set is now an explicit, reported choice |
| hull gap 55.6 points, clean in 3 of 9 | gap **66.7**, clean in **5 of 9** | corrected labels; the hull result got stronger |
| height recovered 8 of 8 | ordering, ρ = +0.894 / +0.866 | the 8/8 depended on F1z break points tuned to the old labels |
| whole hierarchy ρ = +1.000 | ρ = **+0.970** | same; the reconstruction is now threshold-free |
| /y/ is the weak point at 66.7% on the hull | **/e/** at 77.8%; /y/ rises to 88.9% | corrected labels |
| SON led B5 on duration (+2.61% vs +0.56%, ΔAIC 80) | **B5 leads SON** in three of four subset × control combinations | v3 cited `rule_conflict_models.csv`, since retired for surviving-row labels |
| SON +4.64%, ΔAIC 330 vs other hierarchies | +4.50%, ΔAIC 332 | re-run on corrected labels; conclusion unchanged |
