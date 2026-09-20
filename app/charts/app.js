/* Charts for the FIWeatherWatch data explorer.
   Hand-rolled SVG line charts: the data is small, and a dependency-free page
   keeps the prototype deployable anywhere without a build step. */

/* Rainfall reads as a daily total on the watch, not mm/h (§20), so hourly rows
   are summed per Finnish calendar day before plotting. */
const _day = new Intl.DateTimeFormat("en-CA", { timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit" });
function toDaily(rows, key) {
  const sums = new Map();
  for (const r of rows) {
    if (r[key] === null || r[key] === undefined) continue;
    const d = _day.format(new Date(r.epochtime * 1000));
    const cur = sums.get(d) || { epochtime: null, v: 0 };
    cur.v += r[key];
    if (cur.epochtime === null) cur.epochtime = r.epochtime;
    sums.set(d, cur);
  }
  return [...sums.values()].map((x) => ({ epochtime: x.epochtime, [key]: Math.round(x.v * 10) / 10 }));
}

/* Default thresholds from §20 — drawn as a reference line so the chart shows how
   often the limit is actually crossed, which is the point of choosing one. */
const THRESHOLDS = {
  windspeedms: { land: 5, sea: 10 },
  windgust:    { land: 8, sea: 15 },
  WaveHs:      { any: 1.0 },
  temperature: { cold: 0, hot: 25 },
};


const $ = (s) => document.querySelector(s);
const tip = $("#tip");
const PAD = { l: 46, r: 14, t: 10, b: 26 };
const W = 960, H = 210;

const iso = (d) => d.toISOString().slice(0, 10);

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
    daily: true,
    source: (c) => ({ place: c.place, producer: "opendata",
                      params: "precipitation1h", step: 60 }),
    series: [ { key: "precipitation1h", label: "Rain", unit: "mm/day" } ] },

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
    daily: true,
    source: (c) => ({ place: c.place, params: "precipitation1h", step: 60 }),
    series: [ { key: "precipitation1h", label: "Rain", unit: "mm/day" } ] },

  { id: "symbols", group: null, title: "Weather symbols in this forecast",
    q: "Which smartsymbol codes actually occur — i.e. which icons need drawing?",
    forecast: true, symbols: true,
    source: (c) => ({ place: c.place, params: "smartsymbol,smartsymboltext", step: 180 }),
    series: [ { key: "smartsymbol", label: "Symbol", unit: "" } ] },

  { id: "wind", group: "Sea station", title: "Sea wind and gust",
    q: "How do mean and gust relate — and what gust value should the default threshold be?",
    source: (c) => ({ fmisid: c.station, producer: "opendata",
                      params: "windspeedms,windgust", step: 60 }),
    series: [ { key: "windspeedms", label: "Mean wind", unit: "m/s" },
              { key: "windgust",    label: "Gust",      unit: "m/s" } ] },

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

