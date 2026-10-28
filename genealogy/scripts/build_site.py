"""Fill the report template with numbers and generated sections; build REPORT.md and the HTML report page."""
import json, csv, re, html, sys, os, collections
OUT=sys.argv[1]; SCR=os.path.dirname(os.path.abspath(__file__))
D=json.load(open(f'{OUT}/data.json')); P=D['people']
sources=list(csv.DictReader(open(f'{OUT}/sources.csv')))
facts=list(csv.DictReader(open(f'{OUT}/research_facts.csv')))
rels=list(csv.DictReader(open(f'{OUT}/relationships.csv')))
disc_rows=list(csv.reader(open(f'{OUT}/discrepancies.csv')))
manual=[r for r in disc_rows[1:] if r and r[0].startswith('DM')]
auto=[r for r in disc_rows if r and r[0].startswith('D0') or (r and r[0].startswith('D1'))]
overrides=list(csv.DictReader(open(f'{SCR}/overrides.csv')))
charts=json.load(open(f'{OUT}/charts/index.json'))
esc=html.escape
def cnt(pid): return sum(1+cnt(c) for c in P[pid]['children'])
blood=[p for p in P.values() if p['role']!='spouse']; sp=[p for p in P.values() if p['role']=='spouse']
branches=[P[c] for c in P['P0003']['children']]
bsizes={b['id']:cnt(b['id']) for b in branches}
nc=collections.Counter(r['name_check'] for r in rels if r['type']=='parent-child')

# residence per branch
def branch_places(pid):
    c=collections.Counter()
    def walk(x):
        for r in P[x]['residence'].split('; '):
            if r: c[r.title().replace('Nc','N. Cotabato').replace('Sc','S. Cotabato').replace('Gsc','Gen. Santos City').replace('Sk','Sultan Kudarat').replace('Sp','Sarangani').replace('Sar.Prov.','Sarangani')]+=1
        for ch in P[x]['children']: walk(ch)
        for s in P[x]['spouses']:
            for r in P[s]['residence'].split('; '):
                if r: c[r.title()]+=1
    walk(pid); return c
def notables(pid):
    out=[]
    def walk(x):
        p=P[x]
        if p['title'] or p['facts']: out.append(p)
        for ch in p['children']: walk(ch)
    walk(pid); return out

NAMES={'P0005':'Emiliano','P0546':'Agripina','P0789':'Andrea','P0925':'Marcos','P1135':'Florintina','P1202':'Epifanio','P1426':'Sotero','P1620':'Cosmiano','P1768':'Cruz'}
rows=[]
for b in branches:
    pl=branch_places(b['id']); top=', '.join(f'{k} ({v})' for k,v in pl.most_common(4)) or 'not stated'
    nt='; '.join((f"{p['title']}. " if p['title'] and p['title']!='nun' else '')+p['name']+(' (nun)' if p['title']=='nun' else '') for p in notables(b['id']))[:160] or '—'
    rows.append(f"| {b['name']} | {', '.join(P[s]['name'] for s in b['spouses'])} | {len(b['children'])} | {bsizes[b['id']]} | {top} | {nt} |")
BRANCH_TABLE='\n'.join(rows)

