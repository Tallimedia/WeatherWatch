/* Charts for the FIWeatherWatch data explorer.
   Hand-rolled SVG line charts: the data is small, and a dependency-free page
   keeps the prototype deployable anywhere without a build step. */

const $ = (s) => document.querySelector(s);
const tip = $("#tip");
const PAD = { l: 46, r: 14, t: 10, b: 26 };
const W = 960, H = 210;

const iso = (d) => d.toISOString().slice(0, 10);
const fmt = (n, d = 1) => (n === null || n === undefined ? "–" : Number(n).toFixed(d));

/* Each chart names the question it exists to answer (RESEARCH.md §19). */
const CHARTS = [
  { id: "landwind", group: "Land", title: "Land wind and gust",
    q: "The land threshold default — how much lower is it than at sea?",
    source: (c) => ({ place: c.place, producer: "opendata",
                      params: "windspeedms,windgust", step: 60 }),
    series: [ { key: "windspeedms", label: "Mean wind", unit: "m/s" },
              { key: "windgust",    label: "Gust",      unit: "m/s" } ] },

  { id: "landrain", group: null, title: "Land rainfall",
    q: "Does hourly precipitation carry enough signal to show on the watch?",
    source: (c) => ({ place: c.place, producer: "opendata",
                      params: "precipitation1h", step: 60 }),
    series: [ { key: "precipitation1h", label: "Rain", unit: "mm/h" } ] },

  { id: "forecast", group: null, title: "Land forecast — next 10 days",
    q: "What the watch's page 1 draws on. Forward-looking, so it ignores the date range above.",
    forecast: true,
    source: (c) => ({ place: c.place,
                      params: "temperature,windspeedms,hourlymaximumgust", step: 360 }),
    series: [ { key: "temperature",       label: "Temperature", unit: "°C" },
              { key: "windspeedms",       label: "Wind",        unit: "m/s" },
              { key: "hourlymaximumgust", label: "Gust",        unit: "m/s" } ] },

  { id: "fcrain", group: null, title: "Forecast rainfall — next 10 days",
    q: "How far out does the forecast still show meaningful precipitation?",
    forecast: true,
    source: (c) => ({ place: c.place, params: "precipitation1h", step: 360 }),
    series: [ { key: "precipitation1h", label: "Rain", unit: "mm/h" } ] },

  { id: "symbols", group: null, title: "Weather symbols in this forecast",
    q: "Which smartsymbol codes actually occur — i.e. which icons need drawing?",
    forecast: true, symbols: true,
    source: (c) => ({ place: c.place, params: "smartsymbol", step: 180 }),
    series: [ { key: "smartsymbol", label: "Symbol", unit: "" } ] },

  { id: "wind", group: "Sea station", title: "Sea wind and gust",
    q: "How do mean and gust relate — and what gust value should the default threshold be?",
    source: (c) => ({ fmisid: c.station, producer: "opendata",
                      params: "windspeedms,windgust", step: 60 }),
    series: [ { key: "windspeedms", label: "Mean wind", unit: "m/s" },
              { key: "windgust",    label: "Gust",      unit: "m/s" } ] },

  { id: "landsea", group: null, title: "Land vs sea air temperature",
    q: "How far apart are the two stations — do they justify separate thresholds?",
    source: (c) => ({ fmisid: c.station, producer: "opendata",
                      params: "temperature", step: 60 }),
    extra:  (c) => ({ place: c.place, producer: "opendata",
                      params: "temperature", step: 60 }),
    series: [ { key: "temperature",  label: "Sea station", unit: "°C" },
              { key: "temperature2", label: "Land place",  unit: "°C" } ] },

  { id: "waves", group: "Wave buoy", title: "Wave height at the chosen buoy",
    q: "What is a normal wave height here, and what counts as high?",
    buoy: true,
    series: [ { key: "WaveHs", label: "Significant height", unit: "m" },
              { key: "WTP",    label: "Period",             unit: "s" } ] },

  { id: "wavedir", group: null, title: "Wave direction and spread",
    q: "Does WHDD (spread) ever say anything useful, or is ModalWDi enough?",
    buoy: true,
    series: [ { key: "ModalWDi", label: "Direction (ModalWDi)", unit: "°" },
              { key: "WHDD",     label: "Spread (WHDD)",        unit: "°" } ] },

  { id: "water", group: null, title: "Sea water temperature",
    q: "Does the buoy's water temperature earn a line on the watch?",
    buoy: true,
    series: [ { key: "TWATER", label: "Water", unit: "°C" } ] },

  { id: "ice", group: "Sea ice", title: "Sea ice thickness (winter only)",
    q: "How does ice build and decay? Weekly readings — empty outside late Nov–late Apr.",
    ice: true,
    series: [ { key: "ICE_PT1S_INSTANT", label: "Ice thickness", unit: "cm" },
              { key: "SNDICE_PT1M_AVG",  label: "Snow on ice",   unit: "cm" } ] },

];

