# Sonority in Chuvash: a correction, and the measurement that works

**This supersedes `sonority_note.md` v1 on its central conclusion.** v1 said
rule SON's tiers were "a height hierarchy refined by reducedness" and that the
refinement was circular, because full-versus-reduced is established in this
project from stress behaviour. **That was wrong, and the error was mine.**

## 1. What I got wrong

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

## 2. What is peripherality based on phonetically, and can it be measured?

A peripheral vowel sits at the **edge** of the vowel space; a central vowel sits
inside it. That is formant geometry, so it is directly measurable. Which
operationalisation you choose turns out to decide the answer, so three were
tried, on the **rule-neutral unstressed set** — the 315,531 tokens all six
stress rules agree are unstressed, from the 9 speakers who have all eight
vowels at n ≥ 20. Using only unstressed tokens is essential rather than
fastidious: stressed vowels are hyperarticulated and therefore more peripheral,
so measuring on all tokens would let the stress pattern into the measure meant
to be independent of it. Neither F1 nor F2 is used anywhere in this project as
a correlate of stress.

| vowel | de Lacy | centroid distance | backness deviation | % on convex hull | F1 (z) |
|---|---|---|---|---|---|
| /a/ ⟨а⟩ | low periph | 1.245 | 0.550 | **100.0** | +0.720 |
| /e/ ⟨е⟩ | mid periph | 0.666 | 0.644 | **88.9** | −0.508 |
| /i/ ⟨и⟩ | high periph | 0.946 | 0.787 | **100.0** | −0.872 |
| /u/ ⟨у⟩ | high periph | 0.897 | 0.867 | **100.0** | −0.597 |
| /y/ ⟨ӳ⟩ | high periph | 0.730 | 0.470 | **66.7** | −0.898 |
| /ɵ/ ⟨ӑ⟩ | mid central | 0.712 | 0.631 | 11.1 | −0.080 |
| /ø/ ⟨ӗ⟩ | mid central | 0.265 | 0.212 | 11.1 | −0.274 |
| /ʉ/ ⟨ы⟩ | high central | 0.258 | 0.151 | 11.1 | −0.551 |

| measure | separates peripheral from central? | clean per speaker |
|---|---|---|
| distance from the vowel-space centroid | **no** — overlap of −0.046; /e/ and /ɵ/ swap | 1 of 9 |
| backness deviation \|F2 − centroid\| | **no** — overlap of −0.161 | 0 of 9 |
| **convex-hull membership** | **yes** — 66.7–100% vs 11.1%, gap 55.6 points | 3 of 9 |

**Convex-hull membership works, and it is also the formally correct reading of
"peripheral":** a vowel at the edge of the space is a vertex of its convex
hull. The hull of the Chuvash vowel space is `{a, u, y, i, e}` — precisely de
Lacy's peripheral set — with `{ø, ɵ, ʉ}` inside it.

Both failures are driven by the same two vowels, and neither involves ⟨ӗ⟩.

**Centroid distance** puts ⟨ӑ⟩ /ɵ/ at 0.712 above /e/ at 0.666, so the two
classes overlap by −0.046 and the pair swaps. The centroid of an eight-vowel
inventory sits wherever the inventory is densest: Chuvash has four front
vowels, which pulls it forward and deflates /e/'s distance, while ⟨ӑ⟩ sits
alone in the low-back region and gets an inflated one.

**Backness deviation** overlaps by −0.161, and the boundary cases are again
⟨ӑ⟩ and one peripheral vowel — here /y/, the *lowest* peripheral value at
0.470, against ⟨ӑ⟩ as the highest central at 0.631. This measure collapses the
F1 dimension entirely, so /y/ (front but high, |F2 − centroid| only 0.470) is
indistinguishable from a central vowel with a moderately displaced F2. ⟨ӗ⟩ at
0.212 is not implicated in either overlap; it is comfortably inside the central
range on both measures.

What this means for the paper is that "peripheral" has to be defined as
position at the *edge of the two-dimensional space*, not as displacement along
either axis on its own. Hull membership does that; the other two do not.

**Height is recovered perfectly by F1, 8 of 8**, within both classes:
peripheral a(low) > e(mid) > u, i, y(high); central ɵ(mid) > ø(mid) > ʉ(high).

## 3. The whole hierarchy, reconstructed from formants alone

Splitting on hull membership and then ranking by F1 within each class
reconstructs **all five tiers for all eight vowels, Spearman ρ = +1.000**
(`sonority_delacy_test.csv`). No reference to stress, duration, intensity or f0
enters the reconstruction.

So the answer to your question is yes: the classic hierarchy is measurable in
this data, and Chuvash instantiates it exactly.

## 4. What this does to the rule comparison

It rehabilitates the result in `sonority_rule_tests.csv` rather than changing
the numbers. On the conflict subset (61,630 polysyllabic word tokens, 145,077
vowels, 9,725 word types, utterance edge and vowel identity controlled):

| hierarchy | duration β | % | ΔAIC |
|---|---|---|---|
| **SON** = the de Lacy hierarchy | +0.0453 | **+4.64** | 330 |
| height alone | −0.0009 | −0.09 | 758 |
| F1/aperture ranking alone | −0.0057 | −0.57 | 753 |
| duration-derived (circular) | +0.0637 | +6.58 | 0 |

v1 read "height alone predicts nothing" as evidence against a sonority
account. The correct reading is the opposite: **height alone is not the
hierarchy.** One dimension of a two-dimensional scale should not be expected to
work, and it doesn't. The two-dimensional hierarchy does, at +4.64% — and it is
now grounded in a measurement that never sees stress.

The one comparison still to make is against B5 on this same subset, since SON
and B5 differ on 17.7–18.8% of word tokens. From `rule_conflict_models.csv`,
SON led on duration there too (+2.61% against B5's +0.56%, ΔAIC 80). What the
peripherality result adds is a reason to prefer SON's *formulation*: its tiers
are independently motivated, whereas B5's full/reduced partition is stipulated.

## 5. Limits

- **9 speakers.** Only nine have all eight vowels at n ≥ 20, and one of them is
  Chuvash Voice's single dominant voice supplying most tokens. The aggregate
  separation is clean; the per-speaker replication is not — hull membership
  separates the two classes with no overlap in only **3 of 9** speakers. The
  aggregate result is what the table reports and it should be presented as
  such, not as a within-speaker universal.
- **/y/ is the weak point**, on the hull in 66.7% of speakers against 100% for
  /a i u/. With 2,998 tokens it is also the rarest peripheral vowel. If /y/
  were reclassified as central the hierarchy would change, and this corpus
  cannot rule that out firmly.
- **The hull is computed on eight points in two dimensions**, where typical
  hulls have 4–6 vertices. "On the hull" is therefore a minority status by
  construction, which is what makes 11.1% for the central vowels unsurprising
  and 66.7–100% for the peripheral ones meaningful — but it also means the
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
   and 3-of-9 caveats stated plainly. This is the part reviewers will press on,
   and it is better to bound it yourself.
3. Report that height recovers 8 of 8 and that the full tier structure recovers
   at ρ = 1.00.
4. Keep the SON-versus-B5 comparison on the conflict subset as the empirical
   test, and present SON's advantage as being about *formulation* — independently
   motivated tiers versus a stipulated partition — as much as about fit.
