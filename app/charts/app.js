/* Charts for the FIWeatherWatch data explorer.
   Hand-rolled SVG line charts: the data is small, and a dependency-free page
   keeps the prototype deployable anywhere without a build step. */

/* SmartSymbol codes, from FMI's published symbol table.
   Night variants are the day code + 100; codes not listed explicitly fall
   back to that rule. Earlier hand-written guesses in this file were wrong
   (71 is Isolated thundershowers, not sleet) — this table replaces them. */
const SYMBOLS = {"1": {"c": "clear", "t": "Clear"}, "2": {"c": "mostlyclear", "t": "Mostly clear"}, "4": {"c": "partly", "t": "Partly cloudy"}, "6": {"c": "mostlycloudy", "t": "Mostly cloudy"}, "7": {"c": "overcast", "t": "Overcast"}, "9": {"c": "fog", "t": "Fog"}, "11": {"c": "rain", "t": "Drizzle"}, "14": {"c": "sleet", "t": "Freezing drizzle"}, "17": {"c": "sleet", "t": "Freezing rain"}, "21": {"c": "rain", "t": "Isolated showers"}, "24": {"c": "rain", "t": "Scattered showers"}, "27": {"c": "rain", "t": "Showers"}, "31": {"c": "rain", "t": "Partly cloudy and periods of light rain"}, "32": {"c": "rain", "t": "Partly cloudy and periods of moderate rain"}, "33": {"c": "rain", "t": "Partly cloudy and periods of heavy rain"}, "34": {"c": "rain", "t": "Mostly cloudy and periods of light rain"}, "35": {"c": "rain", "t": "Mostly cloudy and periods of moderate rain"}, "36": {"c": "rain", "t": "Mostly cloudy and periods of heavy rain"}, "37": {"c": "rain", "t": "Light rain"}, "38": {"c": "rain", "t": "Moderate rain"}, "39": {"c": "rain", "t": "Heavy rain"}, "41": {"c": "sleet", "t": "Isolated light sleet showers"}, "42": {"c": "sleet", "t": "Isolated moderate sleet showers"}, "43": {"c": "sleet", "t": "Isolated heavy sleet showers"}, "44": {"c": "sleet", "t": "Scattered light sleet showers"}, "45": {"c": "sleet", "t": "Scattered moderate sleet showers"}, "46": {"c": "sleet", "t": "Scattered heavy sleet showers"}, "47": {"c": "sleet", "t": "Light sleet"}, "48": {"c": "sleet", "t": "Moderate sleet"}, "49": {"c": "sleet", "t": "Heavy sleet"}, "51": {"c": "snow", "t": "Isolated light snow showers"}, "52": {"c": "snow", "t": "Isolated moderate snow showers"}, "53": {"c": "snow", "t": "Isolated heavy snow showers"}, "54": {"c": "snow", "t": "Scattered light snow showers"}, "55": {"c": "snow", "t": "Scattered moderate snow showers"}, "56": {"c": "snow", "t": "Scattered heavy snow showers"}, "57": {"c": "snow", "t": "Light snowfall"}, "58": {"c": "snow", "t": "Moderate snowfall"}, "59": {"c": "snow", "t": "Heavy snowfall"}, "61": {"c": "rain", "t": "Isolated hail showers"}, "64": {"c": "rain", "t": "Scattered hail showers"}, "67": {"c": "rain", "t": "Hail showers"}, "71": {"c": "thunder", "t": "Isolated thundershowers"}, "74": {"c": "thunder", "t": "Scattered thundershowers"}, "77": {"c": "thunder", "t": "Thundershowers"}, "101": {"c": "clear", "t": "Clear"}, "102": {"c": "mostlyclear", "t": "Mostly clear"}, "104": {"c": "partly", "t": "Partly cloudy"}, "106": {"c": "mostlycloudy", "t": "Mostly cloudy"}, "121": {"c": "rain", "t": "Isolated showers"}, "124": {"c": "rain", "t": "Scattered showers"}, "131": {"c": "rain", "t": "Partly cloudy and periods of light rain"}, "132": {"c": "rain", "t": "Partly cloudy and periods of moderate rain"}, "133": {"c": "rain", "t": "Partly cloudy and periods of heavy rain"}, "134": {"c": "rain", "t": "Mostly cloudy and periods of light rain"}, "135": {"c": "rain", "t": "Mostly cloudy and periods of moderate rain"}, "136": {"c": "rain", "t": "Mostly cloudy and periods of heavy rain"}, "141": {"c": "sleet", "t": "Isolated light sleet showers"}, "142": {"c": "sleet", "t": "Isolated moderate sleet showers"}, "143": {"c": "sleet", "t": "Isolated heavy sleet showers"}, "144": {"c": "sleet", "t": "Scattered light sleet showers"}, "145": {"c": "sleet", "t": "Scattered moderate sleet showers"}, "151": {"c": "snow", "t": "Isolated light snow showers"}, "152": {"c": "snow", "t": "Isolated moderate snow showers"}, "153": {"c": "snow", "t": "Isolated heavy snow showers"}, "154": {"c": "snow", "t": "Scattered light snow showers"}, "155": {"c": "snow", "t": "Scattered moderate snow showers"}, "156": {"c": "snow", "t": "Scattered heavy snow showers"}, "161": {"c": "rain", "t": "Isolated hail showers"}, "164": {"c": "rain", "t": "Scattered hail showers"}, "171": {"c": "thunder", "t": "Isolated thundershowers"}, "174": {"c": "thunder", "t": "Scattered thundershowers"}};