/* Chart titles and the question each answers, per language. */
const CHART_TEXT = {
  landwind: { en:["Land wind and gust","The land threshold default — how much lower is it than at sea?"],
              fi:["Tuuli ja puuska maalla","Maan raja-arvon oletus — kuinka paljon merta matalampi?"],
              sv:["Vind och byar på land","Standardgränsen för land — hur mycket lägre än till havs?"] },
  landrain: { en:["Land rainfall","Does hourly precipitation carry enough signal to show on the watch?"],
              fi:["Sade maalla","Kertooko tuntisade tarpeeksi, jotta se kannattaa näyttää kellossa?"],
              sv:["Nederbörd på land","Säger timnederbörden tillräckligt för att visas på klockan?"] },
  forecast: { en:["Land forecast — next 10 days","What the watch's page 1 draws on. Forward-looking, so it ignores the date range above."],
              fi:["Ennuste — seuraavat 10 vrk","Kellon sivun 1 lähde. Katsoo eteenpäin, joten yllä oleva aikaväli ei vaikuta."],
              sv:["Prognos — nästa 10 dygn","Källan för klockans sida 1. Framåtblickande, så datumintervallet ovan gäller inte."] },
  fcrain:   { en:["Forecast rainfall — next 10 days","How far out does the forecast still show meaningful precipitation?"],
              fi:["Sade-ennuste — 10 vrk","Kuinka pitkälle ennuste näyttää vielä merkityksellistä sadetta?"],
              sv:["Nederbördsprognos — 10 dygn","Hur långt fram visar prognosen fortfarande meningsfull nederbörd?"] },
  symbols:  { en:["Weather symbols in this forecast","Which smartsymbol codes actually occur — i.e. which icons need drawing?"],
              fi:["Sääsymbolit tässä ennusteessa","Mitkä smartsymbol-koodit oikeasti esiintyvät — eli mitkä kuvakkeet tarvitaan?"],
              sv:["Vädersymboler i prognosen","Vilka smartsymbol-koder förekommer faktiskt — vilka ikoner behövs?"] },
  wind:     { en:["Sea wind and gust","How do mean and gust relate — and what gust value should the default threshold be?"],
              fi:["Tuuli ja puuska merellä","Miten keskituuli ja puuska suhteutuvat — mikä olisi puuskan oletusraja?"],
              sv:["Vind och byar till havs","Hur förhåller sig medelvind och by — vilket byvärde bör vara standardgräns?"] },
  landsea:  { en:["Land vs sea air temperature","How far apart are the two stations — do they justify separate thresholds?"],
              fi:["Ilman lämpötila maalla ja merellä","Kuinka kaukana asemat ovat toisistaan — tarvitaanko erilliset raja-arvot?"],
              sv:["Lufttemperatur land mot hav","Hur långt isär ligger stationerna — motiverar de skilda gränsvärden?"] },
  waves:    { en:["Wave height at the chosen buoy","What is a normal wave height here, and what counts as high?"],
              fi:["Aallonkorkeus valitulla poijulla","Mikä on täällä tavallinen aallonkorkeus, ja mikä on korkea?"],
              sv:["Våghöjd vid vald boj","Vad är normal våghöjd här, och vad räknas som högt?"] },
  wavedir:  { en:["Wave direction and spread","Does WHDD (spread) ever say anything useful, or is ModalWDi enough?"],
              fi:["Aallon suunta ja hajonta","Kertooko WHDD (hajonta) mitään hyödyllistä, vai riittääkö ModalWDi?"],
              sv:["Vågriktning och spridning","Säger WHDD (spridning) något nyttigt, eller räcker ModalWDi?"] },
  water:    { en:["Sea water temperature","Does the buoy's water temperature earn a line on the watch?"],
              fi:["Meriveden lämpötila","Ansaitseeko poijun veden lämpötila rivin kellossa?"],
              sv:["Havsvattnets temperatur","Förtjänar bojens vattentemperatur en rad på klockan?"] },
  ice:      { en:["Sea ice thickness (winter only)","How does ice build and decay? Weekly readings — empty outside late Nov–late Apr."],
              fi:["Merijään paksuus (vain talvella)","Miten jää kasvaa ja sulaa? Viikoittaiset havainnot — tyhjä muulloin kuin marras–huhtikuussa."],
              sv:["Havsisens tjocklek (endast vinter)","Hur byggs isen upp och bryts ner? Veckovisa mätningar — tomt utanför nov–april."] },
};
const chartText = (id) => (CHART_TEXT[id] && (CHART_TEXT[id][LANG] || CHART_TEXT[id].en)) || ["", ""];

async function fetchSeries(args, start, end) {
  const p = new URLSearchParams({ start: start + "T00:00:00Z", end: end + "T00:00:00Z" });
  for (const [k, v] of Object.entries(args)) if (v !== undefined && v !== null) p.set(k, v);
  p.set("lang", LANG);
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

function draw(fig, rows, series, chartId) {
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
      drawPanel(panel, rows, [s], [pts[i]], [COLORS[i]], chartId);
    });
    return;
  }
  drawPanel(fig, rows, series, pts, COLORS, chartId);
}

