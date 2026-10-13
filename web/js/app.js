import { barChart, pairedBars, lineChart, pct } from './charts.js';

// ---------- theme ----------
const THEME_KEY = 'eba-theme';
function applyTheme(t) {
  if (t) document.documentElement.setAttribute('data-theme', t);
  else document.documentElement.removeAttribute('data-theme');
}
try { applyTheme(localStorage.getItem(THEME_KEY)); } catch (e) { /* storage unavailable */ }
document.querySelector('.theme-toggle').addEventListener('click', () => {
  const current = document.documentElement.getAttribute('data-theme')
    || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
  const next = current === 'dark' ? 'light' : 'dark';
  applyTheme(next);
  try { localStorage.setItem(THEME_KEY, next); } catch (e) { /* storage unavailable */ }
});

// ---------- data ----------
const cache = {};
export async function getJSON(name) {
  if (!cache[name]) {
    cache[name] = fetch(`data/${name}`).then(r => {
      if (!r.ok) throw new Error(`${name}: HTTP ${r.status}`);
      return r.json();
    });
  }
  return cache[name];
}

// ---------- overview ----------
function tile(label, value, note, cls = '') {
  const d = document.createElement('div');
  d.className = `tile ${cls}`;
  d.innerHTML = '<div class="label"></div><div class="value"></div><div class="note"></div>';
  d.querySelector('.label').textContent = label;
  d.querySelector('.value').textContent = value;
  d.querySelector('.note').textContent = note || '';
  return d;
}

let overviewData;
function drawOverview() {
  const d = overviewData;
  barChart(document.getElementById('ch-country'), d.country_share.slice(0, 10), { labelWidth: 110 });
  lineChart(document.getElementById('ch-trend'),
    d.npe_trend.map(p => ({ label: { '202409': 'Sep 2024', '202412': 'Dec 2024', '202503': 'Mar 2025', '202506': 'Jun 2025' }[p.period] || p.period, value: p.npe_ratio })),
    { yMin: 0.020, yMax: 0.023 });
  const sectors = d.sectors.map(s => ({ ...s, name: s.name.replace(/^[A-Z] /, '') }));
  pairedBars(document.getElementById('ch-sector'), sectors, [
    { title: 'Share of exposure', value: s => s.share, format: pct, color: () => 'var(--series-1)' },
    { title: 'Non-performing rate', value: s => s.npe_rate, format: pct, color: () => 'var(--series-2)' },
  ]);
}

async function initOverview() {
  overviewData = await getJSON('overview.json');
  const d = overviewData;
  const tiles = document.getElementById('ov-tiles');
  tiles.append(
    tile('Original exposure', `EUR ${d.total_exposure_eur_tn.toFixed(1)}tn`, `${d.banks} banks plus the EBA "all other banks" aggregate`),
    tile('Top 20 banks', pct(d.top20_share), 'share of exposure, named banks'),
    tile('Banks holding half', String(d.banks_for_half), 'largest banks needed to reach 50%'),
    tile('NPE ratio', pct(d.npe_ratio_latest, 2), 'system, June 2025 (EBA definition)'),
  );
  drawOverview();

  const s = await getJSON('stress_inputs.json');
  const { stressBank, median } = await import('./stress-model.js');
  const core = s.banks.filter(b => b.role === 'Core');
  const sc = s.scenarios.find(x => x.code === 'S4');
  const res = core.map(b => ({ b, r: stressBank(b, sc.shock, sc.horizon, s.assumptions) }));
  const below = res.filter(x => x.r.instant.headroom < 0).sort((p, q) => p.r.instant.headroom - q.r.instant.headroom);
  const box = document.getElementById('ov-stress');
  box.innerHTML = '<h2></h2><p class="p1"></p><p class="p2"></p><a class="btn primary" href="#stress">Open the stress test</a>';
  box.querySelector('h2').textContent = 'Could capital absorb the ECB adverse NPE shock?';
  box.querySelector('.p1').textContent =
    `Ten large banks start with a median of ${(median(res.map(x => x.r.headroomToday)) * 100).toFixed(1)} pp of CET1 above their own requirement. ` +
    `The 3-year adverse shock (+${(sc.shock * 100).toFixed(1)} pp of gross loans turning non-performing), charged against today's capital, cuts the median to ${(median(res.map(x => x.r.instant.headroom)) * 100).toFixed(1)} pp, ` +
    `and ${below.length} banks fall below their requirement: ${below.map(x => x.b.bank.replace(' Groep', '').replace(' Group', '')).join(', ')}.`;
  box.querySelector('.p2').textContent =
    'With run-rate earnings after tax and payout, none breaches, so resilience to a severe, prolonged shock depends on continued profitability.';
}

// ---------- router ----------
const loaded = {};
async function show(hash) {
  let tab = hash.split('/')[0];
  if (!['overview', 'ask', 'stress'].includes(tab)) tab = 'overview';
  for (const p of document.querySelectorAll('.tab-panel')) p.hidden = p.id !== `tab-${tab}`;
  for (const a of document.querySelectorAll('.tabs a')) {
    if (a.dataset.tab === tab) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
  }
  try {
    if (!loaded[tab]) {
      loaded[tab] = true;
      if (tab === 'overview') await initOverview();
      if (tab === 'ask') (await import('./ask.js')).initAsk();
      if (tab === 'stress') (await import('./stress.js')).initStress();
    } else {
      redraw(tab);
    }
  } catch (err) {
    console.error(err);
    const panel = document.getElementById(`tab-${tab}`);
    const msg = document.createElement('p');
    msg.className = 'status error';
    msg.textContent = `Could not load this section: ${err.message}`;
    panel.querySelector('.wrap').prepend(msg);
  }
}

async function redraw(tab) {
  if (tab === 'ask') (await import('./ask.js')).selectFromHash();
  if (tab === 'overview' && overviewData) drawOverview();
  if (tab === 'stress') (await import('./stress.js')).render();
}

window.addEventListener('hashchange', () => {
  const tab = location.hash.slice(1).split('/')[0];
  const changedTab = !document.getElementById(`tab-${tab}`) || document.getElementById(`tab-${tab}`).hidden;
  show(location.hash.slice(1));
  if (changedTab) window.scrollTo(0, 0);
});
let resizeTimer;
let lastWidth = window.innerWidth;
window.addEventListener('resize', () => {
  if (window.innerWidth === lastWidth) return;
  lastWidth = window.innerWidth;
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => redraw((location.hash.slice(1) || 'overview').split('/')[0]), 150);
});
show(location.hash.slice(1) || 'overview');
