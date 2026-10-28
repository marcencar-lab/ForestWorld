"""Parse the FERNANDO master sheet into person / relationship registers.
Generation comes from font colour (compiler's legend); indentation and
Filipino naming convention (given + mother's maiden surname + father's
surname) are used to decide spouse vs child vs sibling and to flag conflicts."""
import sys, re, json, csv, unicodedata, openpyxl, collections

SRC, OUT = sys.argv[1], sys.argv[2]
wb = openpyxl.load_workbook(SRC)
ws = wb['FERNANDO']

COLOR_GEN = {'theme:1':1,'rgb:FFC00000':2,'rgb:FF00B050':3,'rgb:FF0070C0':4,'rgb:FF7030A0':5,
             'theme:9':6,'rgb:FF002060':7,'theme:5':8,'rgb:FF92D050':9}
HIGHLIGHT = {'rgb:FFF13E2B','rgb:FFE32D0F'}   # bright red: compiler's highlight for extra wives

def colour_key(c):
    col=c.font.color
    if col is None: return None
    if col.type=='rgb': return 'rgb:'+str(col.rgb)
    if col.type=='theme': return f'theme:{col.theme}'
    return f'idx:{col.indexed}'

TITLES = ['REV.FR.','REV. FR.','ATTY.','ENGR.','DR.','COL.','CONG.']
SUFFIX = {'SR.':'Sr.','SR':'Sr.','JR.':'Jr.','JR':'Jr.','II':'II','III':'III','IV':'IV','LL':'II','2ND':None}

def norm(s):
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(ch for ch in s if not unicodedata.combining(ch))
    return re.sub(r'[^A-Z0-9 ]','',s.upper()).strip()

def parse_name(raw):
    """Return dict with cleaned name parts and flags."""
    s = raw.strip()
    flags = {}
    # death markers
    if re.search(r'[\(\[]\s*[dD]\s*[\)\]]', s): flags['deceased']=True
    s = re.sub(r'-?\s*[\(\[]\s*[dD]\s*[\)\]]','',s)
    # spouse markers
    s = re.sub(r'^\d[.…]+\s*','',s)          # "1……BEULA" = numbered child
    m = re.match(r'^(#+\s*\d*\s*\.*|\d\s*#|1st\s+wife|2ND W\.|3RD W\.)\s*',s,re.I)
    if m:
        mk=m.group(1); s=s[m.end():].strip()
        flags['marker']=mk.strip()
        if re.search(r'\d',mk): flags['spouse_no']=int(re.search(r'\d',mk).group())
        if re.match(r'^(1st|2ND|3RD)',mk,re.I): flags['explicit_wife']=True
    if re.search(r'SPOUSE NO DETAIL|unname',s,re.I): flags['placeholder']=True
    # trailing generation text inside the name
    g = re.search(r'\s+(\d+)G\s*$', s)
    if g: flags['gen_in_text']=int(g.group(1)); s=s[:g.start()]
    # nicknames
    nick = re.findall(r'[\(\[]([^\)\]]+)[\)\]]', s)
    if nick: flags['nickname']=', '.join(n.strip() for n in nick)
    s = re.sub(r'\s*[\(\[][^\)\]]*[\)\]]\s*',' ',s)
    s = re.sub(r'\(NO FN DETAIL\)|\( NO FN DETAIL\)','',s,flags=re.I)
    # titles
    for t in TITLES:
        if s.upper().startswith(t):
            flags['title']=t.rstrip('.').title().replace('Rev.fr','Rev. Fr'); s=s[len(t):].strip()
    if re.search(r'\bnun\b',s): flags['title']='nun'; s=re.sub(r'\bnun\b','',s)
    s = re.sub(r'\s+',' ',s.replace(',','.')).strip(' .-')
    toks = s.split(' ')
    suffix=None
    if len(toks)>1 and toks[-1].upper() in SUFFIX and SUFFIX[toks[-1].upper()]:
        suffix=SUFFIX[toks[-1].upper()]; toks=toks[:-1]
    # fix "D.MUÑASQUE" style glued initials
    fixed=[]
    for t in toks:
        mm=re.match(r'^([A-Z])\.([A-ZÑ][A-ZÑ]+)$',t)
        if mm: fixed += [mm.group(1)+'.', mm.group(2)]
        else: fixed.append(t)
    toks=fixed
    joined=[]; i=0
    PART={'DELA','DE','DELOS','DEL','LA','SAN','STA.','VAN','MALOLOY'}
    while i<len(toks):
        if toks[i].upper() in PART and i+1<len(toks):
            joined.append(toks[i]+' '+toks[i+1]); i+=2
        else: joined.append(toks[i]); i+=1
    toks=joined
    surname = toks[-1] if toks else ''
    given = toks[0] if toks else ''
    middle = ' '.join(toks[1:-1]) if len(toks)>2 else ''
    # names like "MA. THERESA PAILDEN": 'MA.' is part of given name
    if given.upper() in ('MA.','MARIA','MARY','JOHN','JOSE','MARK','MARY') and len(toks)>2:
        given=' '.join(toks[:2]); middle=' '.join(toks[2:-1])
    if len(toks)==1: surname=''; given=toks[0]
    display = ' '.join(toks) + (f' {suffix}' if suffix else '')
    return dict(display=display.title().replace("'S","'s"), given=given.title(), middle=middle.title(),
                surname=surname.title(), suffix=suffix or '', **flags)

