"""Generate static SVG charts from data.json (no external libraries)."""
import json, sys, math, html, collections
OUT=sys.argv[1]
D=json.load(open(f'{OUT}/data.json')); P=D['people']
CH=f'{OUT}/charts'
STYLE="""<style>
svg.gchart{font-family:'DejaVu Sans','Noto Sans',Arial,sans-serif;--ink:#1d1b17;--ink2:#5c5a55;--edge:#8f8c85;--box:#ffffff;--boxline:#9a9790;--acc:#2a78d6;--acc2:#eb6834;--warn:#b26a00;--grid:#e6e3dc;--bg:#faf9f6;background:var(--bg)}
@media (prefers-color-scheme:dark){svg.gchart{--ink:#efede8;--ink2:#b8b5ad;--edge:#8a877f;--box:#23221f;--boxline:#6b6861;--acc:#3987e5;--acc2:#d95926;--warn:#fab219;--grid:#35332f;--bg:#1a1a19}}
.ink{fill:var(--ink)}.ink2{fill:var(--ink2)}.box{fill:var(--box);stroke:var(--boxline);stroke-width:1}.box.low{stroke-dasharray:4 3;stroke:var(--warn)}
.edge{fill:none;stroke:var(--edge);stroke-width:1.2}.edge.low{stroke-dasharray:4 3;stroke:var(--warn)}
.sp{fill:var(--ink2)}.t{font-size:11px}.s{font-size:9.5px}.h{font-size:15px;font-weight:bold}.cap{font-size:10px;fill:var(--ink2)}
.g0,.g1{fill:var(--acc)}.gen{font-size:9px;fill:var(--acc)}
</style>"""
def esc(s): return html.escape(str(s))
def tw(s,size=11): return len(s)*size*0.6+10

# ---------- tree layout ----------
class Node:
    def __init__(s,pid,depth): s.pid=pid; s.p=P[pid]; s.kids=[]; s.depth=depth; s.w=0; s.x=0; s.more=0
def build(pid, maxdepth, depth=0):
    n=Node(pid,depth)
    p=P[pid]
    if depth<maxdepth:
        for c in p['children']:
            n.kids.append(build(c,maxdepth,depth+1))
    else:
        n.more=count_desc(pid)
    return n
def count_desc(pid):
    return sum(1+count_desc(c) for c in P[pid]['children'])
def box_lines(p, show_res=True):
    lines=[(p['name']+(f' ({p["nick"]})' if p['nick'] else ''),'t')]
    for sp in p['spouses']:
        lines.append(('⚭ '+P[sp]['name'],'s'))
    if show_res and p['residence']: lines.append((p['residence'].title(),'s'))
    return lines
BOXH=lambda lines: 10+sum(14 if k=='t' else 12 for _,k in lines)+4
def measure(n, show_res):
    n.lines=box_lines(n.p, show_res)
    n.bw=max(max(tw(l, 11 if k=='t' else 9.5) for l,k in n.lines), 90)
    n.bh=BOXH(n.lines)
    if n.more: n.bh+=12
    for k in n.kids: measure(k, show_res)
    n.w=max(n.bw+14, sum(k.w for k in n.kids)) if n.kids else n.bw+14
def place(n, x0):
    n.x=x0+n.w/2
    cx=x0
    for k in n.kids: place(k,cx); cx+=k.w
    if n.kids: n.x=(n.kids[0].x+n.kids[-1].x)/2
def levels(n, acc):
    acc[n.depth]=max(acc.get(n.depth,0), n.bh); 
    for k in n.kids: levels(k,acc)
