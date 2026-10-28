"""Build the shareable 'Family Archive' page where relatives upload photos/documents and notes tied to people in the tree."""
import json, sys, os, html
OUT=sys.argv[1]
D=json.load(open(f'{OUT}/data.json')); P=D['people']
names=sorted(((p['name']+(f' ({p["nick"]})' if p['nick'] else '')+f' · G{p["gen"]}', p['id']) for p in P.values()), key=lambda t:t[0])
NAMES=json.dumps([[n,i] for n,i in names],ensure_ascii=False,separators=(',',':'))
page=f'''<title>Muñasque Family Archive</title>
<meta name="claude:viewport-fit-sides" content="cover">
<style>
/* Layout: a single-column archive: short instructions, one upload form, then a live gallery of what relatives have added. */
:root{{--bg:#f7f5f0;--surface:#fffdf9;--ink:#1d1b17;--ink2:#5c5a55;--line:#d9d5cc;--acc:#2a78d6;--acc2:#eb6834;--good:#0ca30c;--bad:#d03b3b;
 --display:'Source Serif 4',Georgia,'Times New Roman',serif;--body:'Source Sans 3','Segoe UI',Arial,sans-serif}}
@media (prefers-color-scheme:dark){{:root:not([data-theme="light"]){{--bg:#1a1a19;--surface:#23221f;--ink:#efede8;--ink2:#b8b5ad;--line:#3a3833;--acc:#3987e5;--acc2:#d95926;--good:#2fbf2f;--bad:#e66767;color-scheme:dark}}}}
:root[data-theme="dark"]{{--bg:#1a1a19;--surface:#23221f;--ink:#efede8;--ink2:#b8b5ad;--line:#3a3833;--acc:#3987e5;--acc2:#d95926;--good:#2fbf2f;--bad:#e66767;color-scheme:dark}}
body{{background:var(--bg);color:var(--ink);font-family:var(--body);font-size:16px;line-height:1.5;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px));padding-block:0 48px}}
main{{max-width:960px;margin:0 auto}}
h1{{font-family:var(--display);font-weight:600;font-size:clamp(26px,4vw,36px);margin:28px 0 6px;text-wrap:balance}}
h2{{font-family:var(--display);font-weight:600;font-size:21px;margin:28px 0 8px}}
p{{max-width:70ch;margin:6px 0}} .muted{{color:var(--ink2);font-size:14px}}
.card{{background:var(--surface);border:1px solid var(--line);border-radius:6px;padding:16px;margin:12px 0}}
form{{display:grid;grid-template-columns:1fr 1fr;gap:12px}} @media (max-width:640px){{form{{grid-template-columns:1fr}}}}
label{{display:flex;flex-direction:column;gap:4px;font-size:13px;color:var(--ink2);min-width:0}} label.full{{grid-column:1/-1}}
input,select,textarea{{font:inherit;font-size:15px;padding:8px 10px;border:1px solid var(--line);border-radius:4px;background:var(--bg);color:var(--ink);min-width:0;width:100%;box-sizing:border-box}}
textarea{{min-height:80px;resize:vertical}}
button{{font:inherit;font-size:15px;padding:9px 16px;border-radius:4px;border:1px solid var(--acc);background:var(--acc);color:#fff;cursor:pointer}} button.secondary{{background:transparent;color:var(--acc)}} button:disabled{{opacity:.5;cursor:default}} button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible{{outline:2px solid var(--acc2);outline-offset:2px}}
.status{{font-size:14px;min-height:1.4em}} .status.ok{{color:var(--good)}} .status.err{{color:var(--bad)}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:12px}}
.item{{background:var(--surface);border:1px solid var(--line);border-radius:6px;overflow:hidden;display:flex;flex-direction:column;min-width:0}}
.item img{{width:100%;aspect-ratio:4/3;object-fit:cover;background:var(--line);display:block}} .item .doc{{aspect-ratio:4/3;display:flex;align-items:center;justify-content:center;background:var(--line);color:var(--ink2);font-size:14px}}
.item .b{{padding:10px 12px;display:flex;flex-direction:column;gap:4px;font-size:14px}} .item .t{{font-weight:600}} .item .m{{color:var(--ink2);font-size:13px}}
.pill{{display:inline-block;padding:1px 8px;border-radius:10px;font-size:11px;border:1px solid var(--line);color:var(--ink2);align-self:flex-start}}
.empty{{border:1px dashed var(--line);border-radius:6px;padding:28px;text-align:center;color:var(--ink2)}}
.sr{{position:absolute;left:-9999px}} .row{{display:flex;gap:8px;flex-wrap:wrap;align-items:center}}
.datalist-note{{font-size:12px;color:var(--ink2)}}
@media (prefers-reduced-motion:reduce){{*{{transition:none!important}}}}
</style>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Source+Serif+4:wght@400;600&family=Source+Sans+3:wght@400;600&display=swap">
<main>
<h1>Muñasque Family Archive</h1>
<p>A place for relatives to add what the written tree lacks: photographs, baptism or marriage certificates, obituaries, letters, and corrections. Everything added here is listed below for the whole family, tied to the person it concerns.</p>
<p class="muted">What helps most: any photo of a person in the tree (with who, where and when), any document with a date, and corrections to names or placements. Say where a photo came from so it can be credited. Please do not upload anything you would not want other family members to see.</p>

<section class="card" id="formcard">
<h2>Add a photo, document or note</h2>
<p class="muted" id="access">Checking whether you can upload…</p>
<form id="f">
 <label class="full">Who or what is it about? <input id="person" list="people" placeholder="Start typing a name from the tree" autocomplete="off"><datalist id="people"></datalist><span class="datalist-note">Pick a name from the list so the item links to the right person. Leave blank for a general item.</span></label>
 <label>Title <input id="title" required placeholder="e.g. Wedding photo of Emiliano and Irenea"></label>
 <label>Type <select id="kind"><option value="photo">Photograph</option><option value="document">Document or certificate</option><option value="story">Story or memory</option><option value="correction">Correction to the tree</option><option value="other">Other</option></select></label>
 <label>Date of the photo or document (if known) <input id="docdate" placeholder="e.g. about 1952, or 3 June 1945"></label>
 <label>Your name (so we can credit you) <input id="who" placeholder="Your name"></label>
 <label class="full">Details <textarea id="notes" placeholder="Who is in it, where it was taken, who kept it, what it shows, or what should be corrected and why."></textarea></label>
 <label class="full">File (optional): JPG, PNG, GIF, WebP or PDF, up to 20 MB <input id="file" type="file" accept="image/png,image/jpeg,image/gif,image/webp,application/pdf"></label>
 <div class="full row"><button id="submit" type="submit">Add to the archive</button><span class="status" id="status" aria-live="polite"></span></div>
</form>
</section>

<h2>What the family has added <span class="muted" id="count"></span></h2>
<div class="row" style="margin:6px 0 12px"><label class="sr" for="filter">Filter by name</label><input id="filter" placeholder="Filter by name or title" style="max-width:320px"></div>
<div id="gallery"><div class="empty">Nothing has been added yet. The first photo or document posted with the form above will appear here for everyone.</div></div>
</main>
<script>
const NAMES={NAMES};
const byId=Object.fromEntries(NAMES.map(([n,i])=>[i,n]));
const dl=document.getElementById('people');
(function(){{const frag=document.createDocumentFragment();for(const [n] of NAMES){{const o=document.createElement('option');o.value=n;frag.appendChild(o);}}dl.appendChild(frag);}})();
function esc(s){{return String(s??'').replace(/[&<>"]/g,c=>({{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}})[c]);}}
let db=null,assets=null,user=null,myId=null,items=[];
const status=document.getElementById('status'),access=document.getElementById('access'),form=document.getElementById('f'),submit=document.getElementById('submit');
function setStatus(t,cls){{status.textContent=t;status.className='status '+(cls||'');}}
function render(){{
  const q=(document.getElementById('filter').value||'').toLowerCase();
  const g=document.getElementById('gallery');
  const list=items.filter(d=>!q||(d.title||'').toLowerCase().includes(q)||(d.personName||'').toLowerCase().includes(q)||(d.notes||'').toLowerCase().includes(q));
  document.getElementById('count').textContent=items.length?`(${{items.length}})`:'';
  if(!list.length){{g.innerHTML='<div class="empty">'+(items.length?'No item matches that filter.':'Nothing has been added yet. The first photo or document posted with the form above will appear here for everyone.')+'</div>';return;}}
  g.innerHTML='<div class="grid">'+list.map(d=>{{
    const src=d.assetId?'/_blob/'+d.assetId:'';
    const isImg=d.contentType&&d.contentType.startsWith('image/');
    const media=src?(isImg?`<a href="${{src}}" target="_blank" rel="noopener"><img src="${{src}}" alt="${{esc(d.title)}}" loading="lazy"></a>`:`<a class="doc" href="${{src}}" target="_blank" rel="noopener">Open ${{esc(d.fileName||'document')}}</a>`):'<div class="doc">No file</div>';
    const mine=myId&&d.uploaderId===myId;
    return `<div class="item">${{media}}<div class="b"><span class="pill">${{esc(d.kind||'other')}}</span><div class="t">${{esc(d.title)}}</div>${{d.personName?`<div class="m">About: ${{esc(d.personName)}}</div>`:''}}${{d.docDate?`<div class="m">Date: ${{esc(d.docDate)}}</div>`:''}}${{d.notes?`<div>${{esc(d.notes)}}</div>`:''}}<div class="m">Added by ${{esc(d.contributorName||'a family member')}}${{d.createdAt?' · '+esc(d.createdAt.slice(0,10)):''}}</div>${{mine&&db?`<button class="secondary" data-del="${{esc(d._id)}}" type="button">Remove my item</button>`:''}}</div></div>`;
  }}).join('')+'</div>';
  g.querySelectorAll('[data-del]').forEach(b=>b.addEventListener('click',()=>removeItem(b.dataset.del)));
}}
async function removeItem(id){{
  const d=items.find(x=>x._id===id); if(!d) return;
  if(!d._confirm){{d._confirm=true;const b=document.querySelector(`[data-del="${{CSS.escape(id)}}"]`);if(b)b.textContent='Click again to confirm removal';return;}}
  try{{ await db.collection('contributions').doc(id).delete(); if(d.assetId&&assets){{try{{await assets.delete(d.assetId);}}catch(e){{}}}} setStatus('Item removed.','ok'); }}
  catch(e){{ setStatus('Could not remove: '+(e&&e.code||'error'),'err'); }}
}}
document.getElementById('filter').addEventListener('input',render);
form.addEventListener('submit',async e=>{{
  e.preventDefault();
  if(!db){{setStatus('Saving is not available in this view.','err');return;}}
  const title=document.getElementById('title').value.trim(); if(!title){{setStatus('Please give the item a title.','err');return;}}
  const personText=document.getElementById('person').value.trim();
  const match=NAMES.find(([n])=>n===personText);
  const file=document.getElementById('file').files[0];
  submit.disabled=true; setStatus(file?'Uploading file…':'Saving…');
  let assetId='',contentType='',fileName='',sizeBytes=0;
  try{{
    if(file){{
      if(!assets){{throw {{code:'not_granted'}};}}
      let type=file.type; if(!type&&/\\.pdf$/i.test(file.name)) type='application/pdf';
      const r=await assets.upload(file, type&&type!==file.type?{{type}}:undefined);
      assetId=r.id; contentType=r.contentType; fileName=file.name; sizeBytes=r.sizeBytes;
    }}
    const doc={{title, kind:document.getElementById('kind').value, docDate:document.getElementById('docdate').value.trim(), notes:document.getElementById('notes').value.trim(),
      contributorName:document.getElementById('who').value.trim(), personId:match?match[1]:'', personName:match?match[0]:personText, assetId, contentType, fileName, sizeBytes,
      uploaderId:myId||'', createdAt:new Date().toISOString()}};
    await db.collection('contributions').add(doc);
    setStatus('Added. Thank you.','ok'); form.reset();
  }}catch(err){{
    const c=err&&err.code||'error';
    const msg={{too_large:'That file is over the size limit (20 MB).',unsupported_type:'That file type is not accepted. Use JPG, PNG, GIF, WebP or PDF.',quota_or_state:'The archive storage is full; ask the owner to make room.',not_granted:'You can add notes, but file uploads need Contributor access from the owner.',invalid_argument:'You do not have permission to save here. Ask the owner for Contributor access.',rate_limited:'Too many actions at once; wait a moment and try again.'}}[c]||('Could not save ('+c+').');
    setStatus(msg,'err');
  }}finally{{submit.disabled=false;}}
}});
(async()=>{{
  try{{ user=await claude.use('user'); if(user){{ myId=await user.id(); }} }}catch(e){{}}
  try{{ db=await claude.use('db'); }}catch(e){{}}
  try{{ assets=await claude.use('assets'); }}catch(e){{}}
  if(!db){{ access.textContent='This view cannot save to the archive. Open the page signed in to claude.ai with the access the owner gave you.'; submit.disabled=true; return; }}
  let canWrite=null; try{{ canWrite=user?await user.can('data.write'):null; }}catch(e){{}}
  if(canWrite===false){{ access.textContent='You can browse the archive. To add items, ask the owner to give you Contributor access.'; submit.disabled=true; }}
  else access.textContent=assets?'You can add notes and upload files.':'You can add notes. File uploads need Contributor access from the owner; notes without a file still work.';
  db.collection('contributions').orderBy('createdAt','desc').limit(500).onSnapshot(snap=>{{
    items=snap.docs.map(d=>Object.assign({{_id:d.id}},d.data())); render();
  }},err=>{{ setStatus('Live updates stopped ('+err.code+'); reload the page.','err'); }});
}})();
</script>
'''
os.makedirs(f'{OUT}/site',exist_ok=True)
open(f'{OUT}/site/munasque-archive.html','w',encoding='utf-8').write(page)
print('archive page bytes',len(page.encode()))
