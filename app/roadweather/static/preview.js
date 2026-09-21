/* Design preview for the car app.
 *
 * Renders the tabs the Kotlin app renders, from the same live endpoints,
 * inside a frame the size of the XC60's screen. The point is to judge a layout
 * before building it in Kotlin, where every change costs a build, an emulator
 * boot and a reinstall.
 *
 * The hard rule: draw only what a Car App Library template can produce.
 * Checked against the 1.7.0 AAR rather than from memory:
 *
 *   - A tab holds ONE template. Rows and tiles cannot share a tab unless it is
 *     a SectionedItemTemplate, which 1.7.0 still marks @ExperimentalCarApi.
 *     Hence the Now: rows / tiles switch — "tiles" is the experimental path.
 *   - A Row is an optional icon, a title and at most TWO secondary lines
 *     (RowConstraints.ROW_CONSTRAINTS_SIMPLE → maxTextLinesPerRow = 2).
 *   - A GridItem is an image, a title and exactly ONE text line. That is why
 *     putting the two Now readings side by side costs the wind line.
 *   - Six items is the safe list budget while moving, so every tab is built to
 *     six rows, section headers excluded.
 *
 * `symbolInfo` and `icon` come from /web/common.js — the same smartsymbol
 * mapping the weather page uses, including the +100 night rule.
 */

const PLACES = [
  ["Helsinki", 60.1699, 24.9384],
  ["Espoo", 60.2055, 24.6559],
  ["Tampere", 61.4978, 23.7610],
  ["Jyväskylä", 62.2426, 25.7473],
  ["Oulu", 65.0121, 25.4651],
  ["Rovaniemi", 66.5039, 25.7294],
  ["Utsjoki", 69.9080, 27.0290],
];

let tab = "weather";     // Nico 2026-09-22: the car should open on Weather.
let nowStyle = "rows";   // "rows" (stable) | "tiles" (experimental API)
let data = { road: null, obs: null, fc: null, raw: null, error: null };

const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? "").replace(/[<>&]/g, (c) => ({ "<": "&lt;", ">": "&gt;", "&": "&amp;" }[c]));
const t1 = (v, u = "") => (v === null || v === undefined ? "–" : `${v.toFixed(1)}${u}`);
const t0 = (v, u = "") => (v === null || v === undefined ? "–" : `${Math.round(v)}${u}`);

/* Finnish weather, so Finnish local time regardless of where the viewer sits. */
const hhmm = (epoch) =>
  new Date(epoch * 1000).toLocaleTimeString("fi-FI",
    { hour: "2-digit", minute: "2-digit", timeZone: "Europe/Helsinki" });

function age(seconds) {
  if (seconds === null || seconds === undefined) return "";
  return seconds < 90 ? "just now" : `${Math.round(seconds / 60)} min ago`;
}

/* Digitraffic returns SCREAMING_SNAKE. Unknown states are title-cased rather
   than dropped — winter will bring several this code has never seen. */
const HUMAN = {
  DRY: "Dry", MOIST: "Moist", WET: "Wet", SLUSHY: "Slushy", SNOWY: "Snowy",
  ICY: "Icy", PARTLY_ICY: "Icy", FROSTY: "Frosty",
  NORMAL_CONDITION: "Normal", POOR_CONDITION: "Poor",
  EXTREMELY_POOR_CONDITION: "Very poor",
};
const human = (raw) => raw == null ? "–" : (HUMAN[raw] ||
  raw.split("_").map((w) => w[0] + w.slice(1).toLowerCase()).join(" "));

const RISK = {
  high: ["Frost or black ice", "warnc"],
  moderate: ["Road may be icy", "cautionc"],
  low: ["Road near freezing", "cautionc"],
  none: ["No ice risk", ""],
  unknown: ["Ice risk unknown — no road sensor nearby", "dimc"],
};

/* The station ids are machine names. A driver reads the road number. */
const prettyStation = (raw) =>
  String(raw ?? "").replace(/_/g, " ").replace(/^([a-z]{1,2})(\d+)/, (m, p, n) =>
    p[0].toUpperCase() + p.slice(1) + " " + n);

function row(title, lines, iconHtml, cls = "") {
  const body = [`<div class="t ${cls}">${title}</div>`]
    .concat(lines.filter(Boolean).slice(0, 2).map((l) => `<div class="s">${l}</div>`)).join("");
  return `<div class="row">${iconHtml ? `<div class="ic">${iconHtml}</div>` : ""}
    <div class="body">${body}</div></div>`;
}

