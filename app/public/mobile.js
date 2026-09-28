/* Nico's own mobile-first weather page. No i18n, no picker chrome beyond the
   one place field, no marketing — a personal glance page, not a product
   page. Reuses common.js (icon/fmt/dirArrow/symbolInfo/localHour/localWeekday)
   but not site.js, which carries the two-site marketing template this page
   deliberately has none of. */

const $ = (s) => document.querySelector(s);
const SEA_FMISID = 100996; // Helsinki Harmaja — same default the main site uses

async function jget(path) {
  const r = await fetch(path);
  if (!r.ok) {
    const detail = (await r.json().catch(() => ({}))).detail || r.statusText;
    const err = new Error(detail);
    err.status = r.status;
    throw err;
  }
  return r.json();
}

function ageText(seconds) {
  if (seconds === null || seconds === undefined) return "";
  if (seconds < 90) return "just now";
  if (seconds < 5400) return `${Math.round(seconds / 60)} min ago`;
  return `${Math.round(seconds / 3600)} h ago`;
}

function sampleEven(arr, n) {
  if (arr.length <= n) return arr;
  const out = [];
  for (let i = 0; i < n; i += 1) {
    out.push(arr[Math.round((i * (arr.length - 1)) / (n - 1))]);
  }
  return out;
}

const WIND_ICON = `<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor"
  stroke-width="2" stroke-linecap="round" aria-hidden="true">
  <path d="M3 8h10a3 3 0 1 0-3-3"/><path d="M3 12h14a3 3 0 1 1-3 3"/><path d="M3 16h8"/></svg>`;
const RAIN_ICON = `<svg class="ic" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
  <path d="M12 2C8 8 5 11.5 5 15a7 7 0 0 0 14 0c0-3.5-3-7-7-13z"/></svg>`;

async function loadNow(place) {
  const host = $("#now-box");
  try {
    const [obs, fc, road] = await Promise.all([
      jget(`/v1/observations?place=${encodeURIComponent(place)}`),
      jget(`/v1/forecast?place=${encodeURIComponent(place)}&hours=24&step=60&lang=en`),
      jget(`/v1/road?place=${encodeURIComponent(place)}`).catch(() => null),
    ]);
    const now = Math.floor(Date.now() / 1000);
    const todayStr = localDate(now);
    const ahead = (fc.points || [])
      .filter((p) => p.epochtime >= now - 1800 && localDate(p.epochtime) === todayStr);
    const cur = ahead[0];
    const sym = symbolInfo(cur ? cur.smartsymbol : null);
    const text = cur && cur.smartsymboltext
      ? cur.smartsymboltext.replace(/^./, (m) => m.toUpperCase()) : (sym ? sym.t : "—");
    const rainNow = cur ? cur.precipitation1h : null;
    const popNow = cur ? cur.pop : null;

    // Road box: nearest station's surface temp + freezing point, or nothing
    // if no road station/section is nearby — that is a normal answer, not an
    // error (same reasoning /v1/road's own doc comment gives).
    const rs = road && road.surface;
    const rst = road && road.station;
    const roadBlock = rs
      ? `<div class="road-row">
          <div>Road surface<b>${fmt(rs.road_temp_c, 1)}°C</b></div>
          <div>Road condition<b>${rst && !rst.condition_fault && rst.condition ? rst.condition : "—"}</b></div>
        </div>
        <div class="road-station">${rs.station ?? rst?.name ?? "—"}</div>`
      : "";

    host.innerHTML = `
      <div class="now">
        ${icon(sym ? sym.c : "unknown", sym ? sym.night : false, 56)}
        <div>
          <div class="temp">${fmt(obs.temperature, 1)}°C</div>
          <div class="desc">${text}</div>
          <div class="where">${obs.stationname ?? "—"} · ${ageText(obs.age_seconds)}</div>
        </div>
      </div>
      <div class="facts3">
        <div>${WIND_ICON}Wind<b>${fmt(obs.windspeedms, 1)}<span style="opacity:.6"> /${fmt(obs.windgust, 1)}</span></b></div>
        <div>${RAIN_ICON}Rain<b>${popNow != null ? Math.round(popNow) + "%" : "–"}
          <span style="opacity:.6"> · ${fmt(rainNow, 1)}mm/h</span></b></div>
      </div>
      ${roadBlock}`;
  } catch (err) {
    host.innerHTML = err.status === 404
      ? `<p class="msg">No station found for “${place}”. Try a nearby town.</p>`
      : `<p class="msg">Weather unavailable (${err.message}).</p>`;
  }
}

