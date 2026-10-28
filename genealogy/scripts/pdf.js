const { chromium } = require('playwright'); const fs=require('fs'); const path=require('path');
(async()=>{ const b=await chromium.launch(); const pg=await b.newPage();
  const f=path.resolve(process.argv[2]); await pg.goto('file://'+f,{waitUntil:'load'}); await pg.waitForTimeout(500);
  await pg.pdf({path:process.argv[3],format:'A4',printBackground:true,margin:{top:'16mm',bottom:'16mm',left:'14mm',right:'14mm'},displayHeaderFooter:true,
    headerTemplate:'<div style="font-size:7pt;color:#777;width:100%;padding:0 14mm;font-family:DejaVu Sans,sans-serif">The Muñasque family of Opon, Cebu — printable report, 28 Oct 2026</div>',
    footerTemplate:'<div style="font-size:7pt;color:#777;width:100%;padding:0 14mm;text-align:right;font-family:DejaVu Sans,sans-serif">Page <span class="pageNumber"></span> of <span class="totalPages"></span></div>'});
  await b.close(); const st=fs.statSync(process.argv[3]); console.log('pdf bytes',st.size); })();