const sec = (label) => `<div class="sec">${esc(label)}</div>`;

/* ------------------------------------------------------------------ Road */

/* Every row here answers "what is this number" in its own second line, or
   under a section header that explains the group. Nico 2026-09-22: the data
   was right but unexplained. */
function roadScreen() {
  const r = data.road;
  if (!r) return `<p class="msg">No road data for this location.</p>`;
  const s = r.surface || {};
  const st = r.station || {};
  const [riskText, riskCls] = RISK[r.ice_risk?.level] || RISK.unknown;

  let html = sec("Road surface now — measured on the road, not the air");

  const margin = st.dew_point_margin_c != null ? st.dew_point_margin_c
    : (s.road_temp_c != null && s.dew_point_c != null ? s.road_temp_c - s.dew_point_c : null);

  html += row(s.road_temp_c != null ? t1(s.road_temp_c, " °C") : "No surface reading",
    [`<span class="${riskCls}">${esc(riskText)}</span>`,
     [st.condition ? `Surface ${esc(st.condition.toLowerCase())}` : null,
      `air ${t1(s.air_temp_c, " °C")}`].filter(Boolean).join(" · ")], null);

  html += row(st.freezing_point_c != null
      ? `Freezes at ${t1(st.freezing_point_c, " °C")}` : "Freezing point unknown",
    [st.salt_g_m2 != null ? `Salt on the surface now: ${t1(st.salt_g_m2)} g/m²` : null,
     margin != null ? dewLine(margin) : "Dew point margin unavailable"], null);

  html += row(esc(prettyStation(st.name || s.station) || "No road sensor nearby"),
    [["Nearest road sensor",
      (st.distance_km ?? s.distance_km) != null
        ? `${(st.distance_km ?? s.distance_km).toFixed(1)} km away` : null,
      age(s.age_seconds)].filter(Boolean).join(" · ")], null);

  const out = (r.section?.outlook || []).slice(0, 3);
  if (out.length) {
    html += sec(`Next hours on ${r.section.description || "this road"}`);
    out.forEach((o) => {
      const when = !o.at ? "Later" : o.at === "0h" ? "Now" : `In ${o.at.replace("h", " h")}`;
      const state = human(o.surface || o.road_condition);
      const overall = o.road_condition && o.road_condition !== "NORMAL_CONDITION"
        ? ` · driving ${human(o.road_condition).toLowerCase()}` : "";
      html += row(`${when}&nbsp;&nbsp;&nbsp;${t1(o.road_temp_c, " °C")}`,
        [`${esc(state)}${overall}`,
         o.reliability === "SUCCESSFUL" ? null : "Estimated — no sensor on this stretch"],
        null);
    });
  }
  return html;
}

/* --------------------------------------------------------------- Weather */

/* Nico 2026-09-22: weather now and the road now, together, then the hours
   ahead with temperature, wind and rain. */
