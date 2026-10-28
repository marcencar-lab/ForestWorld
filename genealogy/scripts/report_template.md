# The Muñasque family of Opon (Lapu-Lapu City), Cebu: a genealogical reconstruction

Research report, 28 October 2026. Principal individual: **Fernando Umpad Muñasque** (progenitor, 1st generation). Supplied material: one family spreadsheet. Outside research: web search only (most record websites could not be opened from this session; see §6).

## 1. Executive summary

- The spreadsheet records **{{N_PEOPLE}} people** across **{{N_GEN}} generations** from Fernando Umpad Muñasque: {{N_BLOOD}} blood descendants and {{N_SPOUSE}} spouses or partners. The reconstructed tree gives each person a unique ID, a generation number, parents, spouse(s) and children, with a confidence label on every link.
- The **earliest named ancestors** are Alejandro Muñasque and Saturnina Umpad, Fernando's parents. They appear only as a header line with no dates, so they are *low confidence* (named, but unverified).
- **Only one person in the whole file has dates**: Emiliano Valiente Muñasque, born 20 May 1857, died 19 February 1940 aged 83. Everything else is undated. Generation-based birth estimates are given, clearly marked as estimates.
- Fernando married **Saturnina N. Valiente**; their nine children (Emiliano, Agripina, Andrea, Marcos, Florintina, Epifanio, Sotero, Cosmiano and Cruz, all "Valiente Muñasque") head the nine branches of the tree. Branch sizes range from {{MIN_BRANCH}} to {{MAX_BRANCH}} recorded descendants.
- The family is from **Opon, Mactan Island, Cebu** (today Lapu-Lapu City). By the 20th century most branches had moved to **Mindanao**: Lanao del Norte, the South Cotabato / General Santos / Sarangani settlement belt, North Cotabato, Agusan del Sur, Bukidnon, Misamis Occidental and Zamboanga del Sur, with smaller groups in Manila, the USA, Germany and Australia.
- **Independent corroboration was found for four descendants.** Congressman Benhur Lago Salimbangon (1945–2020) is recorded by outside sources as the son of Martin Salimbangon and Milagros Lago, exactly as the spreadsheet has it. Fr. Rosalio N. Muñasque (died 2003) was a priest of the Diocese of Marbel. "Atty. Benjamin N. Muñasque" was Clerk of Court of the Court of First Instance of Cotabato in the 1970s. An evangelist "Sulpicio Y. Muñasque" reached General Santos from Lala, Lanao del Norte, on 7 March 1939, and a street there carries his name; he matches the spreadsheet's Sulpicio Ynot Muñasque.
- **No outside record was found for any of the first three generations.** The 19th-century parish registers of Opon exist on FamilySearch (collection 5000324) but need a login; searching them is the single most valuable next step.
- The compiler's generation labels and colours contain many slips. {{N_OVERRIDES}} rows were re-attached using the Filipino naming convention (a child's middle name is the mother's maiden surname) and the compiler's own branch sheets; every change is listed with its reason. {{N_LOW}} people remain flagged *low confidence*.

## 2. Inventory of supplied material

| Item | What it is | Assessment |
|---|---|---|
| S1 · sheet "FERNANDO" | Master descendant list, 1,796 name rows in one column; generation shown by font colour (legend in cells J403–J413); spouses indented; "#" marks additional partners; "(D)" marks deceased | Derivative, unsourced family compilation. Created 14 Sep 2014, last saved 12 Jun 2020 (file metadata). No birth, marriage or death dates except Emiliano's. No places except in the branch sheets. |
| S2 · sheets 2–10 | An earlier or parallel version, one sheet per branch, printed as pages 1–36; column F gives a **residence** for 72 people; a few titles (Atty., Engr., Dr., Col., Cong., Rev. Fr., "nun") | Same compiler. Spelling differs from the master sheet in about 50 names; those variants are recorded on each person. Sheet7 carries an older, different colour legend. |
| S3 · note in J416–J418 | "the words muñasque is come from three person namely: MUKILAN-ANAÑAS-ROQUE according to Mr. Amador Piligro 97 yrs old wen I interviewed him last 2006 at Opon, Cebu" | Oral tradition, second-hand, recorded eight years after the interview. No documentary support found. |
| S4 · file properties | Author "User", last modified by "MarkhyNet" | Shows the compilation is recent (2014–2020). |

