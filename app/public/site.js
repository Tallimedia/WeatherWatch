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
    dirFrom:"{d}-suunnasta", wind:"Tuuli", gust:"Puuska", humidity:"Kosteus", pressure:"Paine",
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
    noBuoy:"ei havaitsevaa poijua", noBuoyArea:"Ei poijua alueella", modelled:"WAM-malli — ei mitattu", away:"km päässä",
    navApp:"Sovellus", navWeather:"Säätiedot", brandWeather:"Sää", tagLive:"Live-data", navApp2:"Sovellus",
    ledeWeather:"Ennusteet, merituuli ja live-aaltodata — suoraan Ilmatieteen laitoksen omasta avoimesta datasta, ei globaalista mallista. Kaikki alla on live-dataa juuri nyt.", hApp:"Ranteessasi",
    appLede:"Sama data kellossasi — maasään ennuste, merituuli rannikkoasemilta ja aaltotiedot Ilmatieteen laitoksen poijuilta. Ei tiliä, ei kirjautumista.",
    p1:"Maa: lämpötila, tuuli ja puuskat lähimmältä asemalta, ennuste loppupäivälle",
    p2:"Meri: tuuli ja puuskat 40 rannikkoasemalta ja 14 sisävesiasemalta",
    p3:"Aallot: korkeus, jakso, suunta ja veden lämpötila",
    p4:"Omat rajasi tuulelle, puuskalle ja aallonkorkeudelle",
    soon:"Tulossa Connect IQ -kauppaan", getIt:"Hae Connect IQ -kaupasta",
    seeLive:"Katso säätiedot livenä sääsivultamme",
    devices:"Suomeksi, ruotsiksi ja englanniksi. Toimii 70 Garmin-mallissa.",
    hScreens:"Jokainen näyttö", capLand:"Maa", capSea:"Meri", capWaves:"Aallot", capGlance:"Vilkaisu", capAbout:"Tietoja", capSmall:"Forerunner 255s",
    privacy:"Tietosuoja", terms:"Käyttöehdot",
    coast:"Rannikko", lakes:"Sisävedet", trend:"Tuuli, 12 viime tuntia", mean:"Keskituuli", noTrend:"Ei tuulihistoriaa saatavilla", rain:"Sade", rainNone:"ei sadetta", justNow:"juuri nyt", minAgo:"min sitten", hAgo:"h sitten", retrieved:"Haettu", loading:"Ladataan…",
  },
  sv: {
    heroA:"Finlands väder,", heroB:"på land och till havs.",
    lede:"Prognoser, havsvind och live-vågdata — direkt från Meteorologiska institutets egna öppna data, inte en global modell. Allt nedan är live just nu. Kommer snart till en klocka nära dig.",
    tagDev:"Under utveckling", tagArea:"Finland",
    navLive:"Livedata", navWhat:"Vad den visar", navData:"Om data",
    onLand:"På land", onLandSub:"Observationer och resten av dagen från närmaste station.",
    atSea:"Till havs", atSeaSub:"Vind från en havsstation, vågor från institutets vågbojar.",
    place:"Ort", station:"Havsstation", buoy:"Vågboj", nearest:"Närmaste aktiva",
    dirFrom:"från {d}", wind:"Vind", gust:"By", humidity:"Fuktighet", pressure:"Lufttryck",
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
    noBuoy:"ingen aktiv boj", noBuoyArea:"Ingen boj i området", modelled:"WAM-modell — inte uppmätt", away:"km bort",
    navApp:"Appen", navWeather:"Väderdata", brandWeather:"Väder", tagLive:"Live-data", navApp2:"Appen",
    ledeWeather:"Prognoser, havsvind och vågdata i realtid — direkt från Meteorologiska institutets egna öppna data, inte en global modell. Allt nedan är live just nu.", hApp:"På din handled",
    appLede:"Samma data i din klocka — prognos på land, havsvind från kuststationer och vågdata från Meteorologiska institutets bojar. Inget konto, ingen inloggning.",
    p1:"Land: temperatur, vind och byar från närmaste station, prognos för resten av dagen",
    p2:"Hav: vind och byar från 40 kuststationer och 14 insjöstationer",
    p3:"Vågor: höjd, period, riktning och vattentemperatur",
    p4:"Dina egna gränser för vind, byar och våghöjd",
    soon:"Kommer till Connect IQ Store", getIt:"Hämta från Connect IQ Store",
    seeLive:"Se väderdata live på vår vädersida",
    devices:"På finska, svenska och engelska. Fungerar på 70 Garmin-modeller.",
    hScreens:"Varje skärm", capLand:"Land", capSea:"Hav", capWaves:"Vågor", capGlance:"Överblick", capAbout:"Om appen", capSmall:"Forerunner 255s",
    privacy:"Integritet", terms:"Villkor",
    coast:"Kusten", lakes:"Insjöar", trend:"Vind, senaste 12 timmarna", mean:"Medelvind", noTrend:"Ingen vindhistorik tillgänglig", rain:"Nederbörd", rainNone:"inget regn", justNow:"just nu", minAgo:"min sedan", hAgo:"h sedan", retrieved:"Hämtad", loading:"Laddar…",
  },
  en: {
    heroA:"Finnish weather,", heroB:"land and sea.",
    lede:"Forecasts, marine wind and live wave data — from the Finnish Meteorological Institute's own open data, not a global model. Everything below is live right now. Coming soon to a watch near you.",
    tagDev:"In development", tagArea:"Finland",
    navLive:"Live data", navWhat:"What it shows", navData:"About the data",
    onLand:"On land", onLandSub:"Current conditions and the rest of today, from the nearest reporting station.",
    atSea:"At sea", atSeaSub:"Wind from a Finnish marine station, waves from FMI's wave buoys.",
    place:"Place", station:"Sea station", buoy:"Wave buoy", nearest:"Nearest reporting",
    dirFrom:"from {d}", wind:"Wind", gust:"Gust", humidity:"Humidity", pressure:"Pressure",
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
    noBuoy:"no buoy reporting", noBuoyArea:"No buoy in this area", modelled:"WAM model — not measured", away:"km away",
    navApp:"The app", navWeather:"Weather data", brandWeather:"Weather", tagLive:"Live data", navApp2:"The app",
    ledeWeather:"Forecasts, marine wind and live wave data — from the Finnish Meteorological Institute\u2019s own open data, not a global model. Everything below is live right now.", hApp:"On your wrist",
    appLede:"The same data on your watch — land forecasts, marine wind from the coastal stations, and live wave height from FMI's own buoys. No account, no sign-in.",
    p1:"Land: temperature, wind and gusts from the nearest station, plus the rest of the day",
    p2:"Sea: wind and gusts from 40 coastal and 14 inland lake stations",
    p3:"Waves: height, period, direction and water temperature",
    p4:"Your own limits for wind, gust and wave height",
    soon:"Coming to the Connect IQ Store", getIt:"Get it on the Connect IQ Store",
    seeLive:"View weather data live from our weather page",
    devices:"In Finnish, Swedish and English. Runs on 70 Garmin models.",
    hScreens:"Every screen", capLand:"Land", capSea:"Sea", capWaves:"Waves", capGlance:"Glance", capAbout:"About", capSmall:"Forerunner 255s",
    privacy:"Privacy", terms:"Terms",
    coast:"Coast", lakes:"Inland lakes", trend:"Wind, last 12 hours", mean:"Mean", noTrend:"No wind history available", rain:"Rain", rainNone:"no rain", justNow:"just now", minAgo:"min ago", hAgo:"h ago", retrieved:"Retrieved", loading:"Loading…",
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

function rainCell(mm) {
  if (mm === null || mm === undefined) return `<div class="r"></div>`;
  if (mm < 0.05) {
    return `<div class="r" title="${T("rainNone")}"><span class="dry">·</span></div>`;
  }
  return `<div class="r wet" title="${T("rain")} ${mm.toFixed(1)} mm"
    >${mm.toFixed(1)}<span class="u">mm</span></div>`;
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
            <span class="at">${dirArrow(obs.winddirection, 15)}
              ${dirLabel(obs.winddirection) || (obs.windcompass8 ?? "")} ·
              ${at(obs, "windspeedms")}</span></div>
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
            ${rainCell(p.precipitation1h)}
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
    // Two different absences: no buoy serves this water at all (inland, and
    // permanent), or the buoys are lifted out for the winter. Same dash, and
    // the caption is the only thing that tells them apart.
    const wavesBlock = !w ? `<div><span>${T("waves")}</span><b>—</b>
        <span class="at">${m.mode === "none" ? T("noBuoyArea") : T("noBuoy")}</span></div>`
      : `<div><span>${T("waveH")}</span><b>${fmt(w.wave_height_m, 1)} m</b>
           <span class="at">${w.measured ? w.name : T("modelled")}</span></div>
         <div><span>${T("period")}</span><b>${fmt(w.wave_period_s, 1)} s
             ${dirArrow(w.wave_direction_deg, 22)}</b>
           <span class="at">${w.wave_direction_deg != null
             ? dirLabel(w.wave_direction_deg) + " (" + Math.round(w.wave_direction_deg) + "°)"
             : ""}</span></div>
         <div><span>${T("water")}</span><b>${fmt(w.water_temp_c, 1)}°C</b>
           <span class="at">${w.measured && w.distance_km != null ? w.distance_km + " " + T("away") : ""}</span></div>`;
    host.innerHTML = `
      <div class="grid">
        <div><span>${T("wind")}</span><b>${fmt(s.windspeedms, 1)} m/s
            ${dirArrow(s.winddirection, 22)}</b>
          <span class="at">${dirLabel(s.winddirection) || (s.windcompass8 ?? "")} ·
            ${at(s, "windspeedms")}</span></div>
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

/* Direction label — Finnish suffixes the compass point, the others prefix a
   preposition, so the whole phrase is a per-language format string. */
function dirLabel(degreesFrom) {
  const c = fromCompass(degreesFrom);
  return c ? T("dirFrom").replace("{d}", c) : "";
}

/* The store button, or an honest placeholder.
   STORE_URL is unset until the app is published, and a dead "Get it" link is
   worse than saying it is not out yet. */
let STORE_URL = null;
let WEATHER_URL = "https://weather.tallimedia.com";
let APP_URL = "https://weatherapp.tallimedia.com";

function renderNavCta() {
  const host = $("#nav-cta");
  if (!host) return;
  host.innerHTML = STORE_URL
    ? `<a class="btn btn-primary blueprint" href="${STORE_URL}"
         style="color:var(--color-bg);text-transform:uppercase;letter-spacing:0.06em">${T("getIt")}
         <i class="corner tl"></i><i class="corner tr"></i>
         <i class="corner bl"></i><i class="corner br"></i></a>`
    : `<a class="btn blueprint" href="${WEATHER_ONLY ? APP_URL : WEATHER_URL}"
         style="text-transform:uppercase;letter-spacing:0.06em">${
           WEATHER_ONLY ? T("navApp2") : T("navWeather")}
         <i class="corner tl"></i><i class="corner tr"></i>
         <i class="corner bl"></i><i class="corner br"></i></a>`;
}

function renderCta() {
  renderNavCta();
  const host = $("#app-cta");
  if (!host) return;
  const live = `<a class="cta ${STORE_URL ? "cta-quiet" : "cta-primary"}"
     href="${WEATHER_URL}">${T("seeLive")}</a>`;
  host.innerHTML = STORE_URL
    ? `<a class="cta cta-primary" href="${STORE_URL}">${T("getIt")}</a>${live}`
    : `<span class="cta cta-quiet" style="cursor:default">${T("soon")}</span>${live}`;
}

/* The weather page hides the app pitch: someone who came for the weather
   should get the weather, not a watch app above it. */
const WEATHER_ONLY = document.body.dataset.site === "weather";

function applyStrings() {
  document.documentElement.lang = LANG;
  // Declared before anything uses it. It used to sit further down, after the
  // per-site blocks below already called it — a temporal dead zone, so
  // applyStrings threw on the weather page and every element after the throw
  // kept whatever language it had. That read as "translation half works".
  const set = (id, k) => { const e = $(id); if (e) e.textContent = T(k); };
  // The live data lives only under the weather hostname, and the app pitch
  // only under the app one. Each page hides the other's half rather than
  // being a separate template.
  // The data view is two sections, land and sea. Hiding only the first left
  // the sea half on the app page, stuck at "Loading…" forever because that
  // page deliberately does not fetch.
  const hide = WEATHER_ONLY
    ? ["#app", "#screens", "#nav-app", "#tag-dev"]
    : ["#live", "#live-sea"];
  for (const id of hide) {
    const e = $(id);
    if (e) e.style.display = "none";
  }
  // The weather page is not the app and should not wear its clothes: no app
  // name in the nav, no "Connect IQ widget" tag, and a lede that does not end
  // by advertising a watch.
  if (WEATHER_ONLY) {
    set("#nav-brand", "brandWeather");
    set("#tag-kind", "tagLive");
    set("#lede", "ledeWeather");
  }
  // On the app page the nav entry survives, repointed across rather than
  // removed: someone looking for the data should find the way to it.
  if (!WEATHER_ONLY) {
    const nav = $("#nav-live");
    if (nav) { nav.href = WEATHER_URL; nav.textContent = T("navWeather"); }
  }
  set("#nav-live","navLive"); set("#nav-what","navWhat"); set("#nav-data","navData");
  set("#tag-dev","tagDev"); set("#tag-area","tagArea");
  set("#hero-a","heroA"); set("#hero-b","heroB"); set("#lede","lede");
  set("#h-land","onLand"); set("#sub-land","onLandSub");
  set("#h-sea","atSea"); set("#sub-sea","atSeaSub");
  set("#l-place","place"); set("#l-station","station"); set("#l-buoy","buoy");
  set("#h-what","whatTitle"); set("#h-data","dataTitle"); set("#foot-note","footNote");
  set("#nav-app","navApp"); set("#h-app","hApp"); set("#app-lede","appLede");
  set("#app-devices","devices");
  set("#h-screens","hScreens");
  set("#cap-land","capLand"); set("#cap-sea","capSea"); set("#cap-waves","capWaves");
  set("#cap-glance","capGlance"); set("#cap-about","capAbout");
  set("#foot-privacy","privacy"); set("#foot-terms","terms");
  const pts = $("#app-points");
  if (pts) pts.innerHTML = ["p1","p2","p3","p4"].map((k) => `<li>${T(k)}</li>`).join("");
  renderCta();
  for (const i of [1,2,3,4]) { set(`#c${i}t`,`c${i}t`); set(`#c${i}`,`c${i}`); }
  for (const i of [1,2,3])   { set(`#d${i}t`,`d${i}t`); set(`#d${i}`,`d${i}`); }
  const b = $("#buoy");
  if (b && b.options.length) b.options[0].textContent = T("nearest");
}

/* Wind trend: mean and gust over the last 12 hours, from the same station
   record as the sea box above — same producer, same fmisid, same two
   parameters, just more rows.

   Mean and gust are not two independent categories; the gust is the upper
   envelope of the same wind. So the band between them is filled: its height
   is the gust headroom, which is the part a sailor reads. Both lines are
   still drawn and labelled, because the ask was for both.

   Blue against rust, not two blues. Steps of the site's own accent ramp were
   distinguishable on paper but read as one family on screen — the eye had to
   work out which line was which. Warm against cool is the standard
   colourblind-safe pairing, and these two were measured rather than picked:
   lightness band, chroma floor, CVD separation (protan dE 22.2, tritan 30.9),
   normal vision dE 28.9, and contrast against the panel all pass. The band
   takes the gust hue because that is the region it describes. */
const TREND = { mean: "#2b6cb0", gust: "#c2410c", band: "#c2410c", w: 720, h: 190 };

function trendPath(points, key, x, y) {
  let d = "", pen = false;
  for (const p of points) {
    const v = p[key];
    if (v == null) { pen = false; continue; }   // a gap stays a gap
    d += `${pen ? "L" : "M"}${x(p.t).toFixed(1)} ${y(v).toFixed(1)} `;
    pen = true;
  }
  return d.trim();
}

function renderTrend(data) {
  const pts = (data.points || []).filter((p) => p.wind != null || p.gust != null);
  if (pts.length < 2) return `<p class="msg">${T("noTrend")}</p>`;

  const { w, h } = TREND;
  const pad = { t: 16, r: 54, b: 26, l: 34 };
  const t0 = pts[0].t, t1 = pts[pts.length - 1].t;
  const peak = Math.max(...pts.map((p) => Math.max(p.gust ?? 0, p.wind ?? 0)));
  // Round the top up to a whole number of m/s so the gridlines are readable
  // values rather than whatever the maximum happened to be.
  const top = Math.max(4, Math.ceil(peak + 0.5));
  const x = (t) => pad.l + ((t - t0) / Math.max(1, t1 - t0)) * (w - pad.l - pad.r);
  const y = (v) => pad.t + (1 - v / top) * (h - pad.t - pad.b);

  // Band between mean and gust, closed back along the mean.
  const withBoth = pts.filter((p) => p.wind != null && p.gust != null);
  const band = withBoth.length > 1
    ? "M" + withBoth.map((p) => `${x(p.t).toFixed(1)} ${y(p.gust).toFixed(1)}`).join(" L")
      + " L" + withBoth.slice().reverse().map((p) => `${x(p.t).toFixed(1)} ${y(p.wind).toFixed(1)}`).join(" L") + " Z"
    : "";

  const step = top <= 8 ? 2 : top <= 16 ? 4 : 5;
  let grid = "";
  for (let v = 0; v <= top; v += step) {
    grid += `<line x1="${pad.l}" y1="${y(v).toFixed(1)}" x2="${w - pad.r}" y2="${y(v).toFixed(1)}"
               stroke="var(--color-divider)" stroke-width="1"></line>
             <text x="${pad.l - 6}" y="${(y(v) + 4).toFixed(1)}" text-anchor="end"
               font-size="11" fill="var(--color-neutral-600)">${v}</text>`;
  }

  // Hour marks every three hours, on the hour.
  let ticks = "";
  for (const p of pts) {
    const d = new Date(p.t * 1000);
    if (d.getMinutes() !== 0 || d.getHours() % 3 !== 0) continue;
    ticks += `<text x="${x(p.t).toFixed(1)}" y="${h - 8}" text-anchor="middle"
                font-size="11" fill="var(--color-neutral-600)">${String(d.getHours()).padStart(2, "0")}</text>`;
  }

  const last = pts[pts.length - 1];
  const endLabel = (v, colour, dy) => v == null ? "" :
    `<text x="${w - pad.r + 6}" y="${(y(v) + dy).toFixed(1)}" font-size="12" font-weight="600"
       fill="${colour}" font-variant-numeric="tabular-nums">${v.toFixed(1)}</text>`;

  return `
    <div class="trend-head">
      <span class="trend-title">${T("trend")}</span>
      <span class="trend-key"><i style="background:${TREND.mean}"></i>${T("mean")}</span>
      <span class="trend-key"><i style="background:${TREND.gust}"></i>${T("gust")}</span>
      <span class="trend-read" id="trend-read"></span>
    </div>
    <svg viewBox="0 0 ${w} ${h}" class="trend-svg" role="img"
         aria-label="${T("trend")}, ${T("mean")} ${fmt(last.wind, 1)} m/s, ${T("gust")} ${fmt(last.gust, 1)} m/s">
      ${grid}${ticks}
      ${band ? `<path d="${band}" fill="${TREND.band}" opacity=".13"></path>` : ""}
      <path d="${trendPath(pts, "gust", x, y)}" fill="none" stroke="${TREND.gust}" stroke-width="2"
            stroke-linejoin="round" stroke-linecap="round"></path>
      <path d="${trendPath(pts, "wind", x, y)}" fill="none" stroke="${TREND.mean}" stroke-width="2"
            stroke-linejoin="round" stroke-linecap="round"></path>
      ${endLabel(last.gust, TREND.gust, -6)}${endLabel(last.wind, TREND.mean, 14)}
      <line id="trend-cross" x1="0" y1="${pad.t}" x2="0" y2="${h - pad.b}"
            stroke="var(--color-neutral-600)" stroke-width="1" opacity="0"></line>
      <rect x="${pad.l}" y="0" width="${w - pad.l - pad.r}" height="${h}" fill="transparent"
            id="trend-hit"></rect>
    </svg>
    <p class="note">${data.station.name} · ${T("footData")} ${data.attribution}</p>`;
}

async function loadMarineTrend(fmisid) {
  const host = $("#marine-trend");
  if (!host) return;
  try {
    const data = await jget(`/v1/marine-series?fmisid=${fmisid}&hours=12`);
    host.innerHTML = renderTrend(data);
    wireTrendHover(host, data);
  } catch (err) {
    host.innerHTML = `<p class="msg">${T("noTrend")}</p>`;
  }
}

/* Hover readout. An SVG line chart with no way to interrogate a point makes
   the reader guess at values between the gridlines. */
function wireTrendHover(host, data) {
  const svg = host.querySelector(".trend-svg");
  const hit = host.querySelector("#trend-hit");
  const cross = host.querySelector("#trend-cross");
  const read = host.querySelector("#trend-read");
  if (!svg || !hit || !read) return;
  const pts = (data.points || []).filter((p) => p.wind != null || p.gust != null);
  const t0 = pts[0].t, t1 = pts[pts.length - 1].t;
  const { w } = TREND, pad = { l: 34, r: 54 };

  function at(evt) {
    const box = svg.getBoundingClientRect();
    const sx = ((evt.clientX - box.left) / box.width) * w;      // client px -> viewBox units
    const frac = (sx - pad.l) / (w - pad.l - pad.r);
    const target = t0 + frac * (t1 - t0);
    let best = pts[0];
    for (const p of pts) if (Math.abs(p.t - target) < Math.abs(best.t - target)) best = p;
    return best;
  }
  function show(evt) {
    const p = at(evt);
    const px = pad.l + ((p.t - t0) / Math.max(1, t1 - t0)) * (w - pad.l - pad.r);
    cross.setAttribute("x1", px); cross.setAttribute("x2", px);
    cross.setAttribute("opacity", ".35");
    read.textContent = `${localHour(p.t)} · ${T("mean")} ${fmt(p.wind, 1)} · ${T("gust")} ${fmt(p.gust, 1)} m/s`;
  }
  function hide() { cross.setAttribute("opacity", "0"); read.textContent = ""; }
  hit.addEventListener("mousemove", show);
  hit.addEventListener("mouseleave", hide);
  hit.addEventListener("touchmove", (e) => { show(e.touches[0]); }, { passive: true });
  hit.addEventListener("touchend", hide);
}

function refresh() {
  // The app page does not show the data, so it should not fetch it — that
  // would be four upstream calls per visit for something nobody sees.
  if (!WEATHER_ONLY) { return; }
  loadNow($("#place").value.trim() || "Helsinki");
  loadMarine($("#station").value, $("#buoy").value);
  loadMarineTrend($("#station").value);
}

(async function init() {
  try {
    const meta = await jget("/v1/app");
    STORE_URL = meta.store_url || null;
    if (meta.weather_url) WEATHER_URL = meta.weather_url;
    if (meta.app_url) APP_URL = meta.app_url;
  } catch (_) { STORE_URL = null; }
  const reg = await jget("/v1/stations");
  // Grouped: coast and lakes are both "sea stations" here, but a reader
  // scanning 54 names wants to know which water they are looking at.
  const opt = (s) =>
    `<option value="${s.fmisid}"${s.fmisid === 100996 ? " selected" : ""}>${s.name}</option>`;
  $("#station").innerHTML =
    `<optgroup label="${T("coast")}">${reg.marine_stations.map(opt).join("")}</optgroup>` +
    `<optgroup label="${T("lakes")}">${(reg.lake_stations || []).map(opt).join("")}</optgroup>`;
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
