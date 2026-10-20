import Toybox.Application;
import Toybox.Attention;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Backend client.
//!
//! Responses are **normalised into a flat dictionary of primitives on receipt**
//! rather than kept as the raw JSON. Two reasons, one of them learned the hard
//! way: storing a deeply nested response dictionary in Application.Storage does
//! not round-trip — reading it back faulted with "Illegal Access (Out of
//! Bounds)" at startup. And a flat shape the app owns means the views never
//! depend on the server's JSON layout.
//!
//! Payloads are small by design; the backend does the reshaping so Connect IQ
//! never has to parse more than a few hundred bytes (RESEARCH.md §10).
(:glance)
module Api {

    enum { STATE_IDLE, STATE_LOADING, STATE_OK, STATE_ERROR }

    var land as Dictionary? = null;
    var forecast as Dictionary? = null;
    var road as Dictionary? = null;
    var marine as Dictionary? = null;
    var forecast3 as Dictionary? = null;

    var landState = STATE_IDLE;
    var forecastState = STATE_IDLE;
    var roadState = STATE_IDLE;
    var marineState = STATE_IDLE;
    var forecast3State = STATE_IDLE;

    //! Roads more than this from the nearest FMI road station are not "your
    //! roads" any more than a wave buoy 50 km out is "your sea" (RESEARCH.md
    //! §16) — provisional, easy to retune, not yet validated against a wide
    //! spread of towns.
    const ROAD_ICE_MAX_KM = 30.0;

    //! Fires at most once per app process. Not reset by a manual refresh —
    //! the buzz is a launch-time flag, not a per-refresh alert (RESEARCH.md
    //! §16: "once per launch, never per draw").
    var _roadBuzzed = false;

    //! Why the last request failed, so the page can say something true rather
    //! than blaming the phone for everything.
    enum { FAIL_NONE, FAIL_OFFLINE, FAIL_PLACE, FAIL_SERVER }
    var failure = FAIL_NONE;

    //! Wall-clock second of the last refresh. Select fires a refresh, and
    //! without a floor a held button queues requests faster than the radio can
    //! retire them — which is what fills the BLE queue and then reads, wrongly,
    //! as "no connection".
    var lastRefresh = 0;
    const MIN_REFRESH_SECS = 30;

    //! How long a glance fetch is considered fresh enough.
    //!
    //! The glance fires on every scroll past it in the carousel, so without a
    //! floor a thumb on the widget list is two web requests per pass. Five
    //! minutes also matches the data: FMI republishes observations about every
    //! ten minutes and the backend caches for five, so a faster glance would
    //! spend radio on bytes it already has.
    const GLANCE_MIN_SECS = 300;

    //! The glance runs in **its own process**, started and stopped as the
    //! carousel moves, so an in-memory timestamp does not survive between
    //! showings. It has to persist, and Storage is the only thing that does.
    function glanceDue() as Boolean {
        var last = null;
        try { last = Application.Storage.getValue("gAt"); } catch (e) { last = null; }
        var now = Time.now().value();
        if (last instanceof Number && now - last < GLANCE_MIN_SECS && now >= last) {
            return false;
        }
        try { Application.Storage.setValue("gAt", now); } catch (e) {}
        return true;
    }

    //! Maps a Communications result to a reason.
    //!
    //! Every non-200 used to render as "No connection". A queue-full, an
    //! oversized payload and a genuinely absent phone are different problems
    //! and only one of them is the user's to fix.
    function classify(code as Number) as Number {
        if (code == 404) { return FAIL_PLACE; }
        if (code >= 400 && code < 600) { return FAIL_SERVER; }
        if (code == Communications.BLE_REQUEST_TOO_LARGE) { return FAIL_SERVER; }
        return FAIL_OFFLINE;
    }

    function options() as Dictionary {
        return {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => { "Accept" => "application/json" }
        };
    }

    //! FMI returns weather text already localised, so the app never translates
    //! symbol codes itself (RESEARCH.md §16).
    function lang() as String {
        var l = System.getDeviceSettings().systemLanguage;
        if (l == System.LANGUAGE_FIN) { return "fi"; }
        if (l == System.LANGUAGE_SWE) { return "sv"; }
        return "en";
    }

