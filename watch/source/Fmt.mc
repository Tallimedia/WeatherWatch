import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

//! Formatting and unit conversion.
module Fmt {

    const DASH = "–";

    //! Wind in the user's chosen unit. Values arrive from FMI as m/s, which is
    //! the 10-minute mean and the basis FMI's own marine warnings use.
    function wind(ms as Numeric?) as String {
        if (ms == null) { return DASH; }
        var u = Config.windUnit();
        if (u == 1) { return one(ms * 1.94384) + " kn"; }
        if (u == 2) { return beaufort(ms).toString() + " bft"; }
        return one(ms) + " m/s";
    }

    //! Bare number in the chosen wind unit, for tight layouts.
    function windValue(ms as Numeric?) as String {
        if (ms == null) { return DASH; }
        var u = Config.windUnit();
        if (u == 1) { return one(ms * 1.94384); }
        if (u == 2) { return beaufort(ms).toString(); }
        return one(ms);
    }

    function windUnitLabel() as String {
        var u = Config.windUnit();
        return u == 1 ? "kn" : (u == 2 ? "bft" : "m/s");
    }

    //! Compares against the threshold in m/s, never the displayed unit — the
    //! settings are m/s whatever the display shows.
    function beaufort(ms as Numeric) as Number {
        var limits = [0.5, 1.6, 3.4, 5.5, 8.0, 10.8, 13.9, 17.2, 20.8, 24.5, 28.5, 32.7];
        for (var i = 0; i < limits.size(); i += 1) {
            if (ms < limits[i]) { return i; }
        }
        return 12;
    }

    function dist(km as Numeric?) as String {
        if (km == null) { return DASH; }
        if (Config.distUnit() == 1) { return one(km * 0.539957) + " nm"; }
        return one(km) + " km";
    }

    function temp(c as Numeric?) as String {
        if (c == null) { return DASH; }
        return one(c) + "°";
    }

    function one(v as Numeric) as String {
        return v.format("%.1f");
    }

    function zero(v as Numeric?) as String {
        if (v == null) { return DASH; }
        return v.format("%.0f");
    }

    function metres(v as Numeric?) as String {
        if (v == null) { return DASH; }
        return v.format("%.1f") + " m";
    }

    //! Compass point the wind comes FROM. FMI reports the bearing of origin.
    function compass(deg as Numeric?) as String {
        if (deg == null) { return ""; }
        var points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        var i = ((deg / 45.0) + 0.5).toNumber() % 8;
        if (i < 0) { i += 8; }
        return points[i];
    }

    //! "4 min", "2 h" — how old a reading is. Each field carries its own
    //! measurement time because stations update at different rates
    //! (RESEARCH.md §3).
    function age(epoch as Number?) as String {
        if (epoch == null) { return DASH; }
        var secs = Time.now().value() - epoch;
        if (secs < 0) { secs = 0; }
        if (secs < 90) { return "now"; }
        if (secs < 5400) { return (secs / 60).toNumber().toString() + " min"; }
        return (secs / 3600).toNumber().toString() + " h";
    }

    //! Local clock time for an epoch second.
    function clock(epoch as Number?) as String {
        if (epoch == null) { return DASH; }
        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return info.hour.format("%02d") + ":" + info.min.format("%02d");
    }
}
