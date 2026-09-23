import Foundation

/// The single-page dashboard the computer's browser loads from the phone. It subscribes to the
/// phone's Server-Sent-Events stream, renders scans as they arrive, and posts back /scan and
/// /write requests. Kept dependency-free (no external scripts) so it works on a closed network.
enum BridgeWebPage {
    static let html = """
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>NFC Forge — Computer Reader</title>
    <style>
      :root { color-scheme: light dark; --bg:#f5f5f7; --card:#ffffff; --ink:#1d1d1f; --sub:#6e6e73; --line:#e3e3e6; --accent:#0a84ff; --ok:#1a9e4b; --warn:#c77700; --err:#d23b2f; }
      @media (prefers-color-scheme: dark) { :root { --bg:#000; --card:#1c1c1e; --ink:#f5f5f7; --sub:#98989d; --line:#2c2c2e; } }
      * { box-sizing: border-box; }
      body { margin:0; font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; background:var(--bg); color:var(--ink); }
      header { padding:22px 20px; display:flex; align-items:center; gap:12px; border-bottom:1px solid var(--line); background:var(--card); position:sticky; top:0; z-index:2; }
      header h1 { font-size:18px; margin:0; font-weight:600; }
      .dot { width:10px; height:10px; border-radius:50%; background:var(--sub); flex:none; }
      .dot.on { background:var(--ok); }
      main { max-width:820px; margin:0 auto; padding:20px; }
      .row { display:flex; gap:12px; flex-wrap:wrap; margin-bottom:18px; }
      button { font:inherit; font-weight:600; border:0; border-radius:12px; padding:12px 18px; background:var(--accent); color:#fff; cursor:pointer; }
      button.secondary { background:var(--card); color:var(--ink); border:1px solid var(--line); }
      button:active { transform:translateY(1px); }
      input[type=text] { flex:1; min-width:180px; font:inherit; padding:12px 14px; border-radius:12px; border:1px solid var(--line); background:var(--card); color:var(--ink); }
      .card { background:var(--card); border:1px solid var(--line); border-radius:16px; padding:16px 18px; margin-bottom:14px; }
      .card h2 { font-size:13px; text-transform:uppercase; letter-spacing:.04em; color:var(--sub); margin:0 0 10px; }
      .kv { display:flex; justify-content:space-between; gap:16px; padding:6px 0; border-bottom:1px solid var(--line); }
      .kv:last-child { border-bottom:0; }
      .kv .k { color:var(--sub); }
      .kv .v { font-weight:600; text-align:right; word-break:break-all; }
      .rec { padding:10px 0; border-bottom:1px solid var(--line); }
      .rec:last-child { border-bottom:0; }
      .rec .kind { font-size:12px; color:var(--accent); font-weight:700; text-transform:uppercase; }
      .rec .val { word-break:break-all; }
      .issue { padding:10px 12px; border-radius:10px; margin-bottom:8px; border-left:4px solid var(--sub); background:var(--bg); }
      .issue:last-child { margin-bottom:0; }
      .issue.blocking { border-left-color:var(--err); }
      .issue.warning { border-left-color:var(--warn); }
      .issue.info { border-left-color:var(--accent); }
      .issue .t { font-weight:700; }
      .issue .d { color:var(--sub); font-size:13px; }
      pre { background:var(--bg); border-radius:10px; padding:12px; overflow:auto; font-size:12px; margin:0; max-height:260px; white-space:pre-wrap; word-break:break-all; }
      .muted { color:var(--sub); }
      .empty { text-align:center; color:var(--sub); padding:40px 0; }
      footer { text-align:center; color:var(--sub); font-size:12px; padding:24px; }
    </style>
    </head>
    <body>
    <header>
      <span class="dot" id="dot"></span>
      <h1>NFC Forge — Computer Reader</h1>
    </header>
    <main>
      <div class="row">
        <button onclick="scan()">Read a tag</button>
      </div>
      <div class="row">
        <input type="text" id="writeText" placeholder="Text to write to the next tag…">
        <button class="secondary" onclick="writeText()">Write to next tag</button>
      </div>

      <div id="result"><div class="empty">Waiting for a scan… press “Read a tag”, then hold a tag to the iPhone.</div></div>

      <div class="card">
        <h2>Activity</h2>
        <pre id="log">Connecting…</pre>
      </div>
    </main>
    <footer>Served from your iPhone over the local network · NFC Forge</footer>

    <script>
      const logEl = document.getElementById('log');
      const dot = document.getElementById('dot');
      const resultEl = document.getElementById('result');
      let lines = [];
      function log(msg){ lines.unshift(new Date().toLocaleTimeString()+'  '+msg); lines=lines.slice(0,60); logEl.textContent=lines.join('\\n'); }
      function esc(s){ return String(s).replace(/[&<>]/g, c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c])); }

      function renderScan(d){
        const recs = (d.records||[]).map(r=>
          `<div class="rec"><div class="kind">${esc(r.kind)}</div><div class="val">${esc(r.value||'')}</div></div>`
        ).join('') || '<div class="muted">No NDEF records.</div>';

        const issues = (d.issues||[]).map(i=>
          `<div class="issue ${esc(i.severity)}"><div class="t">${esc(i.title)}</div><div class="d">${esc(i.detail)}</div></div>`
        ).join('');
        const issuesCard = issues ? `<div class="card"><h2>Status</h2>${issues}</div>` : '';

        const mem = d.memoryHex ? `<div class="card"><h2>Raw memory (${d.memoryBytes} bytes)</h2><pre>${esc(d.memoryHex)}</pre></div>` : '';

        resultEl.innerHTML = `
          ${issuesCard}
          <div class="card">
            <h2>Last scan</h2>
            <div class="kv"><span class="k">Type</span><span class="v">${esc(d.family||'—')}</span></div>
            ${d.chip?`<div class="kv"><span class="k">Chip</span><span class="v">${esc(d.chip)}</span></div>`:''}
            <div class="kv"><span class="k">UID</span><span class="v">${esc(d.uid||'—')}</span></div>
            ${d.ndefStatus?`<div class="kv"><span class="k">NDEF</span><span class="v">${esc(d.ndefStatus)}</span></div>`:''}
            ${d.capacity!=null?`<div class="kv"><span class="k">Capacity</span><span class="v">${d.capacity} bytes</span></div>`:''}
          </div>
          <div class="card"><h2>Records</h2>${recs}</div>
          ${mem}`;
      }

      function connect(){
        const es = new EventSource('/events');
        es.addEventListener('hello', ()=>{ dot.classList.add('on'); log('Connected to iPhone.'); });
        es.addEventListener('status', e=>{ const d=JSON.parse(e.data); log(d.message||'status'); });
        es.addEventListener('scan', e=>{ const d=JSON.parse(e.data); renderScan(d); log('Scan received: '+(d.family||'tag')); });
        es.addEventListener('error-event', e=>{ const d=JSON.parse(e.data); log('Error: '+(d.message||'unknown')); });
        es.onerror = ()=>{ dot.classList.remove('on'); log('Disconnected — retrying…'); es.close(); setTimeout(connect, 1500); };
      }
      connect();

      async function scan(){ log('Asking iPhone to scan…'); try{ await fetch('/scan',{method:'POST'}); }catch(e){ log('Request failed.'); } }
      async function writeText(){
        const t = document.getElementById('writeText').value.trim();
        if(!t){ log('Enter some text first.'); return; }
        log('Asking iPhone to write…');
        try{ await fetch('/write',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({text:t})}); }
        catch(e){ log('Request failed.'); }
      }
    </script>
    </body>
    </html>
    """
}