The spreadsheet is a **derivative source**: nobody's birth, baptism or marriage record is cited, and the compiler's own knowledge was clearly strongest for the living generations (4th to 8th) and weakest for the 19th century. What it proves is the compiler's understanding of who descends from whom. What it suggests, strongly, is the overall shape of the family and its geography. What it cannot establish is any date, place of birth, or the identity of the people before Fernando.

## 3. How the tree was decoded

1. **Generation = font colour.** The legend states black = 1st, dark red = 2nd, green = 3rd, blue = 4th, purple = 5th, orange = 6th, dark blue = 7th, red = 8th, light green = 9th generation. The text labels ("4G" etc.) in column F disagree with the colour on 70 rows; the colour was treated as primary because it is applied to every row, while labels are sparse and were visibly copied by hand.
2. **Spouse or child?** A row is read as a spouse when it is indented deeper than the person above it and has the same colour (or a "#"/"2nd wife" marker). A row one colour deeper is a child. The same colour at normal indent is a sibling.
3. **Naming-convention check.** In Philippine usage since the American period the middle name (or initial) is the mother's maiden surname. For every child the middle name was compared with the proposed mother's surname: {{N_OK}} links pass, {{N_MISMATCH}} fail, and the rest cannot be tested (no middle name, or a single-name spouse). A failure usually means the compiler listed a person under a sibling instead of under the parents; {{N_OVERRIDES}} such rows were moved, each with its reason recorded in `overrides.csv`, and the branch sheets (S2) were checked for agreement in every case.
4. **Additional partners.** The rows "#2 Faustina Ynot" and "#3 Basilia" after Marcos's descendants, and "# Sarip Arabia Omar" after Cosmiano's, are read as later partners of Marcos and Cosmiano respectively, because their children are coloured 3rd generation and because the compiler's own branch sheets (Sheet5, Sheet8) put them inside those branches. An alternative reading, that they were later wives of Fernando himself, cannot be excluded but is less consistent with the colours.
5. **Verification pass.** After the registers were built, an automatic check confirmed: every parent-child link is reciprocal and advances the generation by exactly one; every spouse pair is at the same generation; there are no cycles; every one of the 1,794 name rows is accounted for (8 duplicates dropped); and all 977 names that could be matched between the branch sheets and the master sheet fall inside the branch the compiler assigned them to. Two anomalies were found and fixed (three of Rosalia A. Muñasque's children mis-read as spouses; "Lourdes Salili" entered as the wife of two men, logged). Dated statements were then fact-checked by a second research pass (§6).
6. **Confidence labels.** *Moderate* = the spreadsheet's placement is internally consistent and the naming check passes or is untestable. *Low* = a naming-check failure, a colour or indent anomaly, a conflict between the two sheets, or a header-only entry. *High* is reserved for facts with two independent outside sources (only Benhur Salimbangon's dates qualify). Nothing in the first three generations rises above *moderate*.

## 4. The reconstructed lineage

### 4.1 Generation 0–1: the origin at Opon

**Alejandro Muñasque and Saturnina Umpad** (G0) are named once, in the header of the master sheet, as the parents of Fernando. Umpad (also spelled Ompad) is one of the most common surnames of Lapu-Lapu City today, which fits an Opon origin. No dates, no other children. *Low confidence* until a baptism or marriage record for Fernando is found.

**Fernando Umpad Muñasque** (G1) married **Saturnina N. Valiente**. Because their son Emiliano was born in 1857, Fernando was probably born about 1825–1835 and married about 1853–1856: the earliest census measure of Philippine marriage age (1903) puts women at about 21 and men a few years older (S45), so a father in 1857 was most likely 22–30; an 1820 birth is possible if Emiliano was not his first child. Nothing else is known. The surname Muñasque is rare (about 1,050 bearers, mostly in Central Visayas and Mindanao, per Forebears) and is not a known Spanish word; the family story (S3) that it was made from the names Mukilan, Anañas and Roque has no documentary trace. The second research round opened an open transcription of the 1849 *Catálogo alfabético de apellidos* (S53): the exact spelling Muñasque is not in it, but page 87 of the reprint, among the Moñ- names, has an entry read by three of six readings as "moñasque" (the others "monasque", "moliasque"), between "monasca" and "moñascas". If the page image confirms *Moñasque*, the family name is very probably a catalogue surname taken in 1850 and later written with a *u*, which is a common Visayan o/u interchange. Umpad, Ynot, Pino and Valiente are catalogue names too; Cosip, Gusat, Salimbangon and Patalinghug are not, which marks them as older indigenous Mactan names. This is a lead, not a proof: the reading is marked "best effort" by the transcriber and must be checked on the scan (Google Books copy, p. 87; Issuu copy, p. 121).

