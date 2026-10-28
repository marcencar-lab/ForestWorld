"""Printable edition: report text + charts that fit a page + a numbered descendant register. Output: out/print/report_print.html"""
import json, csv, re, html, sys, os
OUT=sys.argv[1]; SCR=os.path.dirname(os.path.abspath(__file__))
sys.argv=[sys.argv[0],OUT]
D=json.load(open(f'{OUT}/data.json')); P=D['people']
esc=html.escape
# reuse the markdown converter from build_site by importing it
import importlib.util
spec=importlib.util.spec_from_file_location('bs',f'{SCR}/build_site.py')
# build_site runs on import; capture its md2html and the markdown text it wrote
bs=importlib.util.module_from_spec(spec); spec.loader.exec_module(bs)
md=open(f'{OUT}/REPORT.md',encoding='utf-8').read()
secs=re.split(r'\n(?=## )', md)

def chart(name, maxw=None):
    s=open(f'{OUT}/charts/{name}',encoding='utf-8').read()
    s=re.sub(r'<style>.*?</style>','',s,flags=re.S)
    m=re.search(r'width="(\d+)" height="(\d+)"',s); w,h=int(m.group(1)),int(m.group(2))
    s=re.sub(r' width="\d+" height="\d+"','',s,1)
    return f'<figure class="pchart"><div class="fit" style="--w:{w};--h:{h}">{s}</div></figure>'

# ---- descendant register (modified Register style) ----
reg=[]
counter=[0]
def person_line(p):
    bits=[]
    if p['title']: bits.append(p['title']+'.')
    bits.append(f"<b>{esc(p['name'])}</b>")
    if p['nick']: bits.append(f'“{esc(p["nick"])}”')
    if p['id']=='P0005': bits.append('(b. 20 May 1857, d. 19 Feb 1940)')
    elif p['deceased']: bits.append('(deceased)')
    sp=[P[s] for s in p['spouses']]
    if sp: bits.append('m. '+'; '.join((f'({i+1}) ' if len(sp)>1 else '')+esc(s['name'])+(f' ({esc(s["residence"].title())})' if s['residence'] else '') for i,s in enumerate(sp)))
    if p['residence']: bits.append(f'— {esc(p["residence"].title())}')
    if p['conf']=='low': bits.append('<span class="low">[low confidence]</span>')
    if p['facts']: bits.append('<span class="fact">'+' '.join(esc(f['fact'])+' ['+esc(f['sources'])+']' for f in p['facts'])+'</span>')
    return ' '.join(bits)
def walk(pid, depth, num):
    p=P[pid]
    reg.append(f'<div class="reg d{min(depth,6)}"><span class="num">{num}</span> {person_line(p)} <span class="src">row {p["row"]}</span></div>')
    for i,c in enumerate(P[pid]['children'],1):
        walk(c, depth+1, f'{num}.{i}')
walk('P0003',0,'1')
REG='\n'.join(reg)

body=[]
for s in secs:
    if s.startswith('# '): s=s.split('\n',1)[1]
    t=s.split('\n',1)[0]
    h=bs.md2html(s)
    if t.startswith('## 2.'): h+=chart('generations.svg')
    if t.startswith('## 4.'):
        h=h.replace('<h3 id="s-4-2',chart('pedigree.svg')+chart('overview.svg')+'<h3 id="s-4-2',1)
    if t.startswith('## 7.'): h+=chart('map.svg')+chart('timeline.svg')
    if t.startswith('## 8.'): h=chart('evidence.svg')+h
    body.append(h)
