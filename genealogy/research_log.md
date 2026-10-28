# Research log

## 2026-10-28 (session 1, morning)

### Phase 1 — Inventory
- First link (Facebook download host `lookaside.fbsbx.com`) blocked by the session's network policy; no copy in Drive or Gmail. User then uploaded the file to Google Drive (file id 1MdDA08LYPHS0cU9wQztCQztprJb86Cz8); read in full.
- Workbook: 12 sheets. `FERNANDO` = master list (1,796 name rows, A1:Q1930); `Sheet2`–`Sheet10` = branch lists with residences and page numbers 1–36; `Sheet11`/`Sheet12` empty. Created 14 Sep 2014, modified 12 Jun 2020.
- Every cell dumped to `sources/spreadsheet_dump.txt`; font colours extracted (generation legend in J403–J413).
- Only dates in file: Emiliano Valiente Muñasque b. 20 May 1857, d. 19 Feb 1940. Only note: surname origin story from Amador Piligro, 97, interviewed 2006 at Opon.

### Phase 2–3 — Extraction and reconstruction
- Wrote a parser (`scripts/parse_tree.py`, `walker.py`): generation from font colour (relative depth), spouse/child/sibling from indentation and markers, Filipino naming convention (middle name = mother's maiden surname) as a check.
- Iterated four times; remaining structural flags reviewed by hand. 140 override rows (`registers/overrides.csv`) and 52 spelling-variant merges (`registers/variant_map.csv`), each with a reason. Duplicated rows dropped (Adelfa/Leoncio Etcuban; Teresita Go block; Rosalinda B. Etcuban).
- Result: 1,788 people (1,328 blood descendants, 460 spouses), 10 generations; 201 people flagged low confidence.

### Phase 4 — Independent research (four parallel searches, ~300 queries)
Limitation: in this session almost every record website could not be opened (FamilySearch, Wikipedia, Forebears, archive.org, Geni, Philippine news sites, Supreme Court mirrors). All findings are from search-result text. Full reports in `research/`.

| Question | Result |
|---|---|
| Any record of Alejandro, Fernando, Emiliano, Saturnina Umpad/Valiente, Irenea Gusat, or the nine G2 children | Nothing found anywhere (search-engine level). |
| Benhur Salimbangon | Found: b. 3 Jun 1945, d. 24 Dec 2020; Rep. Cebu 4th District 2007–2019; parents Martin Salimbangon & Milagros Lago per Geni (unsourced) and press profile of sister; buried Mactan Island Memorial Garden, Lapu-Lapu. Matches spreadsheet. |
| Martin Salimbangon, Milagros Lago | Found: teacher/kapitan of Curva, Medellin; Milagros b. 8 Sep 1915/16; seven children (spreadsheet: eight); daughter Ophelia Cue d. before 2006. |
| Dr. Quintin Salimbangon Jr.; Sergia Muñasque | Nothing. |
| Fr. Rosalio N. Muñasque | Found: Diocese of Marbel priest; seminary rector c. 1975; Banga parish 1975–78; d. 2 Dec 2003. |
| Atty. Benjamin N. Muñasque | Found: Clerk of Court, CFI Cotabato, 1972–1979 (probable). |
| Atty. Marnito Cosip | Found as "Cosep": Provincial Legal Officer, South Cotabato. |
| Col. Coronado Muñasque; Dr. Ricardo Muñasque Jr.; Engr. Marlon Cosip; Tambingag family | Nothing. |
| Other Muñasques | Sulpicio Y. Muñasque, evangelist, Lala → General Santos 7 Mar 1939 (street named after him) = spreadsheet's Sulpicio Ynot Muñasque (probable). Elmo Muñasque, Cebu contractor 1966 (probable). Muñasques in USA/Australia (unlinked). |
| Surname Muñasque | ≈1,050 bearers; 38% Central Visayas, 27% Soccsksargen, 16% N. Mindanao. No etymology published. Presence in 1849 Catálogo could not be checked (no scan reachable). |
| Mactan surnames | Umpad/Ompad, Patalinghug, Booc documented Lapu-Lapu surnames. |
| Amador Piligro | Nothing. |
| Record repositories | FamilySearch 5000324 (Central Visayas church records) lists the Opon parish; civil registration 2018411 / 1410394 / 5000194; PSA holds from 1945 only; Lapu-Lapu LCRO for 1940 death. |
| Historical context | Opon population 1903–1960; 1913 Cotabato colonies; NLSA 1939 (settlers landed 27 Feb 1939); LASEDECO/NARRA/EDCOR; Mactan bridge 1973. |

### Phase 5 — Verification
- Confidence labels assigned per link; 18 topic-level discrepancies written up (`registers/discrepancies.csv`).
- Four parser-vs-compiler readings that matter most: (1) colours over text labels; (2) Faustina Ynot / Basilia / Sarip Arabia Omar as later partners of Marcos and Cosmiano; (3) Marcos block re-levelled by labels and naming; (4) siblings-listed-as-children moved to parents.

### Phase 6 — Visualisation
- SVG charts generated with no external library (`scripts/charts.py`); map is a to-scale coordinate plot because no coastline data could be fetched.
- Report page with D3 explorer built (`scripts/build_site.py`); explorer tested offline with a local D3 copy: 811 nodes at G5, search and detail panel working, no console errors.

### Phase 7 — Report
- `REPORT.md` and `report_page.html` written; registers, GEDCOM, charts committed.

### Open questions carried forward (ranked in REPORT.md §10)
1. Search FamilySearch 5000324 for Muñasque at Opon (needs a login): Emiliano's baptism 1857, Fernando's marriage and baptism, Emiliano's burial 1940.
2. Emiliano's 1940 death: Lapu-Lapu City LCRO transcription.
3. Claveria catalogue "Mu-" pages.
4. Salimbangon marriage in Medellin; Benhur's official profile.
5. Diocese of Marbel / CFI Cotabato files for the Nuñeza brothers; UCCP archives for Sulpicio.
6. Ask the compiler for the 1857/1940 sources, colour conventions and each person's sex.

## 2026-10-28 (session 2: second research round, verification, print and archive)

### Research round 2 (three parallel agents, ~350 queries; page fetches still blocked except GitHub)
| Question | Result |
|---|---|
| Photographs of family members | None reusable found. Benhur: obituary portrait (family copyright, Inquirer) and a 2016 Senate photo release (government work). Janice: 2022 official House portrait (Wikipedia). Mariquita, Milagros: society-page photos (copyright). Nothing for Fr. Rosalio, Atty. Benjamin, Sulpicio, Atty. Marnito Cosep. |
| Historical images of Opon | Ortigas Foundation Library (Opon pier/church 1930s, ferry landing, Magellan monument 1915–19), Filipinas Heritage Library (Osmeña Gate 1914, Spanish gate c. 1915), USC/Calisphere lantern slides (Opon 1933; Curva, Medellin 1932), US Navy Opon airfield 1945. All permission-required except the US Navy photo; none downloadable here. |
| Historical maps | Atlas de Filipinas 1899/1900 (Cebu plate with Mactan inset; Mindanao plates) on Commons/Rumsey, public domain. |
| 1849 Catálogo | Open transcription (ruzcko/catalogo-1849, GitHub) opened and searched here: no "Muñasque", but p. 87 col. 6 row 60 reads "monasque/moñasque" between "monasca" and "moñascas". Umpad, Ynot, Pino, Valiente, Fernan, Dequiña, Olavides, Acaso present; Cosip, Gusat, Salimbangon, Patalinghug absent. Needs scan check. |
| Gabriel Munasque | SCIPSI General Manager, G.R. 235569 (2023); probable match to Gabriel "Bob" D. Muñasque. |
| Martin Salimbangon | Middle initial M. (school name); Curva barrio 1961; Mariquita married Carlos Yeung 1978. |
| Ruel/Rowil Munasque | UCCP youth leader, Zamboanga del Sur, Amnesty 2007; possibly Rowel E. Muñasque (unproven). |
| Milagros Lago | 2013 column names five children with spouses; death notice not found. |
| Benhur official profile, House resolution, Diocese of Marbel necrology, UCCP Lanao histories | Not found. |

### Fact-check of 17 dated statements
8 verified, 6 partly (corrected), 3 not re-found (blocked hosts). Corrections applied: Glan founded 1914 (not surveyed 1912); Benjamin N. Muñasque's case is A.M. No. P-145 (31 Oct 1974), P-227 was his own complaint; Elmo Muñasque's contract date unconfirmed (cheque 9 Jan 1967); "American military rule reimposed 17 Jul 1901"; NLSA settlers landed 27 Feb 1939, eight (not ten) days before Sulpicio arrived, and before CA 441 (3 Jun 1939) chartered the NLSA; Fernando's birth estimate narrowed to c. 1825–1835 using 1903 marriage-age data. Full table: research/agent6_factcheck.md.

### Automated verification (scripts/validate.py)
0 structural errors; all 1,794 name rows accounted for (8 duplicates dropped); spouse pairs at equal generation; no cycles; 977 branch-sheet names all inside their expected branch. Fixed: three of Rosalia A. Muñasque's children mis-read as spouses of Cyril M. Ochotorena; "Lourdes Salili" entered twice (logged).

### Deliverables added
- Printable PDF (A4, 52 pages) with numbered descendant register.
- Family Archive page (artifact with upload capability; db collection "contributions" verified empty after publish).
- Report page republished with the corrections.

### Not done
- AI illustrations via Higgsfield: the account's unlimited allowance did not cover any image model from this session (gpt_image_2 and nano_banana_pro both refused "unlimited"); credits were not spent without the user's decision. Cost quoted: 2 credits per image at medium quality.

### Open questions carried forward
1. Verify "Moñasque" on the 1849 catalogue scan (Google Books p. 87 / Issuu p. 121).
2. Opon parish registers on FamilySearch (5000324) for 1850–1860 baptisms carrying the new surname, and for Emiliano (1857) and Fernando.
3. Obtain photographs: Salimbangon family, Ortigas/FHL/USC reproductions, Diocese of Marbel, UCCP South Cotabato.