def render_tree(root, title, caption, show_res=True, fname=None):
    measure(root, show_res); place(root, 10)
    lh={}; levels(root, lh)
    ys={}; y=50
    for d in sorted(lh): ys[d]=y; y+=lh[d]+44
    W=root.w+20; H=y+10
    out=[f'<svg class="gchart" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W:.0f} {H:.0f}" width="{W:.0f}" height="{H:.0f}" role="img" aria-label="{esc(title)}">',STYLE,
         f'<text x="12" y="24" class="h ink">{esc(title)}</text>',f'<text x="12" y="40" class="cap">{esc(caption)}</text>']
    def draw(n):
        y0=ys[n.depth]; x=n.x-n.bw/2
        low = n.p['conf']=='low' or n.p['link_conf']=='low'
        out.append(f'<rect x="{x:.1f}" y="{y0}" width="{n.bw:.1f}" height="{n.bh}" rx="3" class="box{" low" if low else ""}"/>')
        ty=y0+14
        for i,(l,k) in enumerate(n.lines):
            cls='t ink' if k=='t' else 's sp'
            out.append(f'<text x="{n.x:.1f}" y="{ty}" text-anchor="middle" class="{cls}">{esc(l)}</text>'); ty+= 14 if k=='t' else 12
        if n.more: out.append(f'<text x="{n.x:.1f}" y="{ty}" text-anchor="middle" class="s cap">+{n.more} more below (see explorer)</text>')
        out.append(f'<text x="{x+3:.1f}" y="{y0+n.bh-3}" class="gen">G{n.p["gen"]}</text>')
        for k in n.kids:
            y1=y0+n.bh; y2=ys[k.depth]; ym=(y1+y2)/2
            klow = k.p['link_conf']=='low'
            out.append(f'<path d="M{n.x:.1f} {y1} V{ym:.1f} H{k.x:.1f} V{y2}" class="edge{" low" if klow else ""}"/>')
            draw(k)
    draw(root)
    out.append('</svg>')
    s='\n'.join(out)
    if fname: open(f'{CH}/{fname}','w').write(s)
    return s, W, H

# ---------- 1. pedigree ----------
def pedigree():
    W,H=780,300
    o=[f'<svg class="gchart" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="Pedigree of Emiliano Valiente Muñasque">',STYLE,
       '<text x="12" y="24" class="h ink">Direct ancestral pedigree (all generations known)</text>',
       '<text x="12" y="40" class="cap">Earliest named ancestors: Alejandro Muñasque and Saturnina Umpad. No dates survive for them. Dashed = low confidence (header entry only).</text>']
    def box(x,y,w,h,lines,low=False):
        o.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="3" class="box{" low" if low else ""}"/>')
        ty=y+16
        for l,k in lines:
            o.append(f'<text x="{x+w/2}" y="{ty}" text-anchor="middle" class="{"t ink" if k=="t" else "s sp"}">{esc(l)}</text>'); ty+=14 if k=='t' else 12
    box(20,120,200,60,[('Emiliano Valiente Muñasque','t'),('b. 20 May 1857 – d. 19 Feb 1940','s'),('G2 · m. Irenea Gusat','s')])
    box(250,70,180,46,[('Fernando Umpad Muñasque','t'),('G1 · progenitor · b. c. 1820–1835 (est.)','s')])
    box(250,170,180,46,[('Saturnina N. Valiente','t'),('G1 · 1st wife · parents unknown','s')])
    box(460,30,170,46,[('Alejandro Muñasque','t'),('G0 · named in header only','s')],low=True)
    box(460,110,170,46,[('Saturnina Umpad','t'),('G0 · named in header only','s')],low=True)
    o.append('<path d="M220 150 H235 V93 H250 M235 150 V193 H250" class="edge"/>')
    o.append('<path d="M430 93 H445 V53 H460 M445 93 V133 H460" class="edge low"/>')
    o.append('<text x="250" y="250" class="s cap">Fernando\'s 8 siblings, if any, are unknown. Saturnina Valiente\'s middle initial "N." is the only clue to her mother\'s surname.</text>')
    o.append('<text x="250" y="266" class="s cap">Sources: S1 (sheet FERNANDO rows 1–5). Estimated birth of Fernando assumes a first child born 1857.</text>')
    o.append('</svg>'); s='\n'.join(o); open(f'{CH}/pedigree.svg','w').write(s); return s

# ---------- 2. overview (gen 0–2 with branch sizes) ----------
def overview():
    root=build('P0003',1)
    for k in root.kids: k.more=count_desc(k.pid)
    s,W,H=render_tree(root,'Master family tree, overview: Fernando Umpad Muñasque and his nine children','Each box shows a child of Fernando & Saturnina Valiente (G2) with spouse(s); the count is the number of recorded descendants in that branch. Full depth is in the branch charts and the explorer.',show_res=False,fname='overview.svg')
    return s

