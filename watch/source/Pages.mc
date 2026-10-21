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
    //! one, which on the water is the difference that matters.
    //!
    //! The build number used to sit on this row. It earned its keep during the
    //! beta — twice it settled which build a screenshot had come from — but
    //! the About page carries it now, and keeping it on every page put a
    //! version string into every store screenshot, so the artwork expired with
    //! each release.
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
            text = age;
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

        // Found 2026-10-14: giving the compass point its own row (below)
        // made this page one row taller than before even in the normal
        // case — no fallback label, just the arrow+direction row that
        // didn't used to exist — and that extra height pushed
        // forecastStrip's own two rows down into the fixed-position footer
        // at the bottom (updated() draws at a constant 0.855h, independent
        // of how tall the stack above it grew). Tightened the top offset
        // and gaps here to recover that row's worth of height.
        stackStart(dc, 0.21);
        iconRowUnit(dc, :temp, Graphics.FONT_NUMBER_MILD, Fmt.tempValue(t),
                    Fmt.tempIsBorrowed(d) ? "°C*" : "°C",
                    Theme.tempColour(t), -6);
        // The compass point used to sit inline here ("... m/s S"), ambiguous
        // next to "m/s" whenever the wind happened to blow from the south
        // (found 2026-10-13, not a new bug — just coincidence of the day's
        // actual direction). Moved to its own row with the arrow, same
        // compassRow() the Sea and Buoy pages already use for exactly this.
        iconRow(dc, :wind, Graphics.FONT_SMALL,
                Fmt.windValue(ms) + " (" + Fmt.windValue(gust) + ") " + Fmt.windUnitLabel(),
                Theme.windColour(ms, gust, Config.landWind(), Config.landGust()), 2);

        // Two-tier wind fallback (RESEARCH.md §C5j) — the station this page
        // names in its header may not be the one that measured the wind.
        // Rides on the compass row rather than a row of its own: a
        // dedicated row was tried first and pushed the forecast strip and
        // footer down into the page-dot pager (Land has less spare height
        // than Sea/Buoy, which don't carry a forecast strip). "road" is a
        // live reading from a nearby Fintraffic road-weather station (a
        // different, denser network than FMI's own observation stations);
        // "forecast" is a modelled hour-ahead value, same string the
        // Forecast page itself uses — it genuinely comes from that product,
        // not a separate model, so it is not labelled "Modelled".
        var windSrc = Api.v(d, "windSrc");
        var windSrcLabel = (windSrc != null && !windSrc.equals("station"))
            ? (windSrc.equals("road") ? res(Rez.Strings.WindRoad) : res(Rez.Strings.PageForecast))
            : null;
        compassRow(dc, dir, windSrcLabel);

        drawRoadIce(dc);
        rainLikelihood(dc, _y);

        // One age per page here rather than two: the earlier "8 min · 8 min"
        // read as a repeat rather than as two different fields.
        updated(dc, Fmt.age(Api.v(d, "atW")), Api.landState);
    }

    //! Rain-likelihood row, replacing the old 6-hourly forecast strip —
    //! RESEARCH.md §27 update, 2026-10-15: tester feedback wanted rain data
    //! on Land. First attempt was a live temp-trend sparkline; dropped the
    //! same day on real-hardware feedback (Nico) — the line read as
    //! meaningless noise (ordinary station wobble filled the whole chart
    //! height regardless of scale), and sitting directly under Wind with no
    //! label, it read as wind data, not temperature. Two plain numbers need
    //! no chart to be unambiguous.
    function rainLikelihood(dc as Graphics.Dc, top as Number) as Void {
        var pop1h = Api.v(Api.forecast, "pop1h");
        var pop3h = Api.v(Api.forecast, "pop3h");
        if (pop1h == null && pop3h == null) { return; }

        var cx = (w(dc) / 2).toNumber();
        var lineH = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top, Graphics.FONT_XTINY, res(Rez.Strings.RainChance),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, top + lineH, Graphics.FONT_XTINY,
                    "1h " + popText(pop1h) + "   3h " + popText(pop3h),
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    function popText(pop as Float?) as String {
        if (pop == null) { return Fmt.DASH; }
        return Math.round(pop).toNumber().toString() + "%";
    }

    //! Exception row: present only when the nearest FMI road station reports
    //! `ice_risk` moderate or higher, absent otherwise — v1.1, RESEARCH.md
    //! §16. Icon and word together, never the icon alone: a bare snowflake
    //! beside air temperature and wind reads as "icy outside", and the one
    //! thing this row must say is "icy road". `moderate` and `high` get
    //! different words, not just different colours, since colour alone
    //! disappears on a 1-bit screen (§24) and a mono port is a live
    //! possibility for this app.
    function drawRoadIce(dc as Graphics.Dc) as Void {
        var level = Api.v(Api.road, "level");
        if (level == null) { return; }

        var text = null;
        var colour = Theme.OVER;
        if (level.equals("high")) {
            text = res(Rez.Strings.BlackIceWarning);
            colour = Theme.HOT;
        } else if (level.equals("moderate")) {
            text = res(Rez.Strings.IcyRoadWarning);
        }
        if (text == null) { return; }

        iconRow(dc, :ice, Graphics.FONT_XTINY, text, colour, 4);
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

        compassRow(dc, dir, null);

        iconRow(dc, :temp, Graphics.FONT_XTINY, Fmt.temp(Api.v(m, "stTemp")), Theme.DIM, 0);

        drawSeaWarning(dc, Api.v(m, "windWarn"), Rez.Strings.SeaWindModerate,
                       Rez.Strings.SeaWindSevere);

        updated(dc, Fmt.age(Api.v(m, "stAt")), Api.marineState);
    }

    //! A direction arrow and its compass-point label, as one centred row.
    //!
    //! Was three separate copies of this same block (Sea, Buoy, and now
    //! Land) — factored out 2026-10-13 after the third copy was about to be
    //! added, per the code review's own flag that a future layout tweak to
    //! one copy (exactly what happened here) could silently drift from the
    //! others. Measured together so the pair is centred as a unit rather
    //! than each guessing its own offset.
    //! `suffix`, when given, rides on the same row ("· Tieasema") rather than
    //! costing a row of its own — Land's wind-source fallback label
    //! (RESEARCH.md §C5j) uses this; Sea/Buoy never pass one. Found
    //! 2026-10-13: a dedicated row for the label pushed the forecast strip
    //! and footer down into the page-dot pager on Land, which has less
    //! spare height than Sea/Buoy (it already carries the forecast strip
    //! below). Folding the label into the existing row costs nothing extra.
    function compassRow(dc as Graphics.Dc, dir as Numeric?, suffix as String?) as Void {
        var label = Fmt.compass(dir);
        if (suffix != null) { label = label + " · " + suffix; }
        var labelW = dc.getTextWidthInPixels(label, Graphics.FONT_SMALL);
        var r = (h(dc) * 0.045).toNumber();
        var total = r * 2 + 6 + labelW;
        var left = (w(dc) - total) / 2;
        arrow(dc, left + r, _y + dc.getFontHeight(Graphics.FONT_SMALL) / 2, r, dir);
        dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + r * 2 + 6, _y, Graphics.FONT_SMALL, label, Graphics.TEXT_JUSTIFY_LEFT);
        _y += dc.getFontHeight(Graphics.FONT_SMALL) + 4;
    }

    //! Exception row: FMI marine warning (CAP feed), present only when one is
    //! live for this point, absent otherwise — v1.1, RESEARCH.md §16, same
    //! icon-plus-word pattern as the road-ice row. Shared by the Sea page
    //! (wind) and the Waves page (wave height); `severity` is the raw CAP
    //! string ("Moderate"/"Severe"/"Extreme"/"Minor") the backend passes
    //! through unshaped, same as `ice_risk.level`.
    function drawSeaWarning(dc as Graphics.Dc, severity as String?,
                            moderateRes as ResourceId, severeRes as ResourceId) as Void {
        if (severity == null) { return; }
        var text = null;
        var colour = Theme.OVER;
        if (severity.equals("Severe") || severity.equals("Extreme")) {
            text = res(severeRes);
            colour = Theme.HOT;
        } else if (severity.equals("Moderate")) {
            text = res(moderateRes);
        }
        if (text == null) { return; }
        iconRow(dc, :warning, Graphics.FONT_XTINY, text, colour, 4);
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
            // Three different cases share this branch, and only the last two
            // look alike on screen. `m == null` means the fetch itself never
            // succeeded (no connection, server error) — same failureMessage()
            // path drawLand/drawSea use, not the "no buoy" wording below,
            // which used to show here on any network failure too (found in
            // code review 2026-10-13: mode is null when m is null, so the
            // ternary always fell through to NoBuoy regardless of the real
            // cause). The other two are real absences once a fetch has
            // actually succeeded: inland there is no buoy at all and never
            // will be; on the coast they are lifted out for the winter — same
            // empty page, and the caption is all that distinguishes them.
            if (m == null) {
                if (!loading(dc, Api.marineState)) { failureMessage(dc); }
            } else if (!loading(dc, Api.marineState)) {
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

        compassRow(dc, dir, null);

        var water = Api.v(m, "wTemp");
        if (water != null) {
            // Independent of the header's own "· Modelled" above, which
            // speaks to wave height (wMeas) — a buoy can report live waves
            // while its water sensor is silent and the backend fills this
            // one value from the hydrodyn model instead (RESEARCH.md §26).
            // Silent when measured, same "speaks up only when not the
            // normal case" rule the rest of the app already follows.
            var waterText = res(Rez.Strings.WaterTemp) + " " + Fmt.temp(water);
            if (Api.v(m, "wTempMeas") != true) {
                waterText = waterText + " · " + res(Rez.Strings.Modelled);
            }
            iconRow(dc, :temp, Graphics.FONT_XTINY, waterText, Theme.DIM, 4);
        }

        drawSeaWarning(dc, Api.v(m, "waveWarn"), Rez.Strings.SeaWaveModerate,
                       Rez.Strings.SeaWaveSevere);

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
        // Flat (fillColour == colour) at this size — the Sea/Waves air- and
        // water-temperature rows draw :temp at FONT_XTINY, the same small
        // scale that's already failed for other icons in this file; the
        // two-tone treatment is reserved for Land's much bigger hero icon.
        if (kind == :temp)         { Icons.temp(dc, left, iy, size, Theme.DIM, Theme.DIM); }
        else if (kind == :wind)    { Icons.wind(dc, left, iy, size, Theme.DIM); }
        else if (kind == :wave)    { Icons.wave(dc, left, iy, size, Theme.DIM); }
        else if (kind == :clock)   { Icons.clock(dc, left, iy, size, Theme.DIM); }
        else if (kind == :ice)     { Icons.ice(dc, left, iy, size, Theme.DIM); }
        else if (kind == :warning) { Icons.warning(dc, left, iy, size, Theme.DIM); }
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
        var size = (fh * 0.62).toNumber();
        var drawnW = (size * Icons.widthFactor(kind)).toNumber();
        var vw = dc.getTextWidthInPixels(value, numFont);
        var uw = dc.getTextWidthInPixels(unit, unitFont);
        var gap = 5;
        var unitGap = 3;

        var total = drawnW + gap + vw + unitGap + uw;
        var left = ((w(dc) - total) / 2).toNumber();
        var iy = _y + ((fh - size) / 2).toNumber();
        if (kind == :temp)      { Icons.temp(dc, left, iy, size, Theme.DIM, colour); }
        else if (kind == :wind) { Icons.wind(dc, left, iy, size, Theme.DIM); }
        else if (kind == :wave) { Icons.wave(dc, left, iy, size, Theme.DIM); }

        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + drawnW + gap, _y, numFont, value, Graphics.TEXT_JUSTIFY_LEFT);

        // Vertically centred on the number itself, so the unit sits on the
        // same line as the value — not pinned to its top (made "m/s"/"m"
        // look like stray superscript text) or its bare baseline (made "°C"
        // split into a disconnected mark and letter). One simple rule that
        // reads right for both. Nico's call, 2026-10-13, after three other
        // positions tried in the sim.
        dc.drawText(left + drawnW + gap + vw + unitGap, _y + fh / 2, unitFont, unit,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
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

    // ------------------------------------------------------------ forecast

    //! Opt-in (Config.showForecast), RESEARCH.md §27 — three-way split:
    //! today (rest of day) with more detail on top, Tomorrow/Day+2 basics
    //! side by side below. The four weather-condition icons (Icons.wx*) are
    //! new to the watch with this page — FMI's smartsymbol reduced to four
    //! categories (Api._symbolKind), not the ~20 the web pages use. One icon
    //! per summary row here, not a 13px corner badge, but still the simplest
    //! shape that holds, same lesson as everything else drawn today.
    //!
    //! Shifted from Tomorrow/+2/+3 to Today/Tomorrow/+2, 2026-10-15 — a
    //! tester wanted rain data for today, and this page already had the
    //! hi/lo/rain/wind layout a "today" bucket needs; Api.onForecast3's
    //! bucket loop just needed to stop skipping dayOffset 0. The bottom row
    //! still renders two unlabelled-by-data columns the same way; only
    //! which calendar day each one names changed.
    function drawForecast(dc as Graphics.Dc) as Void {
        // No header title — Nico's call, 2026-10-13: this page is already
        // identifiable by its own distinct layout, and the room a title
        // would cost is exactly what the bottom row needed to clear the
        // round bezel and the page-dot pager without further squeezing.
        if (loading(dc, Api.forecast3State)) { return; }
        var d = Api.forecast3;
        if (d == null) {
            message(dc, Rez.Strings.NoData);
            return;
        }
        var hi = Api.v(d, "hi");
        var lo = Api.v(d, "lo");
        var sym = Api.v(d, "sym");
        var rain = Api.v(d, "rain");
        var wind = Api.v(d, "wind");
        var gust = Api.v(d, "gust");
        // Not an Array on a cache written before 2026-10-15 (Application.Storage
        // held the old Today/Tomorrow/+2 bucket shift's predecessor, which had
        // no "pop" key at all) — crashed the sim on indexing [0] below before
        // this guard, confirmed live on real build output the same day.
        var pop = Api.v(d, "pop");
        if (!(pop instanceof Array)) { pop = [null, null, null, null]; }
        // Once Today has nothing left (late evening: the 6-hourly grid has
        // no point in the day and the 15-minute window is past midnight),
        // the page shifts a day — Tomorrow becomes the big row and +2/+3
        // the columns — rather than showing dashes (Nico, 2026-10-20).
        // Needs the fourth bucket, which a cache written before that
        // change does not have.
        var base = (hi[0] == null && hi.size() > 3) ? 1 : 0;
        var cx = (w(dc) / 2).toNumber();

        // --- Today (rest of day): more detail ---
        // Every vertical advance below uses a real measured height (icon
        // size, font height, or whichever of the two is taller for a mixed
        // row) — never a guessed fraction. A first pass guessed the
        // icon+hi/lo row's height from the icon alone and the number font
        // actually drew taller, overlapping the wind row under it; a second
        // bug let the Day+2/+3 row run into the page-dot pager PageView
        // draws separately at h*0.945. Both found on real sim output,
        // 2026-10-13.
        var xtinyH = dc.getFontHeight(Graphics.FONT_XTINY);
        var numH = dc.getFontHeight(Graphics.FONT_NUMBER_MILD);

        var top = (h(dc) * 0.1).toNumber();
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top, Graphics.FONT_XTINY, (base == 0 ? res(Rez.Strings.Today) : res(Rez.Strings.Tomorrow)),
                    Graphics.TEXT_JUSTIFY_CENTER);
        top += xtinyH + 2;

        var bigIcon = (h(dc) * 0.1).toNumber();
        // Plain single string, same pattern as Day+2/Day+3 below (confirmed
        // right in the sim) — reverted off drawHiLoBig()'s composed
        // big-digit/small-degree-mark rendering after two different offsets
        // both missed (floated mid-digit, then floated disconnected above
        // the digits entirely). FONT_NUMBER_MILD's own inline "°" glyph
        // reads slightly differently than the small-font version elsewhere,
        // accepted as a minor, known difference rather than guess a third
        // pixel offset blind. Nico's call, 2026-10-13.
        var hiLoText = hiLo(hi[base], lo[base]);
        var tw = dc.getTextWidthInPixels(hiLoText, Graphics.FONT_NUMBER_MILD);
        var rowH = bigIcon > numH ? bigIcon : numH;
        var rowLeft = cx - ((bigIcon + 8 + tw) / 2).toNumber();
        drawWx(dc, sym[base], rowLeft, top + ((rowH - bigIcon) / 2).toNumber(), bigIcon);
        dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rowLeft + bigIcon + 8, top + ((rowH - numH) / 2).toNumber(),
                    Graphics.FONT_NUMBER_MILD, hiLoText, Graphics.TEXT_JUSTIFY_LEFT);
        top += rowH + 2;

        var windRainText = Fmt.windRound(wind[base]) + " (" + Fmt.windRound(gust[base]) + ")"
                           + "  ·  " + res(Rez.Strings.Rain) + " " + Fmt.one(rain[base]) + " mm"
                           + popSuffix(pop[base]);
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        // Guarded against overflow, same as the header's own source line —
        // Swedish's "Nederbörd" ran this close enough to the round bezel's
        // edge to clip, found on real sim output 2026-10-13.
        dc.drawText(cx, top, Graphics.FONT_XTINY,
                    fit(dc, windRainText, Graphics.FONT_XTINY, (w(dc) * 0.92).toNumber()),
                    Graphics.TEXT_JUSTIFY_CENTER);
        top += xtinyH + 6;

        // --- divider ---
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w(dc) * 0.2).toNumber(), top, (w(dc) * 0.8).toNumber(), top);
        top += 8;

        // --- Day+2 / Day+3: basics only ---
        // Pulled in from a full-width half-and-half split (±0.25w from
        // centre) to ±0.17w — Nico's call, 2026-10-13: the full split sat
        // close enough to the round bezel's curve on each side to look
        // cramped against it, the same "usable width narrows" effect
        // headerPin already accounts for near the top of every page.
        var colOffset = (w(dc) * 0.17).toNumber();
        var smallIcon = (h(dc) * 0.075).toNumber();
        for (var i = 0; i < 2; i += 1) {
            var colCx = i == 0 ? cx - colOffset : cx + colOffset;
            var y = top;
            dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
            // i==0 is now Tomorrow's own string resource rather than a
            // computed "+2" — the day-bucket shift to Today/Tomorrow/+2
            // (2026-10-15) moved Tomorrow out of the top row and into this
            // loop's first column; only i==1 (+2 days) still needs the
            // computed label.
            var dayN = base + i + 1;
            var colLabel = dayN == 1 ? res(Rez.Strings.Tomorrow)
                                     : "+" + dayN.toString() + " " + res(Rez.Strings.DayAbbrev);
            dc.drawText(colCx, y, Graphics.FONT_XTINY, colLabel,
                        Graphics.TEXT_JUSTIFY_CENTER);
            y += xtinyH + 2;
            drawWx(dc, sym[base + i + 1], (colCx - smallIcon / 2).toNumber(), y, smallIcon);
            y += smallIcon + 2;
            dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(colCx, y, Graphics.FONT_XTINY, hiLo(hi[base + i + 1], lo[base + i + 1]),
                        Graphics.TEXT_JUSTIFY_CENTER);
            y += xtinyH;
            dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(colCx, y, Graphics.FONT_XTINY, Fmt.one(rain[base + i + 1]) + " mm",
                        Graphics.TEXT_JUSTIFY_CENTER);
            y += xtinyH;
            // Mean/gust, same midday-closest point and the same "mean
            // (gust)" pairing as every other wind figure in the app, but
            // without the unit label — Today's own row already establishes
            // it, and hi/lo and rain mm in these same columns already go
            // bare where they can for the same reason. Found on real
            // hardware, 2026-10-15: these columns are only colOffset*2 =
            // 0.34w apart centre to centre, so the first attempt's 0.32w
            // fit() cap left next to no gap — "m/s" on top of that
            // overflowed past centre on both sides and the round bezel
            // clipped what crossed into the other column, reading as
            // interleaved garbage rather than a clean truncation. 0.26w
            // leaves a real gap; measure again if gust ever regularly hits
            // 3 digits.
            dc.drawText(colCx, y, Graphics.FONT_XTINY,
                        fit(dc, Fmt.windRound(wind[base + i + 1]) + " (" + Fmt.windRound(gust[base + i + 1]) + ")",
                            Graphics.FONT_XTINY, (w(dc) * 0.26).toNumber()),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    //! "12°/4°" — a dash on whichever side is missing rather than dropping
    //! the row, same DASH convention as every other reading in the app.
    function hiLo(hi, lo) as String {
        return Fmt.zero(hi) + "°/" + Fmt.zero(lo) + "°";
    }

    //! " · 40 %" for the rest-of-day rain-probability figure, or "" when
    //! there's nothing left to say — `pop` (FMI's precipitation
    //! probability, 0-100) is distinct from the rain-mm total already on
    //! this row (RESEARCH.md §27 update, 2026-10-15): a dry forecast can
    //! still carry a real chance of rain, and vice versa.
    function popSuffix(pop as Float?) as String {
        if (pop == null) { return ""; }
        return "  ·  " + Math.round(pop).toNumber().toString() + " %";
    }

    //! Colour follows the condition, not a caller-supplied theme colour —
    //! Nico's call, 2026-10-16: a flat Theme.DIM grey "clear" circle read as
    //! an unexplained dot rather than a sun. These are decorative, not
    //! threshold signals, so they get their own Theme.WX_* names rather
    //! than reusing OVER/COLD/HOT (see Theme.mc).
    function drawWx(dc as Graphics.Dc, code, x as Number, y as Number,
                    s as Number) as Void {
        var kind = Api._symbolKind(code);
        if (kind == :clear) { Icons.wxClear(dc, x, y, s, Theme.WX_SUN); }
        else if (kind == :rain) { Icons.wxRain(dc, x, y, s, Theme.WX_RAIN); }
        else if (kind == :snow) { Icons.wxSnow(dc, x, y, s, Theme.WX_SNOW); }
        else { Icons.wxCloudy(dc, x, y, s, Theme.DIM); }
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
