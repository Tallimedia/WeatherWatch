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
  { id: "wind", title: "Sea wind and gust",
    q: "How do mean and gust relate — and what gust value should the default threshold be?",
    source: (c) => ({ fmisid: c.station, producer: "opendata",
                      params: "windspeedms,windgust", step: 60 }),
    series: [ { key: "windspeedms", label: "Mean wind", unit: "m/s" },
              { key: "windgust",    label: "Gust",      unit: "m/s" } ] },

  { id: "waves", title: "Wave height at the chosen buoy",
    q: "What is a normal wave height here, and what counts as high?",
    buoy: true,
    series: [ { key: "WaveHs", label: "Significant height", unit: "m" },
              { key: "WTP",    label: "Period",             unit: "s" } ] },

  { id: "wavedir", title: "Wave direction and spread",
    q: "Does WHDD (spread) ever say anything useful, or is ModalWDi enough?",
    buoy: true,
    series: [ { key: "ModalWDi", label: "Direction (ModalWDi)", unit: "°" },
              { key: "WHDD",     label: "Spread (WHDD)",        unit: "°" } ] },

  { id: "landsea", title: "Land vs sea air temperature",
    q: "How far apart are the two stations — do they justify separate thresholds?",
    source: (c) => ({ fmisid: c.station, producer: "opendata",
                      params: "temperature", step: 60 }),
    extra:  (c) => ({ place: c.place, producer: "opendata",
                      params: "temperature", step: 60 }),
    series: [ { key: "temperature",  label: "Sea station", unit: "°C" },
              { key: "temperature2", label: "Land place",  unit: "°C" } ] },

  { id: "water", title: "Sea water temperature",
    q: "Does the buoy's water temperature earn a line on the watch?",
    buoy: true,
    series: [ { key: "TWATER", label: "Water", unit: "°C" } ] },

  { id: "ice", title: "Sea ice thickness (winter only)",
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

function draw(fig, rows, series) {
  const pts = series.map((s) =>
    rows.map((r) => ({ t: r.epochtime, v: r[s.key] })).filter((d) => d.v !== null && d.v !== undefined)
  );
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
  fig.querySelector(".stats").innerHTML = series.map((s, i) => {
    const p = pts[i]; if (!p.length) return "";
    const vals = p.map((d) => d.v).sort((a, b) => a - b);
    const q = (f) => vals[Math.floor((vals.length - 1) * f)];
    return `<div><span style="color:${COLORS[i]}">${s.label}</span>
      <b>${fmt(vals[vals.length - 1])} ${s.unit}</b>
      min ${fmt(vals[0])} · median ${fmt(q(0.5))} · p90 ${fmt(q(0.9))} · max ${fmt(vals[vals.length - 1])}</div>`;
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

async function load() {
  const cfg = { station: $("#station").value, buoy: $("#buoy").value,
                place: $("#place").value.trim(), start: $("#start").value, end: $("#end").value };
  const host = $("#charts"); host.innerHTML = "";
  for (const c of CHARTS) {
    const fig = document.createElement("figure");
    fig.innerHTML = `<figcaption>${c.title}</figcaption><p class="q">${c.q}</p>
      <div class="legend">${c.series.map((s, i) => `<span><i style="background:${COLORS[i]}"></i>${s.label}</span>`).join("")}</div>
      <div class="plot"><p class="msg">Loading…</p></div>
      <div class="stats"></div>
      <details><summary>Raw JSON</summary><pre></pre></details>`;
    host.appendChild(fig);
    try {
      let rows;
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
      const primary = await fetchSeries(c.source(cfg), cfg.start, cfg.end);
      rows = primary.rows;
      if (c.extra) {
        const second = await fetchSeries(c.extra(cfg), cfg.start, cfg.end);
        const byTime = new Map(second.rows.map((r) => [r.epochtime, r.temperature]));
        rows = rows.map((r) => ({ ...r, temperature2: byTime.get(r.epochtime) ?? null }));
      }
      }
      fig.querySelector("pre").textContent = JSON.stringify(rows.slice(0, 40), null, 1);
      draw(fig, rows, c.series);
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
