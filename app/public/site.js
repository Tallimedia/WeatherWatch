/* Page strings. Weather descriptions are NOT here — FMI returns those already
   localised, so only the page's own chrome is translated (RESEARCH.md §16). */
STR = {
  fi: {
    heroA:"Suomen sää,", heroB:"maalla ja merellä.",
    lede:"Ennusteet, merituuli ja live-aaltodata — suoraan Ilmatieteen laitoksen omasta avoimesta datasta, ei globaalista mallista. Kaikki alla on live-dataa juuri nyt. Tulossa pian kelloon lähelläsi.",
    tagDev:"Kehitteillä", tagArea:"Suomi",
    navLive:"Live-data", navWhat:"Mitä se näyttää", navData:"Tietoa datasta",
    onLand:"Maalla", onLandSub:"Havainnot ja loppupäivä lähimmältä asemalta.",
    atSea:"Merellä", atSeaSub:"Tuuli merihavaintoasemalta, aallot Ilmatieteen laitoksen poijuilta.",
    place:"Paikkakunta", station:"Merihavaintoasema", buoy:"Aaltopoiju", nearest:"Lähin havaitseva",
    wind:"Tuuli", gust:"Puuska", humidity:"Kosteus", pressure:"Paine",
    air:"Ilma", waveH:"Aallonkorkeus", period:"Jakso", water:"Vesi", waves:"Aallot",
    whatTitle:"Mitä kello näyttää",
    c1t:"Maa", c1:"Lämpötila, tuuli ja puuskat sekä 10 vuorokauden ennuste — havaintoasema nimettynä ja etäisyys näkyvissä.",
    c2t:"Meri", c2:"Tuuli ja puuskat Harmajalta, Utöstä, Kalbådagrundilta ja 19 muulta merihavaintoasemalta.",
    c3t:"Aallot", c3:"Merkitsevä aallonkorkeus, jakso, suunta ja meriveden lämpötila Ilmatieteen laitoksen aaltopoijuilta.",
    c4t:"Omat rajasi", c4:"Aseta omat tuulen, puuskan ja aallonkorkeuden rajat, niin lukema erottuu kun sillä on sinulle merkitystä.",
    dataTitle:"Tietoa datasta",
    d1t:"Tuuli on 10 minuutin keskiarvo", d1:"Meteorologinen standardi ja sama peruste jota Ilmatieteen laitoksen merivaroitukset käyttävät. Puuska on jakson suurin puuska, ei keskiarvo.",
    d2t:"Jokaisella arvolla on aikaleima", d2:"Asemat päivittyvät eri tahtiin — Harmaja julkaisee tuulen minuutin välein, useimmat asemat kymmenen — joten jokainen lukema kertoo milloin se on mitattu.",
    d3t:"Aaltopoijut ovat kausiluonteisia", d3:"Ne nostetaan vedestä suunnilleen joulukuusta huhtikuuhun. Kun yksikään ei havaitse, sivu kertoo sen ja näyttää mallidatan selvästi merkittynä.",
    footData:"Säädata:", footLic:"avointa dataa, lisenssi",
    footNote:"FIWeatherWatch on itsenäinen projekti, ei Ilmatieteen laitoksen eikä Garminin tukema. Ajat Suomen aikaa. Kehitysvaiheessa — jaettu palautetta varten.",
    unavailable:"Sää ei ole hetkellisesti saatavilla", noPlace:"Paikkakunnalle ei löytynyt havaintoasemaa", tryNearby:"Kokeile lähikaupunkia.",
    noBuoy:"ei havaitsevaa poijua", modelled:"WAM-malli — ei mitattu", away:"km päässä",
    justNow:"juuri nyt", minAgo:"min sitten", hAgo:"h sitten", retrieved:"Haettu", loading:"Ladataan…",
  },
  sv: {
    heroA:"Finlands väder,", heroB:"på land och till havs.",
    lede:"Prognoser, havsvind och live-vågdata — direkt från Meteorologiska institutets egna öppna data, inte en global modell. Allt nedan är live just nu. Kommer snart till en klocka nära dig.",
    tagDev:"Under utveckling", tagArea:"Finland",
    navLive:"Livedata", navWhat:"Vad den visar", navData:"Om data",
    onLand:"På land", onLandSub:"Observationer och resten av dagen från närmaste station.",
    atSea:"Till havs", atSeaSub:"Vind från en havsstation, vågor från institutets vågbojar.",
    place:"Ort", station:"Havsstation", buoy:"Vågboj", nearest:"Närmaste aktiva",
    wind:"Vind", gust:"By", humidity:"Fuktighet", pressure:"Lufttryck",
    air:"Luft", waveH:"Våghöjd", period:"Period", water:"Vatten", waves:"Vågor",
    whatTitle:"Vad klockan visar",
    c1t:"Land", c1:"Temperatur, vind och byar samt en 10-dygnsprognos — med stationen namngiven och avståndet angivet.",
    c2t:"Hav", c2:"Vind och byar från Harmaja, Utö, Kalbådagrund och 19 andra havsstationer.",
    c3t:"Vågor", c3:"Signifikant våghöjd, period, riktning och havsvattnets temperatur från institutets vågbojar.",
    c4t:"Dina gränser", c4:"Ställ in egna gränser för vind, byar och våghöjd, så att ett värde sticker ut när det betyder något för dig.",
    dataTitle:"Om data",
    d1t:"Vinden är ett 10-minutersmedel", d1:"Den meteorologiska standarden, samma grund som institutets sjövarningar använder. Byn är den högsta byn i perioden, inte ett medelvärde.",
    d2t:"Varje värde har en tidsstämpel", d2:"Stationerna uppdateras olika ofta — Harmaja publicerar vind varje minut, de flesta var tionde — så varje avläsning visar när den mättes.",
    d3t:"Vågbojarna är säsongsbundna", d3:"De tas upp ur vattnet ungefär december till april. När ingen rapporterar säger sidan det och visar modelldata tydligt märkt.",
    footData:"Väderdata:", footLic:"öppna data, licens",
    footNote:"FIWeatherWatch är ett fristående projekt, utan koppling till Meteorologiska institutet eller Garmin. Tider i finsk lokaltid. Under utveckling — delad för återkoppling.",
    unavailable:"Vädret är tillfälligt otillgängligt", noPlace:"Ingen väderstation hittades för", tryNearby:"Prova en närliggande ort.",
    noBuoy:"ingen aktiv boj", modelled:"WAM-modell — inte uppmätt", away:"km bort",
    justNow:"just nu", minAgo:"min sedan", hAgo:"h sedan", retrieved:"Hämtad", loading:"Laddar…",
  },
  en: {
    heroA:"Finnish weather,", heroB:"land and sea.",
    lede:"Forecasts, marine wind and live wave data — from the Finnish Meteorological Institute's own open data, not a global model. Everything below is live right now. Coming soon to a watch near you.",
    tagDev:"In development", tagArea:"Finland",
    navLive:"Live data", navWhat:"What it shows", navData:"About the data",
    onLand:"On land", onLandSub:"Current conditions and the rest of today, from the nearest reporting station.",
    atSea:"At sea", atSeaSub:"Wind from a Finnish marine station, waves from FMI's wave buoys.",
    place:"Place", station:"Sea station", buoy:"Wave buoy", nearest:"Nearest reporting",
    wind:"Wind", gust:"Gust", humidity:"Humidity", pressure:"Pressure",
    air:"Air", waveH:"Wave height", period:"Period", water:"Water", waves:"Waves",
    whatTitle:"What the watch shows",
    c1t:"Land", c1:"Current temperature, wind and gusts, plus a 10-day forecast — with the reporting station named and its distance shown.",
    c2t:"Sea", c2:"Wind and gusts from Harmaja, Utö, Kalbådagrund and 19 other Finnish marine stations.",
    c3t:"Waves", c3:"Significant wave height, period, direction and sea water temperature from FMI's wave buoys.",
    c4t:"Your limits", c4:"Set your own wind, gust and wave thresholds, so a reading stands out when it matters to you.",
    dataTitle:"About the data",
    d1t:"Wind is a 10-minute mean", d1:"The meteorological standard, and the same basis FMI's own marine warnings use. Gust is the highest gust in that window, not an average.",
    d2t:"Every value is timestamped", d2:"Stations update at different rates — Harmaja republishes wind every minute, most stations every ten — so each reading shows when it was measured rather than assuming.",
    d3t:"Wave buoys are seasonal", d3:"They are lifted out of the water roughly December to April. When none is reporting, the page says so and falls back to model output, clearly labelled.",
    footData:"Weather data:", footLic:"open data, licensed",
    footNote:"FIWeatherWatch is an independent project, not affiliated with or endorsed by the Finnish Meteorological Institute or Garmin. Times in Finnish local time. In development — shared for feedback.",
    unavailable:"Weather is briefly unavailable", noPlace:"No weather station found for", tryNearby:"Try a nearby town.",
    noBuoy:"no buoy reporting", modelled:"WAM model — not measured", away:"km away",
    justNow:"just now", minAgo:"min ago", hAgo:"h ago", retrieved:"Retrieved", loading:"Loading…",
  },
};
function storedLang() { try { return localStorage.getItem("fiw-lang"); } catch (_) { return null; } }

