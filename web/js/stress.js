import { getJSON } from './app.js';
import { stressBank, median } from './stress-model.js';
import { dumbbell, pp, pct } from './charts.js';

let S;            // stress_inputs.json
const state = { scenario: 'S4', view: 'instant', shock: null, coverage: 1, horizon: null };

const SHORT = {
  'Morgan Stanley Europe Holding SE': 'Morgan Stanley EU',
  'HSBC Continental Europe': 'HSBC Cont. Europe',
  'Groupe Crédit Agricole': 'Crédit Agricole',
  'Revolut Holdings Europe': 'Revolut',
};

function segButtons(container, options, current, onPick) {
  container.innerHTML = '';
  for (const o of options) {
    const b = document.createElement('button');
    b.type = 'button';
    b.setAttribute('role', 'radio');
    b.setAttribute('aria-checked', String(o.value === current));
    b.textContent = o.label;
    b.addEventListener('click', () => onPick(o.value));
    container.appendChild(b);
  }
  if (container.dataset.kb) return;
  container.dataset.kb = '1';
  container.addEventListener('keydown', e => {
    if (!['ArrowLeft', 'ArrowRight'].includes(e.key)) return;
    const btns = [...container.querySelectorAll('button')];
    const i = btns.indexOf(document.activeElement);
    if (i < 0) return;
    const j = (i + (e.key === 'ArrowRight' ? 1 : -1) + btns.length) % btns.length;
    btns[j].focus(); btns[j].click();
  });
}

function scenario() { return S.scenarios.find(s => s.code === state.scenario); }

function pickScenario(code) {
  state.scenario = code;
  state.shock = scenario().shock;
  state.horizon = scenario().horizon;
  state.coverage = 1;
  syncControls();
  render();
}

function syncControls() {
  segButtons(document.getElementById('scn-buttons'),
    S.scenarios.map(s => ({ value: s.code, label: s.name })), state.scenario, pickScenario);
  segButtons(document.getElementById('view-buttons'),
    [{ value: 'instant', label: 'Instant loss' }, { value: 'earnings', label: 'With earnings' }], state.view,
    v => { state.view = v; syncControls(); render(); });
  document.getElementById('sl-shock').value = (state.shock * 100).toFixed(1);
  document.getElementById('sl-cov').value = Math.round(state.coverage * 100);
  document.getElementById('sl-hor').value = state.horizon;
}

function isDefault() {
  const s = scenario();
  return Math.abs(state.shock - s.shock) < 1e-9 && state.coverage === 1 && state.horizon === s.horizon;
}