rows=[]
for r in range(1, ws.max_row+1):
    c=ws.cell(r,1); v=c.value
    if v is None or not str(v).strip(): continue
    raw=str(v)
    indent=len(raw)-len(raw.lstrip(' '))
    ck=colour_key(c)
    gen=COLOR_GEN.get(ck)
    if ck=='theme:1' and r>3: gen=None   # stray black rows: no generation info
    f=ws.cell(r,6).value or ws.cell(r,5).value
    flabel=None
    if f and re.match(r'^\s*(\d+)(ST )?G',str(f)):
        flabel=int(re.match(r'^\s*(\d+)',str(f)).group(1))
    rows.append(dict(row=r, raw=raw, indent=indent, colour=ck, gen_colour=gen, highlight=(ck in HIGHLIGHT),
                     gen_label=flabel, **parse_name(raw)))

# --- Row 1 header: parents of the progenitor
header = ws.cell(1,3).value  # 'ALEJANDRO MUÑASQUE        SATURNINA  UMPAD'

people={}; rels=[]; disc=[]
import difflib
ALL_SURNAMES={norm(r['surname']) for r in rows if r['surname']}
def same_surname(a,b):
    a,b=norm(a),norm(b)
    if not a or not b: return False
    if a==b: return True
    if len(a)==1: return b.startswith(a)
    return difflib.SequenceMatcher(None,a,b).ratio()>=0.8
def pid(n): return f'P{n:04d}'
nid=0
def add_person(rw, gen, gen_src, role):
    global nid
    nid+=1; i=pid(nid)
    p=dict(person_id=i, display=rw['display'], given=rw['given'], middle=rw['middle'], surname=rw['surname'],
           suffix=rw['suffix'], nickname=rw.get('nickname',''), title=rw.get('title',''),
           deceased=bool(rw.get('deceased')), placeholder=bool(rw.get('placeholder')),
           generation=gen, generation_source=gen_src, role=role, sheet_row=rw['row'], raw=rw['raw'].strip(),
           gen_label=rw['gen_label'], colour=rw['colour'], indent=rw['indent'], marker=rw.get('marker',''),
           father_id='', mother_id='', spouse_ids=[], child_ids=[], residence='', variants=[], notes=[], cgen=None)
    people[i]=p; return p

# progenitor's parents
hp = [x for x in re.split(r'\s{2,}', header.strip()) if x]
alejandro = add_person(dict(parse_name(hp[0]), row=1, raw=hp[0], indent=0, colour=None, gen_label=None), 0, 'header', 'ancestor')
saturnina_u = add_person(dict(parse_name(hp[1]), row=1, raw=hp[1], indent=0, colour=None, gen_label=None), 0, 'header', 'ancestor')
alejandro['spouse_ids'].append(saturnina_u['person_id']); saturnina_u['spouse_ids'].append(alejandro['person_id'])
rels.append(dict(a=alejandro['person_id'], b=saturnina_u['person_id'], type='spouse', evidence='FERNANDO!C1 header', confidence='low'))