### 4.2 Generation 2: the nine Valiente Muñasque children

| Child | Spouse(s) | Recorded children | Recorded descendants | Where the branch went (S2) | Notable |
|---|---|---|---|---|---|
{{BRANCH_TABLE}}

Estimated birth years for this generation: 1857 (Emiliano) to about 1880. The order in the sheet is probably not birth order.

### 4.3 Branch summaries

{{BRANCH_SUMMARIES}}

## 5. Ancestor and key-person profiles

{{PROFILES}}

## 6. Independent research: what was searched and what was found

Searches were run in English and, for some topics, Cebuano and Hiligaynon. In this session almost every record website (FamilySearch, Wikipedia, Forebears, archive.org, Geni, the Philippine news sites, the Supreme Court e-library mirrors) could not be opened, so every finding below rests on search-engine result text and must be re-checked by opening the cited page. Full agent reports are in `research/`.

**Found (with source IDs from the bibliography):**

- Benhur Lago Salimbangon: born 3 June 1945 (Medellin, Cebu, per Geni and news; Cebu City per Simple English Wikipedia); Cebu Provincial Board 1992–1998; Representative, Cebu 4th District, elected 2007 (a result later annulled on protest), re-elected 2010 and serving to 2019; died 24 December 2020 of lung cancer; buried 30 December 2020 at Mactan Island Memorial Garden, Lapu-Lapu City (S10–S13). Geni (unsourced) and press profiles of his sister name his parents as Martin Salimbangon and Milagros Lago (S11, S15). This matches the spreadsheet row by row.
- Martin Salimbangon: schoolteacher and barangay captain ("Kapitan") of Curva, Medellin, northern Cebu; a TESDA centre and a high school there are named for him (S14, S15).
- Milagros Lago Salimbangon: "turned 90" on 8 September 2006 (S16) but "turns 98" in October 2013 (S17), so born 1915 or 1916; seven children reported in 2006 (the spreadsheet lists eight), and the 2013 column names five of them with their spouses, Benhur & Janice, Cesar & Fely, Mariquita & Carlos Yeung, Danila & Ulpa, Edwin & Edna (S46); daughter Ophelia Cue already deceased by 2006 (S16).
- Mariquita Salimbangon **Yeung** (spreadsheet: "Teung"): born about 3 March 1952; University of San Carlos graduate; husband Carlos Yeung of Hong Kong (S15, S18).
- Edwin L. Salimbangon: barangay captain of Curva 2018; elected Mayor of Medellin May 2025 (S19, S20).
- Fr. Rosalio N. Muñasque: priest of the Diocese of Marbel; seminary rector about 1975; parish priest of Banga 1975–1978; spiritual director at Notre Dame of Kiamba; died 2 December 2003 (S21–S24). Identity rests on the rare name and the title; his parents are not named online.
- Benjamin N. Muñasque: Clerk of Court of the Court of First Instance in Cotabato City, named as respondent in a Supreme Court decision of 31 October 1974 (A.M. No. P-145) that also records his own complaint of 2 February 1972 (S25). A 1979 case naming him (S26) surfaced in the first pass but could not be re-found. Same middle initial N. (= Nuñeza) and same title as the spreadsheet.
- Marnito B. Cosep (spreadsheet: Cosip): Provincial Legal Officer of South Cotabato, Koronadal (S27, S28). Residence Koronadal in S2 agrees.
- Sulpicio Y. Muñasque: evangelist of the United Evangelical Church, arrived in Dadiangas (General Santos) from Lala, Lanao del Norte, 7 March 1939; asked Gen. Paulino Santos for a church site in 1941; Sulpicio Muñasque Street in Dadiangas North (S29, S30). The Y. matches Ynot, his mother's surname in the spreadsheet.
- Elmo Muñasque of "Galan and Muñasque", Cebu building contractors, whose 1966–67 contract with Tropical Commercial Co. went to the Supreme Court in 1985 (S31). Probably the spreadsheet's Elmo D. Muñasque (son of Cruz), name match only.
- Gabriel Munasque, General Manager of South Cotabato Integrated Port Services (Makar port, General Santos), petitioner in a 2023 Supreme Court case (S54): probably the spreadsheet's Gabriel "Bob" D. Muñasque (son of Zacarias N. Muñasque and Remedios Dequiña), name and place match only.
- Martin Salimbangon's middle initial is M. (the school is "Martin M. Salimbangon National High School"); Curva became a barrio in 1961; Mariquita married Carlos Yeung in 1978 (S55, S15).
- A Ruel/Rowil Munasque, UCCP youth leader in Zamboanga del Sur (aged 33 in 2007), appears in 2007 Amnesty International and AHRC appeals (S56); he may be the spreadsheet's Rowel E. Muñasque of the Asisclo line, whose relatives lived in Lanao del Norte, Plaridel and Pagadian. Unproven.
- The 1849 Catálogo transcription (S53): see §4.1 for the probable "Moñasque" entry.
- Surname distribution: Muñasque about 1,050 bearers, 38% Central Visayas, 27% Soccsksargen, 16% Northern Mindanao (S32); Umpad/Ompad and Patalinghug among the most common surnames of Lapu-Lapu City (S33).