async function loadToday(place) {
  const host = $("#today-box");
  try {
    const fc = await jget(`/v1/forecast?place=${encodeURIComponent(place)}&hours=24&step=60&lang=en`);
    const now = Math.floor(Date.now() / 1000);
    const todayStr = localDate(now);
    const todayPoints = (fc.points || [])
      .filter((p) => p.epochtime >= now - 1800 && localDate(p.epochtime) === todayStr);
    const points = sampleEven(todayPoints, 6);
    host.innerHTML = points.length ? `<div class="hrow">${points.map((p) => {
      const i = symbolInfo(p.smartsymbol);
      const wet = p.precipitation1h != null && p.precipitation1h >= 0.05;
      return `<div class="h">
        <div class="t">${localHour(p.epochtime)}</div>
        ${icon(i ? i.c : "unknown", i ? i.night : false, 24)}
        <div class="v">${fmt(p.temperature, 0)}°</div>
        <div class="r${wet ? " wet" : ""}">${fmt(p.precipitation1h ?? 0, 1)}mm</div>
      </div>`;
    }).join("")}</div>` : `<p class="msg">No forecast left for today.</p>`;
  } catch (err) {
    host.innerHTML = `<p class="msg">Unavailable (${err.message}).</p>`;
  }
}

async function loadD3(place) {
  const host = $("#d3-box");
  try {
    const fc = await jget(`/v1/forecast?place=${encodeURIComponent(place)}&hours=96&step=180&lang=en`);
    const byDate = new Map();
    for (const p of fc.points || []) {
      const d = localDate(p.epochtime);
      if (!byDate.has(d)) byDate.set(d, []);
      byDate.get(d).push(p);
    }
    byDate.delete(localDate(Math.floor(Date.now() / 1000)));
    const days = [...byDate.entries()].slice(0, 3);
    host.innerHTML = days.length ? `<div class="d3">${days.map(([date, pts]) => {
      const temps = pts.map((p) => p.temperature).filter((v) => v != null);
      const gusts = pts.map((p) => p.hourlymaximumgust).filter((v) => v != null);
      const rain = pts.map((p) => p.precipitation1h).filter((v) => v != null)
        .reduce((a, b) => a + b, 0);
      const hi = temps.length ? Math.max(...temps) : null;
      const lo = temps.length ? Math.min(...temps) : null;
      const gustMax = gusts.length ? Math.max(...gusts) : null;
      // Midday's symbol reads as "the day's weather" better than the first
      // point, same reasoning as the main site's own daySummary().
      const midday = pts.reduce((best, p) =>
        Math.abs(Number(localHour(p.epochtime)) - 13) < Math.abs(Number(localHour(best.epochtime)) - 13) ? p : best,
        pts[0]);
      const i = symbolInfo(midday.smartsymbol);
      return `<div class="day">
        <div class="wd">${localWeekday(pts[0].epochtime)}</div>
        ${icon(i ? i.c : "unknown", false, 32)}
        <div class="hilo">${fmt(hi, 0)}°<span class="lo"> ${fmt(lo, 0)}°</span></div>
        <div class="wind">${WIND_ICON}${fmt(gustMax, 0)} m/s</div>
        <div class="rain${rain >= 0.1 ? " wet" : ""}">${RAIN_ICON}${fmt(rain, 1)} mm</div>
      </div>`;
    }).join("")}</div>` : `<p class="msg">Unavailable.</p>`;
  } catch (err) {
    host.innerHTML = err.status === 404
      ? `<p class="msg">No forecast for “${place}”.</p>`
      : `<p class="msg">Unavailable (${err.message}).</p>`;
  }
}

