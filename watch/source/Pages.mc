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

    //! Resources come back as a Resource type; concatenating one without
    //! casting compiles but faults at runtime.
    function res(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }

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
                        res(Rez.Strings.Loading),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return true;
        }
        return false;
    }

    // ---------------------------------------------------------------- land

    function drawLand(dc as Graphics.Dc) as Void {
        var d = Api.land;
        var name = Api.v(d, "name");
        var km = Api.v(d, "dist");
        var src = name == null ? null : name + " · " + Fmt.dist(km);
        header(dc, res(Rez.Strings.PageLand), src);

        if (d == null) {
            if (!loading(dc, Api.landState)) { message(dc, Rez.Strings.NoPhone); }
            return;
        }

        var cx = w(dc) / 2;
        var t = Api.v(d, "temp");
        dc.setColor(Theme.tempColour(t), Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.30).toNumber(), Graphics.FONT_NUMBER_MEDIUM, Fmt.temp(t),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Wind, with the gust in brackets — the marine convention, and the gust
        // is what the threshold actually compares against (RESEARCH.md §20).
        var ms = Api.v(d, "wind");
        var gust = Api.v(d, "gust");
        var dir = Api.v(d, "dir");
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
                    Fmt.age(Api.v(d, "atT")) + " · " + Fmt.age(Api.v(d, "atW")),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Next few forecast steps, 6-hourly (RESEARCH.md §20). The backend
    //! supplies the series; the app stores it as parallel primitive arrays.
    function forecastStrip(dc as Graphics.Dc) as Void {
        var f = Api.forecast;
        if (f == null) { return; }
        var times = Api.v(f, "t");
        var temps = Api.v(f, "v");
        if (!(times instanceof Array) || times.size() == 0) { return; }

        var slots = 4;
        var y = h(dc) * 0.735;
        var span = w(dc) * 0.76;
        var x0 = (w(dc) - span) / 2;
        var count = times.size() < slots ? times.size() : slots;
        for (var i = 0; i < count; i += 1) {
            var x = (x0 + (span / slots) * i + (span / slots) / 2).toNumber();
            dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y.toNumber(), Graphics.FONT_XTINY, Fmt.clock(times[i]),
                        Graphics.TEXT_JUSTIFY_CENTER);
            var t = temps[i];
            dc.setColor(Theme.tempColour(t), Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, (y + h(dc) * 0.055).toNumber(), Graphics.FONT_XTINY, Fmt.zero(t),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ----------------------------------------------------------------- sea

    function drawSea(dc as Graphics.Dc) as Void {
        var m = Api.marine;
        var name = Api.v(m, "stName");
        header(dc, res(Rez.Strings.PageSea), name);

        if (m == null) {
            if (!loading(dc, Api.marineState)) { message(dc, Rez.Strings.NoPhone); }
            return;
        }

        var cx = w(dc) / 2;
        var ms = Api.v(m, "stWind");
        var gust = Api.v(m, "stGust");
        var dir = Api.v(m, "stDir");

        dc.setColor(Theme.windColour(ms, gust, Config.seaWind(), Config.seaGust()),
                    Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.28).toNumber(), Graphics.FONT_NUMBER_MEDIUM, Fmt.windValue(ms),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.48).toNumber(), Graphics.FONT_XTINY,
                    Fmt.windUnitLabel() + "  " + res(Rez.Strings.Gust) + " "
                        + Fmt.windValue(gust),
                    Graphics.TEXT_JUSTIFY_CENTER);

        arrow(dc, cx, h(dc) * 0.615, h(dc) * 0.055, dir);
        dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx + h(dc) * 0.10).toNumber(), (h(dc) * 0.595).toNumber(), Graphics.FONT_SMALL, Fmt.compass(dir),
                    Graphics.TEXT_JUSTIFY_LEFT);

        var t = Api.v(m, "stTemp");
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.73).toNumber(), Graphics.FONT_XTINY, Fmt.temp(t),
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.86).toNumber(), Graphics.FONT_XTINY, Fmt.age(Api.v(m, "stAt")),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---------------------------------------------------------------- buoy

    function drawBuoy(dc as Graphics.Dc) as Void {
        var m = Api.marine;
        var cx = w(dc) / 2;
        var hasWave = Api.v(m, "hasWave") == true;

        var src = null;
        if (hasWave) {
            src = (Api.v(m, "wMeas") == true) ? Api.v(m, "wName") : res(Rez.Strings.Modelled);
        }
        header(dc, res(Rez.Strings.PageBuoy), src);

        if (!hasWave) {
            if (!loading(dc, Api.marineState)) { message(dc, Rez.Strings.NoBuoy); }
            return;
        }

        var hs = Api.v(m, "wHs");
        dc.setColor(Theme.waveColour(hs), Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.28).toNumber(), Graphics.FONT_NUMBER_MEDIUM, Fmt.metres(hs),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Period earns its place: 4 s chop and 8 s swell are different seas at
        // the same height (RESEARCH.md §17).
        var per = Api.v(m, "wPer");
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx).toNumber(), (h(dc) * 0.49).toNumber(), Graphics.FONT_SMALL, Fmt.one(per == null ? 0 : per) + " s",
                    Graphics.TEXT_JUSTIFY_CENTER);

        var dir = Api.v(m, "wDir");
        arrow(dc, cx, h(dc) * 0.635, h(dc) * 0.05, dir);
        dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText((cx + h(dc) * 0.09).toNumber(), (h(dc) * 0.615).toNumber(), Graphics.FONT_XTINY, Fmt.compass(dir),
                    Graphics.TEXT_JUSTIFY_LEFT);

        var water = Api.v(m, "wTemp");
        if (water != null) {
            dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText((cx).toNumber(), (h(dc) * 0.745).toNumber(), Graphics.FONT_XTINY, Fmt.temp(water) + " ~",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        var dist = Api.v(m, "wDist");
        if (dist != null) {
            dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText((cx).toNumber(), (h(dc) * 0.86).toNumber(), Graphics.FONT_XTINY,
                        Fmt.dist(dist), Graphics.TEXT_JUSTIFY_CENTER);
        }
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

    function res2(id as ResourceId) as String { return WatchUi.loadResource(id) as String; }

    function message(dc as Graphics.Dc, res as ResourceId) as Void {
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((w(dc) / 2).toNumber(), (h(dc) / 2).toNumber(), Graphics.FONT_XTINY,
                    res2(res),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