SUMM={
'P0005':"**Emiliano Valiente Muñasque (1857–1940) and Irenea Gusat.** The largest branch ({n} recorded descendants). Six children: Leona (m. Juan Dumo), Godofreda (m. Blas Cosip), Asisclo (m. Felicitas Gonzales), Diosdado (m. Maxima Lucero), Francisco (m. Cesaria Ancajas) and Sergia (m. Quintin Salimbangon Sr.). Godofreda's Cosip children and grandchildren are the Opon core of the sheet (Patalinghug, Lara, Rivera, Zambra, Dueñas lines; residences Opon, Glan, Koronadal, Polomolok, General Santos). Asisclo's children settled in Lanao del Norte, Polomolok and Agusan del Sur; one daughter lives in Germany. Sergia's Salimbangon children include Dr. Quintin Muñasque Salimbangon Jr. The compiler had placed Czar, Ruth and Dr. Quintin Jr. under their sister Thelma; their middle name \"Muñasque\" shows they are Sergia's children, and Sheet2 agrees. Confidence: moderate for the structure; the Gusat surname is itself rare in Philippine data (Forebears), so Irenea's family remains a lead.",
'P0546':"**Agripina Valiente Muñasque and Ambrosio Salimbangon.** Ten children: Sabiana (m. Ciriaco Go), Teodoro (m. Petronila Almazon), Teodulfo (m. Felipa Gelig), Felix (m. Estelita Esorio), Martin (m. Milagros Lago), Vecing (m. 1 Julio Tumulak, 2 Vicente Mejares), Pulguera (m. Sulficio Basmayor), Felicisimo (m. Pascuala Yap), Rosita (m. Marciano Mondigo) and Antonio (m. Lucia Ikong). {n} recorded descendants. Martin's family lived in Curva, Medellin, in northern Cebu, where Martin was a schoolteacher and barangay captain; his son Benhur became Congressman for Cebu's 4th District (2007–2019) and was buried at Mactan Island Memorial Garden, Lapu-Lapu, a cemetery run by his nephew. His brother Edwin was elected mayor of Medellin in 2025. Outside sources confirm the Martin–Milagros–Benhur chain but say nothing about Agripina or Ambrosio, so the link from Martin back to Opon still rests on the spreadsheet alone. The compiler's \"Cong. Benhur\" entry gives \"# Janice Zamora\" as a second partner; that is Janice Zamora Salimbangon, his widow and successor in Congress. Confidence: moderate; the Martin–Benhur link moderate-to-high.",
'P0789':"**Andrea Valiente Muñasque and Leon Pino.** Seven children (Juan, Demetrio \"Etiok\", Leonardo, Restituto, Sergio and others), {n} recorded descendants, residence not stated in the sheets. Sergio Muñasque Pino had two partners (Benavintora Etcuban; \"# 2 Gregoria Arnoco\"), which the sheet marks explicitly. Leonardo, Restituto and Sergio were listed by the compiler under Demetrio; their middle name \"Muñasque\" and surname Pino identify them as Andrea's children, and Sheet4 lists them at the top level. Confidence: moderate.",
'P0925':"**Marcos Valiente Muñasque** with **Matilde (\"Matildi\") Perez**, and later partners **Faustina Ynot** and **Basilia**. By Matilde: Purification (m. Renato Espinosa), Coronacion (m. Jesus Cabahug), Palexina (m. Antonio Serra Ty) and Col. Coronado \"Stim\" Perez Muñasque (m. Narcessa Bondoc Vivera; later Linda Jimenez). By Faustina Ynot: Leonarda (m. Tiburcio Booc), Gregoria (m. Steve Mendoza), Fernando Y. (m. Candida Sajonia). By Basilia: Antonio (m. Gavina Booc), Timotea (m. Alipio Bontilao), Gavino. {n} recorded descendants. This block of the sheet is the most inconsistently coloured, so the text labels and the naming convention were used instead; Palexina and Coronado, whose middle name is Perez, are placed one generation higher than the compiler's label. The Cabahug and Ty lines look urban (Cebu/Manila professional families; one Ty married a Murakami) but no residences are given. No outside record of Col. Coronado Muñasque was found. Confidence: moderate for Matilde's line; moderate for the later partners being Marcos's rather than Fernando's.",
'P1135':"**Florintina Valiente Muñasque and Fruto Etcuban.** Five children: Benvienido (m. Dolores Tabernero), Maximo, Federica (m. Pedro Mendoza), Adelfa and Leoncio (m. Desederia Booc). {n} recorded descendants. Adelfa and Leoncio are entered twice in the master sheet (once as Federica's children, once correctly as Florintina's); the duplicate was dropped. Leoncio's grandchildren with the initial S. (Sumarago) were re-attached to Alfredo B. Etcuban Sr. and Rosenda Salimbangon Sumarago. Residences not stated. Confidence: moderate.",
'P1202':"**Epifanio Valiente Muñasque and Simplicia Etcuban.** Nine children: Felixberto (m. Avelina Misa), Eliezar (m. Patrocinia Cortes), Teresita (m. Rolando Padua), Dominador \"Tting\" (m. Clarisa De Lima), Catalina (m. Felicisimo Gonzales), Ricardo (m. Basilia Cabusas), Cresencia (m. Domingo Cabarlo), Presentacion and Juanita. {n} recorded descendants. Catalina's Gonzales family is large (Pamintuan, Malabago, Duhaylungsod, Largo, Ordista, Tumaquin, Formentera lines). Ricardo's son is Dr. Ricardo C. Muñasque Jr. (m. Luz Olavides). Eliezar, Teresita and Dominador carry the initial E. (Etcuban) and are therefore Epifanio's children, not Felixberto's as the compiler placed them. Sheet7 and the master sheet disagree on whether \"Ethea/Eihea Paul(a)\" and \"Edward Pierre\" belong to Eliezar or to his grandson Erwin Paul; flagged. Residences not stated. Confidence: moderate.",
'P1426':"**Sotero Valiente Muñasque and Sebirina Ynot.** Five children: Basilio (m. Rosalia V. Nuñeza), Hilarion (m. Eustoquia Micayabas), Sulpicio (m. Arcadia N. Acaso), Narcisa (m. Monroyo) and Felisa. {n} recorded descendants. Basilio's children include Atty. Benjamin N. Muñasque (Clerk of Court, CFI Cotabato, 1970s), Rev. Fr. Rosalio N. Muñasque (Diocese of Marbel, d. 2003) and Josephina, a nun. Sulpicio is very probably the evangelist Sulpicio Y. Muñasque who moved from Lala, Lanao del Norte, to General Santos in 1939; his son Gideon A. Muñasque Sr. (children Easter Glory and Gideon Jr., and seven more by a second wife, Elsa Guarde Paredes) heads the next generation. This is the branch with the strongest outside corroboration and the clearest Mindanao story (Lanao del Norte → South Cotabato). Confidence: moderate; identities of the three named men moderate.",
'P1620':"**Cosmiano Valiente Muñasque** with **Sofia Montesclaros Mansueto**, and a second family with **Sarip Arabia Omar**. By Sofia: Marcelina (m. Walter Cebedo Sr.) and Fernando M. Muñasque Sr. (m. Cecilia Lim Fernan), whose line runs Fernando Jr., Fernando III, Fernando IV. By Sarip Arabia Omar: Hadja Amina Omar Muñasque, who married Toncio Maulana Tambingag; their nine children and the Pangolima, Hadjan, Hassan, Moraga and Marohombsar in-laws are a Muslim (Maranao/Maguindanao-named) family. The Tambingag surname clusters today in General Santos City and Sarangani (Forebears; a 2025 Maasim council candidate). {n} recorded descendants. Children of Malapat Tambingag and Tarhata Marohombsar carry the initial T. for the mother's given name, a Moro usage, which the naming check correctly flags but which is not an error. Two US residents named Nigel Fernando and Erwin Fernando Muñasque were found online; they may belong to this \"Fernando\" line but nothing links them. Confidence: moderate for Sofia's line; low-to-moderate for the Omar/Tambingag family.",
'P1768':"**Cruz Valiente Muñasque and Remedios Dela Piña.** Two children, Elmo and Mariano (m. Burgos); {n} recorded descendants, including a Matthews family (Mariano's grandson Frank Luis Fernando married Patricia Matthews). Elmo is probably the Cebu building contractor of the 1966 contract litigated to the Supreme Court in 1985. Confidence: moderate.",
}
BRANCH_SUMMARIES='\n\n'.join(SUMM[b['id']].format(n=bsizes[b['id']]) for b in branches)