/* No station picker on this page (2026-09-27) — the sea box follows
   whichever land place is selected, using the marine/lake station nearest
   to it. Straight-line distance, same measure the backend's own
   nearest-station logic uses elsewhere (app/geo.py::haversine_km) — good
   enough for "which station is this", not a routing distance. */
function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1), dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

let SEA_STATIONS = null;
async function seaStations() {
  if (!SEA_STATIONS) {
    const r = await jget("/v1/stations");
    SEA_STATIONS = [...(r.marine_stations || []), ...(r.lake_stations || [])];
  }
  return SEA_STATIONS;
}

async function nearestSeaStation(lat, lon) {
  const list = await seaStations();
  let best = null, bestKm = Infinity;
  for (const s of list) {
    const km = haversineKm(lat, lon, s.lat, s.lon);
    if (km < bestKm) { bestKm = km; best = s; }
  }
  return best;
}

async function loadSea(place) {
  const host = $("#sea-box");
  try {
    let fmisid = SEA_FMISID;
    try {
      const geo = await jget(`/v1/geocode?place=${encodeURIComponent(place)}`);
      const station = await nearestSeaStation(geo.lat, geo.lon);
      if (station) fmisid = station.fmisid;
    } catch (_) {
      // Falls back to the default station — sea data still shown, just not
      // necessarily the nearest one, rather than the box going blank over a
      // geocoding hiccup.
    }
    const m = await jget(`/v1/marine?fmisid=${fmisid}`);
    const s = m.station, w = m.waves;
    const lbl = $("#sea-lbl");
    if (lbl) lbl.textContent = `Sea — ${s.name}`;
    host.innerHTML = `
      <div class="sea">
        <div>Air<b>${fmt(s.temperature, 1)}°C</b></div>
        <div>Wind<b>${fmt(s.windspeedms, 1)} m/s</b></div>
        <div>Gust<b>${fmt(s.windgust, 1)} m/s</b></div>
        <div>Sea<b>${w && w.water_temp_c != null ? fmt(w.water_temp_c, 1) + "°C" : "—"}</b></div>
      </div>
      <p class="msg" style="margin-top:8px">${s.name}${w && w.measured ? "" : w ? " · modelled" : " · no buoy"}</p>`;
  } catch (err) {
    host.innerHTML = `<p class="msg">Sea data unavailable (${err.message}).</p>`;
  }
}

/* --- Rain radar & lightning map — same mechanism as the main site's
   (weatherapp/public/site.js): FMI's own WMS tiles for radar/rain-rate,
   /v1/lightning markers for lightning, no cloud/satellite layer (FMI's open
   WMS has none). See that file for the CRS/verification notes; unchanged
   here, just ported to a standalone page with no site.js to share it with. */
let radarMap = null, radarLayer = null, rainrateLayer = null, lightningLayer = null;
const FMI_WMS = "https://openwms.fmi.fi/geoserver/Radar/wms";
const FMI_WMS_ATTR = "FMI, CC BY 4.0";
const MAP_NOTES = {
  radar: "FMI's national radar composite, updates every 5 minutes.",
  rainrate: "FMI's rain-rate composite, updates every 5 minutes.",
  lightning: "FMI's own lightning detections.",
};

