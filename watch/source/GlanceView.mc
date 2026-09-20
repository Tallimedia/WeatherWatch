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

    //! Resolves a configured slot to a label, value and colour.
    hidden function field(which as Number) as Array? {
        var land = Api.land;
        var m = Api.marine;

        if (which == 0) {
            var t = Api.v(land, "temp");
            return [Fmt.temp(t), Theme.tempColour(t)];
        } else if (which == 1) {
            var ms = Api.v(land, "wind");
            var g = Api.v(land, "gust");
            return [Fmt.windValue(ms) + " " + Fmt.windUnitLabel(),
                    Theme.windColour(ms, g, Config.landWind(), Config.landGust())];
        } else if (which == 2) {
            var sms = Api.v(m, "stWind");
            var sg = Api.v(m, "stGust");
            // Mean and gust coloured together — splitting them implies a
            // distinction that does not exist (RESEARCH.md §17).
            return [Fmt.windValue(sms) + " (" + Fmt.windValue(sg) + ")",
                    Theme.windColour(sms, sg, Config.seaWind(), Config.seaGust())];
        } else if (which == 3) {
            var g2 = Api.v(m, "stGust");
            return [Fmt.windValue(g2) + " " + Fmt.windUnitLabel(),
                    Theme.windColour(null, g2, Config.seaWind(), Config.seaGust())];
        } else if (which == 4) {
            var hs = Api.v(m, "wHs");
            return [Fmt.metres(hs), Theme.waveColour(hs)];
        } else if (which == 5) {
            var wt = Api.v(m, "wTemp");
            return [Fmt.temp(wt), Theme.INK];
        }
        return null;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        dc.clear();

        var cy = dc.getHeight() / 2;
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(2, cy - dc.getHeight() * 0.34, Graphics.FONT_XTINY, "FIWeather",
                    Graphics.TEXT_JUSTIFY_LEFT);

        var slots = [Config.glance1(), Config.glance2()];
        var x = 2;
        for (var i = 0; i < slots.size(); i += 1) {
            var f = field(slots[i]);
            if (f == null) { continue; }
            dc.setColor(f[1] as Number, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, cy + dc.getHeight() * 0.04, Graphics.FONT_MEDIUM, f[0] as String,
                        Graphics.TEXT_JUSTIFY_LEFT);
            x += dc.getWidth() * 0.42;
        }
    }
}
