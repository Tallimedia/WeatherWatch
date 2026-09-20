import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;
import Toybox.Time;
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
    var marine as Dictionary? = null;

    var landState = STATE_IDLE;
    var forecastState = STATE_IDLE;
    var marineState = STATE_IDLE;

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
        marine = load("f_marine");
        if (land != null) { landState = STATE_OK; }
        if (forecast != null) { forecastState = STATE_OK; }
        if (marine != null) { marineState = STATE_OK; }
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
                "atW"   => n(pickIn(data, "at", "windspeedms"))
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

    function fetchForecast() as Void {
        forecastState = STATE_LOADING;
        Communications.makeWebRequest(
            Config.BASE_URL + "/v1/forecast",
            { "place" => Config.landPlace(), "hours" => 48, "step" => 360, "lang" => lang() },
            options(), new Lang.Method(Api, :onForecast));
    }

    function onForecast(code as Number,
                        data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        if (code == 200 && data instanceof Dictionary) {
            // Parallel arrays of primitives rather than an array of dictionaries:
            // same round-trip reason as above.
            var times = [] as Array<Number>;
            var temps = [] as Array<Float>;
            var pts = pick(data, "points");
            if (pts instanceof Array) {
                var now = Time.now().value();
                for (var i = 0; i < pts.size() && times.size() < 4; i += 1) {
                    var e = n(pick(pts[i], "epochtime"));
                    var t = f(pick(pts[i], "temperature"));
                    if (e == null || t == null || e < now - 1800) { continue; }
                    times.add(e);
                    temps.add(t);
                }
            }
            var flat = { "t" => times, "v" => temps };
            forecast = flat;
            forecastState = STATE_OK;
            save("f_fc", flat);
        } else {
            forecastState = STATE_ERROR;
        }
        WatchUi.requestUpdate();
        fetchMarine();
    }

    // ------------------------------------------------------------- marine

    function fetchMarine() as Void {
        marineState = STATE_LOADING;
        var params = { "fmisid" => Config.seaStation() };
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
                "wAt"     => n(pick(wv, "observed_epoch"))
            };
            marine = flat;
            marineState = STATE_OK;
            save("f_marine", flat);
        } else {
            marineState = STATE_ERROR;
            failure = classify(code);
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

    //! Force a refresh regardless of the floor, for a settings change.
    function refreshNow() as Void {
        lastRefresh = Time.now().value();
        fetchLand();
    }

    //! Read a normalised field. Everything the views draw goes through here.
    function v(d as Dictionary?, key as String) {
        if (d == null) { return null; }
        if (!d.hasKey(key)) { return null; }
        return d[key];
    }
}