PROF=[
("Fernando Umpad Muñasque (G1, progenitor)","Son of Alejandro Muñasque and Saturnina Umpad; husband of Saturnina N. Valiente; father of nine. Born about 1820–1835 (estimate from Emiliano's 1857 birth); of Opon, Cebu. No image, record or date exists for him. The Umpad/Ompad surname is a Mactan Island name, which supports the Opon origin. Sources: S1, S33."),
("Saturnina N. Valiente (G1)","Wife of Fernando; mother of the nine \"Valiente Muñasque\" children. Her middle initial N. is the only clue to her own mother's surname. Valiente is a Spanish surname that also appears in the 1849 Claveria catalogue tradition, but her family is undocumented. Sources: S1."),
("Emiliano Valiente Muñasque (G2), 20 May 1857 – 19 Feb 1940","The only dated person. Husband of Irenea Gusat; father of six; head of the largest branch. Born under Spanish rule and died a year before the Pacific War, aged 83. His death in February 1940 should be in the Opon civil register (Act 3753 was in force) and the Opon parish burial book; neither has been searched yet. Sources: S1."),
("Agripina Valiente Muñasque and Ambrosio Salimbangon (G2)","Parents of the Salimbangon branch (ten children). The branch later appears in Curva, Medellin, 120 km north of Opon, where the son Martin was a teacher and village head; how and when the family moved is unknown. The Cebuano word *salimbangon* is a plant name (Wiktionary). Sources: S1, S14, S15."),
("Martin Salimbangon and Milagros Lago (G3)","Schoolteacher and barangay captain of Curva, Medellin (S14, S15); Milagros born 8 September 1915 or 1916, still living in 2013 at 98 (S16, S17). Parents of Aida, Ofelia/Ophelia (m. Jose Cue; d. before 2006), Benhur, Cesar, Mariquita (m. Carlos Yeung), Danilo, Edwin (Mayor of Medellin 2025) and Freddie per the spreadsheet; the press counts seven children."),
("Congressman Benhur Lago Salimbangon (G4), 3 Jun 1945 – 24 Dec 2020","Provincial Board Member 1992–1998; Representative for Cebu's 4th District 2007–2019; married Mariter Trocino and later Janice Zamora, who succeeded him in Congress; seven children including Francis Edward (Mayor of Tabogon). Died of lung cancer; buried at Mactan Island Memorial Garden, Lapu-Lapu City. The only person in the tree whose dates are confirmed by two independent outside sources. Sources: S10–S13."),
("Sulpicio Ynot Muñasque (G3)","Son of Sotero and Sebirina Ynot. Very probably the evangelist \"Sulpicio Y. Munasque\" of the United Evangelical Church who came from Lala, Lanao del Norte, to Dadiangas on 7 March 1939, two weeks after the first NLSA settlers landed, and who with his wife petitioned Gen. Paulino Santos for a church lot in 1941; a street in Dadiangas North bears his name. Married Arcadia N. Acaso; father of Gideon A. Muñasque Sr. Sources: S1, S29, S30, S40."),
("Rev. Fr. Rosalio N. Muñasque (G4), d. 2 Dec 2003","Son of Basilio Ynot Muñasque and Rosalia V. Nuñeza. Diocesan priest of Marbel (Koronadal, South Cotabato): rector of the Our Lady of Perpetual Help Seminary about 1975, parish priest of Banga 1975–1978, spiritual director of Notre Dame of Kiamba. Sources: S21–S24."),
("Atty. Benjamin N. Muñasque (G4)","Brother of Fr. Rosalio; married Erlinda Yu. Supreme Court records of 1972–1979 name a \"Benjamin N. Muñasque, Clerk of Court, Court of First Instance of Cotabato\"; the rare surname, the initial N. and the title make the identification probable. Sources: S1, S25, S26."),
("Col. Coronado \"Stim\" Perez Muñasque (G3)","Son of Marcos and Matilde Perez; married Narcessa Bondoc Vivera and later Linda Jimenez; grandfather of Stimson Muñasque. The title Col. comes from Sheet5 only; no military record was found. Sources: S1, S2."),
("Hadja Amina Omar Muñasque (G3)","Daughter of Cosmiano by Sarip Arabia Omar; wife of Toncio Maulana Tambingag; mother of Bai, Pompie, Udtog, Hadja Alijah Patring, Eduardo, Rachima, Dayang, Solaiman and Malapat. The honorific Hadja indicates she made the pilgrimage to Mecca. The family is the one Muslim branch of the tree; its location (probably the General Santos–Sarangani coast) is inferred from the surname's distribution, not from the sheet. Sources: S1, S2."),
("Atty. Marnito B. Cosep / Cosip (G5)","Son of Hermenio Muñasque Cosip and Marina Berami; Provincial Legal Officer of South Cotabato, Koronadal City. Sources: S2, S27, S28."),
]
PROFILES='\n\n'.join(f"**{t}.** {b}" for t,b in PROF)

# geography text
pc=charts['place_counts']; ab=charts['abroad']
GEO_TEXT=("The branch sheets (S2) give a residence for 72 people, almost all in generations 4–6, so the map shows where the family was living around 2014–2020, not where each person was born. Counts by place: "
 + ', '.join(f"{k} {v}" for k,v in sorted(pc.items(), key=lambda kv:-kv[1])) + f"; abroad: {', '.join(f'{k} {v}' for k,v in ab.items())}. "
 "Only one move is dated and documented: Sulpicio Y. Muñasque from Lala, Lanao del Norte, to Dadiangas (General Santos) on 7 March 1939 (S29). The Opon origin of every other branch is the compiler's statement (S3) supported by the Mactan surnames (Umpad, Patalinghug, Booc, Ynot, Etcuban) in the early generations. The Martin Salimbangon family's home in Curva, Medellin (northern Cebu) comes from the press (S14–S16). All other arrows on the map are therefore hypothetical routes between a documented origin and a documented later residence.")

