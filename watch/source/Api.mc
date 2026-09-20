import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.PersistedContent;
import Toybox.Time;
import Toybox.WatchUi;

//! Backend client.
//!
//! Every payload is deliberately small — Connect IQ starts failing around 32 kB
//! and needs roughly twice the response size in free memory to parse it
//! (RESEARCH.md §10). The backend does the reshaping so these stay in the
//! hundreds of bytes.
//!
//! Results are cached in Application.Storage so a page that has loaded once
//! keeps showing its last reading when the phone is out of range — which for a
//! marine app is the normal case, not the edge case.
module Api {

    enum { STATE_IDLE, STATE_LOADING, STATE_OK, STATE_ERROR }

    var land = null;        // /v1/observations + /v1/forecast
    var forecast = null;
    var marine = null;

    var landState = STATE_IDLE;
    var forecastState = STATE_IDLE;
    var marineState = STATE_IDLE;
    var lastError = null;

    function options() as Dictionary {
        return {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => { "Accept" => "application/json" }
        };
    }

    //! Two-letter language for the backend, so FMI returns weather text already
    //! localised and the app never translates symbol codes itself.
    function lang() as String {
        var l = System.getDeviceSettings().systemLanguage;
        if (l == System.LANGUAGE_FIN) { return "fi"; }
        if (l == System.LANGUAGE_SWE) { return "sv"; }
        return "en";
    }

    function cacheKey(name as String) as String { return "cache_" + name; }

    function remember(name as String, data as Dictionary) as Void {
        try {
            Application.Storage.setValue(cacheKey(name), data);
            Application.Storage.setValue(cacheKey(name) + "_at", Time.now().value());
        } catch (e) {
            // Storage is a convenience; never let it break a working screen.
        }
    }

    function recall(name as String) as Dictionary? {
        try {
            var v = Application.Storage.getValue(cacheKey(name));
            if (v instanceof Dictionary) { return v; }
        } catch (e) {}
        return null;
    }

    function cachedAt(name as String) as Number? {
        try {
            var v = Application.Storage.getValue(cacheKey(name) + "_at");
            if (v instanceof Number) { return v; }
        } catch (e) {}
        return null;
    }

    function restore() as Void {
        land = recall("land");
        forecast = recall("forecast");
        marine = recall("marine");
        if (land != null) { landState = STATE_OK; }
        if (forecast != null) { forecastState = STATE_OK; }
        if (marine != null) { marineState = STATE_OK; }
    }

    function fetchLand() as Void {
        landState = STATE_LOADING;
        Communications.makeWebRequest(
            Config.BASE_URL + "/v1/observations",
            { "place" => Config.landPlace() },
            options(),
            new Lang.Method(Api, :onLand)
        );
    }

    function onLand(code as Number,
                    data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        if (code == 200 && data instanceof Dictionary) {
            land = data;
            landState = STATE_OK;
            remember("land", data);
        } else {
            landState = STATE_ERROR;
            lastError = code;
        }
        WatchUi.requestUpdate();
    }

    function fetchForecast() as Void {
        forecastState = STATE_LOADING;
        Communications.makeWebRequest(
            Config.BASE_URL + "/v1/forecast",
            { "place" => Config.landPlace(), "hours" => 48, "step" => 360, "lang" => lang() },
            options(),
            new Lang.Method(Api, :onForecast)
        );
    }

    function onForecast(code as Number,
                    data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        if (code == 200 && data instanceof Dictionary) {
            forecast = data;
            forecastState = STATE_OK;
            remember("forecast", data);
        } else {
            forecastState = STATE_ERROR;
            lastError = code;
        }
        WatchUi.requestUpdate();
    }

    function fetchMarine() as Void {
        marineState = STATE_LOADING;
        var params = { "fmisid" => Config.seaStation() };
        var buoy = Config.seaBuoy();
        if (buoy > 0) { params["buoy_fmisid"] = buoy; }
        Communications.makeWebRequest(
            Config.BASE_URL + "/v1/marine", params, options(), new Lang.Method(Api, :onMarine)
        );
    }

    function onMarine(code as Number,
                    data as Dictionary or String or PersistedContent.Iterator or Null) as Void {
        if (code == 200 && data instanceof Dictionary) {
            marine = data;
            marineState = STATE_OK;
            remember("marine", data);
        } else {
            marineState = STATE_ERROR;
            lastError = code;
        }
        WatchUi.requestUpdate();
    }

    function refreshAll() as Void {
        fetchLand();
        fetchForecast();
        fetchMarine();
    }

    //! Safe nested read: d["a"]["b"] without exploding on a missing key.
    function get(d as Dictionary?, key as String) {
        if (d == null) { return null; }
        if (!d.hasKey(key)) { return null; }
        return d[key];
    }

    function getIn(d as Dictionary?, outer as String, inner as String) {
        var o = get(d, outer);
        if (o instanceof Dictionary) { return get(o, inner); }
        return null;
    }

    //! Per-field measurement time from the `at` map.
    function atOf(d as Dictionary?, field as String) as Number? {
        var v = getIn(d, "at", field);
        if (v instanceof Number) { return v; }
        return null;
    }
}
