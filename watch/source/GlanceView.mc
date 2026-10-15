import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Glance card: two configurable fields.
//!
//! Runs in roughly 32 kB shared with the background code, so it draws from the
//! cached payloads and asks for a small refresh rather than pulling everything
//! (RESEARCH.md §17).
(:glance)
class FIWeatherGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onShow() as Void {
        // The cached values are drawn either way; only the refresh is throttled.
        Api.restore();
        if (Api.glanceDue()) {
            Api.fetchLand();
            Api.fetchMarine();
        }
    }

    //! Resolves a configured slot to [label, value, colour].
    //!
    //! A glance is roughly a third of the screen and one text line tall for
    //! values, so there is room for a small caption above each of two numbers —
    //! which is what makes them readable without opening the app.
    hidden function field(which as Number) as Array? {
        var land = Api.land;
        var m = Api.marine;

        if (which == 0) {
            var t = Api.v(land, "temp");
            return [Labels.land(), Fmt.temp(t), Theme.tempColour(t)];
        } else if (which == 1) {
            var ms = Api.v(land, "wind");
            var g = Api.v(land, "gust");
            return [Labels.landWind(),
                    Fmt.windValue(ms) + " " + Fmt.windUnitLabel(),
                    Theme.windColour(ms, g, Config.landWind(), Config.landGust())];
        } else if (which == 2) {
            var sms = Api.v(m, "stWind");
            var sg = Api.v(m, "stGust");
            // Mean and gust coloured together — splitting them implies a
            // distinction that does not exist (RESEARCH.md §17).
            // Found 2026-10-15: windPair() was built compact ("5.5/6.5") and
            // this was the only slot that drew it as-is — every other wind
            // slot here appends Fmt.windUnitLabel() afterward, this one
            // never did, so the unit was silently missing on the real watch.
            return [Labels.seaWind(),
                    Fmt.windPair(sms, sg) + " " + Fmt.windUnitLabel(),
                    Theme.windColour(sms, sg, Config.seaWind(), Config.seaGust())];
        } else if (which == 3) {
            var g2 = Api.v(m, "stGust");
            return [Labels.seaGust(),
                    Fmt.windValue(g2) + " " + Fmt.windUnitLabel(),
                    Theme.windColour(null, g2, Config.seaWind(), Config.seaGust())];
        } else if (which == 4) {
            var hs = Api.v(m, "wHs");
            return [Labels.wave(), Fmt.metres(hs), Theme.waveColour(hs)];
        } else if (which == 5) {
            var wt = Api.v(m, "wTemp");
            return [Labels.water(), Fmt.temp(wt), Theme.INK];
        }
        return null;
    }

    //! The warning icon's colour, if a warning applies to a configured slot
    //! — reading whatever Api.road/Api.marine already hold in
    //! Application.Storage, the same cached data the full app's own fetches
    //! populate. No new network call here: a glance runs in ~32 kB and the
    //! phone is often out of range, so this has to work from what's already
    //! there or not at all.
    //!
    //! Always the triangle (:warning), never Icons.ice() for the road-ice
    //! case — tried a distinct snowflake here 2026-10-09, reverted: its thin
    //! branching lines don't survive this size (same lesson as the temp
    //! icon tried and reverted earlier the same day), and unlike the full
    //! Land page, the icon has no adjoining text to tell "ice" from "wind"
    //! apart anyway — the caption ("Maan lämp" vs "Merituuli") already does
    //! that job, so the icon's only job here is "something's active".
    //!
    //! Colour: marine warnings follow the exact same severity mapping as
    //! drawSeaWarning() on the full pages — Theme.OVER for moderate,
    //! Theme.HOT once it crosses into Severe/Extreme. Road ice is the one
    //! exception, 2026-10-09: always Theme.COLD (the same blue the app
    //! already uses for a cold temperature reading) regardless of
    //! moderate/high, rather than matching drawRoadIce()'s own OVER/HOT —
    //! Nico's call after comparing both in the sim. Blue reads as "ice"
    //! category at a glance, which matters more here than the severity
    //! distinction does, precisely because there's no icon shape left to
    //! carry that distinction once the snowflake had to go.
    //!
    //! Icon sizing matches Pages.mc's own `iconRow` at FONT_XTINY
    //! (`fh * 0.62`) rather than inventing a new size — that proportion is
    //! already proven at this scale on the Land/Sea/Waves pages themselves.
    hidden function warnColour(which as Number) as Number? {
        if (which == 0) {
            var lvl = Api.road != null ? Api.v(Api.road, "level") : null;
            if (lvl != null && (lvl.equals("high") || lvl.equals("moderate"))) { return Theme.COLD; }
        } else if (which == 2 || which == 3) {
            var w = Api.marine != null ? Api.v(Api.marine, "windWarn") : null;
            if (w != null && (w.equals("Severe") || w.equals("Extreme"))) { return Theme.HOT; }
            if (w != null && w.equals("Moderate")) { return Theme.OVER; }
        } else if (which == 4) {
            var wv = Api.marine != null ? Api.v(Api.marine, "waveWarn") : null;
            if (wv != null && (wv.equals("Severe") || wv.equals("Extreme"))) { return Theme.HOT; }
            if (wv != null && wv.equals("Moderate")) { return Theme.OVER; }
        }
        return null;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var slots = [Config.glance1(), Config.glance2()];
        var labelH = dc.getFontHeight(Graphics.FONT_XTINY);
        // FONT_SMALL rather than MEDIUM: the captions need the width more
        // than the numbers need the size.
        var valueFont = Graphics.FONT_SMALL;
        var valueH = dc.getFontHeight(valueFont);

        // Two columns, each a caption over a value. Vertically centred as a
        // block so the pair sits in the glance strip rather than against its top.
        var blockH = labelH + valueH;
        var top = ((dc.getHeight() - blockH) / 2).toNumber();
        var colW = (dc.getWidth() / 2).toNumber();

        for (var i = 0; i < slots.size(); i += 1) {
            var f = field(slots[i]);
            if (f == null) { continue; }
            var x = 2 + i * colW;

            // A warning icon prefixes the caption, same icon-then-label order
            // as iconRow on the full pages — not a floating corner badge,
            // which at this column width collided with the next column's own
            // caption (found 2026-10-09: "Maan lämp❄ Merituuli" read as one
            // run of text). Only reserves the gutter when a warning is
            // actually active, so the normal case is untouched.
            var wc = warnColour(slots[i]);
            var isize = (labelH * 0.62).toNumber();
            var textX = x;
            if (wc != null) {
                var iy = (top + (labelH - isize) / 2).toNumber();
                Icons.warning(dc, x, iy, isize, wc as Number);
                textX = x + isize + 3;
            }
            var room = colW - (textX - x) - 6;

            // White, not a grey: the carousel dims the whole glance strip on
            // AMOLED, so anything recessive stops being legible there even
            // when it reads fine in the simulator. The caption stays
            // subordinate to the value by font size instead of by colour.
            dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(textX, top, Graphics.FONT_XTINY, clip(dc, f[0] as String,
                        Graphics.FONT_XTINY, room), Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(f[2] as Number, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, top + labelH - 2, valueFont, clip(dc, f[1] as String,
                        valueFont, colW - 6), Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    //! A glance column is narrow; a value that overruns it spills into the next
    //! one rather than being clipped, so trim before drawing.
    hidden function clip(dc as Graphics.Dc, text as String,
                         font as Graphics.FontDefinition, room as Number) as String {
        var t = text;
        while (t.length() > 2 && dc.getTextWidthInPixels(t, font) > room) {
            t = t.substring(0, t.length() - 1);
        }
        return t;
    }
}
