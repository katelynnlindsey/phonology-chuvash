"""Step 5. Build bibliography.md (annotated), bibliography.bib (CrossRef-verified DOIs + URL-verified no-DOI items),
from crossref_verified.csv plus hand-written annotations. Metadata (authors, title, year, container, pages) are copied
from CrossRef, not typed. 'read' = content statement checked in the text or a retrieved excerpt; 'record' = only the
bibliographic record verified."""
import os, re, html, pandas as pd
OUT = "/Users/kate/Documents/GitHub/phonology-chuvash/9-analyze/output/overnight_2026-10-01/typology_literature"
V = pd.read_csv(os.path.join(OUT, "crossref_verified.csv"), dtype=str).fillna("")
V = V[V.status == "found"].drop_duplicates("doi").set_index("key")
DROP = {"shih_delacy2019": "DOI guessed for Shih & de Lacy 2019 resolves to a different CatJL paper (D'Alessandro)"}
# topic, check level, annotation
A = {
 "savelyev2020": ("Chuvash phonology / dialects", "read", "Standard reference description of Chuvash. Suffixes alternate by backness only (/a/–/e/, /ə̂/–/ə/, /u/–/ü/). Standard Chuvash has no rounded/unrounded opposition in non-initial reduced vowels, though they may labialise after rounded vowels. Viryal and many Anatri varieties keep rounded vs unrounded reduced vowels. Bears on Q1 and on dialect variation."),
 "agyagasi2019": ("Volga-Kama / Chuvash historical phonology", "secondary", "Monograph on Chuvash historical phonetics in its areal setting. Per a review excerpt, it proposes code-copying of vowel reduction from Middle Chuvash into Late Proto-Mari first syllables, and from Late Proto-Mari into Middle Chuvash second syllables. Central to the overlay hypothesis; the book itself was not read."),
 "agyagasi2019_review_jots": ("Volga-Kama / Chuvash historical phonology", "record", "Review of Agyagási (2019) in Journal of Old Turkic Studies. Use it to check the code-copy summary above."),
 "agyagasi2021_chuvash": ("Chuvash phonology", "record", "Chuvash chapter in the 2nd edition of The Turkic Languages (Routledge). Current handbook description; not read."),
 "johanson2000": ("Volga-Kama Sprachbund", "record", "Classic statement of Volga-area convergence across Turkic and Uralic. Cite for the areal frame; content not re-read tonight."),
 "johanson_csato2021": ("Turkic typology", "record", "Handbook, 2nd ed. Reference volume for Turkic phonology comparisons."),
 "volgakama2011": ("Volga-Kama Sprachbund", "record", "Van Pareren on non-lexical Turkic influence in Volga-Kama Finno-Ugric (Language Contact in Times of Globalization). Areal-features survey."),
 "volgabulgar_permic2021": ("Volga-Kama Sprachbund", "record", "Kreidl on Volga Bulgarian–Permic contact (morphology). Shows Bulgharic as a source language in the area."),
 "fu_turkic_negation2015": ("Volga-Kama Sprachbund", "record", "Manzelli on mutual Finno-Ugric–Turkic influence in negation. Non-phonological areal evidence."),
 "ronatas1988": ("Volga-Kama Sprachbund", "record", "Róna-Tas on Turkic influence on Uralic (in Sinor ed., The Uralic Languages). Standard historical overview."),
 "culver2022": ("Mari phonology", "read", "Mari historical phonology from new dialect dictionaries. Covers Proto-Mari reduced labial vowels and reduction in Chuvash loans. Relevant to when and from where Mari reduction arose."),
 "riese2022_mari": ("Mari phonology", "record", "Saarinen, 'Mari', Oxford Guide to the Uralic Languages. Current reference description; the stress statement was not read tonight."),
 "uralic_guide2022_book": ("Mari phonology", "record", "Volume containing the above."),
 "uralic_languages_1998reprint": ("Mari phonology", "record", "Abondolo (ed.) The Uralic Languages (Routledge reprint); contains Kangasmaa-Minn's Mari chapter (chapter DOI not resolved)."),
 "uralic_languages_2ed2023": ("Mari phonology", "record", "2nd edition of the Routledge Uralic handbook."),
 "lehiste2005": ("Mari phonology / stress", "record", "Meadow Mari Prosody (Linguistica Uralica Suppl. 2): instrumental study of Mari stress. The direct test of the Mari half of the parallel; NOT read tonight — priority to read."),
 "gordon2011_companion": ("Stress typology / Mari", "read", "States that Eastern Mari stress falls on the rightmost full vowel in monomorphemic roots, else initial in non-derived all-reduced words, and that rounding harmony spreads from the stressed vowel (citing Vaysman 2009: 62–64)."),
 "schiering_hulst2010": ("Stress typology / Chuvash–Mari", "read", "Survey of Asian accent systems. Classifies Chuvash as LAST/FIRST with full vowels as heavy (citing Krueger 1961, Hayes 1995), and raises Chuvash–Cheremis mutual influence as the source."),
 "hyman2006": ("Stress typology / Rule B", "read", "Word-prosodic typology. The PhonLab version (below) footnotes Dobrovolsky (1999) on Chuvash as a possible counterexample to obligatory headedness, i.e. stressless all-reduced words. The footnote's presence in the Phonology version is assumed, not checked."),
 "hyman2005_phonlab": ("Stress typology / Rule B", "read", "Working-paper version of Hyman (2006); the Dobrovolsky footnote was read here."),
 "gordon2002": ("Stress typology", "record", "Factorial typology of quantity-insensitive stress. Background for default-edge typology."),
 "gordon2000_bls": ("Stress typology", "record", "Re-examining default-to-opposite stress. Directly relevant to how Rule A's default is classified; not read."),
 "kenstowicz2004_qss": ("Stress typology", "record", "Reprint of Kenstowicz (1997) 'Quality-sensitive stress'. Abstract: lower > higher and peripheral > central vowels attract stress. Whether it treats Mari or Chuvash is unverified."),
 "walker2004_unbounded": ("Stress typology", "record", "CAUTION: by Baković, not Walker. 'Unbounded stress and factorial typology' (reprint)."),
 "delacy2004": ("Stress typology", "read", "Markedness conflation; sonority-driven stress in Nganasan and Kiriwina (abstract). Not about Mari or Chuvash."),
 "delacy2002_tone": ("Stress typology", "record", "Tone–stress interaction in OT. Background for prominence-driven stress."),
 "delacy2006": ("Stress typology", "record", "Markedness book; sonority-driven stress chapters."),
 "delacy2007": ("Stress typology", "record", "Tone, sonority and prosodic structure (Cambridge Handbook of Phonology)."),
 "kaun2004": ("Rounding harmony typology", "record", "Typology of rounding harmony (Phonetically Based Phonology). Frame for Q1's comparison of high-vowel and mid-vowel rounding harmony."),
 "rounding_harmony_hb2024": ("Rounding harmony typology", "record", "Kaun & McCollum, Rounding Harmony (Oxford Handbook of Vowel Harmony)."),
 "washington2024": ("Turkic harmony", "record", "Vowel harmony in Turkic languages (Oxford Handbook of Vowel Harmony). Should state Chuvash's place among Turkic harmony systems; not read."),
 "mascaro2024": ("Harmony typology", "record", "Stress-dependent vowel harmony. Relevant to Mari's stress-controlled rounding harmony."),
 "kabak2011": ("Turkic harmony", "record", "Turkish vowel harmony (Blackwell Companion). Comparison point for Q1."),
 "sezer1986": ("Turkic harmony", "record", "Backness–rounding harmony interaction (Turkish)."),
 "barry2016_turkic": ("Turkic reduced vowels / laryngeals", "record", "Laryngeal features and vowel length in Turkic (Turkic Languages 20)."),
 "surendran_niyogi2006": ("Methods", "read", "Entropy-based functional load; formula used in Q2."),
 "hockett1967": ("Methods", "record", "Original quantification of functional load."),
 "wedel2013": ("Methods", "record", "High functional load inhibits merger; interpretive frame for Q2."),
 "frisch2004": ("Methods / OCP", "record", "Similarity avoidance and the OCP (Arabic). Model for Q3's O/E method."),
 "pozdniakov_segerer2007": ("OCP typology", "record", "Similar place avoidance as a statistical universal. Grounds the claim in Q3 that OCP-Place is not areally diagnostic."),
 "glossa2024_cooccurrence": ("OCP typology", "record", "Doucette et al., cross-linguistic consonant and vowel co-occurrence restrictions. Could supply comparison values for Turkic and Uralic languages."),
 "mielke2008": ("Methods / PBase", "record", "The Emergence of Distinctive Features; P-base background."),
 "chuvash_knowledge2015": ("Chuvash sociolinguistics", "record", "Alòs i Font & Tovar-García: socioeconomic status and settlement type predict Chuvash knowledge among school students."),
 "kutsaeva2019": ("Chuvash sociolinguistics", "record", "Language-policy categorisation of Chuvash in and beyond the Republic."),
 "rus_chuv_bilinguals2025": ("Chuvash–Russian bilingualism", "record", "Grishanova on morphosyntactic variation in the Russian of Chuvash bilinguals (corpus of Russian spoken in Chuvashia). The corpus may also carry phonetic data."),
 "transeurasian_guide2020": ("Chuvash phonology", "record", "Volume containing Savelyev (2020)."),
 "sebeok_review1963": ("Mari phonology", "record", "Review of Sebeok & Ingemann (1961) An Eastern Cheremis Manual. The DOI is the review's, not the book's."),
 "sebeok_review1962": ("Mari phonology", "record", "Second review of the same manual (JAOS)."),
}
URLV = [  # verified by retrieving the document URL (no DOI)
 ("dobrovolsky1999", "Stress typology / Rule B", "read", "Dobrovolsky, Michael", "1999", "The phonetics of Chuvash stress: implications for phonology", "Proceedings of the 14th International Congress of Phonetic Sciences", "539--542",
  "https://www.internationalphoneticassociation.org/icphs-proceedings/ICPhS1999/papers/p14_0539.pdf",
  "THE source for Rule B. Acoustic study of disyllables: there is no default stress, and the initial prominence of all-reduced words is an intonational downturn."),
 ("dobrovolsky1995", "Turkic reduced vowels", "record", "Dobrovolsky, Michael", "1995", "The phonetics of reduced vowels in Chuvash: implications for the phonology of Turkic", "Proceedings of the 13th International Congress of Phonetic Sciences", "62--65",
  "https://www.coli.uni-saarland.de/groups/FK/speech_science/icphs/ICPhS1995/ICPhS1995.html", "Listed in the ICPhS 1995 table of contents; paper not read."),
 ("walker_roa172", "Stress typology / Mari", "read", "Walker, Rachel", "1996", "Prominence-driven stress / Mongolian stress, licensing, and factorial typology", "Rutgers Optimality Archive ROA-172", "",
  "https://roa.rutgers.edu/files/172-0197/172-0197-WALKER-0-1.PDF",
  "Cites Itkonen (1955) and Hayes (1995: 297): Western Cheremis stresses the rightmost non-final strong syllable, else the rightmost non-final syllable. Eastern Cheremis has variants, one being rightmost strong non-final, else leftmost. The ROA file bundles two titles; which is the 1996 ms and which the published version was not resolved."),
 ("lindsey_amp", "Chuvash stress", "read", "Lindsey, Kate", "n.d.", "Solving Chuvash stress with sonority-sensitive feet (AMP handout)", "Annual Meeting on Phonology handout", "",
  "https://katelynnlindsey.weebly.com/uploads/6/1/4/5/6145749/amp_handout.pdf", "Kate's own handout. All-reduced words have no stress (following Dobrovolsky 1999). Groups /ʉ/ with the central vowels."),
]
order = ["Volga-Kama Sprachbund", "Volga-Kama / Chuvash historical phonology", "Chuvash phonology", "Chuvash phonology / dialects", "Chuvash stress",
         "Stress typology / Chuvash–Mari", "Stress typology / Mari", "Stress typology / Rule B", "Stress typology", "Mari phonology", "Mari phonology / stress",
         "Turkic reduced vowels", "Turkic reduced vowels / laryngeals", "Turkic harmony", "Turkic typology", "Rounding harmony typology", "Harmony typology",
         "Chuvash sociolinguistics", "Chuvash–Russian bilingualism", "OCP typology", "Methods", "Methods / OCP", "Methods / PBase"]
