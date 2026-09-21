/* Design preview for the car app.
 *
 * Renders the same three tabs the Kotlin app renders, from the same live
 * endpoints, inside a frame the size of the XC60's screen. The point is to
 * judge a layout before building it in Kotlin, where every change costs a
 * build, an emulator boot and a reinstall.
 *
 * The hard rule: draw only what a Car App Library template can produce. Rows
 * with a title and up to two secondary lines, grid tiles with an image and a
 * label, section headers, and roughly six items per list. A prettier mockup
 * than the templates allow would get approved and then be unbuildable.
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

let tab = "road";
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
  return seconds < 90 ? "just now" : `${Math.round(seconds / 60)} min`;
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
  low: ["Road near freezing", ""],
  none: ["No ice risk", ""],
  unknown: ["Ice risk unknown — no road sensor nearby", "dimc"],
};

function row(title, lines, iconHtml, cls = "") {
  const body = [`<div class="t ${cls}">${title}</div>`]
    .concat(lines.filter(Boolean).map((l) => `<div class="s">${l}</div>`)).join("");
  return `<div class="row">${iconHtml ? `<div class="ic">${iconHtml}</div>` : ""}
    <div class="body">${body}</div></div>`;
}

function roadScreen() {
  const r = data.road;
  if (!r) return `<p class="msg">No road data for this location.</p>`;
  const s = r.surface || {};
  const [riskText, riskCls] = RISK[r.ice_risk?.level] || RISK.unknown;

  let html = `<div class="sec">Now</div>`;
  html += row(t1(s.road_temp_c, " °C"),
    [`<span class="${riskCls}">${esc(riskText)}</span>`, "Road surface"], null);
  html += row(esc(r.station?.condition || "unavailable"),
    [`Air ${t1(s.air_temp_c, " °C")} · Dew point ${t1(s.dew_point_c, " °C")}`], null);
  if (s.station) {
    html += row(esc(s.station),
      [[s.distance_km != null ? `${s.distance_km.toFixed(1)} km` : null, age(s.age_seconds)]
        .filter(Boolean).join(" · ")], null);
  }

  const out = (r.section?.outlook || []).slice(0, 3);
  if (out.length) {
    html += `<div class="sec">${esc(r.section.description || "Outlook")}</div>`;
    out.forEach((o) => {
      html += row(`${esc(o.at || "")}&nbsp;&nbsp;&nbsp;${t1(o.road_temp_c, " °C")}`,
        [human(o.surface || o.road_condition),
         o.reliability === "SUCCESSFUL" ? null : "· forecast not backed by a road station"],
        null);
    });
  }
  return html;
}

function weatherScreen() {
  const o = data.obs, fc = (data.fc || []).slice(0, 6);
  if (!o) return `<p class="msg">No observation for this location.</p>`;
  const first = fc[0];
  const sym = typeof symbolInfo === "function" ? symbolInfo(first?.smartsymbol) : null;
  const big = sym ? icon(sym.c, sym.night, 76) : "";
  const cond = first?.smartsymboltext
    ? first.smartsymboltext.replace(/^./, (m) => m.toUpperCase()) : "–";

  let html = row(t1(o.temperature, " °C"),
    [esc(cond),
     `${esc(o.windcompass8 || "")} ${t1(o.windspeedms)} m/s · gust ${t1(o.windgust)}`],
    big);
  html += row(esc(o.stationname || "–"),
    [[o.distance != null ? `${o.distance.toFixed(1)} km` : null, age(o.age_seconds)]
      .filter(Boolean).join(" · ")], null);

  if (fc.length) {
    html += `<div class="sec">Next hours</div><div class="grid">`;
    fc.forEach((p) => {
      const i = typeof symbolInfo === "function" ? symbolInfo(p.smartsymbol) : null;
      html += `<div class="cell">
        <div class="h">${hhmm(p.epochtime)}</div>
        ${i ? icon(i.c, i.night, 46) : ""}
        <div class="v">${t0(p.temperature, "°")}</div>
        <div class="p">${p.pop == null ? "" : Math.round(p.pop) + "%"}</div>
      </div>`;
    });
    html += `</div>`;
  }
  return html;
}

function aboutScreen() {
  return row("Finnish RoadWeather", ["0.1.0"], null) +
    row("Data", ["Weather and road station data: Finnish Meteorological Institute, " +
      "CC BY 4.0. Road conditions: Source: Fintraffic / digitraffic.fi, license CC 4.0 BY."], null) +
    row("—", ["Independent app, not affiliated with or endorsed by either organisation."], null) +
    row("—", ["General information only. Not a substitute for your own judgement, " +
      "official warnings, or driving to the conditions."], null);
}

function render() {
  ["road", "weather", "about"].forEach((k) => {
    $("#tab-" + k).classList.toggle("sel", k === tab);
    $("#t-" + k).classList.toggle("on", k === tab);
  });
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
      get(`/v1/forecast?lat=${lat}&lon=${lon}&hours=18`),
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
  load(PLACES[0][1], PLACES[0][2]);
}

document.addEventListener("DOMContentLoaded", init);