# ---------- 3. branch charts ----------
def branches():
    res=[]
    for cid in P['P0003']['children']:
        p=P[cid]
        # choose depth so that leaf count stays readable
        depth=2
        r=build(cid,depth); measure(r,True)
        if r.w<1200: depth=3
        r=build(cid,depth)
        total=count_desc(cid)
        s,W,H=render_tree(r,f'Branch: {p["name"]} (G2) and descendants to G{2+depth}',f'{total} recorded descendants in this branch; boxes list spouse(s) and residence where the branch sheets give one. Dashed boxes/lines = low-confidence placement. Deeper generations: use the explorer.',show_res=True,fname=f'branch_{cid}.svg')
        res.append((cid,p['name'],s,W,H,depth,total))
    return res

# ---------- 4. map ----------
PLACES={
 'opon':('Opon / Lapu-Lapu City, Cebu',10.31,123.95),'cebu':('Cebu (province/city)',10.32,123.89),'medellin':('Medellin, Cebu',11.13,123.96),
 'manila':('Manila',14.60,120.98),'cavite':('Cavite',14.48,120.90),
 'lanao':('Lanao del Norte (Lala area)',7.97,123.74),'plaridel':('Plaridel, Misamis Occ.',8.62,123.71),'pagadian':('Pagadian City',7.83,123.44),
 'bukidnon':('Bukidnon',8.15,125.13),'upi':('Upi (Cotabato)',7.03,124.17),'midsayap':('Midsayap, N. Cotabato',7.19,124.53),
 'trento':('Trento, Agusan del Sur',8.05,126.06),'rosario':('Rosario, Agusan del Sur',8.39,126.00),
 'polomolok':('Polomolok, S. Cotabato',6.22,125.06),'koronadal':('Koronadal City',6.50,124.85),'surallah':('Surallah, S. Cotabato',6.37,124.74),
 'stonino':('Sto. Niño, S. Cotabato',6.43,124.67),'tacurong':('Tacurong, Sultan Kudarat',6.69,124.68),'lebak':('Lebak, Sultan Kudarat',6.63,124.06),
 'gensan':('General Santos City',6.11,125.17),'glan':('Glan, Sarangani',5.82,125.20),'cotabatocity':('Cotabato City',7.22,124.25),
}
def place_key(s):
    s=s.upper()
    for k,pat in [('opon','OPON'),('medellin','MEDELLIN'),('cebu','CEBU'),('manila','MANILA'),('cavite','CAVITE'),('lanao','LANAO'),('plaridel','PLARIDEL'),('pagadian','PAGADIAN'),('bukidnon','BUKIDNON'),('upi','UPI'),('midsayap','MIDSAYAP'),('trento','TRINTO'),('rosario','ROSARIO'),('polomolok','POLOMOLOK'),('polomolok','POL.SC'),('koronadal','KORONADAL'),('surallah','SURALLAH'),('stonino','STO'),('tacurong','TACURONG'),('lebak','LIBAK'),('gensan','GSC'),('gensan','GENERAL SANTOS'),('gensan','UHAW'),('glan','GLAN')]:
        if pat in s: return k
    return None
