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
        headerPin(dc, title, source, true);
    }

    function headerPlain(dc as Graphics.Dc, title as String, source as String?) as Void {
        headerPin(dc, title, source, false);
    }

    //! `pin` marks the source line as a place the app resolved for you. Without
    //! it the line is just a name the user already chose.
    function headerPin(dc as Graphics.Dc, title as String, source as String?,
                       pin as Boolean) as Void {
        var cx = w(dc) / 2;
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h(dc) * 0.11).toNumber(), Graphics.FONT_XTINY, title,
                    Graphics.TEXT_JUSTIFY_CENTER);
        if (source == null) { return; }

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        var top = (h(dc) * 0.175).toNumber();
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        // Round screens narrow toward the top, so the usable width here is well
        // short of the full diameter.
        var usable = (w(dc) * 0.78).toNumber();

        if (!pin) {
            dc.drawText(cx, top, Graphics.FONT_XTINY,
                        fit(dc, source, Graphics.FONT_XTINY, usable),
                        Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var size = (fh * 0.62).toNumber();
        var label = fit(dc, source, Graphics.FONT_XTINY, usable - size - 4);
        var tw = dc.getTextWidthInPixels(label, Graphics.FONT_XTINY);
        var left = ((w(dc) - (size + 4 + tw)) / 2).toNumber();
        Icons.station(dc, left, top + ((fh - size) / 2).toNumber(), size, Theme.FAINT);
        dc.drawText(left + size + 4, top, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_LEFT);
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

    //! Build version, small and dim below the footer. Beta testers need to be
    //! able to say which build they are looking at without guessing.
    //! The "last updated" footer: download glyph, age, then the build.
    //!
    //! The version rides on this row rather than getting its own. Stacked, the
    //! two rows collided — the gap between them was smaller than the font's
    //! own height — which left the version unreadable, and the version exists
    //! precisely so a tester can say which build they are looking at.
    //! The footer: download glyph, then one line that changes with the state.
    //!
    //! Fetching says so. Select forces a refresh, and it used to do that
    //! silently — the reading stayed exactly as it was until the new one
    //! landed, so the button read as doing nothing and a user would press it
    //! again. The glyph brightens with the text so the change is visible at a
    //! glance rather than only on reading it.
    //!
    //! When a refresh failed and a cached reading is on screen, the footer
    //! says that instead. Otherwise a stale number looks exactly like a live
    //! one, which on the water is the difference that matters. The version
    //! gives up its place in both cases; it is on the About page regardless.
    function updated(dc as Graphics.Dc, age as String, state as Number) as Void {
        var font = Graphics.FONT_XTINY;
        var fh = dc.getFontHeight(font);
        var size = (fh * 0.66).toNumber();

        var text;
        var colour;
        if (state == Api.STATE_LOADING) {
            text = res(Rez.Strings.Refreshing);
            colour = Theme.DIM;
        } else if (state == Api.STATE_ERROR) {
            text = age + " · " + res(Rez.Strings.Offline);
            colour = Theme.FAINT;
        } else {
            text = age + " · v" + Config.VERSION;
            colour = Theme.FAINT;
        }

        var tw = dc.getTextWidthInPixels(text, font);
        var top = (h(dc) * 0.855).toNumber();
        var left = ((w(dc) - (size + 4 + tw)) / 2).toNumber();
        Icons.download(dc, left, top + ((fh - size) / 2).toNumber(), size, colour);
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + size + 4, top, font, text, Graphics.TEXT_JUSTIFY_LEFT);
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
        var shortName = Fmt.dropPrefix(name, Config.landPlace());
        var src = shortName == null ? null : shortName + " · " + Fmt.dist(km);
        headerPlain(dc, res(Rez.Strings.PageLand), src);

        if (d == null) {
            if (!loading(dc, Api.landState)) { failureMessage(dc); }
            return;
        }

        var t = Api.v(d, "temp");
        var ms = Api.v(d, "wind");
        var gust = Api.v(d, "gust");
        var dir = Api.v(d, "dir");

        stackStart(dc, 0.245);
        iconRowUnit(dc, :temp, Graphics.FONT_NUMBER_MILD, Fmt.tempValue(t), "°C",
                    Theme.tempColour(t), -2);
        iconRow(dc, :wind, Graphics.FONT_SMALL,
                Fmt.windValue(ms) + " (" + Fmt.windValue(gust) + ") " + Fmt.windUnitLabel()
                    + " " + Fmt.compass(dir),
                Theme.windColour(ms, gust, Config.landWind(), Config.landGust()), 4);

        forecastStrip(dc, _y);

        // One age per page here rather than two: the earlier "8 min · 8 min"
        // read as a repeat rather than as two different fields.
        updated(dc, Fmt.age(Api.v(d, "atW")), Api.landState);
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
        headerPlain(dc, res(Rez.Strings.PageSea), Api.v(m, "stName"));

        if (m == null) {
            if (!loading(dc, Api.marineState)) { failureMessage(dc); }
            return;
        }

        var ms = Api.v(m, "stWind");
        var gust = Api.v(m, "stGust");
        var dir = Api.v(m, "stDir");
        var colour = Theme.windColour(ms, gust, Config.seaWind(), Config.seaGust());

        stackStart(dc, 0.245);
        iconRowUnit(dc, :wind, Graphics.FONT_NUMBER_MILD, Fmt.windValue(ms),
                    Fmt.windUnitLabel(), colour, -4);
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

        updated(dc, Fmt.age(Api.v(m, "stAt")), Api.marineState);
    }

    // ---------------------------------------------------------------- buoy

    function drawBuoy(dc as Graphics.Dc) as Void {
        var m = Api.marine;
        var hasWave = Api.v(m, "hasWave") == true;

        var auto = Config.seaBuoy() == 0;
        var src = null;
        if (hasWave) {
            if (Api.v(m, "wMeas") == true) {
                src = Fmt.dropPrefix(Fmt.shortStation(Api.v(m, "wName")),
                                     Config.landPlace());
                // Distance matters only when the app chose the buoy: a
                // sheltered one 2 km out and an open-sea one 21 km out report
                // very different seas (RESEARCH.md §4). If the user picked it,
                // the number is noise.
                var d = Api.v(m, "wDist");
                if (auto && d != null) { src = src + " · " + Fmt.dist(d); }
            } else {
                src = res(Rez.Strings.Modelled);
            }
        }
        headerPlain(dc, res(Rez.Strings.PageBuoy), src);

        if (!hasWave) {
            // Two different absences. Inland there is no buoy at all and
            // never will be; on the coast they are lifted out for the winter.
            // Same empty page, and the caption is all that distinguishes them.
            if (!loading(dc, Api.marineState)) {
                var mode = Api.v(m, "mode");
                message(dc, mode != null && mode.equals("none")
                        ? Rez.Strings.NoBuoyArea : Rez.Strings.NoBuoy);
            }
            return;
        }

        var hs = Api.v(m, "wHs");
        var per = Api.v(m, "wPer");
        var dir = Api.v(m, "wDir");

        stackStart(dc, 0.245);
        iconRowUnit(dc, :wave, Graphics.FONT_NUMBER_MILD, Fmt.metresValue(hs), "m",
                    Theme.waveColour(hs), -4);
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

        updated(dc, Fmt.age(Api.v(m, "wAt")), Api.marineState);
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
        // Some glyphs draw wider than their box side; ask rather than assume,
        // or a wide icon runs under the text next to it.
        var drawnW = (size * Icons.widthFactor(kind)).toNumber();
        var tw = dc.getTextWidthInPixels(text, font);
        var gap = 5;
        var left = ((w(dc) - (drawnW + gap + tw)) / 2).toNumber();
        var iy = _y + ((fh - size) / 2).toNumber();
        if (kind == :temp)         { Icons.temp(dc, left, iy, size, Theme.DIM); }
        else if (kind == :wind)    { Icons.wind(dc, left, iy, size, Theme.DIM); }
        else if (kind == :wave)    { Icons.wave(dc, left, iy, size, Theme.DIM); }
        else if (kind == :clock)   { Icons.clock(dc, left, iy, size, Theme.DIM); }
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + drawnW + gap, _y, font, text, Graphics.TEXT_JUSTIFY_LEFT);
        _y += fh + gapAfter;
    }

    //! Icon, a big number, and its unit in a font that has letters.
    //!
    //! Garmin's FONT_NUMBER_* faces carry digits and punctuation but, on many
    //! devices, no letters — the Forerunner 255s drew "13.4 °C" as "13.4 °"
    //! plus an empty box, and "2.2 m/s" as "2.2 □/□". The fenix 8 happens to
    //! have the glyphs, which is why this survived every test until someone
    //! looked at a small screen. Nothing in a number font may contain letters.
    function iconRowUnit(dc as Graphics.Dc, kind as Symbol, numFont as Graphics.FontDefinition,
                         value as String, unit as String, colour as Number,
                         gapAfter as Number) as Void {
        var unitFont = Graphics.FONT_SMALL;
        var fh = dc.getFontHeight(numFont);
        var uh = dc.getFontHeight(unitFont);
        var size = (fh * 0.62).toNumber();
        var drawnW = (size * Icons.widthFactor(kind)).toNumber();
        var vw = dc.getTextWidthInPixels(value, numFont);
        var uw = dc.getTextWidthInPixels(unit, unitFont);
        var gap = 5;
        var unitGap = 3;

        var total = drawnW + gap + vw + unitGap + uw;
        var left = ((w(dc) - total) / 2).toNumber();
        var iy = _y + ((fh - size) / 2).toNumber();
        if (kind == :temp)      { Icons.temp(dc, left, iy, size, Theme.DIM); }
        else if (kind == :wind) { Icons.wind(dc, left, iy, size, Theme.DIM); }
        else if (kind == :wave) { Icons.wave(dc, left, iy, size, Theme.DIM); }

        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + drawnW + gap, _y, numFont, value, Graphics.TEXT_JUSTIFY_LEFT);
        // Sit the unit on the number's baseline rather than its box top.
        dc.drawText(left + drawnW + gap + vw + unitGap, _y + (fh - uh), unitFont, unit,
                    Graphics.TEXT_JUSTIFY_LEFT);
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

    //! The message for whatever actually went wrong.
    //!
    //! "No connection" used to cover every failure, including a place name FMI
    //! does not know — which told the user to check their phone when the fix
    //! was in the settings.
    function failureMessage(dc as Graphics.Dc) as Void {
        if (Api.failure == Api.FAIL_PLACE) { message(dc, Rez.Strings.NoPlace); }
        else if (Api.failure == Api.FAIL_SERVER) { message(dc, Rez.Strings.NoData); }
        else { message(dc, Rez.Strings.NoPhone); }
    }

    //! About: the build, and the attribution FMI's licence requires.
    //!
    //! This page exists because the credit had nowhere else to go. The data
    //! pages are full — the gap between the last reading and the page dots is
    //! smaller than a line of text, which is what made the version collide
    //! there — and CC BY 4.0 wants the source named in the app, not only in
    //! the store listing.
    function drawAbout(dc as Graphics.Dc) as Void {
        headerPlain(dc, res(Rez.Strings.PageAbout), null);
        var cx = (w(dc) / 2).toNumber();
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);
        var top = (h(dc) * 0.36).toNumber();

        dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top, Graphics.FONT_SMALL, "FIWeatherWatch",
                    Graphics.TEXT_JUSTIFY_CENTER);
        top += dc.getFontHeight(Graphics.FONT_SMALL);

        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top, Graphics.FONT_XTINY, "v" + Config.VERSION,
                    Graphics.TEXT_JUSTIFY_CENTER);
        top += fh + (fh / 2).toNumber();

        // Wrapped, not truncated. The credit ran off both edges of the screen
        // as a single centred line, and it is the one string here that has to
        // be readable in full — CC BY 4.0 requires the source be named. An
        // ellipsis would satisfy the layout and not the licence.
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        var lines = wrap(dc, res(Rez.Strings.Attribution), Graphics.FONT_XTINY,
                         (w(dc) * 0.82).toNumber());
        for (var i = 0; i < lines.size(); i += 1) {
            dc.drawText(cx, top + i * fh, Graphics.FONT_XTINY, lines[i],
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.drawText(cx, top + lines.size() * fh, Graphics.FONT_XTINY, "CC BY 4.0",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Break text into lines that fit `maxW`, at word boundaries.
    //!
    //! Monkey C has no split(), so this scans for spaces itself. A single word
    //! too long for the line is hard-broken rather than allowed to overflow —
    //! no Finnish or Swedish word here is that long, but silent overflow is
    //! exactly the failure this function exists to prevent.
    function wrap(dc as Graphics.Dc, text as String, font as Graphics.FontDefinition,
                  maxW as Number) as Array<String> {
        var lines = [] as Array<String>;
        var rest = text;
        while (rest.length() > 0) {
            if (dc.getTextWidthInPixels(rest, font) <= maxW) {
                lines.add(rest);
                break;
            }
            var cut = -1;
            for (var i = 0; i < rest.length(); i += 1) {
                if (rest.substring(i, i + 1).equals(" ")) {
                    if (dc.getTextWidthInPixels(rest.substring(0, i), font) <= maxW) {
                        cut = i;
                    } else {
                        break;
                    }
                }
            }
            if (cut <= 0) {
                var n = rest.length();
                while (n > 1 && dc.getTextWidthInPixels(rest.substring(0, n), font) > maxW) {
                    n -= 1;
                }
                lines.add(rest.substring(0, n));
                rest = rest.substring(n, rest.length());
            } else {
                lines.add(rest.substring(0, cut));
                rest = rest.substring(cut + 1, rest.length());
            }
        }
        return lines;
    }

    function message(dc as Graphics.Dc, res as ResourceId) as Void {
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((w(dc) / 2).toNumber(), (h(dc) / 2).toNumber(), Graphics.FONT_XTINY,
                    res2(res),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