function initRadarMap() {
  const el = document.getElementById("radar-map");
  if (!el || !window.L || radarMap) return;
  radarMap = L.map(el, { scrollWheelZoom: false }).setView([60.3, 25.0], 8);
  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: "&copy; OpenStreetMap contributors", maxZoom: 12,
  }).addTo(radarMap);
  radarLayer = L.tileLayer.wms(FMI_WMS, {
    layers: "Radar:suomi_dbz_eureffin", format: "image/png", transparent: true,
    opacity: 0.75, attribution: FMI_WMS_ATTR,
  });
  rainrateLayer = L.tileLayer.wms(FMI_WMS, {
    layers: "Radar:suomi_rr_eureffin", format: "image/png", transparent: true,
    opacity: 0.75, attribution: FMI_WMS_ATTR,
  });
  lightningLayer = L.layerGroup();
  radarLayer.addTo(radarMap);
  const sel = document.getElementById("map-layer");
  if (sel) sel.addEventListener("change", () => setMapLayer(sel.value));
  updateMapNote();
}

function setMapLayer(which) {
  if (!radarMap) return;
  for (const layer of [radarLayer, rainrateLayer, lightningLayer]) {
    if (layer && radarMap.hasLayer(layer)) radarMap.removeLayer(layer);
  }
  if (which === "rainrate") rainrateLayer.addTo(radarMap);
  else if (which === "lightning") { lightningLayer.addTo(radarMap); loadLightning(); }
  else radarLayer.addTo(radarMap);
  updateMapNote();
}

function updateMapNote() {
  const note = $("#map-note");
  const sel = $("#map-layer");
  if (!note) return;
  note.textContent = MAP_NOTES[sel ? sel.value : "radar"];
}

async function loadLightning() {
  if (!lightningLayer) return;
  lightningLayer.clearLayers();
  try {
    const data = await jget("/v1/lightning?hours=3");
    for (const s of data.strikes || []) {
      L.circleMarker([s.lat, s.lon], { radius: 4, color: "#c2410c", weight: 1, fillOpacity: 0.7 })
        .bindTooltip(`${localTime(s.epochtime)}${s.peak_current != null ? " · " + Math.round(s.peak_current) + " kA" : ""}`)
        .addTo(lightningLayer);
    }
  } catch (_) { /* the note under the map already says what this layer is */ }
}

function refresh() {
  const place = $("#place").value.trim() || "Tapiola";
  loadNow(place);
  loadToday(place);
  loadD3(place);
  loadSea(place);
  if (radarMap && $("#map-layer").value === "lightning") loadLightning();
}

/* Explicit light/dark choice overrides the system preference and is
   remembered; no stored choice means "follow the system" (handled purely in
   CSS via prefers-color-scheme, nothing to do here in that case). */
function applyTheme(theme) {
  if (theme) document.documentElement.setAttribute("data-theme", theme);
  else document.documentElement.removeAttribute("data-theme");
  const light = $("#theme-light"), dark = $("#theme-dark");
  if (light) light.setAttribute("aria-pressed", String(theme === "light"));
  if (dark) dark.setAttribute("aria-pressed", String(theme === "dark"));
}

function initTheme() {
  let stored = null;
  try { stored = localStorage.getItem("fiw-theme"); } catch (_) {}
  applyTheme(stored);
  const set = (theme) => {
    try {
      if (theme) localStorage.setItem("fiw-theme", theme);
      else localStorage.removeItem("fiw-theme");
    } catch (_) {}
    applyTheme(theme);
  };
  const light = $("#theme-light"), dark = $("#theme-dark");
  // Tapping the already-active choice clears it back to "follow system",
  // rather than being a dead end once you've picked one.
  if (light) light.addEventListener("click", () =>
    set(light.getAttribute("aria-pressed") === "true" ? null : "light"));
  if (dark) dark.addEventListener("click", () =>
    set(dark.getAttribute("aria-pressed") === "true" ? null : "dark"));
}

(function init() {
  $("#place").addEventListener("change", refresh);
  initTheme();
  initRadarMap();
  refresh();
  setInterval(refresh, 300000);
})();
