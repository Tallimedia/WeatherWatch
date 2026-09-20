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
        Api.restore();
        Api.fetchLand();
        Api.fetchMarine();
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
            return [Labels.seaWind(),
                    Fmt.windPair(sms, sg),
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
            var room = colW - 6;
            dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, top, Graphics.FONT_XTINY, clip(dc, f[0] as String,
                        Graphics.FONT_XTINY, room), Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(f[2] as Number, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, top + labelH - 2, valueFont, clip(dc, f[1] as String,
                        valueFont, room), Graphics.TEXT_JUSTIFY_LEFT);
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