DISC_LIST='\n'.join(f"- **{r[1]}** — {r[2]} *Reading:* {r[3]} ({r[4]})." for r in manual)

GAPS="""Ranked by expected value and feasibility.

1. **Opon parish registers, 1840–1940 (highest value).** FamilySearch collection 5000324, "Philippines, Central Visayas, Church Records, 1737–2005", holds baptisms, marriages and burials for Cebu parishes, partly indexed, images browsable with a free account; the FamilySearch wiki inventory lists the parish *Nuestra Señora de la Virgen de Regla, Lapu-Lapu City* (S34, S35). Search surname Muñasque / Munasque / Muñasqui with place Opon, then browse the unindexed images by year. Targets: Emiliano's baptism (May–June 1857) naming Fernando and Saturnina Valiente and the grandparents; Fernando's marriage to Saturnina (before 1857); Fernando's own baptism (c. 1820–1835) naming Alejandro and Saturnina Umpad; baptisms of the other eight children (c. 1858–1885); Emiliano's burial (February 1940). One hit would settle the first three generations.
2. **Emiliano's civil death record, Feb 1940.** Request a "Transcription of Facts of Death from the Registry Book" (Civil Registry Form 2A) from the Lapu-Lapu City Local Civil Registry Office; PSA itself holds almost nothing before 1945 (S36). Also check FamilySearch civil-registration collections 2018411 (1902–1945) and 1410394 (local, 1888–1986).
3. **1849 Claveria catalogue.** Open the Filipinas Heritage Library scan (biblio/50226) or the 1973 National Archives reprint and check the "Mu-" pages for Muñasque. Presence would mean the surname was assigned in 1850 and the Mukilan–Anañas–Roque story is folk etymology; absence would favour an older indigenous or invented name.
4. **Spanish-era *padrones* / vecindarios.** FamilySearch collection 5000268, "Philippines, Neighborhood Census, 1836–1899", extracts parish household lists; a Muñasque household in Opon would give ages and relationships for Fernando's generation.
5. **Benhur Salimbangon's own documents.** His House of Representatives profile or obituary programme would state parents and birthplace and resolve Medellin vs Cebu City. Ask the family for Milagros Lago's death notice to fix her birth year.
6. **Salimbangon move to Medellin.** Search the Medellin parish (San Isidro Labrador?) and civil registers for Martin Salimbangon's marriage to Milagros Lago (c. 1935–1945) and for Ambrosio Salimbangon; this would show whether Agripina's family moved north or whether Ambrosio was from Medellin.
7. **Diocese of Marbel records** for Fr. Rosalio N. Muñasque (ordination file, necrology) and **Court of First Instance of Cotabato** appointment records for Atty. Benjamin N. Muñasque: both would name parents and birthplace and tie the Sotero line to Opon with a document.
8. **UCCP Lagao history (S29) in full** and the UCCP/United Evangelical Church archives for Sulpicio Y. Muñasque: his ordination or appointment papers would give his birthplace and parents (expected: Opon; Sotero and Sebirina Ynot).
9. **Interview the compiler.** The spreadsheet's author (file saved by "MarkhyNet") interviewed Amador Piligro in 2006 and clearly knew the Cosip/Patalinghug families of Opon personally. Ask for the sources of the 1857 and 1940 dates, the meaning of the colour and "#" conventions, and the sex of each person (needed for a correct GEDCOM).
10. **Gusat, Ynot, Etcuban, Cosip families of Opon.** These in-law surnames are rare and local; FamilySearch index hits for them in Opon would indirectly confirm the Muñasque entries around them.
11. **DNA.** No DNA data was supplied. Autosomal tests of descendants from at least three different branches (e.g. Emiliano's, Sotero's and Cosmiano's) would test whether the nine branches really share Fernando and Saturnina as ancestors; Y-DNA from male-line Muñasques would test whether the surname has a single origin. Results give relationship ranges, not exact positions, and cannot by themselves distinguish Fernando from a brother.
12. **Lower priority:** Col. Coronado Muñasque in Philippine Army/Constabulary rosters; Dr. Ricardo C. Muñasque Jr. in PRC physician lists; Engr. Marlon Cosep in PRC engineer lists; the Tambingag family through Sarangani local records; US/Australian records for the Muñasques abroad."""

tpl=open(f'{SCR}/report_template.md',encoding='utf-8').read()
fill={'N_PEOPLE':f'{len(P):,}','N_GEN':str(max(p['gen'] for p in P.values())),'N_BLOOD':f'{len(blood):,}','N_SPOUSE':str(len(sp)),
      'MIN_BRANCH':str(min(bsizes.values())),'MAX_BRANCH':str(max(bsizes.values())),'N_OVERRIDES':str(sum(1 for o in overrides if o.get('parent_row') or o.get('gen') or o.get('spouse_of_row'))),
      'N_LOW':str(sum(p['conf']=='low' for p in P.values())),'N_OK':str(nc['ok']),'N_MISMATCH':str(nc['middle-mismatch']+nc['surname-mismatch']),
      'BRANCH_TABLE':BRANCH_TABLE,'BRANCH_SUMMARIES':BRANCH_SUMMARIES,'PROFILES':PROFILES,'GEO_TEXT':GEO_TEXT,'DISC_LIST':DISC_LIST,'GAPS':GAPS,
      'N_DISC_MANUAL':str(len(manual)),'N_DISC_AUTO':str(len([r for r in disc_rows if r and re.match(r'D\d{4}',r[0])]))}