    // ------------------------------------------------------------ helpers

    function pick(d, key as String) {
        if (d instanceof Dictionary && d.hasKey(key)) { return d[key]; }
        return null;
    }

    function pickIn(d, outer as String, inner as String) {
        return pick(pick(d, outer), inner);
    }

    //! Coerce a JSON value to a Float, or null. Guards against a string or a
    //! missing key reaching the drawing code.
    function f(v) as Float? {
        if (v instanceof Float) { return v; }
        if (v instanceof Number) { return v.toFloat(); }
        if (v instanceof Double) { return v.toFloat(); }
        return null;
    }

    function n(v) as Number? {
        if (v instanceof Number) { return v; }
        if (v instanceof Float || v instanceof Double) { return v.toNumber(); }
        return null;
    }

    function s(v) as String? {
        if (v instanceof String) { return v; }
        return null;
    }

    // -------------------------------------------------------------- cache

    //! Offline cache. Keeps the last reading so a page survives the phone
    //! going out of range — for a marine app that is the normal case, not the
    //! edge case. Only flat dictionaries of primitives are stored.
    function save(key as String, flat as Dictionary) as Void {
        try { Application.Storage.setValue(key, flat); } catch (e) {}
    }

    function load(key as String) as Dictionary? {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Dictionary) { return v; }
        } catch (e) {}
        return null;
    }

    function restore() as Void {
        land = load("f_land");
        forecast = load("f_fc");
        road = load("f_road");
        marine = load("f_marine");
        forecast3 = load("f_fc3");
        if (land != null) { landState = STATE_OK; }
        if (forecast != null) { forecastState = STATE_OK; }
        if (road != null) { roadState = STATE_OK; }
        if (marine != null) { marineState = STATE_OK; }
        if (forecast3 != null) { forecast3State = STATE_OK; }
    }

    // --------------------------------------------------------------- land

    function fetchLand() as Void {
        landState = STATE_LOADING;
        Communications.makeWebRequest(
            Config.BASE_URL + "/v1/observations",
            { "place" => Config.landPlace() },
            options(), new Lang.Method(Api, :onLand));
    }

    function onLand(code as Number,
                    data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        if (code == 200 && data instanceof Dictionary) {
            var flat = {
                "name"  => s(pick(data, "stationname")),
                "dist"  => f(pick(data, "distance")),
                "temp"  => f(pick(data, "temperature")),
                "wind"  => f(pick(data, "windspeedms")),
                "gust"  => f(pick(data, "windgust")),
                "dir"   => f(pick(data, "winddirection")),
                "atT"   => n(pickIn(data, "at", "temperature")),
                "atW"   => n(pickIn(data, "at", "windspeedms")),
                // Two-tier wind fallback (RESEARCH.md §C5j): "station" is the
                // normal case, "road" is a nearby Fintraffic road-weather
                // station's live reading, "forecast" is a modelled hour-ahead
                // value — only the latter two need a row label.
                "windSrc" => s(pick(data, "wind_source")),
                // "nearby" when the nearest station reports wind but no
                // temperature and the backend borrowed one from the next
                // reporting station (<= 25 km) — marked with an asterisk.
                "tempSrc" => s(pick(data, "temp_source"))
            };
            land = flat;
            landState = STATE_OK;
            save("f_land", flat);
        } else {
            landState = STATE_ERROR;
            failure = classify(code);
        }
        WatchUi.requestUpdate();
        fetchForecast();
    }

    // ----------------------------------------------------------- forecast

    //! Repurposed 2026-10-15 (RESEARCH.md §27 update) from a 48h/6h-step
    //! fetch feeding Land's old 4-slot temp strip, to a 3h/15min-step fetch
    //! feeding the 1h/3h rain-likelihood row — the strip is gone, and the
    //! near-term `pop` figures genuinely need the finer step: verified live
    //! that FMI returns distinct 15-minute pop values, where the old 6h step
    //! could only ever say "something in the next 6 hours".
    function fetchForecast() as Void {
        forecastState = STATE_LOADING;
        Communications.makeWebRequest(
            Config.BASE_URL + "/v1/forecast",
            { "place" => Config.landPlace(), "hours" => 3, "step" => 15 },
            options(), new Lang.Method(Api, :onForecast));
    }

    //! Highest `pop` within the next hour and within the next three — a
    //! max, not an average, because "any single quarter-hour might rain" is
    //! the useful answer here, the same reasoning onForecast3() below uses
    //! for its own per-day pop.
    //!
    //! Replaced the live temp-trend sparkline with this, 2026-10-15: on real
    //! hardware the line read as meaningless noise (ordinary station wobble
    //! filled the whole chart height) and, sitting directly under the Wind
    //! row with no label, Nico read it as wind data, not temperature.
    //! Nico's call: two rain-probability numbers instead, which need no
    //! chart to be unambiguous.
    function onForecast(code as Number,
                        data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        if (code == 200 && data instanceof Dictionary) {
            var pop1h = null;
            var pop3h = null;
            // Rest-of-today aggregates from the same 15-minute points, so
            // the Forecast page's Today row has something to show late in
            // the evening, when the coarse 6-hourly grid has no point left
            // in the day (it showed "-/-" otherwise; Nico, 2026-10-20).
            var tHi = null;
            var tLo = null;
            var tRain = 0.0;
            var tSym = null;
            var tWind = null;
            var tGust = null;
            var tPop = null;
            var pts = pick(data, "points");
            if (pts instanceof Array) {
                var now = Time.now().value();
                var today = _localDay(now);
                for (var i = 0; i < pts.size(); i += 1) {
                    var e = n(pick(pts[i], "epochtime"));
                    if (e == null || e < now - 450 || e > now + 10800) { continue; }
                    var pv = f(pick(pts[i], "pop"));
                    if (pv != null) {
                        if (pop3h == null || pv > pop3h) { pop3h = pv; }
                        if (e <= now + 3600 && (pop1h == null || pv > pop1h)) { pop1h = pv; }
                    }
                    if (_localDay(e) != today) { continue; }
                    var t = f(pick(pts[i], "temperature"));
                    if (t != null) {
                        if (tHi == null || t > tHi) { tHi = t; }
                        if (tLo == null || t < tLo) { tLo = t; }
                    }
                    // precipitation1h is mm per hour at each point; these
                    // points are 15 minutes apart, so a quarter each.
                    var p1h = f(pick(pts[i], "precipitation1h"));
                    if (p1h != null) { tRain += p1h / 4.0; }
                    if (tSym == null) {
                        tSym = n(pick(pts[i], "smartsymbol"));
                        tWind = f(pick(pts[i], "windspeedms"));
                        tGust = f(pick(pts[i], "hourlymaximumgust"));
                    }
                    if (pv != null && (tPop == null || pv > tPop)) { tPop = pv; }
                }
            }
            var flat = { "pop1h" => pop1h, "pop3h" => pop3h,
                         "tHi" => tHi, "tLo" => tLo, "tRain" => tRain,
                         "tSym" => tSym, "tWind" => tWind, "tGust" => tGust,
                         "tPop" => tPop };
            forecast = flat;
            forecastState = STATE_OK;
            save("f_fc", flat);
        } else {
            forecastState = STATE_ERROR;
        }
        WatchUi.requestUpdate();
        fetchRoad();
    }

    // ---------------------------------------------------------------- road

    //! No GPS by design (RESEARCH.md §16), so this asks by the same
    //! configured land place as fetchLand()/fetchForecast() — the backend
    //! resolves it the same way `/v1/forecast` already does.
    function fetchRoad() as Void {
        roadState = STATE_LOADING;
        Communications.makeWebRequest(
            Config.BASE_URL + "/v1/road",
            { "place" => Config.landPlace(), "lang" => lang() },
            options(), new Lang.Method(Api, :onRoad));
    }

    function onRoad(code as Number,
                    data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        var level = null;
        if (code == 200 && data instanceof Dictionary) {
            var dist = f(pickIn(data, "surface", "distance_km"));
            // Beyond the cap this is not "your road" any more than a distant
            // buoy is "your sea" — treated the same as no data at all.
            if (dist == null || dist <= ROAD_ICE_MAX_KM) {
                level = s(pickIn(data, "ice_risk", "level"));
            }
            road = { "level" => level };
            roadState = STATE_OK;
            save("f_road", road);
        } else {
            roadState = STATE_ERROR;
        }
        maybeBuzzRoad(level);
        WatchUi.requestUpdate();
        fetchMarine();
    }

    //! Once per app process, not per refresh — a launch-time flag that
    //! something needs attention on a page the user may not be looking at,
    //! not a repeated alert every time Select is pressed (RESEARCH.md §16).
    function maybeBuzzRoad(level as String?) as Void {
        if (_roadBuzzed) { return; }
        _roadBuzzed = true;
        if (level == null) { return; }
        if (!(level.equals("moderate") || level.equals("high"))) { return; }
        if (!(Attention has :vibrate)) { return; }
        try {
            Attention.vibrate([new Attention.VibeProfile(50, 300)]);
        } catch (e) { }
    }

    // ------------------------------------------------------------- marine

    function fetchMarine() as Void {
        marineState = STATE_LOADING;
        var params = { "fmisid" => Config.seaStation(), "lang" => lang() };
        var buoy = Config.seaBuoy();
        if (buoy > 0) { params["buoy_fmisid"] = buoy; }
        Communications.makeWebRequest(
            Config.BASE_URL + "/v1/marine", params, options(), new Lang.Method(Api, :onMarine));
    }

    function onMarine(code as Number,
                      data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        if (code == 200 && data instanceof Dictionary) {
            var st = pick(data, "station");
            var wv = pick(data, "waves");
            var measured = pick(wv, "measured");
            var flat = {
                "mode"    => s(pick(data, "mode")),
                "stName"  => s(pick(st, "name")),
                "stWind"  => f(pick(st, "windspeedms")),
                "stGust"  => f(pick(st, "windgust")),
                "stDir"   => f(pick(st, "winddirection")),
                "stTemp"  => f(pick(st, "temperature")),
                "stAt"    => n(pickIn(st, "at", "windspeedms")),
                "hasWave" => wv != null,
                "wMeas"   => measured == true,
                "wName"   => s(pick(wv, "name")),
                "wDist"   => f(pick(wv, "distance_km")),
                "wHs"     => f(pick(wv, "wave_height_m")),
                "wPer"    => f(pick(wv, "wave_period_s")),
                "wDir"    => f(pick(wv, "wave_direction_deg")),
                "wTemp"   => f(pick(wv, "water_temp_c")),
                // Independent of "wMeas" (wave height) — a buoy's water
                // sensor can be silent while its wave sensor isn't, and the
                // backend's hydrodyn fallback fills water_temp_c in that
                // case without that making the wave height itself modelled
                // (RESEARCH.md §26). Defaults true so a response from an
                // older backend without this field reads as "measured" —
                // the pre-v1.2 behaviour — rather than wrongly labelling
                // every water reading "modelled".
                "wTempMeas" => pick(wv, "water_measured") != false,
                "wAt"     => n(pick(wv, "observed_epoch")),
                "windWarn" => s(pick(data, "wind_warning")),
                "waveWarn" => s(pick(data, "wave_warning"))
            };
            marine = flat;
            marineState = STATE_OK;
            save("f_marine", flat);
        } else {
            marineState = STATE_ERROR;
            failure = classify(code);
        }
        WatchUi.requestUpdate();
        // Opt-in and last in the chain (RESEARCH.md §27): most installs have
        // this off, so the common case is one fewer request, not one more.
        if (Config.showForecast()) { fetchForecast3(); }
    }

    // ------------------------------------------------------- forecast (3d)

    //! Civil (proleptic Gregorian) day number for a local calendar date —
    //! Howard Hinnant's days_from_civil, adapted. Lets two dates be compared
    //! by simple subtraction regardless of month/year boundaries, which
    //! `Gregorian.info()`'s bare day-of-month field cannot do on its own
    //! (year is always >= 2026 here, so the usual negative-year adjustment
    //! in the reference algorithm never triggers and is left out).
    function _civilDay(y as Number, m as Number, d as Number) as Number {
        var yy = y - (m <= 2 ? 1 : 0);
        var era = yy / 400;
        var yoe = yy - era * 400;
        var doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
        var doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        return era * 146097 + doe - 719468;
    }

    //! Which calendar day (local time) an epoch falls on, as a civil day
    //! number — not an absolute "hours since now" bucket, so "Tomorrow"
    //! lines up with the actual calendar date rather than a rolling 24h
    //! window that drifts against it depending what time of day this runs.
    function _localDay(epoch as Number) as Number {
        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return _civilDay(info.year, info.month, info.day);
    }

    //! FMI's smartsymbol has ~20 categories across day/night variants
    //! (RESEARCH.md §16, §27); this page draws only four. Folds night codes
    //! (+100) to their day equivalent first, since the icon carries no
    //! day/night distinction here. Defaults to :rain for anything
    //! precipitating that isn't explicitly snow (sleet, hail, thunder all
    //! read closer to "wet" than "clear" at a glance), and :cloudy for a
    //! missing code — never claims clear skies when the data doesn't say so.
    function _symbolKind(code as Number?) as Symbol {
        if (code == null) { return :cloudy; }
        var c = code % 100;
        if (c == 1 || c == 2) { return :clear; }
        if (c == 4 || c == 6 || c == 7 || c == 9) { return :cloudy; }
        if (c >= 51 && c <= 59) { return :snow; }
        return :rain;
    }

    function fetchForecast3() as Void {
        forecast3State = STATE_LOADING;
        Communications.makeWebRequest(
            Config.BASE_URL + "/v1/forecast",
            { "place" => Config.landPlace(), "hours" => 90, "step" => 360, "lang" => lang() },
            options(), new Lang.Method(Api, :onForecast3));
    }

    //! Groups points by local calendar day into Today / Tomorrow / Day+2 —
    //! shifted from Tomorrow/+2/+3, 2026-10-15 (RESEARCH.md §27 update): a
    //! tester wanted rain data for today, and this endpoint's query already
    //! starts at "now" (app/main.py), so today's bucket is naturally
    //! "rest of day", not the whole day retroactively. Today/Tomorrow keep
    //! wind and a daily rain total plus a rest-of/whole-day rain
    //! probability; Day+2 keeps only hi/lo and a representative symbol
    //! (RESEARCH.md §27 — "basics only").
    function onForecast3(code as Number,
                         data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        if (code == 200 && data instanceof Dictionary) {
            var pts = pick(data, "points");
            var today = _localDay(Time.now().value());
            // Index 0 = Today, 1 = Tomorrow, 2 = Day+2, 3 = Day+3. The
            // fourth bucket is only drawn once Today is empty and the page
            // shifts a day (see Pages.drawForecast).
            var hi = [null, null, null, null] as Array<Float?>;
            var lo = [null, null, null, null] as Array<Float?>;
            var sym = [null, null, null, null] as Array<Number?>;      // midday-closest point's symbol
            var midDist = [999, 999, 999, 999] as Array<Number>;      // distance from that point to 12:00 local
            var rain = [0.0, 0.0, 0.0, 0.0] as Array<Float>;
            var pop = [null, null, null, null] as Array<Float?>;       // highest precipitation probability seen
            var wind = [null, null, null, null] as Array<Float?>;      // midday-closest point's wind
            var gust = [null, null, null, null] as Array<Float?>;
            if (pts instanceof Array) {
                for (var i = 0; i < pts.size(); i += 1) {
                    var e = n(pick(pts[i], "epochtime"));
                    if (e == null) { continue; }
                    var dayOffset = _localDay(e) - today;
                    if (dayOffset < 0 || dayOffset > 3) { continue; }
                    var idx = dayOffset;
                    var t = f(pick(pts[i], "temperature"));
                    if (t != null) {
                        if (hi[idx] == null || t > hi[idx]) { hi[idx] = t; }
                        if (lo[idx] == null || t < lo[idx]) { lo[idx] = t; }
                    }
                    var p1h = f(pick(pts[i], "precipitation1h"));
                    if (p1h != null) { rain[idx] = rain[idx] + p1h; }
                    var pv = f(pick(pts[i], "pop"));
                    if (pv != null && (pop[idx] == null || pv > pop[idx])) { pop[idx] = pv; }
                    // The point whose local hour is nearest noon stands in
                    // for "the day" — same reasoning daySummary() uses on
                    // the web for picking a representative symbol.
                    var info = Gregorian.info(new Time.Moment(e), Time.FORMAT_SHORT);
                    var dist = (info.hour - 12).abs();
                    if (dist < midDist[idx]) {
                        midDist[idx] = dist;
                        sym[idx] = n(pick(pts[i], "smartsymbol"));
                        wind[idx] = f(pick(pts[i], "windspeedms"));
                        gust[idx] = f(pick(pts[i], "hourlymaximumgust"));
                    }
                }
            }
            // Fold in the 15-minute points' view of today (onForecast ran
            // earlier in the chain). Range widens, never narrows; the
            // coarse grid keeps the wind/symbol when it has them.
            var near = forecast;
            var nHi = f(pick(near, "tHi"));
            if (nHi != null) {
                var nLo = f(pick(near, "tLo"));
                if (hi[0] == null || nHi > hi[0]) { hi[0] = nHi; }
                if (nLo != null && (lo[0] == null || nLo < lo[0])) { lo[0] = nLo; }
                var nRain = f(pick(near, "tRain"));
                if (nRain != null && nRain > rain[0]) { rain[0] = nRain; }
                if (sym[0] == null) { sym[0] = n(pick(near, "tSym")); }
                if (wind[0] == null) { wind[0] = f(pick(near, "tWind")); }
                if (gust[0] == null) { gust[0] = f(pick(near, "tGust")); }
                var nPop = f(pick(near, "tPop"));
                if (nPop != null && (pop[0] == null || nPop > pop[0])) { pop[0] = nPop; }
            }
            var flat = {
                "hi" => hi, "lo" => lo, "sym" => sym,
                "rain" => rain, "pop" => pop, "wind" => wind, "gust" => gust
            };
            forecast3 = flat;
            forecast3State = STATE_OK;
            save("f_fc3", flat);
        } else {
            forecast3State = STATE_ERROR;
        }
        WatchUi.requestUpdate();
    }

    //! Fetch the three payloads **one after another**, not all at once.
    //!
    //! Connect IQ's request queue is shallow and shared with the system. Three
    //! simultaneous requests — plus the two the glance makes — overrun it, and
    //! the failure surfaces as an ordinary error the user reads as "no phone".
    //! Each response chains the next from its own callback.
    function refreshAll() as Void {
        var now = Time.now().value();
        if (now - lastRefresh < MIN_REFRESH_SECS && lastRefresh != 0) { return; }
        lastRefresh = now;
        fetchLand();
    }

    //! Force a refresh regardless of the floor — Select, or a settings change.
    //!
    //! All four states go to LOADING up front, not as each request starts.
    //! The fetches are chained, so marking them one at a time would leave the
    //! Sea page showing nothing for three round trips after Select was
    //! pressed, which is the silence this was meant to fix. A refresh of all
    //! four is genuinely under way the moment the chain starts.
    function refreshNow() as Void {
        lastRefresh = Time.now().value();
        landState = STATE_LOADING;
        forecastState = STATE_LOADING;
        roadState = STATE_LOADING;
        marineState = STATE_LOADING;
        fetchLand();
    }

    //! Read a normalised field. Everything the views draw goes through here.
    function v(d as Dictionary?, key as String) {
        if (d == null) { return null; }
        if (!d.hasKey(key)) { return null; }
        return d[key];
    }
}
