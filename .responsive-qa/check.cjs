const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const {spawn} = require('node:child_process');
const root = 'G:/elecom_web/frontend';
const admin = root + '/org_elecom/elecom_admin';
const results = [];
const server = http.createServer((req,res) => {
  const url = new URL(req.url,'http://localhost');
  const file = path.join(root,url.pathname.replace(/^\/static\//,''));
  if (!file.startsWith(path.resolve(root)) && !file.startsWith(root)) { res.writeHead(403).end(); return; }
  try {
    let content = fs.readFileSync(file);
    const ext = path.extname(file);
    if (ext === '.html') content = content.toString().replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, tag => tag.includes('admin_viewport.js') ? tag : '').replace(/<link rel="expect"[^>]*>/g,'');
    res.setHeader('Content-Type', {'.html':'text/html','.css':'text/css','.js':'application/javascript','.png':'image/png'}[ext] || 'application/octet-stream');
    res.end(content);
  } catch { res.writeHead(404).end(); }
});
async function main() {
  await new Promise(r=>server.listen(8766,'127.0.0.1',r));
  const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe', ['--headless=new','--no-first-run','--no-default-browser-check','--disable-gpu','--remote-debugging-port=9333','--user-data-dir=G:/elecom_mobile/.responsive-qa/chrome-profile','about:blank'], {windowsHide:true,stdio:'ignore'});
  let ws;
  try {
    let tabs;
    for(let i=0;i<30;i++) { try { tabs=await (await fetch('http://127.0.0.1:9333/json')).json(); if(tabs.length) break; } catch {} await new Promise(r=>setTimeout(r,200)); }
    ws = new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);
    await new Promise(r=>ws.addEventListener('open',r,{once:true}));
    let id=0; const pending = new Map();
    ws.addEventListener('message',e=> {const m=JSON.parse(e.data); if(m.id && pending.has(m.id)){ const {resolve,reject}=pending.get(m.id); pending.delete(m.id); m.error?reject(m.error):resolve(m.result); }});
    const send=(method,params={})=> new Promise((resolve,reject)=>{const n=++id;pending.set(n,{resolve,reject});ws.send(JSON.stringify({id:n,method,params}));});
    const evaluate=async expression=>(await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true})).result.value;
    await send('Page.enable');
    const pages=fs.readdirSync(admin).filter(n=>n.endsWith('.html') && fs.readFileSync(admin+'/'+n,'utf8').includes('admin_mobile.css'));
    for(const width of [301,327,393,768,980,1440]) {
      await send('Emulation.setDeviceMetricsOverride',{width,height:852,deviceScaleFactor:1,mobile:false});
      for(const name of pages) {
        await send('Page.navigate',{url:'http://127.0.0.1:8766/static/org_elecom/elecom_admin/'+name});
        await evaluate(`new Promise(resolve=>{if(document.readyState==='complete')resolve();else addEventListener('load',resolve,{once:true});setTimeout(resolve,4000)})`);
        const r=await evaluate(`(() => {
          const main=document.querySelector('.main-content');
          const visible=el=>{const r=el.getBoundingClientRect(); const s=getComputedStyle(el);return r.width>0&&r.height>0&&s.visibility!=='hidden'&&s.display!=='none';};
          const over=[...document.querySelectorAll('.content-area *')].filter(el=>visible(el)&&el.getBoundingClientRect().right>innerWidth+2&&!el.closest('.table-responsive,.network-table-wrap,.backup-table-wrap,.ledger-table-wrap,.report-table-wrap')).map(el=>el.tagName+'.'+el.className).slice(0,8);
          return {width:innerWidth,bodyWidth:document.documentElement.scrollWidth,mainWidth:main?.clientWidth,over,bootstrap:[...document.styleSheets].some(s=>s.href?.includes('bootstrap.min.css'))};
        })()`);
        results.push({page:name,width,...r});
        if(width===327 && ['elecom_elections.html','elecom_candidates.html','elecom_certificate_of_candidacy.html','elecom_live_chat.html','elecom_reports.html'].includes(name)) {
          const shot=await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false});
          fs.writeFileSync(__dirname+'/'+name+'.png',Buffer.from(shot.data,'base64'));
        }
      }
    }
    // Simulate a phone asking for a 980px desktop layout.
    await send('Emulation.setDeviceMetricsOverride',{width:393,height:852,screenWidth:393,screenHeight:852,deviceScaleFactor:1,mobile:true});
    await send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:5});
    await send('Page.navigate',{url:'http://127.0.0.1:8766/static/org_elecom/elecom_admin/admin_dashboard.html'});
    await evaluate(`new Promise(r=>setTimeout(r,1000))`);
    const phone=await evaluate(`({width:innerWidth,viewport:document.querySelector('meta[name="viewport"]').content,touch:navigator.maxTouchPoints})`);
    fs.writeFileSync(__dirname+'/results.json',JSON.stringify({results,phone},null,2));
    console.log(JSON.stringify({checked:results.length,overflow:results.filter(r=>r.bodyWidth>r.width+2||r.over.length),phone}));
    await send('Browser.close');
  } finally {ws?.close();chrome.kill();server.close();}
}
main().catch(e=>{console.error(e);server.close();process.exitCode=1;});
