import { getJSON } from './app.js';

// DuckDB-WASM, pinned version, loaded from jsDelivr only when this section is opened
const DUCKDB_VERSION = '1.32.0';
const DUCKDB_URL = `https://cdn.jsdelivr.net/npm/@duckdb/duckdb-wasm@${DUCKDB_VERSION}/+esm`;
const MAX_ROWS_SHOWN = 1000;

let conn = null;
let enginePromise = null;
let queries = [];
let current = null;
let lastResult = null;

const $ = id => document.getElementById(id);

function setStatus(msg, isError = false) {
  const s = $('q-status');
  s.textContent = msg;
  s.classList.toggle('error', isError);
}

async function startEngine() {
  const duckdb = await import(DUCKDB_URL);
  const bundle = await duckdb.selectBundle(duckdb.getJsDelivrBundles());
  const workerUrl = URL.createObjectURL(new Blob([`importScripts("${bundle.mainWorker}");`], { type: 'text/javascript' }));
  const worker = new Worker(workerUrl);
  const db = new duckdb.AsyncDuckDB(new duckdb.VoidLogger(), worker);
  await db.instantiate(bundle.mainModule, bundle.pthreadWorker);
  URL.revokeObjectURL(workerUrl);
  await db.open({ query: { castBigIntToDouble: true, castDecimalToDouble: true } });
  // The extract is a DuckDB database file (built by web/build_web_data.py); it needs no extensions
  const r = await fetch('data/eba.duckdb');
  if (!r.ok) throw new Error(`data/eba.duckdb: HTTP ${r.status}`);
  await db.registerFileBuffer('eba.duckdb', new Uint8Array(await r.arrayBuffer()));
  const c = await db.connect();
  await c.query("ATTACH 'eba.duckdb' AS eba (READ_ONLY)");
  await c.query('USE eba');
  return c;
}

function engine() {
  if (!enginePromise) {
    setStatus('Loading the query engine and data (about 5 MB, first time only)…');
    enginePromise = startEngine().then(c => { conn = c; setStatus('Ready.'); return c; })
      .catch(err => { enginePromise = null; throw err; });
  }
  return enginePromise;
}