def mapchart():
    counts=collections.Counter(); abroad=collections.Counter()
    for p in P.values():
        for r in p['residence'].split('; '):
            if not r: continue
            k=place_key(r)
            if k: counts[k]+=1
            elif any(x in r.upper() for x in ('USA','GERMANY','AUSTRALIA')): abroad[r.title()]+=1
    W,H=720,720; lon0,lon1,lat0,lat1=119.5,127.5,4.5,15.5
    sx=lambda lon:(lon-lon0)/(lon1-lon0)*(W-160)+40
    sy=lambda lat:(lat1-lat)/(lat1-lat0)*(H-120)+70
    o=[f'<svg class="gchart" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="Map of documented family places">',STYLE,
       '<text x="12" y="24" class="h ink">Documented places, plotted to scale (latitude/longitude)</text>',
       '<text x="12" y="40" class="cap">Dot size = number of people the branch sheets place there (c. 2014–2020). Coastlines are not drawn: no map data could be fetched in this session.</text>']
    for lon in range(120,128): o.append(f'<line x1="{sx(lon):.1f}" y1="{sy(lat1):.1f}" x2="{sx(lon):.1f}" y2="{sy(lat0):.1f}" stroke="var(--grid)"/><text x="{sx(lon):.1f}" y="{sy(lat0)+14:.1f}" text-anchor="middle" class="s cap">{lon}°E</text>')
    for lat in range(5,16): o.append(f'<line x1="{sx(lon0):.1f}" y1="{sy(lat):.1f}" x2="{sx(lon1):.1f}" y2="{sy(lat):.1f}" stroke="var(--grid)"/><text x="{sx(lon0)-6:.1f}" y="{sy(lat)+3:.1f}" text-anchor="end" class="s cap">{lat}°N</text>')
    # region labels (approximate island positions)
    for name,lat,lon in [('LUZON',13.8,121.6),('CEBU ISLAND',10.75,123.1),('MINDANAO',8.9,125.3),('NEGROS',9.6,122.6),('BOHOL',9.75,124.4),('PANAY',11.3,122.3)]:
        o.append(f'<text x="{sx(lon):.1f}" y="{sy(lat):.1f}" class="s cap" style="letter-spacing:.08em" opacity=".8">{esc(name)}</text>')
    ox,oy=sx(PLACES['opon'][2]),sy(PLACES['opon'][1])
    # hypothetical routes Opon -> Mindanao places (dashed): documented residence, undocumented move
    for k,c in counts.items():
        if k in ('opon','cebu'): continue
        n,lat,lon=PLACES[k]; x,y=sx(lon),sy(lat)
        o.append(f'<path d="M{ox:.1f} {oy:.1f} Q{(ox+x)/2+20:.1f} {(oy+y)/2:.1f} {x:.1f} {y:.1f}" fill="none" stroke="var(--acc)" stroke-width="1" stroke-dasharray="4 3" opacity=".55"/>')
    # dated documented move: Lala -> General Santos 1939 (Sulpicio Y. Muñasque, S29)
    lx,ly=sx(PLACES['lanao'][2]),sy(PLACES['lanao'][1]); gx,gy=sx(PLACES['gensan'][2]),sy(PLACES['gensan'][1])
    o.append(f'<path d="M{lx:.1f} {ly:.1f} L{gx:.1f} {gy:.1f}" fill="none" stroke="var(--acc2)" stroke-width="2.2"/>')
    o.append(f'<text x="{lx-8:.1f}" y="{ly+30:.1f}" text-anchor="end" class="s ink" fill="var(--acc2)">1939: Sulpicio Y. Muñasque,</text><text x="{lx-8:.1f}" y="{ly+42:.1f}" text-anchor="end" class="s ink">Lala → Dadiangas (Gen. Santos) [S29]</text>')
    # Medellin (Salimbangon branch, from press) and Curva
    mx,my=sx(PLACES['medellin'][2]),sy(PLACES['medellin'][1])
    o.append(f'<circle cx="{mx:.1f}" cy="{my:.1f}" r="6" fill="var(--acc2)" stroke="var(--bg)" stroke-width="2"/><text x="{mx+9:.1f}" y="{my+4:.1f}" class="s ink">Medellin, Cebu (Martin Salimbangon family; press, S14–S16)</text>')
    cluster=[]; 
    for k,c in sorted(counts.items(), key=lambda kv:-kv[1]):
        n,lat,lon=PLACES[k]; x,y=sx(lon),sy(lat); r=4+math.sqrt(c)*3.2
        o.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="var(--acc)" fill-opacity=".85" stroke="var(--bg)" stroke-width="2"/>')
        if lat<7.3 and lon>123.9: cluster.append((lat,lon,x,y,n,c))
        else:
            anchor='start'; lx_=x+r+4; dy=4
            if lon>125.8: anchor='end'; lx_=x-r-4
            if k=='cebu': anchor='end'; lx_=x-r-4; dy=16
            if k=='lanao': dy=16
            if k=='bukidnon': dy=-8
            o.append(f'<text x="{lx_:.1f}" y="{y+dy:.1f}" text-anchor="{anchor}" class="s ink">{esc(n)} ({c})</text>')
    # dense southern cluster: labels in a column to the right with leader lines, ordered north to south
    cluster.sort(key=lambda t:-t[0]); colx=sx(126.0); ly0=sy(7.35)
    for i,(lat,lon,x,y,n,c) in enumerate(cluster):
        ty=ly0+i*13
        o.append(f'<line x1="{x:.1f}" y1="{y:.1f}" x2="{colx-4:.1f}" y2="{ty-3:.1f}" stroke="var(--edge)" stroke-width=".7" opacity=".7"/>')
        o.append(f'<text x="{colx:.1f}" y="{ty:.1f}" class="s ink">{esc(n)} ({c})</text>')
    # abroad box
    bx,by=W-215,60
    o.append(f'<rect x="{bx}" y="{by}" width="200" height="{24+14*len(abroad)+30}" rx="3" class="box"/><text x="{bx+8}" y="{by+16}" class="t ink">Living abroad (branch sheets)</text>')
    yy=by+32
    for a,c in abroad.most_common(): o.append(f'<text x="{bx+8}" y="{yy}" class="s sp">{esc(a)}: {c}</text>'); yy+=14
    o.append(f'<text x="{bx+8}" y="{yy+4}" class="s cap">Undated; no route documented.</text>')
    o.append(f'<text x="12" y="{H-20}" class="s cap">Dashed = descendants recorded as living there; the move itself is undated and the Opon origin is assumed.</text><text x="12" y="{H-8}" class="s cap">Solid orange = dated, documented move. Orange dot = place known only from press reports.</text>')
    o.append('</svg>'); s='\n'.join(o); open(f'{CH}/map.svg','w').write(s); return s, counts, abroad

