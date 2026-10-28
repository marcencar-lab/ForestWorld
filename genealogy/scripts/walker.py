# New structural walker: colour gives RELATIVE depth; actual generation derived from context.
def walk(rows, people, rels, disc, add_person, link_child, norm, OVR, alejandro, saturnina_u):
    last_by_colour={}   # colour gen -> most recent non-spouse person with that colour
    last_at={}          # actual gen -> most recent non-spouse person
    byrow={}; cur=None
    def set_cur(p):
        nonlocal cur
        cur=p
        if p['role']!='spouse':
            last_at[p['generation']]=p
            for k in [k for k in last_at if k>p['generation']]: del last_at[k]
            if p.get('cgen') is not None:
                last_by_colour[p['cgen']]=p
                for k in [k for k in last_by_colour if k>p['cgen']]: del last_by_colour[k]
    def make_spouse(rw, partner, why):
        sp=add_person(rw, partner['generation'], 'spouse', 'spouse'); byrow[rw['row']]=sp; sp['cgen']=partner.get('cgen')
        partner['spouse_ids'].append(sp['person_id']); sp['spouse_ids'].append(partner['person_id'])
        rels.append(dict(a=partner['person_id'], b=sp['person_id'], type='spouse', evidence=f'FERNANDO!A{rw["row"]}; {why}', confidence='', name_check=''))
        if partner is not cur: set_cur(partner)
        cur_ = partner
        return sp
    def make_child(rw, parent, why, cgen):
        p=add_person(rw, parent['generation']+1, why, 'person'); byrow[rw['row']]=p; p['cgen']=cgen
        link_child(p, parent, why); set_cur(p); return p
    for rw in rows:
        if rw['row']==1: continue
        c=rw['gen_colour']; ov=OVR.get(rw['row'])
        if rw['highlight']: c=None
        if cur is None:
            p=add_person(rw, 1, 'header', 'person'); byrow[rw['row']]=p; p['cgen']=1
            p['father_id']=alejandro['person_id']; p['mother_id']=saturnina_u['person_id']
            alejandro['child_ids'].append(p['person_id']); saturnina_u['child_ids'].append(p['person_id'])
            rels.append(dict(a=alejandro['person_id'], b=p['person_id'], type='parent-child', evidence='FERNANDO!C1 header', confidence='low', name_check='ok'))
            set_cur(p); continue
        # ---- overrides ----
        if ov and ov.get('skip'):
            disc.append(dict(person_id='', field='duplicate', detail=f'row {rw["row"]} "{rw["display"]}" skipped: {ov["reason"]}', sheet_row=rw['row'])); continue
        if ov and ov.get('spouse_of_row'):
            sp=make_spouse(rw, byrow[int(ov['spouse_of_row'])], 'override: '+ov['reason']); sp['notes'].append('override: '+ov['reason']); continue
        if ov and ov.get('gen'):
            g=int(ov['gen']); parent=last_at.get(g-1)
            p=make_child(rw, parent, 'override gen: '+ov['reason'], c); p['notes'].append('override: '+ov['reason']); continue
        if ov and ov.get('parent_row'):
            p=make_child(rw, byrow[int(ov['parent_row'])], 'override: '+ov['reason'], c); p['notes'].append('override: '+ov['reason'])
            if rw['gen_label'] and rw['gen_label']!=p['generation']:
                disc.append(dict(person_id=p['person_id'], field='generation', detail=f'row {rw["row"]} "{rw["display"]}": text label {rw["gen_label"]}G vs derived gen {p["generation"]} (override)', sheet_row=rw['row']))
            continue
        marker = rw.get('marker') or rw.get('placeholder')
        ccur = cur.get('cgen')
        # ---- marker rows = additional spouse of the most recent person with that colour ----
        if marker:
            partner = last_by_colour.get(c) if c is not None else None
            if partner is None and rw['gen_label']: partner = last_at.get(rw['gen_label'])
            if partner is None: partner = cur if cur['role']!='spouse' else last_at[cur['generation']]
            make_spouse(rw, partner, 'marker'); continue
        # ---- relative depth ----
        if c is None:
            # no colour info: indent decides
            if rw['indent']>=3 and cur['role']!='spouse':
                make_spouse(rw, cur, 'no colour, indented'); continue
            parent = cur if cur['role']!='spouse' else last_at[cur['generation']]
            p=make_child(rw, parent, 'no colour; inferred child', None); p['notes'].append('no colour information; placed as child by position')
            disc.append(dict(person_id=p['person_id'], field='generation', detail=f'row {rw["row"]} "{rw["display"]}": no colour; placed as child of {parent["display"]} by position', sheet_row=rw['row'])); continue
        if ccur is None: ccur = c-1 if c>cur['generation'] else c
        if c == ccur+1:
            parent = cur if cur['role']!='spouse' else last_at[cur['generation']]
            make_child(rw, parent, 'colour depth', c); continue
        if c > ccur+1:
            parent = cur if cur['role']!='spouse' else last_at[cur['generation']]
            if rw['indent']>=3 and not parent['spouse_ids']:
                sp=make_spouse(rw, parent, 'colour too deep; indented -> spouse')
                disc.append(dict(person_id=sp['person_id'], field='generation', detail=f'row {rw["row"]} "{rw["display"]}": colour depth {c} is {c-ccur} deeper than {parent["display"]} (depth {ccur}); treated as spouse', sheet_row=rw['row'])); continue
            p=make_child(rw, parent, 'clamped', ccur+1)
            disc.append(dict(person_id=p['person_id'], field='generation', detail=f'row {rw["row"]} "{rw["display"]}": colour depth {c} is {c-ccur} deeper than {parent["display"]} (depth {ccur}); clamped to child', sheet_row=rw['row'])); continue
        # c <= ccur : same level as some earlier person
        cand = last_by_colour.get(c)
        if cand is None:
            parent = cur if cur['role']!='spouse' else last_at[cur['generation']]
            p=make_child(rw, parent, 'no level context', c); p['notes'].append('no person found at this colour level; placed as child by position')
            disc.append(dict(person_id=p['person_id'], field='generation', detail=f'row {rw["row"]} "{rw["display"]}": no earlier person at colour depth {c}; placed as child of {parent["display"]}', sheet_row=rw['row'])); continue
        ctoks={norm(t) for t in (cand['middle']+' '+cand['surname']).split() if len(t.strip('.'))>1}
        rtoks={norm(t) for t in (rw['given']+' '+rw['middle']+' '+rw['surname']).split() if len(t.strip('.'))>1}
        shared=bool(ctoks & rtoks); single=(rw['surname']==''); diff_surname = norm(rw['surname'])!=norm(cand['surname'])
        if diff_surname and not shared and ((not cand['spouse_ids'] and (single or rw['indent']>=2)) or rw['indent']>=4):
            make_spouse(rw, cand, 'same colour level, indented/unrelated surname'); continue
        # sibling of cand
        parent_id = cand['father_id'] or cand['mother_id']
        if not parent_id:
            p=add_person(rw, cand['generation'], 'sibling', 'person'); byrow[rw['row']]=p; p['cgen']=c; set_cur(p)
            p['notes'].append('sibling of a person without recorded parent'); continue
        parent=people[parent_id]
        # prefer the same parent-couple as cand
        if cand['father_id'] and cand['mother_id'] and people[cand['father_id']]['role']=='spouse':
            parent=people[cand['mother_id']]
        p=make_child(rw, parent, 'sibling by colour level', c)
        if rw['gen_label'] and rw['gen_label']!=p['generation']:
            disc.append(dict(person_id=p['person_id'], field='generation', detail=f'row {rw["row"]} "{rw["display"]}": text label {rw["gen_label"]}G vs derived gen {p["generation"]}', sheet_row=rw['row']))
    return byrow
