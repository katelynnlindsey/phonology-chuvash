# NOTEBOOK — mari_literature (2026-10-02)

Chronological log of the session.

1. Loaded skills `chuvash-corpus-pipeline` and `pdf-explore`. Parsed both attached PDFs to text in the sandbox.
2. **Vaysman excerpt (attached, 10 pp.).** It holds only the title page, abstract, acknowledgements and table of contents. Pages 2, 4, 7 and 8 are blank, which I checked by pixel density. No Mari stress content is present. The TOC places Eastern Mari stress at §2.3.1, pp. 62–76.
3. The full dissertation is open access on MIT DSpace (handle 1721.1/47830). Kate approved network access to `dspace.mit.edu` and to its asset CDN `cf003.cdn.4science.cloud`. The legacy `/bitstream/` URL returned a human-verification page, so I did not retry it. The REST endpoint `/server/api/core/bitstreams/<uuid>/content` returned the 3.8 MB PDF (sha256 765dfe2b…). This copy's cover is dated 22 Oct 2008, the excerpt's 15 Sept 2008. The TOC page numbers are identical, and PDF page = printed page. The PDF was kept in the sandbox only; it was not saved to the repo.
4. Read Vaysman pp. 60–98 and 126–129 in full and grepped the rest for Mari, Chuvash and Dobrovolsky.
5. **Lehiste et al. (2005).** 142 PDF pages; printed page = PDF page + 2. The text layer is clean, but every data table is font-encoded and comes out as garbage. I read Chapters 1–4 in full as text.
6. Rendered the key table pages at 170 dpi and transcribed them by eye: Tables 1, 2, 5, 23, 24, 25, 26 and Appendix Table 5A. Saved as `mari_transcribed_tables.json`. Values quoted only in the text (ratios, Bark distances) were added with page numbers.
7. Wrote `analyses/speaker_cues/mari_literature/build_mari_tables.py`, which builds the CSVs from the JSON. Ran it: 343 value rows, 16 per-speaker rows, 8 F0 rows.
8. Checked all 30 quotes programmatically against the extracted text of the stated page. All matched, and all are under 25 words (`mari_literature_statements.csv`).
9. Queried CrossRef for cited works (`crossref_mari.json`). Verified: Lehiste 2005, Zoll 1997, Baković 2004, and Stifter 2006 (which verifies the Erzya Prosody record). No CrossRef match for Hayes 1985, Itkonen 1955 or Majors 1998; none added.
10. Read the Chuvash comparison numbers from `overnight_2026-10-01/sociophonetics/FINDINGS.md` Q5 (lines 177–181), not from the task brief alone. They match the brief: 55/74, τ 0.53 dB, −0.51 st.
11. Made the figure `fig_mari_cue_profile.png` and wrote `mari_chuvash_comparison.md`, `bibliography_additions.bib` and `FINDINGS.md`.

Not done: per-speaker F0 tables 13A–22A (Appendix pp. 117–126) and formant tables 23A–29A were not transcribed.