function drawPanel(fig, rows, series, pts, COLORS, chartId) {
  if (!pts.some((p) => p.length)) {
    fig.querySelector(".plot").innerHTML =
      `<p class="msg">${T("noData")}</p>`;
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
    lx.push(`<text x="${x(t)}" y="${H - 8}" text-anchor="middle" fill="var(--muted)" font-size="11">${localStamp(t)}</text>`);
  }
  // Threshold reference lines (§20): a limit is only useful if you can see how
  // often it is actually crossed.
  const marks = [];
  series.forEach((s, i) => {
    const t = THRESHOLDS[s.key];
    if (!t) return;
    const isSea = chartId === "wind" || chartId === "waves";
    const levels = s.key === "temperature"
      ? [["cold", t.cold, "var(--s1)"], ["hot", t.hot, "var(--s2)"]]
      : [[null, t.any ?? (isSea ? t.sea : t.land), COLORS[i]]];
    for (const [tag, level, colour] of levels) {
      if (level === undefined || level < v0 || level > v1) continue;
      const yy = y(level);
      const vals = pts[i].map((d) => d.v);
      const over = vals.filter((v) => v > level).length;
      const share = vals.length ? Math.round((over / vals.length) * 100) : 0;
      marks.push(`<line x1="${PAD.l}" y1="${yy}" x2="${W - PAD.r}" y2="${yy}"
          stroke="${colour}" stroke-width="1.5" stroke-dasharray="5 4" opacity="0.75"/>
        <text x="${W - PAD.r - 4}" y="${yy - 5}" text-anchor="end" fill="${colour}"
          font-size="10.5">${tag ? tag + " " : ""}${level}${s.unit ? " " + s.unit : ""} · ${tag === "cold" ? 100 - share : share}% ${tag === "cold" ? "below" : "above"}</text>`);
    }
  });

  const paths = pts.map((p, i) =>
    p.length
      ? `<path d="${p.map((d, j) => (j ? "L" : "M") + x(d.t) + " " + y(d.v)).join(" ")}" fill="none" stroke="${COLORS[i]}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"/>`
      : ""
  );
  fig.querySelector(".plot").innerHTML = `
    <svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${series.map((s) => s.label).join(", ")}">
      ${gy.join("")}${ly.join("")}${lx.join("")}${marks.join("")}
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
      ${T("latest")} · min ${fmt(vals[0])} · median ${fmt(q(0.5))} · p90 ${fmt(q(0.9))} · max ${fmt(vals[vals.length - 1])}</div>`;
  }).join("");

  const svg = fig.querySelector("svg"), cross = svg.querySelector(".cross");
  svg.querySelector(".hit").addEventListener("mousemove", (e) => {
    const box = svg.getBoundingClientRect();
    const t = t0 + ((e.clientX - box.left) / box.width * W - PAD.l) / (W - PAD.l - PAD.r) * (t1 - t0);
    cross.setAttribute("x1", x(t)); cross.setAttribute("x2", x(t)); cross.setAttribute("opacity", "1");
    const near = pts.map((p) => p.length ? p.reduce((a, b) => Math.abs(b.t - t) < Math.abs(a.t - t) ? b : a) : null);
    tip.innerHTML = `${localStamp((near.find(Boolean) || {}).t)}<br>` +
      series.map((s, i) => near[i] ? `<span style="color:${COLORS[i]}">■</span> ${s.label} <b>${fmt(near[i].v)}</b> ${s.unit}` : "").filter(Boolean).join("<br>");
    tip.style.left = Math.min(e.clientX + 14, innerWidth - 190) + "px";
    tip.style.top = e.clientY - 10 + "px"; tip.style.opacity = "1";
  });
  svg.querySelector(".hit").addEventListener("mouseleave", () => {
    tip.style.opacity = "0"; cross.setAttribute("opacity", "0");
  });
}

