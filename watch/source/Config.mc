import Toybox.Application;
import Toybox.Lang;

//! Settings access, with defaults applied when a property is missing.
//! Properties are phone-edited (Garmin Connect Mobile) and can be null on a
//! fresh install before the first sync, so every read is guarded.
(:glance)
module Config {

    const BASE_URL = "https://weatherapp.tallimedia.com";

    //! Shown at the foot of every page so a tester can say which build they are
    //! looking at. Must match `version` in manifest.xml — build-release.sh
    //! refuses to package if the two drift.
    const VERSION = "0.1.3";

    // Gust limits are derived, not set: land is wind + 3, sea is wind + 5.
    // The offsets differ because the measured gust-minus-mean gap does —
    // 2.5 m/s on land against 1.3 at sea (RESEARCH.md §20).
    const LAND_GUST_OFFSET = 3;
    const SEA_GUST_OFFSET = 5;

    function num(key as String, fallback as Number) as Number {
        var v = null;
        try { v = Properties.getValue(key); } catch (e) { v = null; }
        if (v instanceof Number) { return v; }
        if (v instanceof Float || v instanceof Double) { return v.toNumber(); }
        return fallback;
    }

    function str(key as String, fallback as String) as String {
        var v = null;
        try { v = Properties.getValue(key); } catch (e) { v = null; }
        if (v instanceof String && v.length() > 0) { return v; }
        return fallback;
    }

    function landPlace() as String { return str("landPlace", "Helsinki"); }
    function landWind() as Number { return num("landWind", 5); }
    function landGust() as Number { return landWind() + LAND_GUST_OFFSET; }
    function landCold() as Number { return num("landCold", 0); }
    function landHot() as Number { return num("landHot", 25); }

    function seaStation() as Number { return num("seaStation", 100996); }
    function seaBuoy() as Number { return num("seaBuoy", 0); }
    function seaWind() as Number { return num("seaWind", 10); }
    function seaGust() as Number { return seaWind() + SEA_GUST_OFFSET; }
    function seaWave() as Number { return num("seaWave", 1); }

    function seaFirst() as Boolean { return num("pageOrder", 0) == 1; }
    function glance1() as Number { return num("glance1", 0); }
    function glance2() as Number { return num("glance2", 2); }

    function windUnit() as Number { return num("windUnit", 0); }
    function distUnit() as Number { return num("distUnit", 0); }
}
