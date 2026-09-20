import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.System;
import Toybox.WatchUi;

//! Page rendering.
//!
//! Layout is proportional to screen size rather than pixel-positioned, since
//! the release build targets 70 devices across round and semi-round screens at
//! several resolutions (RESEARCH.md §16).
module Pages {

    function w(dc as Graphics.Dc) as Number { return dc.getWidth(); }
    function h(dc as Graphics.Dc) as Number { return dc.getHeight(); }

    //! Page title and the source line beneath it.
    function header(dc as Graphics.Dc, title as String, source as String?) as Void {
        var cx = w(dc) / 2;
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.11).toNumber(), Graphics.FONT_XTINY, title, Graphics.TEXT_JUSTIFY_CENTER);
        if (source != null) {
            dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText((cx).toNumber(), (h(dc) * 0.175).toNumber(), Graphics.FONT_XTINY, source,
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    //! Dots showing which page you are on.
    function drawPager(dc as Graphics.Dc, index as Number, count as Number) as Void {
        var cx = w(dc) / 2;
        var y = h(dc) * 0.945;
        var gap = 10;
        var startX = cx - ((count - 1) * gap) / 2;
        for (var i = 0; i < count; i += 1) {
            dc.setColor(i == index ? Theme.INK : Theme.FAINT, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle((startX + i * gap).toNumber(), y.toNumber(), i == index ? 3 : 2);
        }
    }

    function loading(dc as Graphics.Dc, state as Number) as Boolean {
        if (state == Api.STATE_LOADING) {
            dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText((w(dc) / 2).toNumber(), (h(dc) / 2).toNumber(), Graphics.FONT_SMALL,
                        WatchUi.loadResource(Rez.Strings.Loading) as String,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return true;
        }
        return false;
    }

    // ---------------------------------------------------------------- land

    function drawLand(dc as Graphics.Dc) as Void {
        var d = Api.land;
        var name = Api.get(d, "stationname");
        var km = Api.get(d, "distance");
        var src = name == null ? null : name + " · " + Fmt.dist(km);
        header(dc, WatchUi.loadResource(Rez.Strings.PageLand) as String, src);

        if (d == null) {
            if (!loading(dc, Api.landState)) { message(dc, Rez.Strings.NoPhone); }
            return;
        }

        var cx = w(dc) / 2;
        var t = Api.get(d, "temperature");
        dc.setColor(Theme.tempColour(t), Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.30).toNumber(), Graphics.FONT_NUMBER_MEDIUM, Fmt.temp(t),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Wind, with the gust in brackets — the marine convention, and the gust
        // is what the threshold actually compares against (RESEARCH.md §20).
        var ms = Api.get(d, "windspeedms");
        var gust = Api.get(d, "windgust");
        var dir = Api.get(d, "winddirection");
        dc.setColor(Theme.windColour(ms, gust, Config.landWind(), Config.landGust()),
                    Graphics.COLOR_TRANSPARENT);
        var windLine = Fmt.windValue(ms) + " (" + Fmt.windValue(gust) + ") " + Fmt.windUnitLabel();
        dc.drawText((cx).toNumber(), (h(dc) * 0.52).toNumber(), Graphics.FONT_MEDIUM, windLine, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.635).toNumber(), Graphics.FONT_XTINY, Fmt.compass(dir),
                    Graphics.TEXT_JUSTIFY_CENTER);

        forecastStrip(dc);

        // Per-field age: wind and temperature update at different rates, so one
        // age for the reading would be wrong for most of it (RESEARCH.md §3).
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.86).toNumber(), Graphics.FONT_XTINY,
                    Fmt.age(Api.atOf(d, "temperature")) + " · " + Fmt.age(Api.atOf(d, "windspeedms")),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Next few forecast steps, 6-hourly (RESEARCH.md §20).
    function forecastStrip(dc as Graphics.Dc) as Void {
        var f = Api.forecast;
        if (f == null) { return; }
        var pts = Api.get(f, "points");
        if (!(pts instanceof Array) || pts.size() == 0) { return; }

        var now = Time.now().value();
        var shown = 0;
        var slots = 4;
        var y = h(dc) * 0.735;
        var span = w(dc) * 0.76;
        var x0 = (w(dc) - span) / 2;
        for (var i = 0; i < pts.size() && shown < slots; i += 1) {
            var p = pts[i];
            if (!(p instanceof Dictionary)) { continue; }
            var e = Api.get(p, "epochtime");
            if (!(e instanceof Number) || e < now - 1800) { continue; }
            var x = x0 + (span / slots) * shown + (span / slots) / 2;
            dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText((x).toNumber(), (y).toNumber(), Graphics.FONT_XTINY, Fmt.clock(e), Graphics.TEXT_JUSTIFY_CENTER);
            var t = Api.get(p, "temperature");
            dc.setColor(Theme.tempColour(t), Graphics.COLOR_TRANSPARENT);
            dc.drawText((x).toNumber(), (y + h(dc) * 0.055).toNumber(), Graphics.FONT_XTINY, Fmt.zero(t),
                        Graphics.TEXT_JUSTIFY_CENTER);
            shown += 1;
        }
    }

    // ----------------------------------------------------------------- sea

    function drawSea(dc as Graphics.Dc) as Void {
        var m = Api.marine;
        var st = Api.get(m, "station");
        var name = Api.get(st, "name");
        header(dc, WatchUi.loadResource(Rez.Strings.PageSea) as String, name);

        if (st == null) {
            if (!loading(dc, Api.marineState)) { message(dc, Rez.Strings.NoPhone); }
            return;
        }

        var cx = w(dc) / 2;
        var ms = Api.get(st, "windspeedms");
        var gust = Api.get(st, "windgust");
        var dir = Api.get(st, "winddirection");

        dc.setColor(Theme.windColour(ms, gust, Config.seaWind(), Config.seaGust()),
                    Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.28).toNumber(), Graphics.FONT_NUMBER_MEDIUM, Fmt.windValue(ms),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.48).toNumber(), Graphics.FONT_XTINY,
                    Fmt.windUnitLabel() + "  " + WatchUi.loadResource(Rez.Strings.Gust) + " "
                        + Fmt.windValue(gust),
                    Graphics.TEXT_JUSTIFY_CENTER);

        arrow(dc, cx, h(dc) * 0.615, h(dc) * 0.055, dir);
        dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx + h(dc) * 0.10).toNumber(), (h(dc) * 0.595).toNumber(), Graphics.FONT_SMALL, Fmt.compass(dir),
                    Graphics.TEXT_JUSTIFY_LEFT);

        var t = Api.get(st, "temperature");
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.73).toNumber(), Graphics.FONT_XTINY, Fmt.temp(t),
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.86).toNumber(), Graphics.FONT_XTINY, Fmt.age(Api.atOf(st, "windspeedms")),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---------------------------------------------------------------- buoy

    function drawBuoy(dc as Graphics.Dc) as Void {
        var m = Api.marine;
        var wv = Api.get(m, "waves");
        var mode = Api.get(m, "mode");
        var cx = w(dc) / 2;

        var src = null;
        if (wv != null) {
            var measured = Api.get(wv, "measured");
            src = (measured == true)
                ? Api.get(wv, "name")
                : WatchUi.loadResource(Rez.Strings.Modelled) as String;
        }
        header(dc, WatchUi.loadResource(Rez.Strings.PageBuoy) as String, src);

        if (wv == null) {
            if (!loading(dc, Api.marineState)) { message(dc, Rez.Strings.NoBuoy); }
            return;
        }

        var hs = Api.get(wv, "wave_height_m");
        dc.setColor(Theme.waveColour(hs), Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.28).toNumber(), Graphics.FONT_NUMBER_MEDIUM, Fmt.metres(hs),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Period earns its place: 4 s chop and 8 s swell are different seas at
        // the same height (RESEARCH.md §17).
        var per = Api.get(wv, "wave_period_s");
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.49).toNumber(), Graphics.FONT_SMALL, Fmt.one(per == null ? 0 : per) + " s",
                    Graphics.TEXT_JUSTIFY_CENTER);

        var dir = Api.get(wv, "wave_direction_deg");
        arrow(dc, cx, h(dc) * 0.635, h(dc) * 0.05, dir);
        dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx + h(dc) * 0.09).toNumber(), (h(dc) * 0.615).toNumber(), Graphics.FONT_XTINY, Fmt.compass(dir),
                    Graphics.TEXT_JUSTIFY_LEFT);

        var water = Api.get(wv, "water_temp_c");
        if (water != null) {
            dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText((cx).toNumber(), (h(dc) * 0.745).toNumber(), Graphics.FONT_XTINY, Fmt.temp(water) + " ~",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.86).toNumber(), Graphics.FONT_XTINY,
                    (mode != null ? mode : "") , Graphics.TEXT_JUSTIFY_CENTER);
    }

    // -------------------------------------------------------------- shared

    //! Direction arrow. FMI gives the bearing the wind or waves come FROM, so
    //! the arrow is drawn 180° round to point where they are going.
    function arrow(dc as Graphics.Dc, cxf as Numeric, cyf as Numeric, rf as Numeric, degFrom as Numeric?) as Void {
        if (degFrom == null) { return; }
        var cx = cxf.toNumber();
        var cy = cyf.toNumber();
        var r = rf.toFloat();
        var a = (degFrom + 180) % 360;
        var rad = Math.toRadians(a - 90);
        var tipX = cx + r * Math.cos(rad);
        var tipY = cy + r * Math.sin(rad);
        var backX = cx - r * Math.cos(rad);
        var backY = cy - r * Math.sin(rad);
        dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(backX.toNumber(), backY.toNumber(), tipX.toNumber(), tipY.toNumber());
        var lw = Math.toRadians(a - 90 + 150);
        var rw = Math.toRadians(a - 90 - 150);
        dc.drawLine(tipX.toNumber(), tipY.toNumber(),
                    (tipX + r * 0.6 * Math.cos(lw)).toNumber(),
                    (tipY + r * 0.6 * Math.sin(lw)).toNumber());
        dc.drawLine(tipX.toNumber(), tipY.toNumber(),
                    (tipX + r * 0.6 * Math.cos(rw)).toNumber(),
                    (tipY + r * 0.6 * Math.sin(rw)).toNumber());
        dc.setPenWidth(1);
    }

    function message(dc as Graphics.Dc, res as ResourceId) as Void {
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((w(dc) / 2).toNumber(), (h(dc) / 2).toNumber(), Graphics.FONT_XTINY,
                    WatchUi.loadResource(res) as String,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