function weatherScreen() {
  const o = data.obs;
  if (!o) return `<p class="msg">No observation for this location.</p>`;

  const pts = data.fc || [];
  const now = pts[0];
  const sym = typeof symbolInfo === "function" ? symbolInfo(now?.smartsymbol) : null;
  const cond = now?.smartsymboltext
    ? now.smartsymboltext.replace(/^./, (m) => m.toUpperCase()) : "–";
  const rain = now?.pop == null ? null : `rain ${Math.round(now.pop)} %`;

  const r = data.road, s = r?.surface || {}, st = r?.station || {};
  const [riskText, riskCls] = RISK[r?.ice_risk?.level] || RISK.unknown;
  const roadState = st.condition ? esc(st.condition) : "–";

  let html = sec("Now, where you are");

  if (nowStyle === "tiles") {
    // GridItem = image + title + ONE text line, so the wind has to go.
    html += `<div class="grid grid2">
      <div class="cell">${sym ? icon(sym.c, sym.night, 72) : ""}
        <div class="v big">${t1(o.temperature, " °C")}</div>
        <div class="p dim">${esc(cond)}${rain ? " · " + rain : ""}</div></div>
      <div class="cell">${roadTile()}
        <div class="v big">${s.road_temp_c != null ? t1(s.road_temp_c, " °C") : "Road"}</div>
        <div class="p ${s.road_temp_c != null ? (riskCls || "dim") : "dim"}">${
          s.road_temp_c != null ? `${roadState} · ${esc(riskText.toLowerCase())}`
                                : "No sensor within reach"}</div></div>
    </div>`;
  } else {
    html += row(t1(o.temperature, " °C"),
      [[esc(cond), rain].filter(Boolean).join(" · "), windLine(o)],
      sym ? icon(sym.c, sym.night, 62) : "");
    const where = [prettyStation(st.name || s.station),
      (st.distance_km ?? s.distance_km) != null
        ? `${(st.distance_km ?? s.distance_km).toFixed(1)} km` : null]
      .filter(Boolean).join(" · ");
    html += row(
      s.road_temp_c != null ? `Road ${t1(s.road_temp_c, " °C")}` : "Road surface unknown",
      [s.road_temp_c != null
        ? `${roadState} · <span class="${riskCls}">${esc(riskText.toLowerCase())}</span>`
        : `<span class="dimc">No road sensor within reach</span>`,
       // Naming a sensor that reported nothing only invites the question.
       (s.road_temp_c != null || st.condition) ? (where || null) : null],
      roadTile(56));
  }

  // points[0] is the current hour, so the outlook starts at [1]. Three-hour
  // steps: four rows reach 12 h, six tiles reach 18 h.
  const ahead = pts.slice(1, nowStyle === "tiles" ? 7 : 5);
  if (ahead.length) {
    html += sec("Next 12 hours");
    ahead.forEach((p) => {
      const i = typeof symbolInfo === "function" ? symbolInfo(p.smartsymbol) : null;
      const text = p.smartsymboltext
        ? p.smartsymboltext.replace(/^./, (m) => m.toUpperCase()) : "–";
      html += row(`${hhmm(p.epochtime)}&nbsp;&nbsp;&nbsp;${t0(p.temperature, " °C")}`,
        [esc(text),
         `${esc(p.windcompass8 || "")} ${t0(p.windspeedms)} m/s` +
         (p.pop == null ? "" : ` · rain ${Math.round(p.pop)} %`) +
         (p.precipitation1h ? ` · ${p.precipitation1h.toFixed(1)} mm` : "")],
        i ? icon(i.c, i.night, 40) : "");
    });
  }
  return html;
}

/* The margin goes negative, and Utsjoki was already at -0.1 in September.
   "-0.1 °C above the dew point" is the wrong way round, and this is the one
   number on the tab that says whether frost is forming right now. */
function dewLine(margin) {
  if (margin < 0) {
    return `<span class="cautionc">${t1(-margin, " °C")} below the dew point` +
           ` — moisture condensing on the surface</span>`;
  }
  return `${t1(margin, " °C")} above the dew point — frost forms at 0`;
}

/* Wind is optional in an FMI observation — Utsjoki reports none. */
function windLine(o) {
  if (o.windspeedms == null) return `<span class="dimc">Wind not reported here</span>`;
  const gust = o.windgust == null ? "" : ` · gust ${t1(o.windgust)}`;
  return `Wind ${esc(o.windcompass8 || "")} ${t1(o.windspeedms)} m/s${gust}`;
}

/* A road-surface glyph, so the road reading is not mistaken for an air one. */
const roadTile = (px = 72) => `<svg class="rt" width="${px}" height="${px}" viewBox="0 0 24 24"
  fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round">
  <path d="M5 21 9 3M19 21 15 3" /><path d="M12 5v3M12 11v3M12 17v3" stroke-dasharray="0" />
</svg>`;

/* ----------------------------------------------------------------- About */

/* Was four full-height rows and dominated the screen. A MessageTemplate is a
   single compact block and still carries both licences in the app, which is
   what the attribution obliges. Nico 2026-09-22. */
function aboutScreen() {
  return `<div class="mcard">
    <img src="/demo/static/icon.png" alt="">
    <div class="mtitle">Finnish RoadWeather 0.1.0</div>
    <div class="mtext">Weather and road station data: Finnish Meteorological Institute,
      CC BY 4.0. Road conditions: Source: Fintraffic / digitraffic.fi, license CC 4.0 BY.
      Independent app, not affiliated with or endorsed by either organisation.</div>
    <div class="mtext">General information only. Not a substitute for your own judgement,
      official warnings, or driving to the conditions.</div>
  </div>`;
}

/* ---------------------------------------------------------------- Render */