# --- walk rows ---
# stack of "current person at generation g": last_at[g] = person dict
last_at={}
cur=None            # most recent non-spouse person
cur_spouse=None     # most recent spouse row (of cur)
def link_child(child, parent, src):
    spouses=[people[x] for x in parent['spouse_ids']]
    def sn(p_): return p_['surname'] or p_['given']
    spd=None
    cs=norm(child['surname']); cm=norm(child['middle']).replace('.','').split(' ')[-1] if child['middle'] else ''
    if cm and len(cm)>1 and cm not in ALL_SURNAMES and not any(difflib.SequenceMatcher(None,cm,x).ratio()>=0.85 for x in ALL_SURNAMES): cm=''   # part of a compound given name
    if spouses:
        spd=spouses[-1]
        for s_ in spouses:                       # father-line match
            if cs and same_surname(sn(s_),cs): spd=s_; break
        else:
            for s_ in spouses:                   # mother-line match via middle name/initial
                if cm and same_surname(cm, sn(s_)): spd=s_; break
    check='n/a'; f_id=m_id=''
    if spd:
        if cs and same_surname(cs,sn(parent)) and not same_surname(cs,sn(spd)):
            f_id,m_id = parent['person_id'], spd['person_id']; mother=spd
        elif cs and same_surname(cs,sn(spd)):
            f_id,m_id = spd['person_id'], parent['person_id']; mother=parent
        else:
            f_id,m_id = parent['person_id'], spd['person_id']; mother=spd
            check = 'n/a' if not cs else 'surname-mismatch'
        if check=='n/a' and cs and cm:
            ms=sn(mother)
            if ms: check = 'ok' if same_surname(cm,ms) else 'middle-mismatch'
    else:
        f_id = parent['person_id']; check='single-parent'
    child['father_id']=f_id; child['mother_id']=m_id
    parent['child_ids'].append(child['person_id'])
    if spd: spd['child_ids'].append(child['person_id'])
    rels.append(dict(a=f_id or m_id, b=child['person_id'], type='parent-child', evidence=f'FERNANDO!A{child["sheet_row"]} ({src})', confidence='', name_check=check))
    if check in ('middle-mismatch','surname-mismatch'):
        child['notes'].append(f'name check {check}: child "{child["display"]}" under {parent["display"]}' + (f' & {spd["display"]}' if spd else ''))
        disc.append(dict(person_id=child['person_id'], field='parentage', detail=child['notes'][-1], sheet_row=child['sheet_row']))

import os
OVR={}
ovp=os.path.join(os.path.dirname(os.path.abspath(__file__)),'overrides.csv')
if os.path.exists(ovp):
    for o in csv.DictReader(open(ovp)):
        OVR[int(o['sheet_row'])]=o
import importlib.util as _il, os as _os
_spec=_il.spec_from_file_location('walker', _os.path.join(_os.path.dirname(_os.path.abspath(__file__)),'walker.py'))
_w=_il.module_from_spec(_spec); _spec.loader.exec_module(_w)
byrow=_w.walk(rows, people, rels, disc, add_person, link_child, norm, OVR, alejandro, saturnina_u)
fernando=people['P0003']
for r_,o in OVR.items():
    if o.get('set_surname') and r_ in byrow:
        q=byrow[r_]; q['variants'].append(q['display']); q['notes'].append('surname set to maiden name: '+o['reason'])
        q['surname']=o['set_surname']; q['display']=q['display'].rsplit(' ',1)[0]+' '+o['set_surname']
# recompute name checks for children of renamed people
for rl in rels:
    if rl['type']!='parent-child' or rl.get('name_check') not in ('middle-mismatch','surname-mismatch'): continue
    ch=people[rl['b']]; f=people.get(ch['father_id']); m=people.get(ch['mother_id'])
    if f and m:
        cm=norm(ch['middle']).replace('.','').split(' ')[-1] if ch['middle'] else ''
        for mo in (m,f):
            if cm and same_surname(cm, mo['surname'] or mo['given']) and same_surname(ch['surname'], (f if mo is m else m)['surname'] or ''):
                rl['name_check']='ok'; ch['notes']=[n for n in ch['notes'] if not n.startswith('name check')]
                disc[:]=[d for d in disc if not (d['sheet_row']==ch['sheet_row'] and d['field']=='parentage')]

# --- residences, titles and variants from branch sheets ---
index=collections.defaultdict(list)
for p in people.values():
    index[norm(p['display'].replace('Sr.','').replace('Jr.',''))].append(p)
    if p['given'] and p['surname']:
        index[norm(p['given']+' '+p['surname'])].append(p)
