/* Shared by the internal data explorer and the public weather page.
   Plain script, no modules: both pages load this first, then their own file. */

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
  en: { measured:"measured", retrieved:"fetched", language:"Language", landPlace:"Land place", seaStation:"Sea station", waveBuoy:"Wave buoy",
        from:"From", to:"To", load:"Load", loading:"Loading…",
        d3:"Last 3 days", d14:"Last 14 days", d60:"Last 60 days",
        ice:"Feb 2026 — ice season", storm:"19 Sep — storm",
        wind:"Wind", gust:"Gust", humidity:"Humidity", pressure:"Pressure",
        away:"km away", justNow:"just now", minAgo:"min ago", hAgo:"h ago",
        gLand:"Land", gSea:"Sea station", gBuoy:"Wave buoy", gIce:"Sea ice",
        noData:"No data in this range — expected for seasonal sensors.",
        raw:"Raw JSON", latest:"latest", subtitle:"FMI open data, as the backend serves it. For understanding what the values do — not a preview of the watch UI.",
        foot:"Data: Finnish Meteorological Institute, CC BY 4.0. Buoys are lifted out of the water roughly December–April, so gaps in winter are expected rather than faults. Times are Finnish local time (Europe/Helsinki)." },
  fi: { measured:"mitattu", retrieved:"haettu", language:"Kieli", landPlace:"Paikkakunta", seaStation:"Merihavaintoasema", waveBuoy:"Aaltopoiju",
        from:"Alkaen", to:"Asti", load:"Hae", loading:"Ladataan…",
        d3:"3 vrk", d14:"14 vrk", d60:"60 vrk",
        ice:"Helmikuu 2026 — jääkausi", storm:"19.9. — ukkonen",
        wind:"Tuuli", gust:"Puuska", humidity:"Kosteus", pressure:"Paine",
        away:"km päässä", justNow:"juuri nyt", minAgo:"min sitten", hAgo:"h sitten",
        gLand:"Maa", gSea:"Merihavaintoasema", gBuoy:"Aaltopoiju", gIce:"Merijää",
        noData:"Ei havaintoja tällä aikavälillä — odotettua kausiluonteisilta antureilta.",
        raw:"Raakadata (JSON)", latest:"viimeisin", subtitle:"Ilmatieteen laitoksen avointa dataa sellaisena kuin taustapalvelu sen tarjoaa. Arvojen ymmärtämiseen — ei esikatselu kellon käyttöliittymästä.",
        foot:"Data: Ilmatieteen laitos, CC BY 4.0. Aaltopoijut nostetaan vedestä suunnilleen joulu–huhtikuuksi, joten talven katkot ovat odotettuja eivätkä vikoja. Ajat Suomen aikaa (Europe/Helsinki)." },
  sv: { measured:"uppmätt", retrieved:"hämtad", language:"Språk", landPlace:"Ort", seaStation:"Havsstation", waveBuoy:"Vågboj",
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
/* localStorage throws in private browsing and with site data blocked, so the
   language preference is a convenience that must never break the page. */
function storedLang() {
  try { return localStorage.getItem("fiw-lang"); } catch (_) { return null; }
}
let LANG = storedLang() || "fi";
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

const fmt = (n, d = 1) => (n === null || n === undefined ? "–" : Number(n).toFixed(d));

/* Each field carries its own measurement time (RESEARCH.md §3). */
function at(obj, field) {
  const t = obj && obj.at && obj.at[field];
  return t ? localTime(t) : "–";
}