function symbolInfo(code) {
  if (code === null || code === undefined) return null;
  if (SYMBOLS[code]) return { ...SYMBOLS[code], night: code > 100 };
  if (code > 100 && SYMBOLS[code - 100])
    return { ...SYMBOLS[code - 100], night: true };   // documented +100 rule
  return null;
}

/* Data layer is epoch/UTC everywhere, because FMI's bare `time` field is local
   and silently wrong by 2-3 hours (RESEARCH.md §2). Display is Europe/Helsinki
   regardless of where the viewer sits — this is Finnish weather, so Finnish
   local time is the meaningful clock, not the browser's. */
/* Page strings in the three v1 languages. Weather descriptions are NOT here —
   FMI returns those already localised via `smartsymboltext`, so the app only
   ever translates its own chrome (RESEARCH.md §16). */
const STR = {
  en: { language:"Language", landPlace:"Land place", seaStation:"Sea station", waveBuoy:"Wave buoy",
        from:"From", to:"To", load:"Load", loading:"Loading…",
        d3:"Last 3 days", d14:"Last 14 days", d60:"Last 60 days",
        ice:"Feb 2026 — ice season", storm:"19 Sep — storm",
        wind:"Wind", gust:"Gust", humidity:"Humidity", pressure:"Pressure",
        away:"km away", justNow:"just now", minAgo:"min ago", hAgo:"h ago",
        gLand:"Land", gSea:"Sea station", gBuoy:"Wave buoy", gIce:"Sea ice",
        noData:"No data in this range — expected for seasonal sensors.",
        raw:"Raw JSON", latest:"latest", subtitle:"FMI open data, as the backend serves it. For understanding what the values do — not a preview of the watch UI.",
        foot:"Data: Finnish Meteorological Institute, CC BY 4.0. Buoys are lifted out of the water roughly December–April, so gaps in winter are expected rather than faults. Times are Finnish local time (Europe/Helsinki)." },
  fi: { language:"Kieli", landPlace:"Paikkakunta", seaStation:"Merihavaintoasema", waveBuoy:"Aaltopoiju",
        from:"Alkaen", to:"Asti", load:"Hae", loading:"Ladataan…",
        d3:"3 vrk", d14:"14 vrk", d60:"60 vrk",
        ice:"Helmikuu 2026 — jääkausi", storm:"19.9. — ukkonen",
        wind:"Tuuli", gust:"Puuska", humidity:"Kosteus", pressure:"Paine",
        away:"km päässä", justNow:"juuri nyt", minAgo:"min sitten", hAgo:"h sitten",
        gLand:"Maa", gSea:"Merihavaintoasema", gBuoy:"Aaltopoiju", gIce:"Merijää",
        noData:"Ei havaintoja tällä aikavälillä — odotettua kausiluonteisilta antureilta.",
        raw:"Raakadata (JSON)", latest:"viimeisin", subtitle:"Ilmatieteen laitoksen avointa dataa sellaisena kuin taustapalvelu sen tarjoaa. Arvojen ymmärtämiseen — ei esikatselu kellon käyttöliittymästä.",
        foot:"Data: Ilmatieteen laitos, CC BY 4.0. Aaltopoijut nostetaan vedestä suunnilleen joulu–huhtikuuksi, joten talven katkot ovat odotettuja eivätkä vikoja. Ajat Suomen aikaa (Europe/Helsinki)." },
  sv: { language:"Språk", landPlace:"Ort", seaStation:"Havsstation", waveBuoy:"Vågboj",
        from:"Från", to:"Till", load:"Hämta", loading:"Laddar…",
        d3:"3 dygn", d14:"14 dygn", d60:"60 dygn",
        ice:"Februari 2026 — issäsong", storm:"19 sep — åska",
        wind:"Vind", gust:"By", humidity:"Fuktighet", pressure:"Lufttryck",
        away:"km bort", justNow:"just nu", minAgo:"min sedan", hAgo:"h sedan",
        gLand:"Land", gSea:"Havsstation", gBuoy:"Vågboj", gIce:"Havsis",
        noData:"Inga data i detta intervall — väntat för säsongsgivare.",
        raw:"Rådata (JSON)", latest:"senaste", subtitle:"Meteorologiska institutets öppna data, som backend levererar dem. För att förstå vad värdena gör — inte en förhandsvisning av klockans gränssnitt.",
        foot:"Data: Meteorologiska institutet, CC BY 4.0. Vågbojarna tas upp ur vattnet ungefär december–april, så luckor på vintern är väntade och inte fel. Tider i finsk lokaltid (Europe/Helsinki)." },
};
let LANG = localStorage.getItem("fiw-lang") || "fi";
const T = (k) => (STR[LANG] && STR[LANG][k]) || STR.en[k];

