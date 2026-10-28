import json, csv, collections, re, unicodedata, openpyxl, sys
OUT='out'; D=json.load(open(f'{OUT}/data.json')); P=D['people']
errs=[]; warn=[]
def norm(s):
    s=unicodedata.normalize('NFKD',s); s=''.join(c for c in s if not unicodedata.combining(c)); return re.sub(r'[^A-Z0-9 ]','',s.upper()).strip()
# 1. referential integrity
for p in P.values():
    for c in p['children']:
        q=P[c]
        if p['id'] not in (q['father'],q['mother']): errs.append(f"{p['id']} lists child {c} but child does not point back")
    for s in p['spouses']:
        if p['id'] not in P[s]['spouses']: errs.append(f"spouse link not symmetric {p['id']}<->{s}")
        if P[s]['gen']!=p['gen']: errs.append(f"spouse gens differ {p['name']} G{p['gen']} vs {P[s]['name']} G{P[s]['gen']}")
    for par in (p['father'],p['mother']):
        if par:
            if p['id'] not in P[par]['children']: errs.append(f"{p['id']} points to parent {par} who does not list it")
            if P[par]['gen']+1!=p['gen']: errs.append(f"gen math: {P[par]['name']} G{P[par]['gen']} -> {p['name']} G{p['gen']}")
    if p['father'] and p['mother'] and P[p['father']]['role']=='spouse' and P[p['mother']]['role']=='spouse': errs.append(f"both parents are spouse-role for {p['name']}")
# 2. cycles
def anc(pid,seen=()):
    if pid in seen: errs.append(f"cycle at {pid}"); return
    for par in (P[pid]['father'],P[pid]['mother']):
        if par: anc(par,seen+(pid,))
for p in P.values(): anc(p['id'])
# 3. every non-empty sheet row accounted for
wb=openpyxl.load_workbook('download/valiente.xlsx'); ws=wb['FERNANDO']
rows=[r for r in range(2,ws.max_row+1) if ws.cell(r,1).value and str(ws.cell(r,1).value).strip()]
have={p['row'] for p in P.values()}
skipped={590,591,592,593,1232,1233,1234,1252}
missing=[r for r in rows if r not in have and r not in skipped]
print('sheet rows',len(rows),'people',len(P),'missing rows',missing, [str(ws.cell(r,1).value) for r in missing])
# 4. duplicate names under same parents
seen=collections.defaultdict(list)
for p in P.values(): seen[(norm(p['name']),p['father'],p['mother'])].append(p['row'])
dups=[(k,v) for k,v in seen.items() if len(v)>1]
print('duplicate name+parents', dups[:20])
# 5. branch-sheet cross-check: every matched branch-sheet row should be in the founder's subtree
FOUNDER={'Sheet2':'P0005','Sheet3':'P0546','Sheet4':'P0789','Sheet5':'P0925','Sheet6':'P1135','Sheet7':'P1202','Sheet8':'P1620','Sheet9':'P1426','Sheet10':'P1768'}
def subtree(pid):
    s={pid}
    for c in P[pid]['children']: s|=subtree(c)
    for sp in P[pid]['spouses']: s.add(sp)
    return s
index=collections.defaultdict(list)
for p in P.values(): index[norm(p['name'].replace('Sr.','').replace('Jr.',''))].append(p['id'])
bad=[]; checked=0
for sh,f in FOUNDER.items():
    st=subtree(f); st|={s for x in list(st) for s in P[x]['spouses']}
    w=wb[sh]
    for r in range(1,w.max_row+1):
        v=w.cell(r,1).value
        if not v or not str(v).strip(): continue
        n=norm(re.sub(r'\(.*?\)|\[.*?\]|#|\d[.…]+|^(ATTY|ENGR|DR|COL|CONG|REV\.?FR)\.?','',str(v)).replace('SR.','').replace('JR.','').replace('JR','')).strip()
        ids=index.get(n)
        if not ids: continue
        checked+=1
        if not any(i in st for i in ids): bad.append((sh,r,str(v).strip(),[P[i]['name']+' G'+str(P[i]['gen']) for i in ids]))
print('branch cross-check: rows checked',checked,'outside expected branch',len(bad))
for b in bad: print('  ',b)
# 6. gen distribution sanity & people with >2 spouses, children before spouse etc.
print('people with >2 spouses',[(p['name'],len(p['spouses'])) for p in P.values() if len(p['spouses'])>2])
print('children of a spouse-role person with no partner', sum(1 for p in P.values() if p['role']=='spouse' and p['children'] and not p['spouses']))
print('ERRORS',len(errs)); print('\n'.join(errs[:30]))