const COLORS = ["var(--s1)", "var(--s2)", "var(--s3)"];

async function fetchSeries(args, start, end) {
  const p = new URLSearchParams({ start: start + "T00:00:00Z", end: end + "T00:00:00Z" });
  for (const [k, v] of Object.entries(args)) if (v !== undefined && v !== null) p.set(k, v);
  const r = await fetch("/v1/series?" + p);
  if (!r.ok) throw new Error((await r.json()).detail || r.statusText);
  return r.json();
}

/* One axis per measure. Two series only share a y-axis when they are the same
   unit AND comparable in magnitude — otherwise the smaller one flattens against
   the baseline and says nothing. Different scales get their own panel. */
function sharesAxis(series, pts) {
  if (series.length < 2) return true;
  if (new Set(series.map((s) => s.unit)).size > 1) return false;
  const spans = pts.map((p) => (p.length ? Math.max(...p.map((d) => d.v)) : 0));
  const hi = Math.max(...spans), lo = Math.min(...spans);
  return lo > 0 && hi / lo < 3;
}

function draw(fig, rows, series) {
  const pts = series.map((s) =>
    rows.map((r) => ({ t: r.epochtime, v: r[s.key] })).filter((d) => d.v !== null && d.v !== undefined)
  );
  if (!sharesAxis(series, pts)) {
    const host = fig.querySelector(".plot");
    host.innerHTML = "";
    series.forEach((s, i) => {
      const panel = document.createElement("div");
      panel.innerHTML = '<div class="plot"></div><div class="stats"></div>';
      host.appendChild(panel);
      drawPanel(panel, rows, [s], [pts[i]], [COLORS[i]]);
    });
    return;
  }
  drawPanel(fig, rows, series, pts, COLORS);
}

