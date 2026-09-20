/* Public weather page. Deliberately not the internal data explorer: this shows
   what the watch shows, in the same shape, with none of the research framing
   (RESEARCH.md §19). */

const $ = (s) => document.querySelector(s);

async function jget(path) {
  const r = await fetch(path);
  if (!r.ok) throw new Error((await r.json().catch(() => ({}))).detail || r.statusText);
  return r.json();
}

function ageText(seconds) {
  if (seconds === null || seconds === undefined) return "";
  if (seconds < 90) return "just now";
  if (seconds < 5400) return `${Math.round(seconds / 60)} min ago`;
  return `${Math.round(seconds / 3600)} h ago`;
}

async function loadNow(place) {
  const host = $("#widget");
  try {
    const [obs, fc] = await Promise.all([
      jget(`/v1/observations?place=${encodeURIComponent(place)}`),
      jget(`/v1/forecast?place=${encodeURIComponent(place)}&hours=24&step=60&lang=en`),
    ]);
    const now = Math.floor(Date.now() / 1000);
    const ahead = (fc.points || []).filter((p) => p.epochtime >= now - 1800).slice(0, 12);
    const sym = symbolInfo(ahead.length ? ahead[0].smartsymbol : null);
    const text = ahead.length && ahead[0].smartsymboltext
      ? ahead[0].smartsymboltext.replace(/^./, (m) => m.toUpperCase())
      : (sym ? sym.t : "—");

    host.innerHTML = `
      <div class="now">
        <div>${icon(sym ? sym.c : "unknown", sym ? sym.night : false, 70)}</div>
        <div>
          <div class="temp">${fmt(obs.temperature, 1)}°C</div>
          <div class="desc">${text}</div>
          <div class="where">${obs.stationname ?? "—"} · ${fmt(obs.distance, 1)} km ·
            ${ageText(obs.age_seconds)}</div>
        </div>
        <div class="facts">
          <div>Wind<b>${fmt(obs.windspeedms, 1)} m/s</b>
            <span class="at">${obs.windcompass8 ?? ""} · ${at(obs, "windspeedms")}</span></div>
          <div>Gust<b>${fmt(obs.windgust, 1)} m/s</b>
            <span class="at">${at(obs, "windgust")}</span></div>
          <div>Humidity<b>${fmt(obs.humidity, 0)}%</b>
            <span class="at">${at(obs, "humidity")}</span></div>
          <div>Pressure<b>${fmt(obs.pressure, 0)} hPa</b>
            <span class="at">${at(obs, "pressure")}</span></div>
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
    host.innerHTML = `<p class="msg">Weather is briefly unavailable (${err.message}).</p>`;
  }
}

async function loadMarine(fmisid, buoy) {
  const host = $("#marine");
  try {
    const m = await jget(`/v1/marine?fmisid=${fmisid}` + (buoy ? `&buoy_fmisid=${buoy}` : ""));
    const s = m.station, w = m.waves;
    // `mode` says whether waves are measured or modelled; never present a model
    // value as if a buoy had reported it (RESEARCH.md §16).
    const wavesBlock = !w ? `<div><span>Waves</span><b>—</b>
        <span class="at">no buoy reporting</span></div>`
      : `<div><span>Wave height</span><b>${fmt(w.wave_height_m, 1)} m</b>
           <span class="at">${w.measured ? w.name : "WAM model — not measured"}</span></div>
         <div><span>Period</span><b>${fmt(w.wave_period_s, 1)} s</b>
           <span class="at">${w.wave_direction_deg != null ? Math.round(w.wave_direction_deg) + "°" : ""}</span></div>
         <div><span>Water</span><b>${fmt(w.water_temp_c, 1)}°C</b>
           <span class="at">${w.measured && w.distance_km != null ? w.distance_km + " km away" : ""}</span></div>`;
    host.innerHTML = `
      <div class="grid">
        <div><span>Wind</span><b>${fmt(s.windspeedms, 1)} m/s</b>
          <span class="at">${s.windcompass8 ?? ""} · ${at(s, "windspeedms")}</span></div>
        <div><span>Gust</span><b>${fmt(s.windgust, 1)} m/s</b>
          <span class="at">${at(s, "windgust")}</span></div>
        <div><span>Air</span><b>${fmt(s.temperature, 1)}°C</b>
          <span class="at">${at(s, "temperature")}</span></div>
        ${wavesBlock}
      </div>
      <p class="note">${s.name}${w && w.measured ? ` · waves from ${w.name}` : ""}.
         Retrieved ${m.retrieved ? localTime(m.retrieved) : "—"}.</p>`;
  } catch (err) {
    host.innerHTML = `<p class="msg">Sea conditions are briefly unavailable (${err.message}).</p>`;
  }
}

function refresh() {
  loadNow($("#place").value.trim() || "Helsinki");
  loadMarine($("#station").value, $("#buoy").value);
}

(async function init() {
  const reg = await jget("/v1/stations");
  $("#station").innerHTML = reg.marine_stations
    .map((s) => `<option value="${s.fmisid}"${s.fmisid === 100996 ? " selected" : ""}>${s.name}</option>`)
    .join("");
  $("#buoy").innerHTML = `<option value="">Nearest reporting</option>` + reg.wave_buoys
    .map((s) => `<option value="${s.fmisid}">${s.name}</option>`).join("");
  for (const id of ["#place", "#station", "#buoy"]) {
    $(id).addEventListener("change", refresh);
  }
  refresh();
  setInterval(refresh, 300000);   // matches the observation cache TTL
})();