unmatched=[]
VMAP={}
vmp=os.path.join(os.path.dirname(os.path.abspath(__file__)),'variant_map.csv')
for o in csv.DictReader(open(vmp)): VMAP[(o['sheet'],int(o['row']))]=o
for sh in wb.worksheets[1:]:
    for r in range(1, sh.max_row+1):
        v=sh.cell(r,1).value
        if v is None or not str(v).strip(): continue
        loc=None
        for col in (4,5,6):
            x=sh.cell(r,col).value
            if x and not re.match(r'^\s*page',str(x),re.I): loc=str(x).strip()
        pn=parse_name(str(v))
        keys=[norm(pn['display'].replace('Sr.','').replace('Jr.','')), norm(pn['given']+' '+pn['surname'])]
        hit=None
        vm=VMAP.get((sh.title,r))
        if vm:
            if int(vm['master_row']) in byrow:
                hit=[byrow[int(vm['master_row'])]]; hit[0]['notes'].append('branch-sheet variant: '+vm['note'])
        else:
            for k in keys:
                if k in index: hit=index[k]; break
        if not hit:
            unmatched.append(dict(sheet=sh.title,row=r,name=str(v).strip(),loc=loc,title=pn.get('title','')))
            continue
        for p in hit:
            if loc and loc not in p['residence'].split('; '):
                p['residence']=('; '.join(filter(None,[p['residence'],loc])))
            if pn.get('title') and not p['title']: p['title']=pn['title']
            if norm(pn['display'])!=norm(p['display']) and pn['display'] not in p['variants']:
                p['variants'].append(pn['display'])

# --- confidence per relationship ---
for rl in rels:
    if rl['confidence']: continue
    chk=rl.get('name_check','')
    if rl['type']=='spouse': rl['confidence']='moderate'
    elif chk=='ok': rl['confidence']='moderate'
    elif chk in ('n/a','single-parent',''): rl['confidence']='low'
    else: rl['confidence']='low'
    rl['source_id']='S1'

import os; os.makedirs(OUT, exist_ok=True)
with open(f'{OUT}/people.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['person_id','full_name','given','middle','surname','suffix','nickname','title','generation','generation_source','role','father_id','mother_id','spouse_ids','children_ids','deceased_marked','residence_from_file','spelling_variants','gen_label_in_file','sheet_row','raw_cell','notes','sources','confidence'])
    for p in people.values():
        conf = 'moderate' if p['role']!='ancestor' else 'low'
        if p['notes']: conf='low'
        w.writerow([p['person_id'],p['display'],p['given'],p['middle'],p['surname'],p['suffix'],p['nickname'],p['title'],p['generation'],p['generation_source'],p['role'],p['father_id'],p['mother_id'],'|'.join(p['spouse_ids']),'|'.join(p['child_ids']),'yes' if p['deceased'] else '', p['residence'],'|'.join(p['variants']),p['gen_label'] or '',p['sheet_row'],p['raw'],' / '.join(p['notes']),'S1'+('; S2' if p['residence'] or p['variants'] else ''),conf])
with open(f'{OUT}/relationships.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['relationship_id','person_a_id','person_b_id','type','evidence','name_check','confidence'])
    for i,rl in enumerate(rels,1): w.writerow([f'R{i:04d}',rl['a'],rl['b'],rl['type'],rl['evidence'],rl.get('name_check',''),rl['confidence']])
with open(f'{OUT}/discrepancies_auto.csv','w',newline='') as f:
    w=csv.writer(f); w.writerow(['discrepancy_id','person_id','field','detail','sheet_row'])
    for i,d in enumerate(disc,1): w.writerow([f'D{i:04d}',d['person_id'],d['field'],d['detail'],d['sheet_row']])
with open(f'{OUT}/unmatched_branch_rows.csv','w',newline='') as f:
    w=csv.DictWriter(f, fieldnames=['sheet','row','name','loc','title']); w.writeheader(); w.writerows(unmatched)
json.dump({k:{kk:vv for kk,vv in v.items() if kk not in ('raw','colour','cgen')} for k,v in people.items()}, open(f'{OUT}/people.json','w'), ensure_ascii=False, indent=0)
print('people',len(people),'rels',len(rels),'discrepancies',len(disc),'unmatched branch rows',len(unmatched))
print('gen counts', collections.Counter(p['generation'] for p in people.values()))
print('name checks', collections.Counter(r.get('name_check','') for r in rels))