entries = []
for k, (topic, lvl, note) in A.items():
    r = V.loc[k]
    au = html.unescape(r.authors) if r.authors else ""
    entries.append(dict(key=k, topic=topic, lvl=lvl, note=note, authors=au, year=str(int(float(r.year))) if r.year != "" else "", title=html.unescape(re.sub("<[^>]+>", "", r.title)),
                        container=html.unescape(re.sub("<[^>]+>", "", r.container)), volume=re.sub(r"\.0$","",str(r.volume)), page=str(r.page), doi=r.doi, url="", type=r.type, publisher=r.publisher))
for k, topic, lvl, au, yr, ti, co, pg, url, note in URLV:
    entries.append(dict(key=k, topic=topic, lvl=lvl, note=note, authors=au, year=yr, title=ti, container=co, volume="", page=pg, doi="", url=url, type="url-verified", publisher=""))
E = pd.DataFrame(entries); E["o"] = E.topic.map(lambda t: order.index(t) if t in order else 99); E = E.sort_values(["o", "year"])
L = {"read": "content checked", "secondary": "content via secondary source", "record": "record only"}
md = ["# Annotated bibliography — Volga-Kama / Mari / Chuvash (overnight 2026-10-01)", "",
      "Every entry below was verified tonight. DOI entries were resolved against CrossRef (api.crossref.org/works/{doi}), with author, title, year, container and pages copied from the CrossRef record. Entries without a DOI were verified by retrieving the document URL. The tag after each entry gives the depth of checking: *content checked* = the claim in the annotation was read in the work or in a retrieved excerpt of it; *content via secondary source* = known only from another work's summary; *record only* = only the bibliographic record was verified, and the annotation states relevance, not content. Unverified items are in `unverified_leads.md`.", ""]