function drawPanel(fig, rows, series, pts, COLORS) {
  if (!pts.some((p) => p.length)) {
    fig.querySelector(".plot").innerHTML =
      '<p class="msg">No data in this range — expected for seasonal sensors.</p>';
    return;
  }
  const all = pts.flat();
  const t0 = Math.min(...all.map((d) => d.t)), t1 = Math.max(...all.map((d) => d.t));
  let v0 = Math.min(...all.map((d) => d.v)), v1 = Math.max(...all.map((d) => d.v));
  if (v0 === v1) { v0 -= 1; v1 += 1; }
  const pad = (v1 - v0) * 0.1; v0 -= pad; v1 += pad;
  const x = (t) => PAD.l + ((t - t0) / (t1 - t0 || 1)) * (W - PAD.l - PAD.r);
  const y = (v) => H - PAD.b - ((v - v0) / (v1 - v0)) * (H - PAD.t - PAD.b);

  const ticks = 4, gy = [], ly = [];
  for (let i = 0; i <= ticks; i++) {
    const v = v0 + ((v1 - v0) * i) / ticks, yy = y(v);
    gy.push(`<line x1="${PAD.l}" y1="${yy}" x2="${W - PAD.r}" y2="${yy}" stroke="var(--grid)" stroke-width="1"/>`);
    ly.push(`<text x="${PAD.l - 8}" y="${yy + 4}" text-anchor="end" fill="var(--muted)" font-size="11">${fmt(v, Math.abs(v1 - v0) < 5 ? 1 : 0)}</text>`);
  }
  const lx = [];
  for (let i = 0; i <= 3; i++) {
    const t = t0 + ((t1 - t0) * i) / 3;
    lx.push(`<text x="${x(t)}" y="${H - 8}" text-anchor="middle" fill="var(--muted)" font-size="11">${new Date(t * 1000).toISOString().slice(5, 16).replace("T", " ")}</text>`);
  }
  const paths = pts.map((p, i) =>
    p.length
      ? `<path d="${p.map((d, j) => (j ? "L" : "M") + x(d.t) + " " + y(d.v)).join(" ")}" fill="none" stroke="${COLORS[i]}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>`
      : ""
  );
  fig.querySelector(".plot").innerHTML = `
    <svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${series.map((s) => s.label).join(", ")}">
      ${gy.join("")}${ly.join("")}${lx.join("")}
      <line x1="${PAD.l}" y1="${H - PAD.b}" x2="${W - PAD.r}" y2="${H - PAD.b}" stroke="var(--axis)" stroke-width="1"/>
      ${paths.join("")}
      <rect x="${PAD.l}" y="${PAD.t}" width="${W - PAD.l - PAD.r}" height="${H - PAD.t - PAD.b}" fill="transparent" class="hit"/>
      <line class="cross" x1="0" y1="${PAD.t}" x2="0" y2="${H - PAD.b}" stroke="var(--axis)" stroke-width="1" opacity="0"/>
    </svg>`;

  // Summary stats double as the table view the contrast WARN obliges.
  const statsEl = fig.querySelector(".stats");
  if (statsEl) statsEl.innerHTML = series.map((s, i) => {
    const p = pts[i]; if (!p.length) return "";
    const latest = p[p.length - 1].v;                       // last by TIME
    const vals = p.map((d) => d.v).slice().sort((a, b) => a - b);
    const q = (f) => vals[Math.floor((vals.length - 1) * f)];
    return `<div><span style="color:${COLORS[i]}">${s.label}</span>
      <b>${fmt(latest)} ${s.unit}</b>
      latest · min ${fmt(vals[0])} · median ${fmt(q(0.5))} · p90 ${fmt(q(0.9))} · max ${fmt(vals[vals.length - 1])}</div>`;
  }).join("");

  const svg = fig.querySelector("svg"), cross = svg.querySelector(".cross");
  svg.querySelector(".hit").addEventListener("mousemove", (e) => {
    const box = svg.getBoundingClientRect();
    const t = t0 + ((e.clientX - box.left) / box.width * W - PAD.l) / (W - PAD.l - PAD.r) * (t1 - t0);
    cross.setAttribute("x1", x(t)); cross.setAttribute("x2", x(t)); cross.setAttribute("opacity", "1");
    const near = pts.map((p) => p.length ? p.reduce((a, b) => Math.abs(b.t - t) < Math.abs(a.t - t) ? b : a) : null);
    tip.innerHTML = `${new Date((near.find(Boolean) || {}).t * 1000).toISOString().slice(0, 16).replace("T", " ")} UTC<br>` +
      series.map((s, i) => near[i] ? `<span style="color:${COLORS[i]}">■</span> ${s.label} <b>${fmt(near[i].v)}</b> ${s.unit}` : "").filter(Boolean).join("<br>");
    tip.style.left = Math.min(e.clientX + 14, innerWidth - 190) + "px";
    tip.style.top = e.clientY - 10 + "px"; tip.style.opacity = "1";
  });
  svg.querySelector(".hit").addEventListener("mouseleave", () => {
    tip.style.opacity = "0"; cross.setAttribute("opacity", "0");
  });
}

