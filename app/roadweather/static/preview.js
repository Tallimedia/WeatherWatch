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
let data = { road: null, obs: null, fc: null, error: null };

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
}

async function load(lat, lon) {
  data = { road: null, obs: null, fc: null, error: null };
  $("#status").textContent = "fetching…";
  render();
  const get = (p) => fetch(p).then((r) => r.ok ? r.json() : Promise.reject(r.status));
  try {
    // Each source may be absent without the others failing — the same way the
    // app degrades, so the preview shows the real degraded states too.
    const [road, obs, fc] = await Promise.allSettled([
      get(`/v1/road?lat=${lat}&lon=${lon}`),
      get(`/v1/observations?lat=${lat}&lon=${lon}`),
      get(`/v1/forecast?lat=${lat}&lon=${lon}&hours=21&step=180`),
    ]);
    data.road = road.status === "fulfilled" ? road.value : null;
    data.obs = obs.status === "fulfilled" ? obs.value : null;
    data.fc = fc.status === "fulfilled" ? (fc.value.points || []) : [];
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
