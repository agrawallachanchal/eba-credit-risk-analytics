// Small SVG chart helpers (no library). Marks follow one style: bars at most 24px thick with a
// 4px rounded data end, 2px lines, 8px markers, hairline grid, labels in text colours.

const NS = 'http://www.w3.org/2000/svg';

export function el(tag, attrs = {}, parent) {
  const n = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) if (v !== undefined && v !== null) n.setAttribute(k, v);
  if (parent) parent.appendChild(n);
  return n;
}

function text(parent, x, y, str, attrs = {}) {
  const t = el('text', { x, y, ...attrs }, parent);
  t.textContent = str;
  return t;
}

export const pct = (v, d = 1) => `${(v * 100).toFixed(d)}%`;
export const pp = (v, d = 2) => `${v < 0 ? '−' : ''}${Math.abs(v * 100).toFixed(d)} pp`;

// Horizontal bar whose data end (right for positive, left for negative) is rounded
function hbarPath(x0, x1, y, h, r = 4) {
  const left = Math.min(x0, x1), right = Math.max(x0, x1), w = right - left;
  const rr = Math.min(r, w / 2, h / 2);
  if (x1 >= x0) {
    return `M${left},${y}H${right - rr}Q${right},${y} ${right},${y + rr}V${y + h - rr}Q${right},${y + h} ${right - rr},${y + h}H${left}Z`;
  }
  return `M${right},${y}H${left + rr}Q${left},${y} ${left},${y + rr}V${y + h - rr}Q${left},${y + h} ${left + rr},${y + h}H${right}Z`;
}

// Shorten a label to fit a width (approximate glyph width for 12px system sans)
function fit(str, px) {
  const max = Math.max(4, Math.floor(px / 6.3));
  return str.length > max ? str.slice(0, max - 1).trimEnd() + '…' : str;
}

// Decimals for a percentage tick: none for whole percentages, one otherwise
const tickDp = t => (Math.abs(t * 100 - Math.round(t * 100)) < 1e-9 ? 0 : 1);

function niceTicks(min, max, count = 5) {
  const span = max - min || 1;
  const step0 = span / count;
  const mag = 10 ** Math.floor(Math.log10(step0));
  const step = [1, 2, 2.5, 5, 10].map(m => m * mag).find(s => span / s <= count) || 10 * mag;
  const ticks = [];
  const end = Math.ceil(max / step - 1e-9) * step;
  for (let v = Math.floor(min / step + 1e-9) * step; v <= end + step * 1e-6; v += step) ticks.push(+v.toFixed(12));
  return ticks;
}

// ---------- tooltip ----------
const tip = () => document.getElementById('tooltip');
export function showTip(evt, title, rows) {
  const t = tip();
  t.innerHTML = '';
  const s = document.createElement('strong'); s.textContent = title; t.appendChild(s);
  for (const [k, v] of rows) {
    const r = document.createElement('div'); r.className = 'tt-row';
    const a = document.createElement('span'); a.textContent = k;
    const b = document.createElement('span'); b.textContent = v;
    r.append(a, b); t.appendChild(r);
  }
  t.hidden = false;
  moveTip(evt);
}
export function moveTip(evt) {
  const t = tip();
  let x, y;
  if (evt.clientX !== undefined && evt.type !== 'focus') { x = evt.clientX; y = evt.clientY; }
  else { const b = evt.target.getBoundingClientRect(); x = b.left + b.width / 2; y = b.top; }
  const w = t.offsetWidth, h = t.offsetHeight;
  let left = x + 14, top = y - h - 10;
  if (left + w > window.innerWidth - 8) left = x - w - 14;
  if (left < 8) left = 8;
  if (top < 8) top = y + 16;
  t.style.left = `${left}px`; t.style.top = `${top}px`;
}
export function hideTip() { tip().hidden = true; }

function bindTip(node, title, rows) {
  node.setAttribute('tabindex', '0');
  node.addEventListener('mouseenter', e => showTip(e, title, rows()));
  node.addEventListener('mousemove', moveTip);
  node.addEventListener('mouseleave', hideTip);
  node.addEventListener('focus', e => showTip(e, title, rows()));
  node.addEventListener('blur', hideTip);
}