# ---------- 5. timeline ----------
EVENTS=[
 (1849,'Claveria surname decree (21 Nov 1849); fixed surnames in records from 1850','context','S41; S42'),
 (1857,'Emiliano Valiente Muñasque born, 20 May','family','S1'),
 (1901,'American military rule reimposed over Cebu, 17 Jul; Opon\'s first municipal election 1905','context','S38'),
 (1903,'First US census: Opon 14,851 people','context','S37'),
 (1913,'Cebuano colonists found Pikit, Cotabato (17 Jun); Glan (Colony No. 9) follows in 1914','context','S39'),
 (1915,'Milagros Lago (later Salimbangon) born, 8 Sep 1915/16','family','S16; S17'),
 (1918,'Census: Opon 20,988','context','S37'),
 (1930,'Civil Registry Law (Act 3753) creates municipal civil registers','context','S42'),
 (1939,'First NLSA settlers land at Sarangani Bay 27 Feb; Sulpicio Y. Muñasque reaches Dadiangas from Lala 7 Mar','family','S40; S29'),
 (1940,'Emiliano Valiente Muñasque dies, 19 Feb, aged 83','family','S1'),
 (1941,'Japanese air raids on Opon oil tanks (Dec, per Wikipedia); WWII','context','S38'),
 (1945,'Benhur Lago Salimbangon born, 3 Jun (Medellin, Cebu)','family','S10; S11'),
 (1961,'Opon becomes Lapu-Lapu City (RA 3134)','context','S38'),
 (1967,'Galan & Muñasque (Elmo) contract with Tropical Commercial Co., Cebu, later litigated (probable identity)','family','S31'),
 (1972,'Benjamin N. Muñasque, Clerk of Court, CFI Cotabato City, files a complaint (2 Feb); SC decision 1974 (probable identity)','family','S25'),
 (1973,'Mactan–Mandaue Bridge opens, 4 Jul','context','S43'),
 (1975,'Fr. Rosalio N. Muñasque rector of Marbel seminary; parish priest of Banga 1975–78','family','S21; S22'),
 (2003,'Fr. Rosalio N. Muñasque dies, 2 Dec','family','S24'),
 (2006,'Compiler interviews Amador Piligro (97) at Opon about the surname; Milagros Lago turns 90','family','S3; S16'),
 (2007,'Benhur Salimbangon enters Congress (Cebu 4th District), serves to 2019','family','S10'),
 (2014,'Family spreadsheet created (14 Sep)','family','S4'),
 (2020,'Spreadsheet last edited (12 Jun); Benhur Salimbangon dies 24 Dec','family','S4; S12'),
]
def timeline():
    W=1000; top=60; per=26; H=top+per*len(EVENTS)+60
    y0,y1=1845,2026
    sx=lambda yr: 70+(yr-y0)/(y1-y0)*(W-110)
    o=[f'<svg class="gchart" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="Timeline">',STYLE,
       '<text x="12" y="24" class="h ink">Chronological timeline: family events (orange) and historical context (blue)</text>',
       f'<line x1="{sx(y0):.0f}" y1="{top-8}" x2="{sx(y1):.0f}" y2="{top-8}" stroke="var(--edge)"/>']
    for yr in range(1850,2030,10): o.append(f'<line x1="{sx(yr):.1f}" y1="{top-12}" x2="{sx(yr):.1f}" y2="{top-4}" stroke="var(--edge)"/><text x="{sx(yr):.1f}" y="{top-16}" text-anchor="middle" class="s cap">{yr}</text>')
    for i,(yr,txt,kind,src) in enumerate(EVENTS):
        y=top+i*per+10; x=sx(yr); col='var(--acc2)' if kind=='family' else 'var(--acc)'
        o.append(f'<line x1="{x:.1f}" y1="{top-8}" x2="{x:.1f}" y2="{y}" stroke="{col}" stroke-width="1" opacity=".35"/>')
        o.append(f'<circle cx="{x:.1f}" cy="{y}" r="4.5" fill="{col}"/>')
        o.append(f'<text x="{x+9:.1f}" y="{y+4}" class="s ink"><tspan font-weight="bold">{yr}</tspan> {esc(txt)} <tspan class="cap">[{esc(src)}]</tspan></text>' if x<W*0.55 else f'<text x="{x-9:.1f}" y="{y+4}" text-anchor="end" class="s ink"><tspan font-weight="bold">{yr}</tspan> {esc(txt)} <tspan class="cap">[{esc(src)}]</tspan></text>')
    o.append(f'<text x="12" y="{H-10}" class="s cap">Only the 1857/1940 dates come from the family file; all other dates come from outside sources listed in the bibliography.</text>')
    o.append('</svg>'); s='\n'.join(o); open(f'{CH}/timeline.svg','w').write(s); return s