const TZ = "Europe/Helsinki";
const _hhmm = new Intl.DateTimeFormat("en-GB",
  { timeZone: TZ, hour: "2-digit", minute: "2-digit", hour12: false });
const _hour = new Intl.DateTimeFormat("en-GB",
  { timeZone: TZ, hour: "2-digit", hour12: false });
const _daytime = new Intl.DateTimeFormat("en-GB",
  { timeZone: TZ, day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit", hour12: false });
const localHour = (epoch) => _hour.format(new Date(epoch * 1000));
const localTime = (epoch) => _hhmm.format(new Date(epoch * 1000));
const localStamp = (epoch) => _daytime.format(new Date(epoch * 1000));

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
    source: (c) => ({ place: c.place, params: "smartsymbol,smartsymboltext", step: 180 }),
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


/* Weather icons — one per SmartSymbol category, day and night variants where it
   matters. Inline SVG so the page keeps its no-dependency, no-build property. */
function icon(cat, night, size = 56) {
  const sun = night
    ? `<path d="M40 22a14 14 0 1 1-14-14 11 11 0 0 0 14 14Z" fill="var(--s4,#eda100)"/>`
    : `<circle cx="26" cy="24" r="11" fill="var(--s4,#eda100)"/>`;
  const cloud = (x = 0, y = 0, c = "var(--cloud)") =>
    `<path transform="translate(${x},${y})" fill="${c}" d="M20 44a11 11 0 0 1 .6-21.9 15 15 0 0 1 28.3 4.4A9.5 9.5 0 0 1 47 44Z"/>`;
  const drops = (c = "var(--s1)") =>
    `<g stroke="${c}" stroke-width="3" stroke-linecap="round">
       <line x1="24" y1="49" x2="21" y2="57"/><line x1="34" y1="49" x2="31" y2="57"/>
       <line x1="44" y1="49" x2="41" y2="57"/></g>`;
  const flakes = (c = "var(--s1)") =>
    `<g stroke="${c}" stroke-width="2.5" stroke-linecap="round">
       <g transform="translate(24,53)"><line x1="-4" y1="0" x2="4" y2="0"/><line x1="0" y1="-4" x2="0" y2="4"/></g>
       <g transform="translate(38,53)"><line x1="-4" y1="0" x2="4" y2="0"/><line x1="0" y1="-4" x2="0" y2="4"/></g></g>`;
  const bolt = `<path d="M33 46l-8 12h6l-3 10 11-14h-6l4-8z" fill="var(--s4,#eda100)"/>`;
  const body = {
    clear:        sun,
    mostlyclear:  sun + cloud(10, 10, "var(--cloud-2)"),
    partly:       sun + cloud(6, 6),
    mostlycloudy: cloud(0, 2),
    overcast:     cloud(0, 2, "var(--cloud-2)"),
    fog:          cloud(0, -2) + `<g stroke="var(--muted)" stroke-width="3" stroke-linecap="round"><line x1="18" y1="52" x2="48" y2="52"/><line x1="22" y1="59" x2="44" y2="59"/></g>`,
    rain:         cloud(0, -2) + drops(),
    sleet:        cloud(0, -2) + drops() + flakes("var(--muted)"),
    snow:         cloud(0, -2) + flakes(),
    thunder:      cloud(0, -2) + bolt,
    unknown:      `<circle cx="34" cy="34" r="16" fill="none" stroke="var(--muted)" stroke-width="2" stroke-dasharray="4 4"/>`,
  }[cat] || `<circle cx="34" cy="34" r="16" fill="none" stroke="var(--muted)" stroke-width="2"/>`;
  return `<svg class="icon" width="${size}" height="${size}" viewBox="0 0 68 72" aria-hidden="true">${body}</svg>`;
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
          <div class="where">${obs.stationname ?? "—"} · ${fmt(obs.distance, 1)} ${T("away")} · ${ageTxt}</div>
        </div>
        <div class="facts">
          <div>${T("wind")}<b>${fmt(obs.windspeedms, 1)} m/s</b>${obs.windcompass8 ?? ""}</div>
          <div>${T("gust")}<b>${fmt(obs.windgust, 1)} m/s</b></div>
          <div>${T("humidity")}<b>${fmt(obs.humidity, 0)}%</b></div>
          <div>${T("pressure")}<b>${fmt(obs.pressure, 0)} hPa</b></div>
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