// ---------- horizontal bar chart (one series) ----------
export function barChart(container, data, { format = pct, labelWidth = 120, tipRows } = {}) {
  container.innerHTML = '';
  const W = Math.max(container.clientWidth, 280);
  const rowH = 30, barH = 18, top = 4, bottom = 22;
  const lw = Math.min(labelWidth, W * 0.38);
  const valueW = 52;
  const H = top + data.length * rowH + bottom;
  const svg = el('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': data.map(d => `${d.name} ${format(d.value)}`).join('; ') }, container);
  const max = Math.max(...data.map(d => d.value));
  const x0 = lw, x1 = W - valueW;
  const ticks = niceTicks(0, max, 4);
  const sx = v => x0 + (v / ticks[ticks.length - 1]) * (x1 - x0);
  for (const t of ticks) {
    el('line', { x1: sx(t), x2: sx(t), y1: top, y2: H - bottom, class: t === 0 ? 'baseline' : 'gridline' }, svg);
    const g = el('g', { class: 'tick' }, svg);
    text(g, sx(t), H - 6, format(t, tickDp(t)), { 'text-anchor': 'middle' });
  }
  data.forEach((d, i) => {
    const y = top + i * rowH;
    const g = el('g', { class: 'row' }, svg);
    el('rect', { x: 0, y, width: W, height: rowH, class: 'row-hover', rx: 4 }, g);
    text(g, lw - 8, y + rowH / 2 + 4, fit(d.name, lw - 12), { 'text-anchor': 'end' });
    el('path', { d: hbarPath(sx(0), sx(d.value), y + (rowH - barH) / 2, barH), fill: 'var(--series-1)' }, g);
    text(g, sx(d.value) + 6, y + rowH / 2 + 4, format(d.value), { class: 'value-label' });
    bindTip(g, d.name, () => (tipRows ? tipRows(d) : [['Value', format(d.value)]]));
  });
}

// ---------- two aligned bar panels sharing rows (no dual axis: each panel has its own scale) ----------
export function pairedBars(container, data, panels, { labelWidth = 290 } = {}) {
  container.innerHTML = '';
  const W = Math.max(container.clientWidth, 300);
  const narrow = W < 620;
  const rowH = 28, barH = 16, top = 26, bottom = 22;
  const lw = narrow ? Math.min(150, W * 0.42) : labelWidth;
  const gap = 24, valueW = 48;
  const panelW = (W - lw - gap * (panels.length - 1) - 8) / panels.length;
  const H = top + data.length * rowH + bottom;
  const svg = el('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': panels.map(p => p.title).join(' and ') + ' by sector' }, container);
  const scales = panels.map((p, k) => {
    const max = Math.max(...data.map(p.value));
    const ticks = niceTicks(0, max, narrow ? 2 : 3);
    const a = lw + k * (panelW + gap), b = a + panelW - valueW;
    return { ...p, ticks, a, b, s: v => a + (v / ticks[ticks.length - 1]) * (b - a) };
  });
  for (const p of scales) {
    text(svg, p.a, 14, p.title, { class: 'section-label' });
    for (const t of p.ticks) {
      el('line', { x1: p.s(t), x2: p.s(t), y1: top, y2: H - bottom, class: t === 0 ? 'baseline' : 'gridline' }, svg);
      const g = el('g', { class: 'tick' }, svg);
      text(g, p.s(t), H - 6, p.format(t, tickDp(t)), { 'text-anchor': 'middle' });
    }
  }
  data.forEach((d, i) => {
    const y = top + i * rowH;
    const g = el('g', { class: 'row' }, svg);
    el('rect', { x: 0, y, width: W, height: rowH, class: 'row-hover', rx: 4 }, g);
    text(g, lw - 8, y + rowH / 2 + 4, fit(d.name, lw - 12), { 'text-anchor': 'end' });
    for (const p of scales) {
      const v = p.value(d);
      el('path', { d: hbarPath(p.s(0), p.s(v), y + (rowH - barH) / 2, barH), fill: p.color(d) }, g);
      text(g, p.s(v) + 5, y + rowH / 2 + 4, p.format(v), { class: 'value-label' });
    }
    bindTip(g, d.name, () => scales.map(p => [p.title, p.format(p.value(d))]));
  });
}

