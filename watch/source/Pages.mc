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

        var t = Api.v(d, "temp");
        var ms = Api.v(d, "wind");
        var gust = Api.v(d, "gust");
        var dir = Api.v(d, "dir");

        stackStart(dc, 0.245);
        iconRow(dc, :temp, Graphics.FONT_NUMBER_MILD, Fmt.temp(t), Theme.tempColour(t), -2);
        iconRow(dc, :wind, Graphics.FONT_SMALL,
                Fmt.windValue(ms) + " (" + Fmt.windValue(gust) + ") " + Fmt.windUnitLabel()
                    + " " + Fmt.compass(dir),
                Theme.windColour(ms, gust, Config.landWind(), Config.landGust()), 4);

        forecastStrip(dc, _y);

        // One age per page here rather than two: the earlier "8 min · 8 min"
        // read as a repeat rather than as two different fields.
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w(dc) / 2, (h(dc) * 0.855).toNumber(), Graphics.FONT_XTINY,
                    Fmt.age(Api.v(d, "atW")), Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Next few forecast steps, 6-hourly (RESEARCH.md §20), drawn from the
    //! running stack position so it can never sit on top of the wind line.
    function forecastStrip(dc as Graphics.Dc, top as Number) as Void {
        var f = Api.forecast;
        if (f == null) { return; }
        var times = Api.v(f, "t");
        var temps = Api.v(f, "v");
        if (!(times instanceof Array) || times.size() == 0) { return; }

        var slots = 4;
        var span = (w(dc) * 0.74).toNumber();
        var x0 = (w(dc) - span) / 2;
        var ih = dc.getFontHeight(Graphics.FONT_XTINY);
        Icons.clock(dc, (x0 - ih - 2).toNumber(), top + 1, (ih * 0.7).toNumber(), Theme.FAINT);
        var count = times.size() < slots ? times.size() : slots;
        var lineH = dc.getFontHeight(Graphics.FONT_XTINY);
        for (var i = 0; i < count; i += 1) {
            var x = (x0 + (span / slots) * i + (span / slots) / 2).toNumber();
            dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, top, Graphics.FONT_XTINY, Fmt.hour(times[i]),
                        Graphics.TEXT_JUSTIFY_CENTER);
            var t = temps[i];
            dc.setColor(Theme.tempColour(t), Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, top + lineH - 2, Graphics.FONT_XTINY, Fmt.zero(t),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ----------------------------------------------------------------- sea

    function drawSea(dc as Graphics.Dc) as Void {
        var m = Api.marine;
        header(dc, res(Rez.Strings.PageSea), Api.v(m, "stName"));

        if (m == null) {
            if (!loading(dc, Api.marineState)) { message(dc, Rez.Strings.NoPhone); }
            return;
        }

        var ms = Api.v(m, "stWind");
        var gust = Api.v(m, "stGust");
        var dir = Api.v(m, "stDir");
        var colour = Theme.windColour(ms, gust, Config.seaWind(), Config.seaGust());

        stackStart(dc, 0.245);
        iconRow(dc, :wind, Graphics.FONT_NUMBER_MILD,
                Fmt.windValue(ms) + " " + Fmt.windUnitLabel(), colour, -4);
        row(dc, Graphics.FONT_XTINY,
            res(Rez.Strings.Gust) + " " + Fmt.windValue(gust) + " " + Fmt.windUnitLabel(),
            Theme.DIM, 6);

        // Arrow and compass point share a row, measured so the pair is centred
        // rather than each guessing its own offset.
        var label = Fmt.compass(dir);
        var labelW = dc.getTextWidthInPixels(label, Graphics.FONT_SMALL);
        var r = (h(dc) * 0.045).toNumber();
        var total = r * 2 + 6 + labelW;
        var left = (w(dc) - total) / 2;
        arrow(dc, left + r, _y + dc.getFontHeight(Graphics.FONT_SMALL) / 2, r, dir);
        dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + r * 2 + 6, _y, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT);
        _y += dc.getFontHeight(Graphics.FONT_SMALL) + 4;

        iconRow(dc, :temp, Graphics.FONT_XTINY, Fmt.temp(Api.v(m, "stTemp")), Theme.DIM, 0);

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w(dc) / 2, (h(dc) * 0.855).toNumber(), Graphics.FONT_XTINY,
                    Fmt.age(Api.v(m, "stAt")), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ---------------------------------------------------------------- buoy

    function drawBuoy(dc as Graphics.Dc) as Void {
        var m = Api.marine;
        var hasWave = Api.v(m, "hasWave") == true;

        var src = null;
        if (hasWave) {
            src = (Api.v(m, "wMeas") == true)
                ? Fmt.shortStation(Api.v(m, "wName"))
                : res(Rez.Strings.Modelled);
        }
        header(dc, res(Rez.Strings.PageBuoy), src);

        if (!hasWave) {
            if (!loading(dc, Api.marineState)) { message(dc, Rez.Strings.NoBuoy); }
            return;
        }

        var hs = Api.v(m, "wHs");
        var per = Api.v(m, "wPer");
        var dir = Api.v(m, "wDir");

        stackStart(dc, 0.245);
        iconRow(dc, :wave, Graphics.FONT_NUMBER_MILD, Fmt.metres(hs), Theme.waveColour(hs), -4);
        row(dc, Graphics.FONT_XTINY,
            res(Rez.Strings.Period) + " " + (per == null ? Fmt.DASH : Fmt.one(per)) + " s",
            Theme.DIM, 6);

        var label = Fmt.compass(dir);
        var labelW = dc.getTextWidthInPixels(label, Graphics.FONT_SMALL);
        var r = (h(dc) * 0.045).toNumber();
        var total = r * 2 + 6 + labelW;
        var left = (w(dc) - total) / 2;
        arrow(dc, left + r, _y + dc.getFontHeight(Graphics.FONT_SMALL) / 2, r, dir);
        dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + r * 2 + 6, _y, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT);
        _y += dc.getFontHeight(Graphics.FONT_SMALL) + 4;

        var water = Api.v(m, "wTemp");
        if (water != null) {
            iconRow(dc, :temp, Graphics.FONT_XTINY,
                    res(Rez.Strings.WaterTemp) + " " + Fmt.temp(water), Theme.DIM, 0);
        }

        var dist = Api.v(m, "wDist");
        if (dist != null) {
            dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w(dc) / 2, (h(dc) * 0.855).toNumber(), Graphics.FONT_XTINY,
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
        // Monkey C's % is integer modulo — applying it to the Float that comes
        // back from JSON faults at runtime. Round to a Number first.
        var a = (degFrom.toNumber() + 180) % 360;
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


    // ------------------------------------------------------------- layout
    //
    // Elements are stacked using the real font heights rather than fractions
    // of the screen. Guessed fractions collided as soon as a number font was
    // involved, and they would drift further across the 70 devices the release
    // targets, which vary in both resolution and font metrics.

    var _y = 0;

    function stackStart(dc as Graphics.Dc, topFraction as Float) as Void {
        _y = (h(dc) * topFraction).toNumber();
    }

    //! Icon + value on one line, measured and centred as a pair so neither has
    //! to guess the other's width.
    function iconRow(dc as Graphics.Dc, kind as Symbol, font as Graphics.FontDefinition,
                     text as String, colour as Number, gapAfter as Number) as Void {
        var fh = dc.getFontHeight(font);
        var size = (fh * 0.62).toNumber();
        var tw = dc.getTextWidthInPixels(text, font);
        var gap = 5;
        var left = ((w(dc) - (size + gap + tw)) / 2).toNumber();
        var iy = _y + ((fh - size) / 2).toNumber();
        if (kind == :temp)         { Icons.temp(dc, left, iy, size, Theme.DIM); }
        else if (kind == :wind)    { Icons.wind(dc, left, iy, size, Theme.DIM); }
        else if (kind == :wave)    { Icons.wave(dc, left, iy, size, Theme.DIM); }
        else if (kind == :clock)   { Icons.clock(dc, left, iy, size, Theme.DIM); }
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + size + gap, _y, font, text, Graphics.TEXT_JUSTIFY_LEFT);
        _y += fh + gapAfter;
    }

    function row(dc as Graphics.Dc, font as Graphics.FontDefinition, text as String,
                 colour as Number, gapAfter as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w(dc) / 2, _y, font, text, Graphics.TEXT_JUSTIFY_CENTER);
        _y += dc.getFontHeight(font) + gapAfter;
    }

    //! Trim a label until it fits, so a long buoy name cannot run off the edge.
    function fit(dc as Graphics.Dc, text as String?, font as Graphics.FontDefinition,
                 maxW as Number) as String {
        if (text == null) { return ""; }
        if (dc.getTextWidthInPixels(text, font) <= maxW) { return text; }
        var t = text;
        while (t.length() > 4 && dc.getTextWidthInPixels(t + "…", font) > maxW) {
            t = t.substring(0, t.length() - 1);
        }
        return t + "…";
    }

    function res2(id as ResourceId) as String { return WatchUi.loadResource(id) as String; }

    function message(dc as Graphics.Dc, res as ResourceId) as Void {
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((w(dc) / 2).toNumber(), (h(dc) / 2).toNumber(), Graphics.FONT_XTINY,
                    res2(res),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