/* smartsymbol is a CATEGORICAL code, not a magnitude — code 134 is not "more"
   than code 1, so a line chart of it would be meaningless. Rendered as an
   inventory instead, which is the actual question: which icons need drawing?
   Night variants are the day code + 100. Labels below cover only the codes
   confirmed in FMI's published symbol set; anything else is flagged rather than
   guessed, because a wrong icon is worse than an unknown one. */
const SYMBOL_LABELS = {
  1: "Clear", 2: "Partly cloudy", 3: "Cloudy",
  21: "Light showers", 22: "Moderate showers", 23: "Heavy showers",
  31: "Light rain", 32: "Moderate rain", 33: "Heavy rain",
  41: "Light snow showers", 42: "Moderate snow showers", 43: "Heavy snow showers",
  51: "Light snowfall", 52: "Moderate snowfall", 53: "Heavy snowfall",
  61: "Thundershowers", 62: "Heavy thundershowers", 63: "Thunder", 64: "Heavy thunder",
  71: "Light sleet showers", 72: "Moderate sleet showers", 73: "Heavy sleet showers",
};

function drawSymbols(fig, rows) {
  const counts = new Map();
  for (const r of rows) {
    const code = r.smartsymbol;
    if (code === null || code === undefined) continue;
    counts.set(code, (counts.get(code) || 0) + 1);
  }
  if (!counts.size) {
    fig.querySelector(".plot").innerHTML = '<p class="msg">No symbols in this range.</p>';
    return;
  }
  const total = [...counts.values()].reduce((a, b) => a + b, 0);
  const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1]);
  const unmapped = [];
  const rowsHtml = sorted.map(([code, n]) => {
    const night = code > 100;
    const day = night ? code - 100 : code;
    const label = SYMBOL_LABELS[day];
    if (!label) unmapped.push(code);
    const pct = Math.round((n / total) * 100);
    return `<tr>
      <td style="font-variant-numeric:tabular-nums"><b>${code}</b></td>
      <td>${label ? label : '<span style="color:var(--s2)">unmapped — look up</span>'}</td>
      <td style="color:var(--muted)">${night ? "night" : "day"}</td>
      <td style="font-variant-numeric:tabular-nums">${n}</td>
      <td><span style="display:inline-block;height:8px;border-radius:2px;background:var(--s1);width:${Math.max(2, pct * 2)}px"></span>
          <span style="color:var(--muted);font-size:.75rem"> ${pct}%</span></td>
    </tr>`;
  }).join("");
  fig.querySelector(".plot").innerHTML = `
    <table style="width:100%;border-collapse:collapse;font-size:.85rem">
      <thead><tr style="color:var(--muted);font-size:.7rem;text-transform:uppercase;letter-spacing:.04em;text-align:left">
        <th>Code</th><th>Meaning</th><th></th><th>Count</th><th>Share</th></tr></thead>
      <tbody>${rowsHtml}</tbody>
    </table>`;
  const stats = fig.querySelector(".stats");
  if (stats) {
    stats.innerHTML = `<div><span>Distinct codes</span><b>${counts.size}</b>
        over ${total} forecast points</div>` +
      (unmapped.length
        ? `<div><span style="color:var(--s2)">Needs lookup</span><b>${unmapped.length}</b>
             ${unmapped.join(", ")} — icons can't be drawn without these</div>`
        : `<div><span>Coverage</span><b>complete</b> every code has a label</div>`);
  }
}