function formatValue(v) {
  if (v === null || v === undefined) return { text: 'NULL', cls: 'null' };
  if (typeof v === 'bigint') v = Number(v);
  if (typeof v === 'number') {
    if (!Number.isFinite(v)) return { text: String(v), cls: 'num' };
    if (Number.isInteger(v)) return { text: String(v), cls: 'num' };
    const abs = Math.abs(v);
    const text = abs >= 1000
      ? v.toLocaleString('en-GB', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
      : v.toLocaleString('en-GB', { maximumFractionDigits: 6 });
    return { text, cls: 'num' };
  }
  if (v instanceof Date) return { text: v.toISOString().slice(0, 10), cls: '' };
  return { text: String(v), cls: '' };
}

function toRows(table) {
  const names = table.schema.fields.map(f => f.name);
  const cols = names.map((_, i) => table.getChildAt(i));
  const rows = [];
  for (let r = 0; r < table.numRows; r++) rows.push(cols.map(c => c.get(r)));
  return { names, rows };
}

function renderResult({ names, rows }, ms) {
  const box = $('q-result');
  box.innerHTML = '';
  const wrap = document.createElement('div');
  wrap.className = 'table-wrap';
  const t = document.createElement('table');
  const head = t.createTHead().insertRow();
  const firstRow = rows[0] || [];
  names.forEach((n, i) => {
    const th = document.createElement('th');
    th.textContent = n;
    if (typeof firstRow[i] === 'number' || typeof firstRow[i] === 'bigint') th.className = 'num';
    head.appendChild(th);
  });
  const body = t.createTBody();
  for (const row of rows.slice(0, MAX_ROWS_SHOWN)) {
    const tr = body.insertRow();
    for (const v of row) {
      const { text, cls } = formatValue(v);
      const td = tr.insertCell();
      td.textContent = text;
      if (cls) td.className = cls;
    }
  }
  wrap.appendChild(t);
  box.appendChild(wrap);
  const shown = Math.min(rows.length, MAX_ROWS_SHOWN);
  setStatus(`${rows.length.toLocaleString('en-GB')} row${rows.length === 1 ? '' : 's'}${rows.length > shown ? ` (first ${shown} shown; the CSV has all)` : ''} · ${ms.toFixed(0)} ms`);
}

function csvEscape(v) {
  if (v === null || v === undefined) return '';
  const s = typeof v === 'bigint' ? v.toString() : String(v);
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

function download() {
  if (!lastResult) return;
  const lines = [lastResult.names.map(csvEscape).join(',')]
    .concat(lastResult.rows.map(r => r.map(csvEscape).join(',')));
  const blob = new Blob([lines.join('\n') + '\n'], { type: 'text/csv' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `${current ? current.id.toLowerCase() : 'query'}_result.csv`;
  document.body.appendChild(a);
  a.click();
  setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 0);
}

async function run() {
  const sql = $('q-sql').value.trim();
  if (!sql) return;
  const btn = $('q-run');
  btn.disabled = true;
  $('q-download').disabled = true;
  lastResult = null;
  try {
    const c = await engine();
    setStatus('Running…');
    const t0 = performance.now();
    const res = await c.query(sql);
    lastResult = toRows(res);
    renderResult(lastResult, performance.now() - t0);
    $('q-download').disabled = false;
  } catch (err) {
    $('q-result').innerHTML = '';
    const pre = document.createElement('pre');
    pre.className = 'error';
    pre.textContent = String(err.message || err);
    $('q-result').appendChild(pre);
    setStatus('Query failed.', true);
  } finally {
    btn.disabled = false;
  }
}

function select(q, { runIt = true, updateHash = true } = {}) {
  current = q;
  $('q-meta').textContent = `${q.id} · ${q.meta || ''}`.replace(/ · $/, '');
  $('q-title').textContent = q.question;
  const notes = $('q-notes');
  notes.innerHTML = '';
  const extra = q.id === 'Q3'
    ? ['On this page: the browser extract holds only the items the queries use, so this query lists those items, not all 89.']
    : [];
  for (const n of [...q.notes, ...extra]) { const p = document.createElement('p'); p.textContent = n; notes.appendChild(p); }
  const src = document.createElement('p');
  const a = document.createElement('a');
  a.href = `https://github.com/agrawallachanchal/eba-credit-risk-analytics/blob/main/${q.file}`;
  a.textContent = q.file;
  src.append('Source: ', a);
  notes.appendChild(src);
  $('q-sql').value = q.sql;
  $('q-result').innerHTML = '';
  $('q-download').disabled = true;
  for (const b of document.querySelectorAll('.q-item')) b.setAttribute('aria-current', String(b.dataset.id === q.id));
  if (updateHash) history.replaceState(null, '', `#ask/${q.id}`);
  if (runIt) run();
}

function buildList() {
  const host = $('q-groups');
  host.innerHTML = '';
  for (const s of queries) {
    const g = document.createElement('div');
    g.className = 'q-group';
    const h = document.createElement('h3');
    h.textContent = s.section;
    g.appendChild(h);
    for (const q of s.queries) {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'q-item';
      b.dataset.id = q.id;
      b.dataset.search = `${q.id} ${q.question}`.toLowerCase();
      const strong = document.createElement('b');
      strong.textContent = q.id;
      b.append(strong, q.question);
      b.addEventListener('click', () => select(q));
      g.appendChild(b);
    }
    host.appendChild(g);
  }
  $('q-filter').addEventListener('input', e => {
    const term = e.target.value.trim().toLowerCase();
    for (const g of host.querySelectorAll('.q-group')) {
      let any = false;
      for (const b of g.querySelectorAll('.q-item')) {
        const hit = !term || b.dataset.search.includes(term);
        b.hidden = !hit;
        any = any || hit;
      }
      g.hidden = !any;
    }
  });
}

export function selectFromHash() {
  const id = (location.hash.split('/')[1] || '').toUpperCase();
  const all = queries.flatMap(s => s.queries);
  const q = all.find(x => x.id.toUpperCase() === id);
  if (q && q !== current) select(q, { updateHash: false });
}

export async function initAsk() {
  const data = await getJSON('queries.json');
  queries = data;
  buildList();
  $('q-run').addEventListener('click', run);
  $('q-reset').addEventListener('click', () => { if (current) $('q-sql').value = current.sql; });
  $('q-download').addEventListener('click', download);
  $('q-sql').addEventListener('keydown', e => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); run(); }
  });
  const all = queries.flatMap(s => s.queries);
  const id = (location.hash.split('/')[1] || '').toUpperCase();
  select(all.find(x => x.id.toUpperCase() === id) || all.find(x => x.id === 'Q8') || all[0], { updateHash: false });
}