for t, g in E.groupby("o", sort=True):
    md.append(f"## {g.topic.iloc[0]}"); md.append("")
    for _, e in g.iterrows():
        loc = (f"*{e.container}*" if e.container else "") + (f" {e.volume}" if e.volume and e.volume != "nan" else "") + (f", {e.page}" if e.page and e.page != "nan" else "")
        link = f"https://doi.org/{e.doi}" if e.doi else e.url
        md.append(f"- **{e.authors} ({e.year}).** {e.title}. {loc}. <{link}> — [{L[e.lvl]}] {e.note}")
    md.append("")
md.append("**Dropped after verification:** " + "; ".join(f"`{k}`: {v}" for k, v in DROP.items()))
open(os.path.join(OUT, "bibliography.md"), "w").write("\n".join(md) + "\n")
def bibkey(e):
    a = re.sub(r"[^A-Za-z]", "", e.authors.split(",")[0]) or "anon"; return f"{a}{e.year}{e.key.split('_')[0][-4:] if False else ''}_{e.key}"
bib = []
for _, e in E.iterrows():
    typ = {"journal-article": "article", "book": "book", "monograph": "book", "edited-book": "book", "book-chapter": "incollection", "proceedings-article": "inproceedings"}.get(e.type, "misc")
    if e.type == "url-verified": typ = "inproceedings" if "Proceedings" in e.container else "misc"
    au = " and ".join(a.strip() for a in e.authors.split(";")) if e.authors else ""
    f = [f"  author = {{{au}}}", f"  title = {{{e.title}}}", f"  year = {{{e.year}}}"]
    if e.container: f.append(("  journal" if typ == "article" else "  booktitle") + f" = {{{e.container}}}")
    if e.volume and e.volume != "nan": f.append(f"  volume = {{{e.volume}}}")
    if e.page and e.page != "nan": f.append(f"  pages = {{{e.page.replace('-', '--') if '--' not in e.page else e.page}}}")
    if e.publisher: f.append(f"  publisher = {{{e.publisher}}}")
    if e.doi: f.append(f"  doi = {{{e.doi}}}")
    if e.url: f.append(f"  url = {{{e.url}}}"); f.append("  note = {Verified by URL; no DOI}")
    f.append(f"  annote = {{[{L[e.lvl]}] {e.note}}}")
    bib.append(f"@{typ}{{{bibkey(e)},\n" + ",\n".join(f) + "\n}")
open(os.path.join(OUT, "bibliography.bib"), "w").write("\n\n".join(bib) + "\n")
print(len(E), E.lvl.value_counts().to_dict())
