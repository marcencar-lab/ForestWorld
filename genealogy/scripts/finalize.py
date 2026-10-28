"""Merge parsed registers with research facts, write sources/discrepancies/GEDCOM/JSON."""
import csv, json, sys, os, collections
OUT=sys.argv[1]
P=json.load(open(f'{OUT}/people.json'))
rels=list(csv.DictReader(open(f'{OUT}/relationships.csv')))
auto=list(csv.DictReader(open(f'{OUT}/discrepancies_auto.csv')))
byrow={p['sheet_row']:p for p in P.values()}
def R(row): return byrow[row]['person_id']

# ---------------- sources ----------------
sources=[
 ('S1','Family spreadsheet "FERNANDO VALIENTE MUÑASQUE.xlsx", sheet FERNANDO (master descendant list)','family compilation (derivative, unsourced)','unknown compiler ("User"); last modified by "MarkhyNet"','created 14 Sep 2014, modified 12 Jun 2020','Philippines (Opon/Lapu-Lapu City, Cebu and Mindanao)','supplied by user via Google Drive','file id 1MdDA08LYPHS0cU9wQztCQztprJb86Cz8','derivative','yes','1,796 name rows; generation encoded by font colour; only one date in the file'),
 ('S2','Same workbook, sheets Sheet2–Sheet10 (branch lists with residences, titles, page numbers 1–36)','family compilation (derivative)','same compiler','2014–2020','same','supplied by user','same file','derivative','yes','older/parallel version; residence column; spelling variants'),
 ('S3','Compiler note in sheet FERNANDO cells J416–J418: surname origin told by Mr. Amador Piligro, aged 97, interviewed 2006 at Opon, Cebu','oral history (secondhand, recorded 2006–2014)','compiler','interview 2006','Opon (Lapu-Lapu City), Cebu','in file','FERNANDO!J416:J418','derivative','yes','"MUKILAN-ANAÑAS-ROQUE" blend story; no documentary support found'),
 ('S4','Document properties of the workbook (docProps/core.xml)','file metadata','Microsoft Excel','2014-09-14 / 2020-06-12','','in file','docProps/core.xml','original (metadata)','yes',''),
 ('S10','Wikipedia, "Benhur Salimbangon"','encyclopedia (derivative)','Wikipedia editors','accessed 28 Oct 2026','','https://en.wikipedia.org/wiki/Benhur_Salimbangon','','derivative','no','b. 3 Jun 1945, d. 24 Dec 2020; Rep. Cebu 4th District 2007–2019'),
 ('S11','Geni profile "Benhur Salimbangon" (user tree, unsourced)','online family tree (unsourced)','Geni user','updated 26 Apr 2022','','https://www.geni.com/people/Benhur-Salimbangon/6000000143128201990','','derivative','no','names parents Martin Salimbangon & Milagros Lago; birth Medellin; burial Mactan Island Memorial Garden'),
 ('S12','Inquirer, "Former Cebu congressman dies" (24 Dec 2020)','newspaper','Philippine Daily Inquirer','2020-12-24','','https://newsinfo.inquirer.net/1375610/former-cebu-congressman-dies','','original (news)','no','death, lung cancer; son Francis'),
 ('S13','SunStar Cebu, "Salimbangon lived faithfully, bravely"','newspaper','SunStar','Dec 2020','','https://www.sunstar.com.ph/cebu/local-news/salimbangon-lived-faithfully-bravely','','original (news)','no','requiem Lahug; burial 30 Dec 2020 Mactan Island Memorial Garden, Lapu-Lapu City'),
 ('S14','Philstar/The Freeman, "Aeronautics school to open in Medellin" (29 Nov 2014)','newspaper','The Freeman','2014-11-29','','https://www.philstar.com/the-freeman/cebu-news/2014/11/29/1397044/aeronautics-school-open-medellin','','original (news)','no','"Kapitan Martin Salimbangon Skills Training Center", Curva, Medellin'),
 ('S15','Everything Cebu, profile of Mariquita Salimbangon Yeung','magazine profile','Everything Cebu','n.d.','','https://www.everythingcebu.com/lifestyle/people/mariquita-salimbangon-yeung/','','derivative','no','father Martin Salimbangon, schoolteacher and village elder of Curva, Medellin; husband Carlos Yeung'),
 ('S16','Philstar Cebu Lifestyle, "Tiya Meling\'s 90th birthday" (28 Sep 2006)','newspaper','Philstar','2006-09-28','','https://www.philstar.com/cebu-lifestyle/2006/09/28/360284/tiya-melings-90th-birthday','','original (news)','no','Milagros Lago Salimbangon turned 90 on 8 Sep 2006; seven children; Ophelia Cue deceased'),
 ('S17','Philstar Cebu Lifestyle, "Mama Meling turns 98" (27 Oct 2013)','newspaper','Philstar','2013-10-27','','https://www.philstar.com/cebu-lifestyle/2013/10/27/1250047/mama-meling-turns-98','','original (news)','no','implies birth 1915 (conflicts with S16: 1916)'),
 ('S18','SunStar, "The son rises" (Martin Philip Salimbangon Yeung)','newspaper','SunStar','n.d.','','https://www.sunstar.com.ph/more-articles/the-son-rises','','original (news)','no','son of Mariquita; CEO Mactan Island Memorial Garden'),
 ('S19','Philstar/The Freeman, "Big names gun for ABC federation" (28 May 2018)','newspaper','The Freeman','2018-05-28','','https://www.philstar.com/the-freeman/cebu-news/2018/05/28/1819398/big-names-gun-abc-federation-province','','original (news)','no','Edwin Salimbangon, younger brother, Curva barangay captain'),
 ('S20','Wikipedia, "Medellin, Cebu"','encyclopedia','Wikipedia','accessed 28 Oct 2026','','https://en.wikipedia.org/wiki/Medellin,_Cebu','','derivative','no','Edwin L. Salimbangon elected mayor May 2025'),
 ('S21','Our Lady of Perpetual Help Seminary (Marbel), history page','institutional history','OLPH Seminary','n.d.','Koronadal, South Cotabato','http://olphseminarium.blogspot.com/p/history.html','','derivative','no','Fr. Rosalio Muñasque rector c. 1975'),
 ('S22','Our Lady of the Miraculous Medal Parish, Banga, history (2012)','institutional history','parish','2012','Banga, South Cotabato','https://olmmpbanga1950.wordpress.com/2012/03/','','derivative','no','Rosalio Muñasque parish priest 1975–1978'),
 ('S23','Diocese of Marbel, Catholic schools page','institutional','Diocese of Marbel','n.d.','','https://dioceseofmarbel.wordpress.com/catholic-schools/','','derivative','no','Fr. Muñasque spiritual director, Notre Dame of Kiamba'),
 ('S24','Diocese of Marbel directory (freeservers)','institutional directory','Diocese of Marbel','n.d.','','http://marbeldiocese.freeservers.com/directory.htm','','derivative','no','"Rosalio Muňasque died Dec. 2, 2003"'),
 ('S25','Supreme Court of the Philippines, A.M. No. P-227 (30 Sep 1974), via Chan Robles','court decision','Supreme Court','1974-09-30','Cotabato City','https://chanrobles.com/cralaw/1974septemberdecisions.php?id=336','','original (legal)','no','"Benjamin N. Muñasque, Clerk of Court, CFI Cotabato"'),
 ('S26','Supreme Court, G.R. No. L-28485 (Oct 1979), via LawPhil','court decision','Supreme Court','1979-10','','https://lawphil.net/judjuris/juri1979/oct1979/gr_l-28485_1979.html','','original (legal)','no','"Clerk of Court, Atty. Benjamin Munasque"'),
 ('S27','Province of South Cotabato, Provincial Heads page','government website','Provincial Government of South Cotabato','accessed 28 Oct 2026','Koronadal City','https://southcotabato.gov.ph/provincial-heads/','','original (official)','no','"Marnito B. Cosep, Provincial Legal Officer"'),
 ('S28','RMN news (Hiligaynon): appointment of Atty. Marnito Cosep confirmed','radio news','RMN','n.d.','','https://rmn.ph/appointment-ni-atty-marnito-cosep-bilang-bag-o-nga-provincial-legal-officer-sang-south-cotabato-ginkumpirmar-sang-mga-katapo-sang-sangguniang-panlalawigan/','','original (news)','no',''),
 ('S29','UCCP Lagao (General Santos City) church history (2022)','institutional history','UCCP Lagao','2022','General Santos City','https://automate.video/uccp_lagao_history_2022_p77c02cb7','','derivative','no','"Arrival of Evangelist Sulpicio Y. Munasque of United Evangelical Church from Lala, Lanao Del Norte", 7 Mar 1939; 1941 request to Gen. Paulino Santos'),
 ('S30','OpenAlfa street index, General Santos City','gazetteer','OpenAlfa','accessed 28 Oct 2026','','https://philippines-streets.openalfa.com/general-santos','','derivative','no','"Sulpicio Muñasque Street", Dadiangas North'),
 ('S31','Supreme Court, G.R. No. L-39780 (11 Nov 1985), via Chan Robles','court decision','Supreme Court','1985-11-11','Cebu','https://chanrobles.com/cralaw/1985novemberdecisions.php?id=411','','original (legal)','no','Elmo Muñasque, building contractor, contract 20 Dec 1966'),
 ('S32','Forebears, surname Muñasque','surname distribution database','Forebears','accessed 28 Oct 2026','','https://forebears.io/surnames/mu%C3%B1asque','','derivative (statistical)','no','≈1,050 bearers; 38% Central Visayas, 27% Soccsksargen, 16% Northern Mindanao'),
 ('S33','Wiktionary, Appendix: Cebuano surnames','reference list','Wiktionary','accessed 28 Oct 2026','','https://en.wiktionary.org/wiki/Appendix:Cebuano_surnames','','derivative','no','Ompad/Umpad and Patalinghug among most common surnames of Lapu-Lapu City'),
 ('S34','FamilySearch, "Philippines, Central Visayas, Church Records, 1737–2005" (collection 5000324)','archival collection (original images, partial index)','FamilySearch / parishes of Cebu','1737–2005','Cebu','https://www.familysearch.org/search/collection/5000324','','original (images)','no','NOT yet searched: requires login; the key next step'),
 ('S35','FamilySearch Wiki, Philippines Catholic Church Records inventory','finding aid','FamilySearch','accessed 28 Oct 2026','','https://familysearch.org/wiki/en/Philippines,_Catholic_Church_Records,_1520-2014_-_Inventory','','derivative','no','lists parish Nuestra Señora de la Virgen de Regla, Lapu-Lapu City'),
 ('S36','Philippine FOI reply on pre-1945 PSA records','government FOI response','PSA','n.d.','','https://foi.gov.ph/requests/birth-certificate-psa-933576770502','','original (official)','no','PSA archive generally starts 1945'),
 ('S37','Wikidata Q574903 (Lapu-Lapu City) population series','statistical','Wikidata (citing censuses)','accessed 28 Oct 2026','','https://www.wikidata.org/wiki/Q574903','','derivative','no','1903: 14,851; 1918: 20,988; 1939: 33,426; 1948: 37,280; 1960: 48,546'),
 ('S38','Wikipedia, "Lapu-Lapu City"','encyclopedia','Wikipedia','accessed 28 Oct 2026','','https://en.wikipedia.org/wiki/Lapu-Lapu_City','','derivative','no','Opon founded as Christian town 1730; cityhood 1961'),
 ('S39','Wikipedia, "Pikit" and "Glan, Sarangani"','encyclopedia','Wikipedia','accessed 28 Oct 2026','','https://en.wikipedia.org/wiki/Pikit ; https://en.wikipedia.org/wiki/Glan,_Sarangani','','derivative','no','1913 Cotabato agricultural colonies; Glan = Colony No. 9'),
 ('S40','Commonwealth Act 441 (NLSA), 3 Jun 1939; Tupi municipal history','law / local history','Philippine Congress; LGU Tupi','1939','Koronadal Valley','https://lawphil.net/statutes/comacts/ca1939/pdf/ca_441_1939.pdf ; https://tupi.gov.ph/history/','','original (law)','no','first NLSA settlers landed Sarangani Bay 27 Feb 1939'),
 ('S41','Inquirer, "How Filipinos got their surnames"','newspaper','Inquirer','n.d.','','https://opinion.inquirer.net/127676/how-filipinos-got-their-surnames/amp','','derivative','no','Claveria decree 21 Nov 1849'),
 ('S42','FamilySearch syllabus "Filipino Genealogy 101"','guide','FamilySearch','n.d.','','https://cms-z-assets.familysearch.org/d2/bd/f25915764f2a96e231c3a5862b6a/syllabus-filipino-genealogy-101.pdf','','derivative','no','naming convention (mother\'s maiden name as middle name); 1932–1945 national civil copies destroyed in WWII'),
 ('S43','Structurae, Mactan–Mandaue Bridge','engineering database','Structurae','accessed 28 Oct 2026','','https://structurae.net/en/structures/mactan-mandaue-bridge','','derivative','no','construction 1970, inaugurated 4 Jul 1973'),
]
with open(f'{OUT}/sources.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['source_id','title','record_type','creator','date','location','repository_or_url','identifier','original_derivative_or_index','supplied_by_user','notes']); w.writerows(sources)

# ---------------- research facts attached to people ----------------
facts=[
 (R(2),'identity','Progenitor of the family as compiled; parents named in the sheet header as Alejandro Muñasque and Saturnina Umpad','S1','low','header only; no dates'),
 (R(4),'birth','20 May 1857 (place not stated; family of Opon, Cebu)','S1','moderate','only date in file; secondhand family record'),
 (R(4),'death','19 Feb 1940, aged 83 (place not stated)','S1','moderate','age consistent with birth date'),
 (R(709),'occupation','Schoolteacher; barangay captain ("Kapitan") and village elder of Barangay Curva, Medellin, Cebu; a TESDA training centre and a high school in Curva are named after him','S14; S15','moderate','identity link to the spreadsheet rests on the Benhur/Milagros match'),
 (R(710),'birth','8 September 1915 or 1916 (press reports: "turned 90" on 8 Sep 2006; "turns 98" in Oct 2013)','S16; S17','moderate','year conflicts between two reports'),
 (R(710),'family','Seven children reported in 2006 (spreadsheet lists eight); daughter Ophelia Cue already deceased in 2006','S16','moderate','discrepancy logged'),
 (R(712),'death','Deceased before September 2006 ("Ophelia Cue")','S16','moderate','spelling Ofelia/Ophelia'),
 (R(710+0),'residence','Barangay Curva, Medellin, northern Cebu (not Opon)','S15; S14','moderate','the Martin Salimbangon branch lived in Medellin'),
 (R(723),'birth','3 June 1945; Medellin, Cebu (Geni, news) or Cebu City (Simple Wikipedia)','S10; S11; S12','high','birthplace conflict logged'),
 (R(723),'parents','Son of Martin Salimbangon and Milagros Lago (independent of the spreadsheet)','S11; S15','moderate','Geni is unsourced; corroborated by press profiles of his sister'),
 (R(723),'career','Cebu Provincial Board Member 1992–1998; Representative, 4th District of Cebu, 2007–2010 and 2010–2019','S10','high',''),
 (R(723),'death','24 December 2020, aged 75, lung cancer; requiem at Lahug, Cebu City; buried 30 Dec 2020 at Mactan Island Memorial Garden, Lapu-Lapu City','S12; S13; S11','high','place of death: Quezon City (Geni) vs Cebu City (Wikipedia)'),
 (R(723),'spouse','Second wife Janice Zamora Salimbangon (the "# Janice Zamora" row), who succeeded him in Congress 2019–2025','S10','high',''),
 (R(738),'identity','Mariquita "Kit" Salimbangon Yeung; husband Carlos Yeung (spreadsheet: "Teung"); born c. 3 March 1952 (40th birthday 3 Mar 1992); University of San Carlos graduate','S15; S18','moderate','spelling correction Teung → Yeung'),
 (R(747),'career','Barangay captain of Curva (2018); elected Mayor of Medellin, Cebu, May 2025','S19; S20','moderate',''),
 (R(1665),'career','Diocesan priest, Diocese of Marbel (Koronadal, South Cotabato): seminary rector c. 1975; parish priest of Banga 1975–1978; spiritual director, Notre Dame of Kiamba','S21; S22; S23','moderate','identity by unusual name + title; parents not named online'),
 (R(1665),'death','2 December 2003','S24','moderate',''),
 (R(1530),'career','Probably the "Benjamin N. Muñasque, Clerk of Court, Court of First Instance of Cotabato, Cotabato City" named in Supreme Court records of 1972–1979','S25; S26','moderate','same middle initial N. (Nuñeza) and title; parents not named in the records'),
 (R(254),'career','Atty. Marnito B. Cosep (spelled Cosep online), Provincial Legal Officer of South Cotabato, Koronadal City','S27; S28','moderate','spreadsheet spells Cosip; residence Koronadal in S2 matches'),
 (R(1720),'career','Very probably the "Evangelist Sulpicio Y. Munasque of the United Evangelical Church" who arrived in General Santos (then Dadiangas) from Lala, Lanao del Norte on 7 March 1939; in 1941 he and his wife asked Gen. Paulino Santos for a church site; Sulpicio Muñasque Street in Dadiangas North is named for him','S29; S30','moderate','Y. = Ynot matches his mother Sebirina Ynot; fits the Lanao del Norte cluster of the family'),
 (R(1912),'career','Probably the Elmo Muñasque, Cebu building contractor, party to a 1966 contract litigated to the Supreme Court in 1985','S31','low','name match only'),
 (R(1746),'family','Second family with Sarip Arabia Omar in Mindanao; descendants (Tambingag, Pangolima, Marohombsar, Hassan) carry Maranao/Maguindanao Muslim names; Tambingag surname clusters in General Santos City / Sarangani','S1; S2','low','no outside record of the named individuals found'),
]
with open(f'{OUT}/research_facts.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['person_id','full_name','fact_type','fact','source_ids','confidence','notes'])
    for pid,t,fa,s,c,n in facts: w.writerow([pid,P[pid]['display'],t,fa,s,c,n])

# ---------------- curated discrepancy register ----------------
manual=[
 ('generation-labels','Text labels "nG" in column F disagree with the font colour on 70 rows (e.g. Hermenio Muñasque Cosip labelled 5G but coloured 4G). The colour legend in J403–J413 was treated as primary; labels were used only where colours were internally inconsistent (Marcos branch rows 949–1044).','colour used; label conflicts listed in discrepancies_auto.csv','resolved (method)'),
 ('two-colour-legends','Sheet FERNANDO legend: black=1st, dark red=2nd, green=3rd, blue=4th, purple=5th, orange=6th, dark blue=7th, red 2=8th, light green=9th. Sheet7 legend differs (blue=1st, red=2nd, green=3rd, black=4th, violet=5th, yellow=6th, orange=7th). Sheet7 is an earlier draft.','master sheet legend applied','resolved'),
 ('additional-wives','Rows "#2..Faustina Ynot" and "#3..Basilia" (after Marcos Valiente Muñasque\'s descendants) and "#..Sarip Arabia Omar" (after Cosmiano\'s descendants) are coloured in a special red. They are read as 2nd/3rd partners of Marcos and 2nd partner of Cosmiano because their children are coloured 3rd generation and because Sheet5/Sheet8 place them inside those branches. An alternative reading, that they were later wives of the progenitor Fernando, would make their children 2nd generation; the colours argue against it.','Marcos (2nd, 3rd) and Cosmiano (2nd)','moderate'),
 ('Marcos-branch-colours','Rows 949–1044 (Marcos branch) are coloured one or two levels too deep and inconsistently; e.g. Purification P. Muñasque is blue (4th) although she is a child of a 2nd-generation person. Text labels and naming convention were used instead; Palexina Perez Muñasque and Col. Coronado Perez Muñasque ("Perez" = mother Matilde Perez) are placed as children of Marcos (3rd generation), one level higher than the compiler\'s label.','labels + naming convention','moderate'),
 ('siblings-listed-as-children','Several people whose middle name shows their mother\'s surname were placed by the compiler under a sibling instead of their parents (e.g. Czar, Ruth and Dr. Quintin Jr. Muñasque Salimbangon under Thelma; Wilfredo, Raquel, Sarah and Cezar Franco A. Muñasque under Samuel A.; Leonardo, Restituto and Sergio Muñasque Pino under Demetrio; Eliezar, Teresita and Dominador E. Muñasque under Felixberto). Re-attached to the parents implied by the naming convention; the branch sheets (S2) agree in each case checked. All such moves are listed in overrides.csv with reasons.','naming convention + S2','moderate'),
 ('Teodulfo-children-initials','Alice/Alicia, Perla, Leonillo/Leonilo and Sonia Salimbangon carry the initial P. in the master sheet but G. (Gelig) in Sheet3. Treated as children of Teodulfo & Felipa Gelig per Sheet3. A second wife beginning with P. cannot be excluded.','Sheet3 reading','low'),
 ('Milagros-children-count','Press (2006) says Milagros Lago Salimbangon had seven children; spreadsheet lists eight (Aida, Ofelia, Benhur, Cesar, Mariquita, Danilo, Edwin, Freddie).','unresolved; press count may exclude a deceased child or the spreadsheet may include a non-child','unresolved'),
 ('Benhur-birthplace','Medellin, Cebu (Geni; Cebu Daily News, Manila Bulletin) vs Cebu City (Simple English Wikipedia).','Medellin better supported (multiple news sources; family lived in Curva, Medellin)','moderate'),
 ('Milagros-birth-year','1916 (90 in Sept 2006) vs 1915 (96 in 2011; 98 in 2013).','unresolved; a civil or church record would settle it','unresolved'),
 ('Yeung-vs-Teung','Spreadsheet "Carlos Teung" vs published "Carlos Yeung" (Hong Kong businessman).','Yeung (published spelling)','high'),
 ('Cosip-vs-Cosep','Spreadsheet uses Cosip (Blas Cosip line) and Cosep (Rivera children); official South Cotabato pages spell Atty. Marnito Cosep.','both spellings recorded as variants','resolved'),
 ('registered-under-mother','Children carrying the mother\'s surname and the mother\'s own middle name (e.g. Roberto M. Cosip under Esperanza Muñasque Cosip; Samantha Jean M. Muñasque under Jojo C. Muñasque; Princess Justine S. Muñasque under Elena S. Muñasque; Jona Girl Muñasque and Cyril M. Ochotorena under Rosalia A. Muñasque) follow the Philippine practice of registering a child under the mother\'s name. Kept as the compiler placed them; flagged low confidence.','kept','low'),
 ('married-surnames','Some women are entered under married surnames (Leonarda Y. Booc, Vivian G. Caballes, Eva Muñasque Jo, Delilah Stevens Carey); their middle initials show the maiden line. Leonarda is shown as Muñasque with Booc recorded as a variant.','noted','moderate'),
 ('Muslim-naming','Children of Malapat Muñasque Tambingag & Tarhata Marohombsar carry "T." (apparently for Tarhata, the mother\'s given name), a Maranao/Maguindanao usage, not a Hispanic maiden-surname initial.','noted; no change','n/a'),
 ('duplicates','Adelfa and Leoncio Muñasque Etcuban (rows 1232–1234) and Teresita Go with the Grande family (rows 590–593) are entered twice; Rosalinda B. Etcuban twice (1252, 1285). Second copies dropped.','dropped','resolved'),
 ('conflicting-child-placements','Jerimar: "Jerimar Muñasque Booc" (Sheet5, child of Leonarda) vs "Jerimar B. Quirante" (master, child of Fe M. Booc & Oscar Quirante). Ethea/Eihea Paul(a): child of Eliezar & Cortes (Sheet7) vs child of Erwin Paul & Alicia B. Rogan (master). Samuel Salimbangon Go: child of Sabiana (Sheet3) vs "Samuel", spouse of Alicia Salimbangon Go (master). Norman vs Norma Muñasque Salimbangon (Sheet2 vs master).','master sheet (later version) followed; conflicts flagged on the persons','low'),
 ('Sulpicio-identity','"Sulpicio Y. Munasque", evangelist, Lala, Lanao del Norte → General Santos 1939 (S29) vs spreadsheet "Sulpicio Ynot Muñasque" (son of Sotero & Sebirina Ynot) with no residence given.','same person probable (rare name, Y. = Ynot, family cluster in Lanao del Norte)','moderate'),
 ('Opon-origin','The compiler places the family at Opon, Cebu (S3, residence column "OPON, CEBU" in S2). The Salimbangon branch that produced Congressman Benhur lived in Curva, Medellin (northern Cebu). How Agripina Valiente Muñasque\'s family came to Medellin is undocumented.','noted','unresolved'),
]
with open(f'{OUT}/discrepancies.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['discrepancy_id','topic','detail','best_supported_reading','status_or_confidence'])
    for i,(t,d,b,s) in enumerate(manual,1): w.writerow([f'DM{i:03d}',t,d,b,s])
    w.writerow([]); w.writerow(['-- automatic flags from the parser (row-level) --'])
    for a in auto: w.writerow([a['discrepancy_id'],a['field'],a['detail'],'see person notes / overrides.csv',f"row {a['sheet_row']}"])

# ---------------- generation birth-year estimates ----------------
EST={0:'c. 1790–1815',1:'c. 1820–1835',2:'1857 (Emiliano) to c. 1880',3:'c. 1880–1915',4:'c. 1905–1945',5:'c. 1930–1970',6:'c. 1955–1995',7:'c. 1980–2015',8:'c. 2000–2020',9:'after c. 2010',10:'after c. 2015'}

# ---------------- GEDCOM ----------------
def ged_name(p):
    g=' '.join(filter(None,[p['given'],p['middle']])).strip()
    s=p['surname'] or ''
    n=f"{g} /{s}/"
    if p['suffix']: n+=f" {p['suffix']}"
    return n
fams={}  # (father,mother) -> fam id
def famkey(f,m): return (f or '', m or '')
lines=['0 HEAD','1 SOUR ForestWorld-genealogy-parser','2 VERS 1.0','1 GEDC','2 VERS 5.5.1','2 FORM LINEAGE-LINKED','1 CHAR UTF-8','1 DATE 28 OCT 2026',
       '1 NOTE Generated from the family spreadsheet "FERNANDO VALIENTE MUÑASQUE.xlsx" (S1/S2). Generation and parentage were reconstructed from font colours, indentation and Filipino naming convention; see discrepancies.csv. Only one person has dates. Most people listed are living; treat as private.']
# families from spouse links and parent links
for p in P.values():
    for sp in p['spouse_ids']:
        k=tuple(sorted([p['person_id'],sp]))
        fams.setdefault(k, {'spouses':list(k),'children':[]})
for p in P.values():
    if p['father_id'] or p['mother_id']:
        k=tuple(sorted([x for x in [p['father_id'],p['mother_id']] if x]))
        if len(k)==1: k=(k[0],'')
        fams.setdefault(k,{'spouses':[x for x in k if x],'children':[]})
        fams[k]['children'].append(p['person_id'])
famid={k:f'F{i+1:04d}' for i,k in enumerate(fams)}
for p in P.values():
    pid=p['person_id']
    lines+= [f'0 @{pid}@ INDI', f'1 NAME {ged_name(p)}']
    if p['nickname']: lines.append(f'2 NICK {p["nickname"]}')
    if p['title']: lines.append(f'1 TITL {p["title"]}')
    if pid==R(4):
        lines+=['1 BIRT','2 DATE 20 MAY 1857','2 NOTE Family spreadsheet (S1); place not stated, family of Opon, Cebu','1 DEAT','2 DATE 19 FEB 1940','2 NOTE Family spreadsheet (S1), "83 yrs old"']
    elif p['deceased']: lines+=['1 DEAT Y','2 NOTE Marked (D) in the family spreadsheet; no date']
    if p['residence']: lines+=['1 RESI',f'2 PLAC {p["residence"]}','2 NOTE Residence as given in the branch sheets (S2), c. 2014–2020']
    lines.append(f'1 NOTE Generation {p["generation"]} from the progenitor (0 = his parents); estimated birth period {EST.get(p["generation"],"")}. Source: FERNANDO!A{p["sheet_row"]}. Confidence: {"low" if p["notes"] else "moderate"}.')
    for n in p['notes']: lines.append('2 CONT '+n.replace('\n',' '))
    for v in p['variants']: lines.append(f'1 NOTE Spelling variant in branch sheets: {v}')
    for k,fm in fams.items():
        if pid in fm['spouses']: lines.append(f'1 FAMS @{famid[k]}@')
        if pid in fm['children']: lines.append(f'1 FAMC @{famid[k]}@')
    lines.append('1 SOUR @S1@')
for k,fm in fams.items():
    lines.append(f'0 @{famid[k]}@ FAM')
    sps=[P[x] for x in fm['spouses'] if x]
    # husband = male-line guess: the one whose surname the children carry; else first
    husb=wife=None
    if len(sps)==2:
        a,b=sps
        chs=[P[c] for c in fm['children']]
        if chs and chs[0]['surname'] and chs[0]['surname']==b['surname'] and chs[0]['surname']!=a['surname']: husb,wife=b,a
        else: husb,wife=a,b
    elif len(sps)==1: husb=sps[0]
    if husb: lines.append(f'1 HUSB @{husb["person_id"]}@')
    if wife: lines.append(f'1 WIFE @{wife["person_id"]}@')
    for c in fm['children']: lines.append(f'1 CHIL @{c}@')
    lines.append('1 NOTE HUSB/WIFE assignment is inferred from which surname the children carry; the spreadsheet does not record sex.')
lines+=['0 @S1@ SOUR','1 TITL Family spreadsheet "FERNANDO VALIENTE MUÑASQUE.xlsx" (2014–2020)','1 AUTH unknown family compiler','1 NOTE Unsourced family compilation; see sources.csv for all other sources.','0 TRLR']
open(f'{OUT}/valiente_munasque.ged','w',encoding='utf-8').write('\n'.join(lines)+'\n')

# ---------------- JSON for charts/artifact ----------------
factmap=collections.defaultdict(list)
for pid,t,fa,s,c,n in facts: factmap[pid].append(dict(type=t,fact=fa,sources=s,confidence=c,notes=n))
relmap={ (r['person_a_id'],r['person_b_id']):r for r in rels}
data={'generated':'2026-10-28','estimates':EST,'people':{}}
for p in P.values():
    conf='low' if p['notes'] else 'moderate'
    d=dict(id=p['person_id'],name=p['display'],given=p['given'],middle=p['middle'],surname=p['surname'],suffix=p['suffix'],nick=p['nickname'],title=p['title'],
           gen=p['generation'],role=p['role'],row=p['sheet_row'],father=p['father_id'],mother=p['mother_id'],spouses=p['spouse_ids'],children=p['child_ids'],
           deceased=p['deceased'],residence=p['residence'],variants=p['variants'],notes=p['notes'],conf=conf,facts=factmap.get(p['person_id'],[]))
    # confidence of the link to parent
    r=relmap.get((p['father_id'] or p['mother_id'],p['person_id']))
    d['link_conf']= r['confidence'] if r else ''
    d['name_check']= r['name_check'] if r else ''
    data['people'][p['person_id']]=d
json.dump(data, open(f'{OUT}/data.json','w'), ensure_ascii=False)
print('sources',len(sources),'facts',len(facts),'fams',len(fams),'gedcom lines',len(lines))