function drawSymbols(fig, rows) {
  const counts = new Map();
  const fmiText = new Map();   // FMI's own localised description, when present
  for (const r of rows) {
    const code = r.smartsymbol;
    if (code === null || code === undefined) continue;
    counts.set(code, (counts.get(code) || 0) + 1);
    if (r.smartsymboltext) fmiText.set(code, r.smartsymboltext);
  }
  if (!counts.size) {
    fig.querySelector(".plot").innerHTML = '<p class="msg">No symbols in this range.</p>';
    return;
  }
  const total = [...counts.values()].reduce((a, b) => a + b, 0);
  const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1]);
  const unmapped = [];
  const rowsHtml = sorted.map(([code, n]) => {
    const info = symbolInfo(code);
    const night = code > 100;
    const label = fmiText.get(code) || (info ? info.t : null);
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



async function loadWidget(cfg) {
  const host = $("#widget");
  try {
    const [obs, fc] = await Promise.all([
      fetch(`/v1/observations?place=${encodeURIComponent(cfg.place)}`).then((r) => r.json()),
      fetch(`/v1/forecast?place=${encodeURIComponent(cfg.place)}&hours=24&step=60&lang=${LANG}`)
        .then((r) => r.json()),
    ]);
    const now = Math.floor(Date.now() / 1000);
    const ahead = (fc.points || []).filter((p) => p.epochtime >= now - 1800).slice(0, 12);
    const sym = symbolInfo(ahead.length ? ahead[0].smartsymbol : null);
    const age = obs.age_seconds;
    const ageTxt = age == null ? "" :
      age < 90 ? T("justNow")
      : age < 5400 ? `${Math.round(age / 60)} ${T("minAgo")}`
      : `${Math.round(age / 3600)} ${T("hAgo")}`;

    host.innerHTML = `
      <div class="now">
        <div>${icon(sym ? sym.c : "unknown", sym ? sym.night : false, 68)}</div>
        <div>
          <div class="temp">${fmt(obs.temperature, 1)}°C</div>
          <div class="desc">${ahead.length && ahead[0].smartsymboltext
              ? ahead[0].smartsymboltext.replace(/^./, (m) => m.toUpperCase())
              : (sym ? sym.t : "—")}</div>
          <div class="where">${obs.stationname ?? "—"} · ${fmt(obs.distance, 1)} ${T("away")} ·
            ${T("measured")} ${at(obs, "temperature")} · ${ageTxt}</div>
          <div class="where">${T("retrieved")} ${obs.retrieved ? localTime(obs.retrieved) : "—"}</div>
        </div>
        <div class="facts">
          ${[["wind", fmt(obs.windspeedms, 1) + " m/s", "windspeedms", obs.windcompass8 ?? ""],
             ["gust", fmt(obs.windgust, 1) + " m/s", "windgust", ""],
             ["humidity", fmt(obs.humidity, 0) + "%", "humidity", ""],
             ["pressure", fmt(obs.pressure, 0) + " hPa", "pressure", ""]]
            .map(([k, v, field, extra]) => `<div>${T(k)}<b>${v}</b>
               <span class="at">${at(obs, field)}${extra ? " · " + extra : ""}</span></div>`).join("")}
        </div>
      </div>
      <div class="today">
        ${ahead.map((p) => {
          const i = symbolInfo(p.smartsymbol);
          return `<div class="h" title="${i ? i.t : ""}">
            <div class="t">${localHour(p.epochtime)}</div>
            ${icon(i ? i.c : "unknown", i ? i.night : false, 30)}
            <div class="v">${fmt(p.temperature, 0)}°</div>
            <div class="w">${fmt(p.windspeedms, 0)}<span style="opacity:.6">/${fmt(p.hourlymaximumgust, 0)}</span></div>
          </div>`;
        }).join("")}
      </div>`;
  } catch (err) {
    host.innerHTML = `<p class="msg">Could not load current conditions: ${err.message}</p>`;
  }
}


function applyStrings() {
  document.documentElement.lang = LANG;
  const set = (id, k) => { const e = $(id); if (e) e.textContent = T(k); };
  set("#l-lang", "language"); set("#l-place", "landPlace"); set("#l-station", "seaStation");
  set("#l-buoy", "waveBuoy"); set("#l-from", "from"); set("#l-to", "to");
  set("#go", "load"); set("#subtitle", "subtitle"); set("#foot", "foot");
  const keys = ["d3", "d14", "d60", "ice", "storm"];
  document.querySelectorAll(".presets button").forEach((b, i) => {
    if (keys[i]) b.textContent = T(keys[i]);
  });
}

async function load() {
  const cfg = { station: $("#station").value, buoy: $("#buoy").value,
                place: $("#place").value.trim(), start: $("#start").value, end: $("#end").value };
  const host = $("#charts"); host.innerHTML = "";
  loadWidget(cfg);
  for (const c of CHARTS) {
    if (c.group) {
      const h = document.createElement("h2");
      h.textContent = T({ Land: "gLand", "Sea station": "gSea",
                          "Wave buoy": "gBuoy", "Sea ice": "gIce" }[c.group]);
      h.className = "group";
      host.appendChild(h);
    }
    const fig = document.createElement("figure");
    const [title, question] = chartText(c.id);
    fig.innerHTML = `<figcaption>${title}</figcaption><p class="q">${question}</p>
      <div class="legend">${c.series.map((s, i) => `<span><i style="background:${COLORS[i]}"></i>${s.label}</span>`).join("")}</div>
      <div class="plot"><p class="msg">${T("loading")}</p></div>
      <div class="stats"></div>
      <details><summary>${T("raw")}</summary><pre></pre></details>`;
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
      if (c.daily) rows = toDaily(rows, c.series[0].key);
      fig.querySelector("pre").textContent = JSON.stringify(rows.slice(0, 40), null, 1);
      if (c.symbols) drawSymbols(fig, rows); else draw(fig, rows, c.series, c.id);
    } catch (err) {
      fig.querySelector(".plot").innerHTML = `<p class="msg">${err.message}</p>`;
    }
  }
}

(async function init() {
  const reg = await (await fetch("/v1/stations")).json();
  $("#station").innerHTML = reg.marine_stations.map((s) =>
    `<option value="${s.fmisid}"${s.fmisid === 100996 ? " selected" : ""}>${s.name}</option>`).join("");
  $("#buoy").innerHTML = reg.wave_buoys.map((s) =>
    `<option value="${s.fmisid}"${s.fmisid === 103976 ? " selected" : ""}>${s.name}</option>`).join("");
  const now = new Date();
  $("#end").value = iso(new Date(now.getTime() + 864e5));
  $("#start").value = iso(new Date(now.getTime() - 3 * 864e5));
  $("#lang").value = LANG;
  $("#lang").addEventListener("change", (e) => {
    LANG = e.target.value;
    try { localStorage.setItem("fiw-lang", LANG); } catch (_) {}
    applyStrings();
    load();
  });
  applyStrings();
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