page=f'''<!doctype html><html><head><meta charset="utf-8"><title>The Muñasque family of Opon, Cebu — printable report</title>
<style>
@page{{size:A4;margin:16mm 14mm}}
body{{font-family:'DejaVu Serif',Georgia,serif;font-size:10.5pt;line-height:1.42;color:#111;background:#fff;margin:0}}
h1{{font-size:22pt;margin:0 0 6pt}} h2{{font-size:15pt;margin:18pt 0 6pt;page-break-after:avoid;border-top:1px solid #999;padding-top:6pt}} h3{{font-size:12pt;margin:12pt 0 4pt;page-break-after:avoid}}
p,li{{max-width:100%}} a{{color:#1a4d8f;text-decoration:none;word-break:break-all}}
table{{border-collapse:collapse;font-size:8.5pt;width:100%;page-break-inside:auto}} th,td{{border:1px solid #bbb;padding:3pt 4pt;vertical-align:top;text-align:left}} th{{background:#eee}} tr{{page-break-inside:avoid}}
.tablewrap{{margin:6pt 0}}
figure.pchart{{margin:8pt 0;page-break-inside:avoid;border:1px solid #ccc;padding:4pt}} .fit svg{{width:100%;height:auto;display:block}}
svg.gchart{{font-family:'DejaVu Sans',Arial,sans-serif;background:#fff}}
.ink{{fill:#111}}.ink2{{fill:#555}}.box{{fill:#fff;stroke:#777;stroke-width:1}}.box.low{{stroke-dasharray:4 3;stroke:#b26a00}}
.edge{{fill:none;stroke:#888;stroke-width:1.2}}.edge.low{{stroke-dasharray:4 3;stroke:#b26a00}}
.sp{{fill:#555}}.t{{font-size:11px}}.s{{font-size:9.5px}}.h{{font-size:15px;font-weight:bold}}.cap{{font-size:10px;fill:#555}}.gen{{font-size:9px;fill:#1a4d8f}}
.cover{{page-break-after:always;padding-top:60mm}} .cover p{{font-size:12pt;max-width:120mm}}
.reg{{font-family:'DejaVu Sans',Arial,sans-serif;font-size:8.6pt;margin:1.5pt 0;page-break-inside:avoid}} .reg .num{{display:inline-block;min-width:26mm;color:#1a4d8f;font-variant-numeric:tabular-nums}} .reg .src{{color:#888;font-size:7pt}} .reg .low{{color:#b26a00}} .reg .fact{{color:#333;font-style:italic}}
.d1{{margin-left:4mm}}.d2{{margin-left:8mm}}.d3{{margin-left:12mm}}.d4{{margin-left:16mm}}.d5{{margin-left:20mm}}.d6{{margin-left:24mm}}
.toc li{{margin:2pt 0}}
.note{{border-left:3px solid #1a4d8f;padding:4pt 8pt;background:#f3f6fb;margin:8pt 0}}
</style></head><body>
<div class="cover"><h1>The Muñasque family of Opon (Lapu-Lapu City), Cebu</h1><p>A genealogical reconstruction from the family spreadsheet “FERNANDO VALIENTE MUÑASQUE.xlsx”, with independent web research.</p><p>Printable edition, 28 October 2026.</p><p>{len(P):,} people in {max(p['gen'] for p in P.values())} generations descending from Fernando Umpad Muñasque and Saturnina N. Valiente.</p>
<div class="note">How to read this document: Part A is the written report with its charts. Part B is the complete descendant register, numbered so that 1 is Fernando, 1.3 his third listed child, 1.3.2 that child's second child, and so on. Each entry gives spouse(s), residence where known, the spreadsheet row it came from, and a “low confidence” mark where the placement is uncertain. The wide branch charts are in the online version and the SVG files; they do not fit a printed page.</div>
<h3>Contents</h3><ol class="toc">{''.join(f'<li>{esc(t.split(chr(10),1)[0][3:])}</li>' for t in secs[1:])}<li>Part B — Descendant register</li></ol></div>
<h1>Part A — Report</h1>
{''.join(body)}
<h1 style="page-break-before:always">Part B — Descendant register</h1>
<p class="note">Numbering: 1 = Fernando Umpad Muñasque; 1.n = his n-th listed child; deeper numbers follow the same rule. Children are listed in the order the family spreadsheet gives them, which is not necessarily birth order. “m.” = married/partner. Residence is as given in the branch sheets (c. 2014–2020). Source rows refer to sheet FERNANDO, column A.</p>
{REG}
</body></html>'''
os.makedirs(f'{OUT}/print',exist_ok=True)
open(f'{OUT}/print/report_print.html','w',encoding='utf-8').write(page)
print('print html bytes',len(page.encode()),'register entries',len(reg))