export function render() {
  if (!S) return;
  const a = S.assumptions;
  document.getElementById('out-shock').textContent = `+${(state.shock * 100).toFixed(1)} pp`;
  document.getElementById('out-cov').textContent = state.coverage === 1 ? "bank's own" : `${Math.round(state.coverage * 100)}% of bank's own`;
  document.getElementById('out-hor').textContent = `${state.horizon} year${state.horizon > 1 ? 's' : ''}`;
  const hc = document.getElementById('ctl-horizon');
  hc.classList.toggle('disabled', state.view !== 'earnings');
  document.getElementById('sl-hor').disabled = state.view !== 'earnings';
  document.getElementById('ctl-note').textContent = isDefault()
    ? `Settings of the ${scenario().name} scenario. Figures equal the Excel model.`
    : 'Custom settings: figures no longer correspond to a named scenario.';

  const rows = S.banks.map(b => {
    const bb = { ...b, npe_coverage: b.npe_coverage * state.coverage };
    const r = stressBank(bb, state.shock, state.horizon, a);
    const v = state.view === 'instant' ? r.instant : r.earnings;
    return { b, r, after: v.headroom, ratio: v.ratio };
  });
  const core = rows.filter(x => x.b.role === 'Core');
  const ref = rows.filter(x => x.b.role !== 'Core');
  const below = core.filter(x => x.after < 0);

  // tiles
  const tiles = document.getElementById('st-tiles');
  tiles.innerHTML = '';
  const mk = (label, html, note, cls = '') => {
    const d = document.createElement('div');
    d.className = `tile ${cls}`;
    d.innerHTML = `<div class="label"></div><div class="value">${html}</div><div class="note"></div>`;
    d.querySelector('.label').textContent = label;
    d.querySelector('.note').textContent = note;
    tiles.appendChild(d);
  };
  mk('Core banks below requirement', `${below.length > 0 ? '▼ ' : ''}${below.length} <span class="from">of ${core.length}</span>`,
    below.length ? below.map(x => SHORT[x.b.bank] || x.b.bank).join(', ') : 'none', below.length ? 'alert' : '');
  mk('Median headroom', pp(median(core.map(x => x.after))),
    `from ${pp(median(core.map(x => x.r.headroomToday)))} today, core banks`);
  const prov = core.reduce((s, x) => s + x.r.provisions, 0);
  mk('New provisions', `EUR ${(prov / 1000).toFixed(0)}bn`, `core banks, on EUR ${(core.reduce((s, x) => s + x.r.newNpe, 0) / 1000).toFixed(0)}bn of new NPE`);
  const lowest = [...core].sort((p, q) => p.after - q.after)[0];
  mk('Lowest headroom', pp(lowest.after), SHORT[lowest.b.bank] || lowest.b.bank, lowest.after < 0 ? 'alert' : '');

  // legend + chart
  document.getElementById('st-legend').innerHTML =
    '<span><i class="sw-today"></i>June 2025</span>' +
    '<span><i class="sw-after"></i>After shock</span>' +
    '<span><i class="sw-below"></i>After shock, below requirement ▼</span>';
  const toItem = x => ({ name: x.b.bank, short: SHORT[x.b.bank], before: x.r.headroomToday, after: x.after, x });
  dumbbell(document.getElementById('ch-headroom'), [
    { title: 'Core banks', items: core.map(toItem).sort((p, q) => p.after - q.after) },
    { title: 'Reference case', items: ref.map(toItem) },
  ], {
    tipRows: d => [
      ['CET1 ratio, June 2025', pct(d.x.r.cet1Today, 2)],
      ['CET1 requirement', pct(d.x.b.cet1_requirement, 2)],
      ['Headroom today', pp(d.before)],
      ['Stressed CET1 ratio', pct(d.x.ratio, 2)],
      ['Headroom after shock', pp(d.after)],
    ],
  });

  // table
  const fmtBn = v => (v / 1000).toLocaleString('en-GB', { maximumFractionDigits: 1, minimumFractionDigits: 1 });
  const head = ['Bank', 'Gross loans', 'NPE ratio', 'Coverage', 'New provisions', 'CET1 ratio', 'Requirement', 'Headroom today', 'Stressed CET1', 'Headroom after'];
  const body = r => [
    [r.b.bank, ''],
    [fmtBn(r.b.gross_loans), 'num'],
    [pct(r.b.npe_ratio, 2), 'num'],
    [pct(r.b.npe_coverage * state.coverage, 1), 'num'],
    [fmtBn(r.r.provisions), 'num'],
    [pct(r.r.cet1Today, 2), 'num'],
    [pct(r.b.cet1_requirement, 2), 'num'],
    [pp(r.r.headroomToday), 'num'],
    [pct(r.ratio, 2), 'num'],
    [(r.after < 0 ? '▼ ' : '') + pp(r.after), r.after < 0 ? 'num neg' : 'num'],
  ];
  const t = document.createElement('table');
  const thead = t.createTHead().insertRow();
  head.forEach((h, i) => { const th = document.createElement('th'); th.textContent = h; if (i) th.className = 'num'; thead.appendChild(th); });
  const tb = t.createTBody();
  const group = label => { const tr = tb.insertRow(); tr.className = 'group'; const td = tr.insertCell(); td.colSpan = head.length; td.textContent = label; };
  const add = r => { const tr = tb.insertRow(); for (const [v, c] of body(r)) { const td = tr.insertCell(); td.textContent = v; if (c) td.className = c; } };
  group('Core banks');
  [...core].sort((p, q) => p.after - q.after).forEach(add);
  group('Reference case');
  ref.forEach(add);
  const wrap = document.getElementById('st-table');
  wrap.innerHTML = '';
  wrap.appendChild(t);
}

export async function initStress() {
  S = await getJSON('stress_inputs.json');
  state.shock = scenario().shock;
  state.horizon = scenario().horizon;
  document.getElementById('sl-shock').addEventListener('input', e => { state.shock = +e.target.value / 100; render(); });
  document.getElementById('sl-cov').addEventListener('input', e => { state.coverage = +e.target.value / 100; render(); });
  document.getElementById('sl-hor').addEventListener('input', e => { state.horizon = +e.target.value; render(); });
  syncControls();
  render();
}