function render() {
  ["road", "weather", "about"].forEach((k) => {
    $("#tab-" + k).classList.toggle("sel", k === tab);
    $("#t-" + k).classList.toggle("on", k === tab);
  });
  ["rows", "tiles"].forEach((k) =>
    $("#n-" + k).classList.toggle("on", k === nowStyle));
  $("#nowhint").textContent = nowStyle === "tiles"
    ? "Side by side needs SectionedItemTemplate — @ExperimentalCarApi in 1.7.0 — and a grid tile has no room for the wind line."
    : "Stacked rows: stable API, and each row keeps two secondary lines, so wind and rain both fit.";

  const screen = $("#screen");
  if (data.error) { screen.innerHTML = `<p class="msg">${esc(data.error)}</p>`; return; }
  if (!data.road && !data.obs && tab !== "about") {
    screen.innerHTML = `<p class="msg">Loading…</p>`; return;
  }
  screen.innerHTML = tab === "road" ? roadScreen()
    : tab === "weather" ? weatherScreen() : aboutScreen();
  catalogue();
}

async function load(lat, lon) {
  data = { road: null, obs: null, fc: null, raw: null, error: null };
  $("#status").textContent = "fetching…";
  render();
  const get = (p) => fetch(p).then((r) => r.ok ? r.json() : Promise.reject(r.status));
  try {
    // Each source may be absent without the others failing — the same way the
    // app degrades, so the preview shows the real degraded states too.
    const [road, obs, fc, raw] = await Promise.allSettled([
      get(`/v1/road?lat=${lat}&lon=${lon}`),
      get(`/v1/observations?lat=${lat}&lon=${lon}`),
      get(`/v1/forecast?lat=${lat}&lon=${lon}&hours=21&step=180`),
      // Not an app endpoint: the raw field catalogue under the mockup.
      get(`/demo/fields?lat=${lat}&lon=${lon}`),
    ]);
    data.road = road.status === "fulfilled" ? road.value : null;
    data.obs = obs.status === "fulfilled" ? obs.value : null;
    data.fc = fc.status === "fulfilled" ? (fc.value.points || []) : [];
    data.raw = raw.status === "fulfilled" ? raw.value : null;
    if (!data.road && !data.obs) data.error = "No data for this location.";
    $("#status").textContent = "live data · " +
      new Date().toLocaleTimeString("fi-FI", { timeZone: "Europe/Helsinki" });
  } catch (e) {
    data.error = "Could not reach the backend.";
    $("#status").textContent = "";
  }
  render();
}

function init() {
  const sel = $("#place");
  PLACES.forEach(([name], i) => {
    const o = document.createElement("option");
    o.value = i; o.textContent = name; sel.appendChild(o);
  });
  sel.addEventListener("change", () => {
    const [, lat, lon] = PLACES[sel.value]; load(lat, lon);
  });
  ["road", "weather", "about"].forEach((k) => {
    const go = () => { tab = k; render(); };
    $("#t-" + k).addEventListener("click", go);
    $("#tab-" + k).addEventListener("click", go);
  });
  ["rows", "tiles"].forEach((k) =>
    $("#n-" + k).addEventListener("click", () => { nowStyle = k; tab = "weather"; render(); }));
  load(PLACES[0][1], PLACES[0][2]);
}

document.addEventListener("DOMContentLoaded", init);

/* ===================================================================== */
/* The data catalogue: everything the sources hold, not just what is drawn.
 *
 * Nico 2026-09-22: "print all possible data fields ... maybe I can view what
 * is possible to get from the data and feedback what I might want". So this
 * is generated from the live responses rather than hand-listed — a written
 * list would be wrong within a month, and being wrong here would rule out a
 * field that actually exists.
 */

/* Digitraffic name their sensors in Finnish with no unit on half of them.
   Base name after stripping the 1/2 sensor-pair suffix. */