# ---------- 6. evidence diagram ----------
def evidence():
    W,H=1000,560
    o=[f'<svg class="gchart" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="Evidence diagram">',STYLE,
       '<text x="12" y="24" class="h ink">Relationship and evidence diagram for the key links</text>',
       '<text x="12" y="40" class="cap">Dashed box/line = family spreadsheet only (S1/S2). Solid = an outside source names the person. Orange line = the outside source states the parent-child link independently.</text>']
    C=[40,280,520,760]; Rw=[90,190,300,400,500]
    nodes={'alej':(C[0],Rw[0],'Alejandro Muñasque\n& Saturnina Umpad','S1 header only',True),
           'fern':(C[0],Rw[1],'Fernando Umpad Muñasque\n& Saturnina N. Valiente','S1',True),
           'emil':(C[0],Rw[2],'Emiliano V. Muñasque\n1857–1940','S1 (only dated person)',True),
           'agri':(C[1],Rw[2],'Agripina V. Muñasque\n& Ambrosio Salimbangon','S1',True),
           'mart':(C[1],Rw[3],'Martin Salimbangon\n& Milagros Lago (b. 1915/16)','S1 · S14–S17 (press)',False),
           'benh':(C[1],Rw[4],'Cong. Benhur L. Salimbangon\n1945–2020','S1 · S10–S13; parents per S11, S15',False),
           'sote':(C[2],Rw[2],'Sotero V. Muñasque\n& Sebirina Ynot','S1',True),
           'sulp':(C[2],Rw[3],'Sulpicio Ynot Muñasque\nevangelist, Lala → Gen. Santos 1939','S1 · S29–S30 (Y. = Ynot)',False),
           'basi':(C[3],Rw[3],'Basilio Ynot Muñasque\n& Rosalia V. Nuñeza','S1',True),
           'rosa':(C[3],Rw[4],'Fr. Rosalio N. (d. 2003)\n& Atty. Benjamin N. Muñasque','S1 · S21–S26 (name + title)',False),
           'cosm':(C[3],Rw[2],'Cosmiano V. Muñasque\n& Sofia Mansueto · # S. Arabia Omar','S1, S2 (Sheet8)',True)}
    def nb(k):
        x,y,t,src,dashed=nodes[k]; w=210
        o.append(f'<rect x="{x}" y="{y-28}" width="{w}" height="58" rx="3" class="box{" low" if dashed else ""}"/>')
        for i,l in enumerate(t.split('\n')): o.append(f'<text x="{x+w/2}" y="{y-9+i*14}" text-anchor="middle" class="t ink">{esc(l)}</text>')
        o.append(f'<text x="{x+w/2}" y="{y+23}" text-anchor="middle" class="s cap">{esc(src)}</text>')
    def edge(a,b,strong=False,corr=False):
        xa,ya=nodes[a][0]+105,nodes[a][1]+30; xb,yb=nodes[b][0]+105,nodes[b][1]-28
        d=f'M{xa} {ya} V{yb}' if abs(xa-xb)<1 else f'M{xa} {ya} V{(ya+yb)/2} H{xb} V{yb}'
        extra=' stroke="var(--acc2)" stroke-width="2"' if corr else ''
        o.append(f'<path d="{d}" class="edge{"" if strong else " low"}"{extra}/>')
    for a,b,st,co in [('alej','fern',False,False),('fern','emil',False,False),('fern','agri',False,False),('fern','sote',False,False),('fern','cosm',False,False),('agri','mart',False,False),('mart','benh',True,True),('sote','sulp',True,True),('sote','basi',False,False),('basi','rosa',True,False)]:
        edge(a,b,st,co)
    for k in nodes: nb(k)
    o.append('</svg>'); s='\n'.join(o); open(f'{CH}/evidence.svg','w').write(s); return s