md=tpl
for k,v in fill.items(): md=md.replace('{{'+k+'}}',v)
# bibliography appended
bib=['','## 14. Source bibliography','','| ID | Source | Type | Original / derivative | Supplied by user | Notes |','|---|---|---|---|---|---|']
for s in sources:
    link=s['repository_or_url'];
    if link.startswith('http'): link=' ; '.join(f'<{u.strip()}>' for u in link.split(';'))
    bib.append(f"| {s['source_id']} | {s['title']} ({link}) | {s['record_type']} | {s['original_derivative_or_index']} | {s['supplied_by_user']} | {s['notes']} |")
md+='\n'.join(bib)+'\n'
open(f'{OUT}/REPORT.md','w',encoding='utf-8').write(md)

# ---------------- minimal markdown -> html ----------------
def inline(t):
    t=esc(t)
    t=re.sub(r'&lt;(https?://[^&]+)&gt;',r'<a href="\1">\1</a>',t)
    t=re.sub(r'\[([^\]]+)\]\((https?://[^)]+)\)',r'<a href="\2">\1</a>',t)
    t=re.sub(r'`([^`]+)`',r'<code>\1</code>',t)
    t=re.sub(r'\*\*(.+?)\*\*',r'<strong>\1</strong>',t)
    t=re.sub(r'(?<![\w*])\*([^*]+?)\*(?!\w)',r'<em>\1</em>',t)
    return t
def md2html(md):
    out=[]; lines=md.split('\n'); i=0
    while i<len(lines):
        l=lines[i]
        if l.startswith('#'):
            n=len(l)-len(l.lstrip('#')); txt=l[n:].strip(); sid=re.sub(r'[^a-z0-9]+','-',txt.lower()).strip('-')[:60]
            out.append(f'<h{n} id="s-{sid}">{inline(txt)}</h{n}>'); i+=1; continue
        if l.startswith('|'):
            tb=[]
            while i<len(lines) and lines[i].startswith('|'): tb.append(lines[i]); i+=1
            hdr=[c.strip() for c in tb[0].strip('|').split('|')]
            out.append('<div class="tablewrap"><table><thead><tr>'+''.join(f'<th>{inline(c)}</th>' for c in hdr)+'</tr></thead><tbody>')
            for r in tb[2:]:
                cells=[c.strip() for c in r.strip('|').split('|')]
                out.append('<tr>'+''.join(f'<td>{inline(c)}</td>' for c in cells)+'</tr>')
            out.append('</tbody></table></div>'); continue
        if re.match(r'^\s*[-*] ',l):
            out.append('<ul>')
            while i<len(lines) and re.match(r'^\s*[-*] ',lines[i]): out.append(f'<li>{inline(re.sub(r"^\s*[-*] ","",lines[i]))}</li>'); i+=1
            out.append('</ul>'); continue
        if re.match(r'^\s*\d+\. ',l):
            out.append('<ol>')
            while i<len(lines) and re.match(r'^\s*\d+\. ',lines[i]): out.append(f'<li>{inline(re.sub(r"^\s*\d+\. ","",lines[i]))}</li>'); i+=1
            out.append('</ol>'); continue
        if l.strip()=='' : i+=1; continue
        para=[l]; i+=1
        while i<len(lines) and lines[i].strip() and not re.match(r'^(#|\||\s*[-*] |\s*\d+\. )',lines[i]): para.append(lines[i]); i+=1
        out.append(f'<p>{inline(" ".join(para))}</p>')
    return '\n'.join(out)

# split report into sections by H2 so we can interleave charts
secs=re.split(r'\n(?=## )', md)
body_html=[]
def chart(name):
    s=open(f'{OUT}/charts/{name}',encoding='utf-8').read()
    s=re.sub(r'<style>.*?</style>','',s,flags=re.S)
    return f'<figure class="chart"><div class="scroller">{s}</div></figure>'
titles=[re.match(r'## (.*)',s).group(1) if s.startswith('## ') else 'Title' for s in secs]
for s in secs:
    if s.startswith('# '): s=s.split('\n',1)[1]
    h=md2html(s)
    t=s.split('\n',1)[0]
    if t.startswith('## 2.'): h+=chart('generations.svg')
    if t.startswith('## 4.'):
        h=h.replace('<h3 id="s-4-2',chart('pedigree.svg')+chart('overview.svg')+'<h3 id="s-4-2',1)
        bl=''.join(chart(f'branch_{c}.svg') for c,_,_,_,_,_ in charts['branches'])
        h=h.replace('<h3 id="s-4-3',bl+'<h3 id="s-4-3',1)
    if t.startswith('## 7.'): h+=chart('map.svg')+chart('timeline.svg')
    if t.startswith('## 8.'): h=chart('evidence.svg')+h
    body_html.append(h)
SHORT={'1':'Summary','2':'Inventory','3':'Method','4':'Lineage','5':'Profiles','6':'Research','7':'Geography','8':'Evidence','9':'Discrepancies','10':'Next steps','11':'Privacy','12':'Files','13':'Conclusion','14':'Sources'}
NAV='\n'.join(f'<a href="#s-{re.sub(r"[^a-z0-9]+","-",t.lower()).strip("-")[:60]}">{SHORT.get(t.split(".")[0],t[:20])}</a>' for t in titles[1:])

# compact tree data for the explorer
tree={}
for p in P.values():
    tree[p['id']]={'id':p['id'],'n':p['name'],'g':p['gen'],'r':p['role'][0],'f':p['father'],'m':p['mother'],'s':p['spouses'],'c':p['children'],'res':p['residence'],'t':p['title'],'nk':p['nick'],'d':p['deceased'],
                   'cf':p['conf'],'lc':p['link_conf'],'row':p['row'],'v':p['variants'],'no':p['notes'],'fx':[(f['type'],f['fact'],f['sources'],f['confidence']) for f in p['facts']]}
TREEJSON=json.dumps(tree,ensure_ascii=False,separators=(',',':'))