const SENSOR_EN = {
  ILMA: "Air temperature",
  ILMAN_KOSTEUS: "Air humidity",
  "ILMAN_LÄMPÖTILA_24H_MAX": "Air temperature, 24 h maximum",
  "ILMAN_LÄMPÖTILA_24H_MIN": "Air temperature, 24 h minimum",
  ILMA_DERIVAATTA: "Air temperature trend",
  "JÄÄN_MÄÄRÄ": "Ice on the surface",
  "JÄÄTYMISPISTE": "Freezing point of the surface solution",
  KASTEPISTE: "Dew point",
  KASTEPISTE_ERO_ILMA: "Dew point margin to the air",
  KASTEPISTE_ERO_TIE: "Dew point margin to the road surface",
  KELI: "Road condition, categorical",
  KESKITUULI: "Mean wind",
  KITKA: "Friction coefficient",
  KITKA_LUKU: "Friction coefficient, reading",
  "KOSTEUDEN_MÄÄRÄ": "Moisture on the surface",
  KUURAPISTE: "Frost point",
  KUURAPISTE_ERO_ILMA: "Frost point margin to the air",
  KUURAPISTE_ERO_TIE: "Frost point margin to the road surface",
  "LUMEN_MÄÄRÄ": "Snow on the surface",
  MAA: "Ground temperature",
  MAKSIMITUULI: "Maximum wind",
  "NÄKYVYYS_KM": "Visibility",
  "NÄKYVYYS_M": "Visibility",
  OPTISEN_ANTURIN_KELI: "Road condition, optical sensor",
  SADE: "Precipitation, categorical",
  SADESUMMA: "Precipitation total",
  SADESUMMA_LIUKUVA_24H: "Precipitation, rolling 24 h",
  SADE_INTENSITEETTI: "Precipitation intensity",
  SADE_TILA: "Precipitation state",
  SATEEN_OLOMUOTO_PWDXX: "Precipitation form",
  "SUOLAN_MÄÄRÄ": "Salt on the surface",
  "SUOLAN_VÄKEVYYS": "Salt concentration",
  TIENPINNAN_TILA: "Road surface state",
  TIENPINNAN_TILA_OPT: "Road surface state, optical",
  TIE: "Road surface temperature",
  TIE_DERIVAATTA: "Road surface temperature trend",
  "TURVALLISUUSLÄMPÖ": "Safety temperature — freezing point of what is on the road",
  TUULENSUUNTA: "Wind direction",
  "VALLITSEVA_SÄÄ": "Prevailing weather",
  VAROITUS: "Station warning",
  "VEDEN_MÄÄRÄ": "Water film on the surface",
};

/* Instrument health and raw transducer output. Real, but not content. */
const SENSOR_DIAG = /^(ASEMAN_STATUS|DSC_|KUITUVASTE|PINTASIGNAALI|PWD_|JOHTAVUUS|JÄÄTAAJUUS|OPTISEN_ANTURIN_VAROITUS|VALOISAA|AURINKOUP)/;

/* `TIE_1`, `KITKA1`, `TIENPINNAN_TILA_OPT2` → the shared base. The probe
   number is not always last: `TIE_1_DERIVAATTA` and `KITKA1_LUKU` carry it in
   the middle, and stripping only a trailing digit dropped the road-temperature
   trend — one of the more useful readings here — into the diagnostics pile. */
const sensorBase = (n) =>
  n.replace(/_?(?:OPT)?[12](?=_|$)/g, (m) => (m.includes("OPT") ? "_OPT" : ""));

/* What the mockup draws today, so everything else reads as "available". */
const USED = {
  obs: ["stationname", "distance", "temperature", "windspeedms", "windgust",
        "windcompass8", "age_seconds"],
  fc: ["epochtime", "temperature", "smartsymbol", "smartsymboltext",
       "windspeedms", "windcompass8", "pop", "precipitation1h"],
  road: ["surface.road_temp_c", "surface.air_temp_c", "surface.dew_point_c",
         "surface.station", "surface.distance_km", "surface.age_seconds",
         "station.name", "station.distance_km", "station.condition",
         "station.freezing_point_c", "station.dew_point_margin_c",
         "station.salt_g_m2", "section.description", "section.outlook",
         "ice_risk.level", "ice_risk.reason"],
  sensors: ["KELI_1", "VAROITUS_1", "JÄÄTYMISPISTE_1", "KASTEPISTE_ERO_TIE",
            "SUOLAN_MÄÄRÄ_1"],
};

const fmt = (v) => {
  if (v === null || v === undefined) return `<span class="nul">null</span>`;
  if (Array.isArray(v)) return `<span class="nul">${v.length} ×</span>`;
  if (typeof v === "object") return `<span class="nul">{…}</span>`;
  if (typeof v === "number") return Number.isInteger(v) ? String(v) : v.toFixed(2);
  return esc(String(v));
};

const mark = (used) => used
  ? `<span class="tag on">shown</span>`
  : `<span class="tag">available</span>`;

/* Flatten one level of nesting; `at` maps are noise and are dropped. */
function flat(obj, prefix = "") {
  const out = [];
  for (const [k, v] of Object.entries(obj || {})) {
    if (k === "at") continue;
    const path = prefix ? `${prefix}.${k}` : k;
    if (v && typeof v === "object" && !Array.isArray(v)) out.push(...flat(v, path));
    else out.push([path, v]);
  }
  return out;
}