**Second round and fact-check (same day).** A second research round and a separate fact-check of 17 dated statements were run. Of the 17: 8 verified, 6 partly verified (wording or a secondary detail corrected), 3 not re-found (Fr. Rosalio Muñasque's diocesan pages, the Sulpicio Muñasque church history, and the Forebears figures, all blocked hosts). Corrections made as a result: Glan was founded in 1914, not surveyed in 1912; the Supreme Court decision that names Benjamin N. Muñasque as Clerk of Court is A.M. No. P-145 of 31 October 1974 (P-227 was his own complaint); the 1966 contract date for Elmo Muñasque is not confirmed; "US control restored by 1901" is more exactly "American military rule reimposed over Cebu on 17 July 1901"; Fernando's estimated birth is narrowed to about 1825–1835; the Milagros Lago birth-year conflict (1915/1916) stands. Full table: `research/agent6_factcheck.md`.

**Not found (searched, no result):** any record of Alejandro, Fernando, Emiliano, Saturnina Umpad, Saturnina Valiente, Irenea Gusat, or any of the nine 2nd-generation children; Ambrosio Salimbangon; Dr. Quintin Salimbangon Jr.; Col. Coronado "Stim" Muñasque; Dr. Ricardo C. Muñasque Jr.; Engr. Marlon Cosip; any member of the Tambingag branch; Amador Piligro; the surname in the Claveria catalogue; any Muñasque entry on FamilySearch public pages, Find a Grave, BillionGraves, WikiTree or MyHeritage. Absence from a search engine is weak evidence: FamilySearch's indexes are not crawlable.

## 7. Geography and migration

{{GEO_TEXT}}

Historical context that explains the pattern: Opon was a poor-soil fishing and boat-building town (population 14,851 in 1903, 33,426 in 1939; S37, S38). From 1913 the colonial government planted agricultural colonies in Cotabato: Pikit was founded on 17 June 1913 by about 120 Cebuano colonists, and Glan ("Colony No. 9") in 1914 by Cebu pioneers (S39). The National Land Settlement Administration (Commonwealth Act 441, 1939) opened the Koronadal and Allah valleys; its first settlers landed at Sarangani Bay on 27 February 1939 under Gen. Paulino Santos, who had been running the project since January (S40), eight days before Sulpicio Muñasque arrived there (S29). Post-war programmes (LASEDECO 1950, NARRA 1954, EDCOR in Kapatagan, Lanao) kept the flow going. The family's Lanao del Norte, Polomolok, Koronadal, General Santos and Glan clusters sit exactly on these settlement fronts.

### 7.1 Historical images and maps: what exists and how to get it

A picture-research pass found **no photograph of any family member born before 1945 online**, and no image of Fr. Rosalio Muñasque, Atty. Benjamin Muñasque, Sulpicio Muñasque or Atty. Marnito Cosep. Nothing could be downloaded in this session, so the report page carries no photographs; the links below are where to obtain them (full list with licence notes in `research/agent5_images.md`).

- **People.** Benhur Salimbangon: obituary portrait "courtesy of Francis Salimbangon" (Inquirer, 24 Dec 2020; family copyright, ask the family) and a Senate photo release of 13 Dec 2016 (Philippine government work, likely reusable with attribution) (S52). Janice Salimbangon: official 2022 House portrait on Wikipedia (check the Commons file page for its licence). Mariquita Salimbangon Yeung: Philstar and Inquirer lifestyle photographs (copyright). Milagros Lago Salimbangon: Philstar 27 Oct 2013 birthday photographs (copyright).
- **Opon, 1914–1945.** Ortigas Foundation Library: the Opon pier and old Virgen de la Regla church (1930s), the Opon ferry landing (Harry Hawkins Jr., 1930s), the Magellan monument (1915–19), the Opon church postcard noting the 1744 church was bulldozed in 1960 and rebuilt (S49). Filipinas Heritage Library: Osmeña Gate, Opon (1914); Spanish gate at Opon (Bureau of Public Works, c. 1915); Lapu-Lapu and Magellan monuments (S50). USC Libraries / Calisphere lantern slides: "Barata with sail, Opon, 1933"; carabao ploughing at Opon, 1933; Magellan Memorial School, Opon, 1933; and, for the Salimbangon branch, "Evangelical chapel, Curva, Medellin, 1932" and a market scene at Curva, 1932 (S48). Pacific Wrecks: Opon airfield, 1945 (US Navy photograph, public domain).
- **Mindanao frontier.** Kolambugan, Lanao del Norte, 1919–21 (Ortigas, Kincaid album); "Arrival of Vice President Osmeña ... Gen. Santos", 1938, and Main Street, Cotabato, 1902 (Filipinas Heritage Library). No photograph of the 1939–50 Koronadal, Dadiangas, Glan or Polomolok settlements was found online.
- **Maps (public domain).** *Atlas de Filipinas* (1899/1900), plate 22 "Cebu" with the inset "Isla de Mactan", and plates 27–28 for Mindanao, on Wikimedia Commons and the David Rumsey collection (S51); US War Department map of 1900 at the Library of Congress; US Coast and Geodetic Survey chart "Cebu and Mactan" (NOAA historical charts).
- **Illustrations.** No AI-generated images were added: the Higgsfield unlimited allowance did not cover any image model from this session, and credits were not spent without your say-so. Any reconstruction added later must be labelled as an illustration, never presented as a photograph.

## 8. Evidence matrix for the key relationships

| Relationship | Evidence | Conflicts | Confidence |
|---|---|---|---|
| Alejandro Muñasque + Saturnina Umpad → Fernando | S1 header line only | none | Low |
| Fernando + Saturnina Valiente → nine children | S1 (colour, position, "Valiente Muñasque" middle name on all nine) | none | Moderate |
| Fernando → Emiliano (b. 1857) | S1; the only dates in the file | none | Moderate |
| Emiliano + Irenea Gusat → six children ("Gusat/G." middle names) | S1, S2 | none | Moderate |
| Agripina + Ambrosio Salimbangon → Martin Salimbangon | S1, S3 (Sheet3) | Salimbangon family of Martin lived in Medellin, not Opon | Moderate |
| Martin Salimbangon + Milagros Lago → Benhur | S1; S11 (Geni, unsourced); S15 (press profile of sister); S14 (institutions named for Martin in Curva) | seven vs eight children; birthplace Medellin vs Cebu City | Moderate–High |
| Benhur's dates | S10, S12, S13 (two independent news sources + Wikipedia) | place of death Quezon City vs Cebu City | High |
| Sotero + Sebirina Ynot → Sulpicio Ynot Muñasque = evangelist Sulpicio Y. Munasque (1939) | S1 + S29/S30 | none; identity by rare name + initial | Moderate |
| Sotero → Basilio Ynot Muñasque + Rosalia Nuñeza → Fr. Rosalio N., Atty. Benjamin N. | S1 + S21–S25 | none; identity by name + title; Fr. Rosalio's sources come from one research pass and were not re-found in the fact-check | Moderate |
| Marcos → second and third partners Faustina Ynot, Basilia | S1 colours, S2 (Sheet5 placement) | could instead be wives of Fernando | Moderate |
| Cosmiano → second family with Sarip Arabia Omar (Tambingag line) | S1, S2 (Sheet8) | no outside trace | Low–Moderate |
| Hermenio Muñasque Cosip → Atty. Marnito B. Cosep | S1, S2 (Koronadal) + S27/S28 | spelling Cosip/Cosep | Moderate |

## 9. Discrepancy log (summary)

The full log is `registers/discrepancies.csv` ({{N_DISC_MANUAL}} topic-level entries and {{N_DISC_AUTO}} row-level flags). The main points:

{{DISC_LIST}}

## 10. Research gaps and ranked next steps

{{GAPS}}

## 11. Privacy

Most of the people in generations 5 to 10 are living. The registers contain only what the family's own spreadsheet contains (names, relationships, city-level residences, a few professional titles) plus published facts about public figures. No addresses, contact details or identifiers were collected. The published report page is private by default; share it only with family.

## 12. Deliverables and formats

- `registers/people.csv` — one row per person: ID, name parts, generation, parents, spouses, children, residence, variants, notes, confidence.
- `registers/relationships.csv` — every parent-child and spouse link with its evidence cell, naming check and confidence.
- `registers/sources.csv` — bibliography with record type, repository/URL, original-or-derivative status.
- `registers/research_facts.csv` — facts found outside the spreadsheet, linked to person IDs and sources.
- `registers/discrepancies.csv` — curated and automatic conflict log.
- `registers/overrides.csv` and `variant_map.csv` — every editorial decision that changed the compiler's placement or merged a spelling variant, with reasons.
- `valiente_munasque.ged` — GEDCOM 5.5.1 export (UTF-8). Limits: the spreadsheet records no sex, so HUSB/WIFE are inferred from which surname the children carry; no dates except Emiliano; all notes carry the sheet row for traceability.
- `data.json` — the full tree as structured data, used by the report page and the charts.
- `charts/*.svg` — pedigree, overview, nine branch charts, map, timeline, evidence diagram, generation sizes (editable SVG, theme-aware).
- `scripts/` — the parser and chart generators, so the tree can be regenerated when the spreadsheet is corrected.
- `research/` — the six web-research reports (first round, picture research, fact-check) with every query tried.
- `Munasque_family_report.pdf` — printable edition (A4): the report with its charts and a complete numbered descendant register.
- Family Archive page (artifact) — relatives upload photos, documents and corrections tied to people in the tree.
- Report page (artifact) — interactive tree explorer, all charts, this text, the tables.

## 13. Research conclusion

**Established (moderate confidence):** the descent of about 1,300 named people from Fernando Umpad Muñasque and Saturnina Valiente of Opon through nine children; the internal structure of each branch; the family's move from Mactan to the Mindanao settlement areas during the 20th century; the identities and public careers of Benhur Salimbangon, Fr. Rosalio Muñasque, Atty. Benjamin Muñasque, Atty. Marnito Cosep and the evangelist Sulpicio Muñasque.

**Probable but unverified:** the dates of Emiliano (1857–1940); that Faustina Ynot and Basilia were later partners of Marcos (not of Fernando); that Elmo D. Muñasque is the 1966 Cebu contractor.

**Unverified:** Alejandro Muñasque and Saturnina Umpad as Fernando's parents; the probable "Moñasque" entry in the 1849 catalogue as the origin of the surname; every birth, marriage and death in generations 1–4 other than Emiliano's; the Amador Piligro surname story; the whole Tambingag (Muslim) branch beyond the spreadsheet.

**Cannot currently be determined:** anything before Alejandro; whether Muñasque is a Claveria-catalogue surname; where and when each branch left Opon. All of these are answerable from the Opon parish registers and the Cebu civil registers once those collections are searched with a FamilySearch account or at the Lapu-Lapu City civil registry.