# ---------- 7. generation sizes ----------
def gensizes():
    c=collections.Counter(p['gen'] for p in P.values() if p['role']!='spouse'); sp=collections.Counter(p['gen'] for p in P.values() if p['role']=='spouse')
    W,H=620,300; gens=sorted(c); mx=max(c[g]+sp[g] for g in gens)
    o=[f'<svg class="gchart" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="People per generation">',STYLE,
       '<text x="12" y="24" class="h ink">People recorded per generation</text>','<text x="12" y="40" class="cap">Blood descendants (blue) and spouses (grey) by generation from Fernando (G1). Estimated birth periods are given under each bar.</text>']
    bw=44; x0=50
    for i,g in enumerate(gens):
        x=x0+i*52; h1=c[g]/mx*170; h2=sp[g]/mx*170; base=240
        o.append(f'<rect x="{x}" y="{base-h1:.1f}" width="{bw}" height="{h1:.1f}" fill="var(--acc)" rx="2"/>')
        o.append(f'<rect x="{x}" y="{base-h1-h2-2:.1f}" width="{bw}" height="{h2:.1f}" fill="var(--edge)" rx="2"/>')
        o.append(f'<text x="{x+bw/2}" y="{base-h1-h2-6:.1f}" text-anchor="middle" class="s ink">{c[g]}+{sp[g]}</text>')
        o.append(f'<text x="{x+bw/2}" y="{base+14}" text-anchor="middle" class="s ink">G{g}</text>')
        est=D['estimates'].get(str(g),'')
        o.append(f'<text x="{x+bw/2}" y="{base+27}" text-anchor="middle" class="s cap" font-size="7.5">{esc(est[:14])}</text>')
    o.append('</svg>'); s='\n'.join(o); open(f'{CH}/generations.svg','w').write(s); return s

ped=pedigree(); ov=overview(); br=branches(); mp,counts,abroad=mapchart(); tl=timeline(); ev=evidence(); gs=gensizes()
json.dump({'branches':[(c,n,W,H,d,t) for c,n,s,W,H,d,t in br],'place_counts':counts,'abroad':abroad}, open(f'{CH}/index.json','w'))
print('overview size', len(ov)); print('branches:',[(n,W,H,d,t) for c,n,s,W,H,d,t in br]); print('places',counts, abroad)