async function load() {
  const cfg = { station: $("#station").value, buoy: $("#buoy").value,
                place: $("#place").value.trim(), start: $("#start").value, end: $("#end").value };
  const host = $("#charts"); host.innerHTML = "";
  for (const c of CHARTS) {
    if (c.group) {
      const h = document.createElement("h2");
      h.textContent = c.group;
      h.className = "group";
      host.appendChild(h);
    }
    const fig = document.createElement("figure");
    fig.innerHTML = `<figcaption>${c.title}</figcaption><p class="q">${c.q}</p>
      <div class="legend">${c.series.map((s, i) => `<span><i style="background:${COLORS[i]}"></i>${s.label}</span>`).join("")}</div>
      <div class="plot"><p class="msg">Loading…</p></div>
      <div class="stats"></div>
      <details><summary>Raw JSON</summary><pre></pre></details>`;
    host.appendChild(fig);
    try {
      let rows;
      let from = cfg.start, to = cfg.end;
      if (c.forecast) {
        // Forecasts are forward-looking; the date pickers select history.
        const now = new Date();
        from = now.toISOString().slice(0, 10);
        to = new Date(now.getTime() + 10 * 864e5).toISOString().slice(0, 10);
      }
      if (c.buoy) {
        // Buoy observations are WFS-only — the JSON timeseries endpoint returns
        // all-null rows for WaveHs rather than an error (RESEARCH.md §4).
        const r = await fetch(`/v1/buoy-series?fmisid=${cfg.buoy}` +
                              `&start=${cfg.start}T00:00:00Z&end=${cfg.end}T00:00:00Z`);
        if (!r.ok) throw new Error((await r.json()).detail || r.statusText);
        rows = (await r.json()).rows.map((x) => ({ ...x, epochtime: Date.parse(x.time) / 1000 }));
      } else if (c.ice) {
        // Ice has no JSON producer at all — WFS only (RESEARCH.md §18).
        const r = await fetch(`/v1/ice-series?place=${encodeURIComponent(cfg.place)}` +
                              `&start=${cfg.start}T00:00:00Z&end=${cfg.end}T00:00:00Z`);
        if (!r.ok) throw new Error((await r.json()).detail || r.statusText);
        rows = (await r.json()).rows.map((x) => ({ ...x, epochtime: Date.parse(x.time) / 1000 }));
      } else {
      const primary = await fetchSeries(c.source(cfg), from, to);
      rows = primary.rows;
      if (c.extra) {
        const second = await fetchSeries(c.extra(cfg), from, to);
        const byTime = new Map(second.rows.map((r) => [r.epochtime, r.temperature]));
        rows = rows.map((r) => ({ ...r, temperature2: byTime.get(r.epochtime) ?? null }));
      }
      }
      fig.querySelector("pre").textContent = JSON.stringify(rows.slice(0, 40), null, 1);
      if (c.symbols) drawSymbols(fig, rows); else draw(fig, rows, c.series);
    } catch (err) {
      fig.querySelector(".plot").innerHTML = `<p class="msg">${err.message}</p>`;
    }
  }
}

(async function init() {
  const reg = await (await fetch("/v1/buoys")).json();
  $("#station").innerHTML = reg.marine_stations.map((s) =>
    `<option value="${s.fmisid}"${s.fmisid === 100996 ? " selected" : ""}>${s.name}</option>`).join("");
  $("#buoy").innerHTML = reg.wave_buoys.map((s) =>
    `<option value="${s.fmisid}"${s.fmisid === 103976 ? " selected" : ""}>${s.name}</option>`).join("");
  const now = new Date();
  $("#end").value = iso(new Date(now.getTime() + 864e5));
  $("#start").value = iso(new Date(now.getTime() - 3 * 864e5));
  $("#go").addEventListener("click", load);
  document.querySelectorAll(".presets button").forEach((b) => b.addEventListener("click", () => {
    if (b.dataset.range) { const [a, z] = b.dataset.range.split(","); $("#start").value = a; $("#end").value = z; }
    else { const d = +b.dataset.days;
      $("#end").value = iso(new Date(Date.now() + 864e5));
      $("#start").value = iso(new Date(Date.now() - d * 864e5)); }
    load();
  }));
  load();
})();