page=f'''<title>Muñasque Family Lineage</title>
<meta name="claude:viewport-fit-sides" content="cover">
<style>
/* Layout: a long-form research report with a sticky section nav, an interactive explorer near the top, and wide charts in their own scrollers. */
:root{{--bg:#f7f5f0;--surface:#fffdf9;--ink:#1d1b17;--ink2:#5c5a55;--line:#d9d5cc;--acc:#2a78d6;--acc2:#eb6834;--warn:#b26a00;--good:#0ca30c;--grid:#e6e3dc;--box:#ffffff;--boxline:#9a9790;--edge:#8f8c85;
 --display:'Source Serif 4',Georgia,'Times New Roman',serif;--body:'Source Sans 3','Segoe UI',Arial,sans-serif;--mono:'DejaVu Sans Mono',Menlo,Consolas,monospace}}
@media (prefers-color-scheme:dark){{:root:not([data-theme="light"]){{--bg:#1a1a19;--surface:#23221f;--ink:#efede8;--ink2:#b8b5ad;--line:#3a3833;--acc:#3987e5;--acc2:#d95926;--warn:#fab219;--good:#2fbf2f;--grid:#35332f;--box:#23221f;--boxline:#6b6861;--edge:#8a877f;color-scheme:dark}}}}
:root[data-theme="dark"]{{--bg:#1a1a19;--surface:#23221f;--ink:#efede8;--ink2:#b8b5ad;--line:#3a3833;--acc:#3987e5;--acc2:#d95926;--warn:#fab219;--good:#2fbf2f;--grid:#35332f;--box:#23221f;--boxline:#6b6861;--edge:#8a877f;color-scheme:dark}}
body{{background:var(--bg);color:var(--ink);font-family:var(--body);font-size:16px;line-height:1.55;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px));padding-block:0 48px}}
header.top{{max-width:1100px;margin:0 auto;padding:28px 0 8px;border-bottom:1px solid var(--line)}}
header.top h1{{font-family:var(--display);font-weight:600;font-size:clamp(26px,4vw,40px);line-height:1.1;margin:0 0 8px;text-wrap:balance}}
header.top p{{margin:4px 0;color:var(--ink2);max-width:70ch}}
nav.sec{{position:sticky;top:env(safe-area-inset-top,0px);background:var(--bg);z-index:5;display:flex;gap:4px 14px;flex-wrap:wrap;padding:8px 0;border-bottom:1px solid var(--line);font-size:13px;max-width:1100px;margin:0 auto 12px}}
nav.sec a{{color:var(--acc);text-decoration:none;white-space:nowrap}} nav.sec a:hover,nav.sec a:focus-visible{{text-decoration:underline;outline:none}}
main{{max-width:1100px;margin:0 auto}}
main p,main li{{max-width:72ch}}
h2{{font-family:var(--display);font-weight:600;font-size:26px;margin:40px 0 12px;padding-top:8px;border-top:1px solid var(--line);text-wrap:balance}}
h3{{font-family:var(--display);font-weight:600;font-size:19px;margin:28px 0 8px}}
a{{color:var(--acc)}} code{{font-family:var(--mono);font-size:.9em;background:var(--surface);border:1px solid var(--line);border-radius:3px;padding:0 3px}}
.tablewrap{{overflow-x:auto;margin:12px 0;border:1px solid var(--line);border-radius:4px;background:var(--surface)}}
table{{border-collapse:collapse;font-size:14px;min-width:100%}} th,td{{text-align:left;vertical-align:top;padding:6px 9px;border-bottom:1px solid var(--line)}} th{{font-size:12px;letter-spacing:.04em;text-transform:uppercase;color:var(--ink2);background:var(--bg)}}
figure.chart{{margin:16px 0;border:1px solid var(--line);border-radius:4px;background:var(--surface)}} .scroller{{overflow-x:auto;padding:6px}} .scroller svg{{display:block;max-width:none}}
svg.gchart{{font-family:'DejaVu Sans','Noto Sans',Arial,sans-serif;background:var(--surface)}}
.ink{{fill:var(--ink)}}.ink2{{fill:var(--ink2)}}.box{{fill:var(--box);stroke:var(--boxline);stroke-width:1}}.box.low{{stroke-dasharray:4 3;stroke:var(--warn)}}
.edge{{fill:none;stroke:var(--edge);stroke-width:1.2}}.edge.low{{stroke-dasharray:4 3;stroke:var(--warn)}}
.sp{{fill:var(--ink2)}}.t{{font-size:11px}}.s{{font-size:9.5px}}.h{{font-size:15px;font-weight:bold}}.cap{{font-size:10px;fill:var(--ink2)}}.gen{{font-size:9px;fill:var(--acc)}}
/* explorer */
.explorer{{border:1px solid var(--line);border-radius:4px;background:var(--surface);margin:12px 0 8px}}
.explorer .bar{{display:flex;gap:8px;flex-wrap:wrap;align-items:center;padding:10px;border-bottom:1px solid var(--line)}}
.explorer input[type=search]{{flex:1 1 220px;min-width:0;padding:7px 10px;border:1px solid var(--line);border-radius:4px;background:var(--bg);color:var(--ink);font:inherit;font-size:14px}}
.explorer button{{padding:7px 12px;border:1px solid var(--line);border-radius:4px;background:var(--bg);color:var(--ink);font:inherit;font-size:13px;cursor:pointer}} .explorer button:hover,.explorer button:focus-visible{{border-color:var(--acc);outline:none}}
.explorer .hint{{font-size:12px;color:var(--ink2);flex-basis:100%}}
.explorer .wrap{{display:grid;grid-template-columns:minmax(0,1fr) 300px;min-height:420px}} @media (max-width:760px){{.explorer .wrap{{grid-template-columns:1fr}}}}
.explorer .treebox{{overflow:auto;max-height:70vh;min-width:0}} .explorer #tree{{display:block}}
.explorer .detail{{border-left:1px solid var(--line);padding:12px;font-size:14px;overflow:auto;max-height:70vh}} @media (max-width:760px){{.explorer .detail{{border-left:0;border-top:1px solid var(--line)}}}}
.detail h4{{margin:0 0 6px;font-family:var(--display);font-size:17px}} .detail dl{{margin:0;display:grid;grid-template-columns:auto 1fr;gap:3px 10px}} .detail dt{{color:var(--ink2);font-size:12px;text-transform:uppercase;letter-spacing:.04em}} .detail dd{{margin:0}}
.pill{{display:inline-block;padding:1px 7px;border-radius:10px;font-size:11px;border:1px solid var(--line)}} .pill.low{{border-color:var(--warn);color:var(--warn)}} .pill.moderate{{border-color:var(--acc);color:var(--acc)}} .pill.high{{border-color:var(--good);color:var(--good)}}
.node circle{{stroke:var(--acc);stroke-width:1.5;fill:var(--surface);cursor:pointer}} .node.collapsed circle{{fill:var(--acc)}} .node.sel circle{{stroke:var(--acc2);stroke-width:3}} .node text{{font:11px var(--body);fill:var(--ink);cursor:pointer;paint-order:stroke;stroke:var(--surface);stroke-width:3px;stroke-linejoin:round}} .node.low text{{fill:var(--warn)}}
.link{{fill:none;stroke:var(--edge);stroke-width:1}} .link.low{{stroke:var(--warn);stroke-dasharray:3 3}}
.legend{{font-size:12px;color:var(--ink2);padding:6px 10px;display:flex;gap:14px;flex-wrap:wrap}}
.sr{{position:absolute;left:-9999px}}
@media (prefers-reduced-motion:reduce){{*{{transition:none!important}}}}
</style>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Source+Serif+4:wght@400;600&family=Source+Sans+3:wght@400;600&display=swap">
<header class="top">
<h1>The Muñasque family of Opon, Cebu</h1>
<p>Genealogical reconstruction from the family spreadsheet "FERNANDO VALIENTE MUÑASQUE.xlsx", with independent web research. Report date 28 October 2026.</p>
<p>{len(P):,} people · {max(p['gen'] for p in P.values())} generations · 9 branches · 1 dated person · 4 descendants corroborated by outside sources</p>
</header>
<nav class="sec" aria-label="Sections"><a href="#explorer">Explorer</a>{NAV}</nav>
<main>
<section id="explorer">
<h2 id="s-explorer">Interactive tree explorer</h2>
<p>Click a circle to open or close a branch; click a name to see details. Filled circles have hidden children. Orange names and dashed lines mark low-confidence placements. Spouses are shown in the detail panel, not as tree nodes.</p>
<div class="explorer">
 <div class="bar"><label class="sr" for="q">Search a name</label><input id="q" type="search" placeholder="Search a name (e.g. Salimbangon, Sulpicio, Cosip)"><button id="expand2" type="button">Show to G3</button><button id="expand4" type="button">Show to G5</button><button id="collapse" type="button">Collapse all</button><span class="hint" id="hint">Generation numbering: G1 = Fernando Umpad Muñasque; G0 = his parents.</span></div>
 <div class="wrap"><div class="treebox"><svg id="tree" role="img" aria-label="Collapsible family tree"></svg></div><aside class="detail" id="detail"><h4>Fernando Umpad Muñasque</h4><p>Select a person to see parents, spouses, children, residence, confidence and any outside facts.</p></aside></div>
 <div class="legend"><span>● filled = collapsed branch</span><span>orange = low confidence</span><span>G = generation</span><span>Source rows refer to sheet FERNANDO, column A</span></div>
</div>
</section>
{''.join(body_html)}
</main>
<script src="https://cdnjs.cloudflare.com/ajax/libs/d3/7.9.0/d3.min.js"></script>
<script>
if(!window.d3){{document.getElementById('detail').innerHTML='<p>The tree library (D3, from cdnjs.cloudflare.com) did not load, so the explorer cannot draw. The static charts and tables below do not depend on it.</p>';}}
const T={TREEJSON};
const ROOT='P0003';
function mk(id){{const p=T[id];return {{id,p,children:p.c.map(mk)}};}}
const data=mk(ROOT);
const root=d3.hierarchy(data);
root.each(d=>{{d._children=d.children;}});
function collapseBelow(gen){{root.each(d=>{{if(d.data.p.g>=gen){{d.children=null;}}else{{d.children=d._children;}}}});}}
collapseBelow(2);
const svg=d3.select('#tree');const g=svg.append('g').attr('transform','translate(10,20)');
const tree=d3.tree().nodeSize([16,230]);
let sel=null;
function label(p){{return p.n+(p.t?' ('+p.t+')':'')+(p.d?' †':'');}}
function update(){{
  tree(root);
  let y0=Infinity,y1=-Infinity;root.each(d=>{{y0=Math.min(y0,d.x);y1=Math.max(y1,d.x);}});
  const H=y1-y0+40,W=(root.height+1)*230+260;
  svg.attr('width',W).attr('height',H).attr('viewBox',`0 0 ${{W}} ${{H}}`);
  g.attr('transform',`translate(10,${{-y0+20}})`);
  const nodes=root.descendants(),links=root.links();
  const l=g.selectAll('path.link').data(links,d=>d.target.data.id);
  l.enter().append('path').attr('class',d=>'link'+(d.target.data.p.lc==='low'?' low':'')).merge(l)
   .attr('d',d3.linkHorizontal().x(d=>d.y).y(d=>d.x));
  l.exit().remove();
  const n=g.selectAll('g.node').data(nodes,d=>d.data.id);
  const ne=n.enter().append('g');
  ne.append('circle').attr('r',4.5).on('click',(e,d)=>{{d.children=d.children?null:d._children;update();}});
  ne.append('text').attr('dy','0.32em').attr('x',8).on('click',(e,d)=>{{show(d.data.id);}});
  ne.append('title');
  const nm=ne.merge(n);
  nm.attr('class',d=>'node'+(d._children&&d._children.length&&!d.children?' collapsed':'')+(d.data.p.cf==='low'?' low':'')+(sel===d.data.id?' sel':''))
    .attr('transform',d=>`translate(${{d.y}},${{d.x}})`);
  nm.select('text').text(d=>label(d.data.p)+(d._children&&d._children.length&&!d.children?'  (+'+countDesc(d)+')':''));
  nm.select('title').text(d=>'G'+d.data.p.g+' · row '+d.data.p.row+' · '+d.data.p.cf+' confidence');
  n.exit().remove();
}}
function countDesc(d){{let c=0;(function w(x){{(x._children||[]).forEach(k=>{{c++;w(k);}});}})(d);return c;}}
function esc(s){{return String(s).replace(/[&<>"]/g,c=>({{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}})[c]);}}
function nameOf(id){{return id&&T[id]?esc(T[id].n):'';}}
function show(id){{
  sel=id;const p=T[id];const d=document.getElementById('detail');
  const par=[p.f,p.m].filter(x=>x).map(x=>`<a href="#" data-go="${{x}}">${{nameOf(x)}}</a>`).join(' &amp; ')||'<em>not recorded</em>';
  const sps=p.s.map(x=>`<a href="#" data-go="${{x}}">${{nameOf(x)}}</a>`).join(', ')||'<em>none recorded</em>';
  const kids=p.c.map(x=>`<a href="#" data-go="${{x}}">${{nameOf(x)}}</a>`).join(', ')||'<em>none recorded</em>';
  const fx=p.fx.map(f=>`<li><strong>${{esc(f[0])}}:</strong> ${{esc(f[1])}} <span class="pill ${{esc(f[3])}}">${{esc(f[3])}}</span> <span style="color:var(--ink2)">[${{esc(f[2])}}]</span></li>`).join('');
  d.innerHTML=`<h4>${{esc(label(p))}}${{p.nk?' <span style="font-weight:normal;color:var(--ink2)">"'+esc(p.nk)+'"</span>':''}}</h4>
   <dl><dt>Generation</dt><dd>G${{p.g}} ${{p.r==='s'?'(spouse)':''}}</dd><dt>Parents</dt><dd>${{par}}</dd><dt>Spouse(s)</dt><dd>${{sps}}</dd><dt>Children</dt><dd>${{kids}}</dd>
   ${{p.res?`<dt>Residence</dt><dd>${{esc(p.res)}} <span style="color:var(--ink2)">(branch sheets, c. 2014–2020)</span></dd>`:''}}
   ${{p.v.length?`<dt>Variants</dt><dd>${{esc(p.v.join('; '))}}</dd>`:''}}
   <dt>Confidence</dt><dd><span class="pill ${{p.cf}}">${{p.cf}}</span> placement${{p.lc?`, <span class="pill ${{p.lc}}">${{p.lc}}</span> link to parents`:''}}</dd>
   <dt>Source</dt><dd>S1, sheet FERNANDO row ${{p.row}}</dd></dl>
   ${{p.no.length?'<p style="font-size:13px"><strong>Notes:</strong> '+esc(p.no.join(' · '))+'</p>':''}}
   ${{fx?'<p style="margin:8px 0 2px"><strong>Outside facts</strong></p><ul style="padding-left:18px;font-size:13px">'+fx+'</ul>':''}}`;
  d.querySelectorAll('[data-go]').forEach(a=>a.addEventListener('click',e=>{{e.preventDefault();reveal(a.dataset.go);}}));
  update();
}}
function reveal(id){{
  // expand the path from root to the person (or to their descendant-line anchor for spouses)
  let target=id;const p=T[id];
  if(p.r==='s'){{target=p.s[0]||id;}}
  const path=[];let x=target;while(x){{path.unshift(x);const q=T[x];x=q.f&&T[q.f]&&T[q.f].r!=='s'?q.f:(q.m||'');}}
  root.each(d=>{{if(path.includes(d.data.id)&&d._children){{d.children=d._children;}}}});
  show(id);
  const el=[...document.querySelectorAll('#tree g.node')].find(n=>d3.select(n).datum().data.id===target);
  if(el){{el.scrollIntoView({{block:'center',inline:'center'}});}}
}}
document.getElementById('q').addEventListener('input',e=>{{
  const q=e.target.value.trim().toLowerCase();const hint=document.getElementById('hint');
  if(q.length<2){{hint.textContent='Generation numbering: G1 = Fernando Umpad Muñasque; G0 = his parents.';return;}}
  const hits=Object.values(T).filter(p=>p.n.toLowerCase().includes(q)).slice(0,12);
  hint.innerHTML=hits.length?hits.map(p=>`<a href="#" data-hit="${{p.id}}">${{esc(p.n)}} (G${{p.g}})</a>`).join(' · '):'No match';
  hint.querySelectorAll('[data-hit]').forEach(a=>a.addEventListener('click',ev=>{{ev.preventDefault();reveal(a.dataset.hit);}}));
}});
document.getElementById('expand2').addEventListener('click',()=>{{collapseBelow(3);update();}});
document.getElementById('expand4').addEventListener('click',()=>{{collapseBelow(5);update();}});
document.getElementById('collapse').addEventListener('click',()=>{{collapseBelow(2);update();}});
if(window.d3){{update();show('P0003');}}
</script>
'''
os.makedirs(f'{OUT}/site',exist_ok=True)
open(f'{OUT}/site/munasque-lineage.html','w',encoding='utf-8').write(page)
print('report chars',len(md),'page bytes',len(page.encode()))