function table(rows) {
  return `<table class="cat"><tbody>${rows.map(
    ([name, value, tag, note]) => `<tr><td class="f">${esc(name)}</td>
      <td class="v">${value}</td><td class="tg">${tag || ""}</td>
      <td class="n">${note || ""}</td></tr>`).join("")}</tbody></table>`;
}

function catalogue() {
  const el = $("#fields");
  if (!el) return;
  const raw = data.raw;
  const parts = [];

  if (data.obs) {
    parts.push(`<h3>/v1/observations <span class="sub">FMI weather station</span></h3>`);
    parts.push(table(flat(data.obs).map(([k, v]) =>
      [k, fmt(v), mark(USED.obs.includes(k.split(".").pop()))])));
  }

  const pt = (data.fc || [])[0];
  if (pt) {
    parts.push(`<h3>/v1/forecast <span class="sub">per point · ${
      (data.fc || []).length} points served</span></h3>`);
    parts.push(table(flat(pt).map(([k, v]) => [k, fmt(v), mark(USED.fc.includes(k))])));
  }

  if (data.road) {
    parts.push(`<h3>/v1/road <span class="sub">merged FMI + Fintraffic</span></h3>`);
    const rows = flat(data.road).map(([k, v]) =>
      [k, fmt(v), mark(USED.road.some((u) => k === u || k.startsWith(u + ".")))]);
    // The outlook is an array, so it flattens to "5 ×" and its own fields
    // would go unlisted — which is exactly where the unused ones are.
    const out0 = (data.road.section?.outlook || [])[0];
    if (out0) {
      const usedInOutlook = ["at", "road_temp_c", "surface", "road_condition", "reliability"];
      rows.push(...Object.entries(out0).map(([k, v]) =>
        [`section.outlook[].${k}`, fmt(v), mark(usedInOutlook.includes(k))]));
    }
    parts.push(table(rows));
  }

  if (raw) {
    const good = [], diag = [];
    for (const s of raw.digitraffic_sensors || []) {
      const base = sensorBase(s.name);
      const en = SENSOR_EN[base];
      const unit = s.unit && !/^[?*/#]+$/.test(s.unit) ? ` ${s.unit}` : "";
      const row = [s.name, fmt(s.value) + unit,
                   mark(USED.sensors.includes(s.name)),
                   esc(s.description ? `${en || base} — ${s.description}` : (en || ""))];
      (SENSOR_DIAG.test(s.name) || !en ? diag : good).push(row);
    }
    if (good.length) {
      parts.push(`<h3>Digitraffic station sensors <span class="sub">${
        esc(raw.digitraffic_station?.name || "")} · ${good.length} with meaning, ${
        diag.length} instrument diagnostics</span></h3>`);
      parts.push(`<p class="note">This is the interesting list. <strong>Friction</strong>
        (<code>KITKA</code>, µ) is measured and unused; FMI's own <code>friction</code>
        parameter is one of the dead ones below. So are the <strong>trends</strong>
        (<code>_DERIVAATTA</code>, °C/h) — a road at +1 and falling is a different
        drive from a road at +1 and rising — and the separate <strong>frost point</strong>
        (<code>KUURAPISTE</code>), which is not the dew point below zero. Sensors ending
        1 and 2 are two probes on the same gantry, usually different lanes.</p>`);
      parts.push(table(good));
    }
    if (diag.length) {
      parts.push(`<details><summary>${diag.length} instrument diagnostics — station
        health and raw transducer output</summary>${table(diag)}</details>`);
    }

    const fr = Object.entries(raw.fmi_road || {});
    if (fr.length) {
      parts.push(`<h3>FMI road station <span class="sub">${
        esc(raw.fmi_road_station || "")} · every parameter the proxy requests</span></h3>`);
      parts.push(table(fr.map(([k, v]) => [k, fmt(v), mark(true)])));
    }
    if ((raw.fmi_road_never_populated || []).length) {
      parts.push(`<h3>FMI road parameters that exist but never return a value</h3>`);
      parts.push(`<p class="note">Accepted as names, <code>null</code> at every station
        tested, in July and January alike. Listed so they are not mistaken for an
        option — <code>friction</code> among them, which is exactly why the Digitraffic
        <code>KITKA</code> reading above matters.</p>`);
      parts.push(table(raw.fmi_road_never_populated.map((n) =>
        [n, `<span class="nul">always null</span>`, ""])));
    }
  } else {
    parts.push(`<p class="note">Raw sensor catalogue unavailable for this place.</p>`);
  }

  el.innerHTML = parts.join("");
}