/* Public weather page. Deliberately not the internal data explorer: this shows
   what the watch shows, in the same shape, with none of the research framing
   (RESEARCH.md §19). */

const $ = (s) => document.querySelector(s);

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
  if (seconds < 90) return T("justNow");
  if (seconds < 5400) return `${Math.round(seconds / 60)} ${T("minAgo")}`;
  return `${Math.round(seconds / 3600)} ${T("hAgo")}`;
}

async function loadNow(place) {
  const host = $("#widget");
  try {
    const [obs, fc] = await Promise.all([
      jget(`/v1/observations?place=${encodeURIComponent(place)}`),
      jget(`/v1/forecast?place=${encodeURIComponent(place)}&hours=24&step=60&lang=${LANG}`),
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
          <div>${T("wind")}<b>${fmt(obs.windspeedms, 1)} m/s</b>
            <span class="at">${obs.windcompass8 ?? ""} · ${at(obs, "windspeedms")}</span></div>
          <div>${T("gust")}<b>${fmt(obs.windgust, 1)} m/s</b>
            <span class="at">${at(obs, "windgust")}</span></div>
          <div>${T("humidity")}<b>${fmt(obs.humidity, 0)}%</b>
            <span class="at">${at(obs, "humidity")}</span></div>
          <div>${T("pressure")}<b>${fmt(obs.pressure, 0)} hPa</b>
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
    // A place FMI does not know is the visitor's typo, not an outage — say so.
    host.innerHTML = err.status === 404
      ? `<p class="msg">${T("noPlace")} “${place}”. ${T("tryNearby")}</p>`
      : `<p class="msg">${T("unavailable")} (${err.message}).</p>`;
  }
}

async function loadMarine(fmisid, buoy) {
  const host = $("#marine");
  try {
    const m = await jget(`/v1/marine?fmisid=${fmisid}` + (buoy ? `&buoy_fmisid=${buoy}` : ""));
    const s = m.station, w = m.waves;
    // `mode` says whether waves are measured or modelled; never present a model
    // value as if a buoy had reported it (RESEARCH.md §16).
    const wavesBlock = !w ? `<div><span>${T("waves")}</span><b>—</b>
        <span class="at">${T("noBuoy")}</span></div>`
      : `<div><span>${T("waveH")}</span><b>${fmt(w.wave_height_m, 1)} m</b>
           <span class="at">${w.measured ? w.name : T("modelled")}</span></div>
         <div><span>${T("period")}</span><b>${fmt(w.wave_period_s, 1)} s</b>
           <span class="at">${w.wave_direction_deg != null ? Math.round(w.wave_direction_deg) + "°" : ""}</span></div>
         <div><span>${T("water")}</span><b>${fmt(w.water_temp_c, 1)}°C</b>
           <span class="at">${w.measured && w.distance_km != null ? w.distance_km + " " + T("away") : ""}</span></div>`;
    host.innerHTML = `
      <div class="grid">
        <div><span>${T("wind")}</span><b>${fmt(s.windspeedms, 1)} m/s</b>
          <span class="at">${s.windcompass8 ?? ""} · ${at(s, "windspeedms")}</span></div>
        <div><span>${T("gust")}</span><b>${fmt(s.windgust, 1)} m/s</b>
          <span class="at">${at(s, "windgust")}</span></div>
        <div><span>${T("air")}</span><b>${fmt(s.temperature, 1)}°C</b>
          <span class="at">${at(s, "temperature")}</span></div>
        ${wavesBlock}
      </div>
      <p class="note">${s.name}${w && w.measured ? ` · waves from ${w.name}` : ""}.
         ${T("retrieved")} ${m.retrieved ? localTime(m.retrieved) : "—"}.</p>`;
  } catch (err) {
    host.innerHTML = `<p class="msg">Sea conditions are briefly unavailable (${err.message}).</p>`;
  }
}

function applyStrings() {
  document.documentElement.lang = LANG;
  const set = (id, k) => { const e = $(id); if (e) e.textContent = T(k); };
  set("#nav-live","navLive"); set("#nav-what","navWhat"); set("#nav-data","navData");
  set("#tag-dev","tagDev"); set("#tag-area","tagArea");
  set("#hero-a","heroA"); set("#hero-b","heroB"); set("#lede","lede");
  set("#h-land","onLand"); set("#sub-land","onLandSub");
  set("#h-sea","atSea"); set("#sub-sea","atSeaSub");
  set("#l-place","place"); set("#l-station","station"); set("#l-buoy","buoy");
  set("#h-what","whatTitle"); set("#h-data","dataTitle"); set("#foot-note","footNote");
  for (const i of [1,2,3,4]) { set(`#c${i}t`,`c${i}t`); set(`#c${i}`,`c${i}`); }
  for (const i of [1,2,3])   { set(`#d${i}t`,`d${i}t`); set(`#d${i}`,`d${i}`); }
  const b = $("#buoy");
  if (b && b.options.length) b.options[0].textContent = T("nearest");
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
  $("#buoy").innerHTML = `<option value="">${T("nearest")}</option>` + reg.wave_buoys
    .map((s) => `<option value="${s.fmisid}">${s.name}</option>`).join("");
  for (const id of ["#place", "#station", "#buoy"]) {
    $(id).addEventListener("change", refresh);
  }
  $("#lang").value = LANG;
  $("#lang").addEventListener("change", (e) => {
    LANG = e.target.value;
    try { localStorage.setItem("fiw-lang", LANG); } catch (_) {}
    applyStrings();
    refresh();
  });
  applyStrings();
  refresh();
  setInterval(refresh, 300000);   // matches the observation cache TTL
})();