// ---------- line chart (one series, a handful of points) ----------
export function lineChart(container, data, { format = v => pct(v, 2), yMin, yMax } = {}) {
  container.innerHTML = '';
  const W = Math.max(container.clientWidth, 280);
  const H = 240, left = 52, right = 56, top = 16, bottom = 30;
  const svg = el('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': data.map(d => `${d.label} ${format(d.value)}`).join('; ') }, container);
  const vals = data.map(d => d.value);
  const lo = yMin ?? Math.min(...vals), hi = yMax ?? Math.max(...vals);
  const ticks = niceTicks(lo, hi, 4);
  const t0 = Math.min(ticks[0], lo), t1 = Math.max(ticks[ticks.length - 1], hi);
  const sy = v => top + (1 - (v - t0) / (t1 - t0)) * (H - top - bottom);
  const sx = i => left + (data.length === 1 ? 0.5 : i / (data.length - 1)) * (W - left - right);
  for (const t of ticks) {
    el('line', { x1: left, x2: W - right, y1: sy(t), y2: sy(t), class: 'gridline' }, svg);
    const g = el('g', { class: 'tick' }, svg);
    text(g, left - 8, sy(t) + 4, format(t), { 'text-anchor': 'end' });
  }
  data.forEach((d, i) => { const g = el('g', { class: 'tick' }, svg); text(g, sx(i), H - 8, d.label, { 'text-anchor': 'middle' }); });
  el('path', { d: data.map((d, i) => `${i ? 'L' : 'M'}${sx(i)},${sy(d.value)}`).join(''), fill: 'none', stroke: 'var(--series-1)', 'stroke-width': 2, 'stroke-linejoin': 'round' }, svg);
  data.forEach((d, i) => {
    const g = el('g', { class: 'row' }, svg);
    el('rect', { x: sx(i) - 24, y: top, width: 48, height: H - top - bottom, class: 'hit' }, g);
    el('circle', { cx: sx(i), cy: sy(d.value), r: 4, fill: 'var(--series-1)', stroke: 'var(--surface)', 'stroke-width': 2 }, g);
    if (i === 0 || i === data.length - 1) {
      text(g, sx(i) + (i ? 8 : -8), sy(d.value) - 8, format(d.value), { class: 'value-label', 'text-anchor': i ? 'start' : 'end' });
    }
    bindTip(g, d.label, () => [['NPE ratio', format(d.value)]]);
  });
}

// ---------- dumbbell: headroom today -> after shock, zero line = requirement ----------
export function dumbbell(container, groups, { tipRows } = {}) {
  container.innerHTML = '';
  const W = Math.max(container.clientWidth, 300);
  const narrow = W < 560;
  const rowH = 30, groupH = 26, top = 8, bottom = 26;
  const lw = narrow ? 112 : 210;
  const right = 16;
  const rows = groups.reduce((n, g) => n + g.items.length, 0);
  const H = top + rows * rowH + groups.length * groupH + bottom;
  const all = groups.flatMap(g => g.items.flatMap(d => [d.before, d.after]));
  const lo = Math.min(0, ...all), hi = Math.max(0, ...all);
  const ticks = niceTicks(lo, hi, narrow ? 4 : 6);
  const t0 = Math.min(ticks[0], lo), t1 = Math.max(ticks[ticks.length - 1], hi);
  const sx = v => lw + ((v - t0) / (t1 - t0)) * (W - lw - right);
  const svg = el('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': groups.flatMap(g => g.items).map(d => `${d.name}: ${pp(d.before)} to ${pp(d.after)}`).join('; ') }, container);
  for (const t of ticks) {
    el('line', { x1: sx(t), x2: sx(t), y1: top, y2: H - bottom, class: Math.abs(t) < 1e-12 ? 'baseline' : 'gridline' }, svg);
    const g = el('g', { class: 'tick' }, svg);
    text(g, sx(t), H - 8, `${t < 0 ? '−' : t > 0 ? '+' : ''}${Math.abs(t * 100).toFixed(0)}`, { 'text-anchor': 'middle' });
  }
  el('line', { x1: sx(0), x2: sx(0), y1: top, y2: H - bottom, stroke: 'var(--ink-2)', 'stroke-width': 1.5 }, svg);
  let y = top;
  for (const grp of groups) {
    text(svg, 0, y + 17, grp.title, { class: 'section-label' });
    y += groupH;
    for (const d of grp.items) {
      const cy = y + rowH / 2;
      const g = el('g', { class: 'row' }, svg);
      el('rect', { x: 0, y, width: W, height: rowH, class: 'row-hover', rx: 4 }, g);
      const name = fit(narrow && d.short ? d.short : d.name, lw - 14);
      text(g, lw - 10, cy + 4, name, { 'text-anchor': 'end' });
      const below = d.after < 0;
      el('line', { x1: sx(d.before), x2: sx(d.after), y1: cy, y2: cy, stroke: below ? 'var(--critical)' : 'var(--series-1)', 'stroke-width': 2, 'stroke-opacity': 0.55 }, g);
      el('circle', { cx: sx(d.before), cy, r: 5, fill: 'var(--today)', stroke: 'var(--surface)', 'stroke-width': 2 }, g);
      el('circle', { cx: sx(d.after), cy, r: 5.5, fill: below ? 'var(--critical)' : 'var(--series-1)', stroke: 'var(--surface)', 'stroke-width': 2 }, g);
      if (below) {
        const label = `▼ ${pp(d.after)}`;
        const roomLeft = sx(d.after) - lw > 78;
        const lx = roomLeft ? sx(d.after) - 10 : Math.max(sx(d.after), sx(d.before)) + 10;
        text(g, lx, cy + 4, label, { 'text-anchor': roomLeft ? 'end' : 'start', class: 'value-label neg-label' });
      }
      bindTip(g, d.name, () => (tipRows ? tipRows(d) : []));
      y += rowH;
    }
  }
  text(svg, sx(0) + 4, top + 10, 'requirement', { class: 'zero-label' });
}
