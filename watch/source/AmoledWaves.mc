import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

//! AMOLED-styled Waves (Buoy) page — fourth page of the C5s graphics
//! overhaul (FI-WEATHER-ROADMAP.md), same approach and shared shapes as
//! AmoledSea.mc. Wave height has no "hot/cold" semantic the way
//! temperature or even wind danger does, so the crown gauge uses a single
//! cold-blue ramp (light -> deep blue) instead of the warm cold->hot
//! sweep Land/Sea use — matches the "cooler palette" the original 4-page
//! Artifact mockup used for this page, one of the few things carried over
//! from that sketch rather than re-derived.
(:amoledTheme)
module AmoledWaves {

    const WAVE_MAX = 3.0;
    const ARC_START = 158.0;
    const ARC_END = 22.0;

    var _waveBmp = null;
    var _tempBmp = null;

    function waveBmp() as WatchUi.BitmapResource {
        if (_waveBmp == null) { _waveBmp = WatchUi.loadResource(Rez.Drawables.IconWaveBitmap); }
        return _waveBmp;
    }
    function tempBmp() as WatchUi.BitmapResource {
        if (_tempBmp == null) { _tempBmp = WatchUi.loadResource(Rez.Drawables.IconTempBitmap); }
        return _tempBmp;
    }

    function draw(dc as Graphics.Dc, pageIndex as Number, pageCount as Number) as Void {
        var w = dc.getWidth();
        var cx = w / 2.0;
        var cy = dc.getHeight() / 2.0;
        var s = w / 480.0;

        dc.setColor(Theme.INK, Theme.BG);
        dc.clear();
        rim(dc, cx, cy, s);

        var m = Api.marine;
        var hasWave = Api.v(m, "hasWave") == true;
        var titleBottom = title(dc, cx, cy, s, Pages.res(Rez.Strings.PageBuoy));

        if (!hasWave) {
            if (m == null) {
                if (!Pages.loading(dc, Api.marineState)) { Pages.failureMessage(dc); }
            } else if (!Pages.loading(dc, Api.marineState)) {
                var mode = Api.v(m, "mode");
                Pages.message(dc, mode != null && mode.equals("none")
                    ? Rez.Strings.NoBuoyArea : Rez.Strings.NoBuoy);
            }
            Pages.drawPager(dc, pageIndex, pageCount);
            return;
        }

        var hs = Api.v(m, "wHs");
        var per = Api.v(m, "wPer");
        var dir = Api.v(m, "wDir");

        var auto = Config.seaBuoy() == 0;
        var stName = null;
        if (Api.v(m, "wMeas") == true) {
            stName = Fmt.dropPrefix(Fmt.shortStation(Api.v(m, "wName")), Config.landPlace());
            var d = Api.v(m, "wDist");
            if (auto && d != null) { stName = stName + " · " + Fmt.dist(d); }
        } else {
            stName = Pages.res(Rez.Strings.Modelled);
        }

        arcGauge(dc, cx, cy, s, hs);
        warnBanner(dc, cx, s, titleBottom, Api.v(m, "waveWarn"),
            Rez.Strings.SeaWaveModerate, Rez.Strings.SeaWaveSevere);

        var readingTop = SY(cy, s, 128);
        var readingH = dc.getFontHeight(Graphics.FONT_NUMBER_MILD);
        var hsText = Fmt.metresValue(hs);
        dc.setColor(Theme.waveColour(hs), Graphics.COLOR_TRANSPARENT);
        dc.drawText(SX(cx, s, 218), readingTop, Graphics.FONT_NUMBER_MILD,
            hsText, Graphics.TEXT_JUSTIFY_CENTER);
        // TEXT_JUSTIFY_VCENTER against the number's own midline, not
        // top-anchored box math — see AmoledSea.mc's identical fix for why.
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SX(cx, s, 218) + dc.getTextWidthInPixels(hsText, Graphics.FONT_NUMBER_MILD) / 2 + SZ(s, 8),
            readingTop + readingH / 2,
            Graphics.FONT_XTINY, "M",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var y = readingTop + readingH + SZ(s, 2);

        var wbmp = waveBmp();
        var heroIconH = (readingH * 0.45).toNumber();
        var heroIconW = (heroIconH * wbmp.getWidth() / wbmp.getHeight()).toNumber();
        dc.drawScaledBitmap(SX(cx, s, 64), readingTop + (readingH - heroIconH) / 2, heroIconW, heroIconH, wbmp);

        if (stName != null) {
            // Centred on the dial's true centre — same fix as Land's
            // place-name row, found on real hardware 2026-10-28.
            dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(SX(cx, s, 240), y, Graphics.FONT_XTINY, stName, Graphics.TEXT_JUSTIFY_CENTER);
        }
        y += dc.getFontHeight(Graphics.FONT_XTINY) + SZ(s, 4);

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(SX(cx, s, 90), y, SX(cx, s, 390), y);
        y += SZ(s, 4);

        // Period + direction, same combined-row pattern as Sea's gust row
        // — centred as a cluster (not left-anchored, same reasoning as
        // Sea's fix), font dropped to FONT_XTINY.
        var rowFont = Graphics.FONT_XTINY;
        var rowH = dc.getFontHeight(rowFont);
        var perText = Pages.res(Rez.Strings.Period) + " " + (per == null ? Fmt.DASH : Fmt.one(per)) + " s";
        var perW = dc.getTextWidthInPixels(perText, rowFont);
        var arrowR = SZ(s, 13);
        var perTotalW = perW + SZ(s, 16) + arrowR * 2;
        var perLeft = SX(cx, s, 240) - perTotalW / 2;
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(perLeft, y, rowFont, perText, Graphics.TEXT_JUSTIFY_LEFT);
        Pages.arrow(dc, perLeft + perW + SZ(s, 16) + arrowR, y + rowH / 2, arrowR, dir);
        y += rowH + SZ(s, 8);

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(SX(cx, s, 90), y, SX(cx, s, 390), y);
        y += SZ(s, 8);

        var water = Api.v(m, "wTemp");
        if (water != null) {
            var waterText = Pages.res(Rez.Strings.SeaTemp) + " " + Fmt.temp(water);
            if (Api.v(m, "wTempMeas") != true) {
                waterText = waterText + " · " + Pages.res(Rez.Strings.Modelled);
            }
            var tbmp = tempBmp();
            var waterIconH = (dc.getFontHeight(Graphics.FONT_XTINY) * 0.85).toNumber();
            var waterIconW = (waterIconH * tbmp.getWidth() / tbmp.getHeight()).toNumber();
            var waterTw = dc.getTextWidthInPixels(waterText, Graphics.FONT_XTINY);
            var waterLeft = SX(cx, s, 240) - (waterIconW + SZ(s, 6) + waterTw) / 2;
            dc.drawScaledBitmap(waterLeft, y, waterIconW, waterIconH, tbmp);
            dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(waterLeft + waterIconW + SZ(s, 6), y, Graphics.FONT_XTINY,
                waterText, Graphics.TEXT_JUSTIFY_LEFT);
            y += dc.getFontHeight(Graphics.FONT_XTINY) + SZ(s, 4);
        }

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SX(cx, s, 240), y, Graphics.FONT_XTINY,
            Fmt.age(Api.v(m, "wAt")), Graphics.TEXT_JUSTIFY_CENTER);

        Pages.drawPager(dc, pageIndex, pageCount);
    }

    function SX(cx as Float, s as Float, mockX as Numeric) as Number {
        return (cx + (mockX - 240) * s).toNumber();
    }
    function SY(cy as Float, s as Float, mockY as Numeric) as Number {
        return (cy + (mockY - 240) * s).toNumber();
    }
    function SZ(s as Float, len as Numeric) as Number {
        return (len * s).toNumber();
    }

    function rim(dc as Graphics.Dc, cx as Float, cy as Float, s as Float) as Void {
        dc.setColor(0x141A1D, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawCircle(cx.toNumber(), cy.toNumber(), SZ(s, 222));
        dc.setPenWidth(1);
    }

    function title(dc as Graphics.Dc, cx as Float, cy as Float, s as Float, text as String) as Number {
        var y = SY(cy, s, 54);
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SX(cx, s, 240), y, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER);
        return y + dc.getFontHeight(Graphics.FONT_XTINY);
    }

    function arcGauge(dc as Graphics.Dc, cx as Float, cy as Float, s as Float, hs as Numeric?) as Void {
        var r = SZ(s, 206);
        var pen = SZ(s, 7);
        if (pen < 2) { pen = 2; }
        dc.setPenWidth(pen);

        var steps = 32;
        for (var i = 0; i < steps; i += 1) {
            var f0 = i.toFloat() / steps;
            var f1 = (i + 1).toFloat() / steps;
            dc.setColor(gradColour((f0 + f1) / 2.0), Graphics.COLOR_TRANSPARENT);
            var a0 = ARC_START - f0 * (ARC_START - ARC_END);
            var a1 = ARC_START - f1 * (ARC_START - ARC_END);
            dc.drawArc(cx.toNumber(), cy.toNumber(), r, Graphics.ARC_CLOCKWISE, a0, a1);
        }
        dc.setPenWidth(1);

        if (hs == null) { return; }
        var frac = hs / WAVE_MAX;
        if (frac < 0.0) { frac = 0.0; }
        if (frac > 1.0) { frac = 1.0; }
        var angle = Math.toRadians(ARC_START - frac * (ARC_START - ARC_END));
        var mx = cx + r * Math.cos(angle);
        var my = cy - r * Math.sin(angle);
        dc.setColor(gradColour(frac), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx.toNumber(), my.toNumber(), SZ(s, 5));
    }

    //! Single cold-blue ramp (light -> deep), not the warm cold->hot sweep
    //! Land/Sea use — see the module header note.
    function gradColour(f as Float) as Number {
        var stops = [[0xbf, 0xe3, 0xff], [0x3f, 0xa6, 0xff], [0x1a, 0x4a, 0xb8]];
        if (f <= 0.0) { return rgb(stops[0]); }
        if (f >= 1.0) { return rgb(stops[2]); }
        var seg = f * 2.0;
        var i = seg.toNumber();
        if (i > 1) { i = 1; }
        var lf = seg - i;
        var a = stops[i];
        var b = stops[i + 1];
        return rgb([
            (a[0] + (b[0] - a[0]) * lf).toNumber(),
            (a[1] + (b[1] - a[1]) * lf).toNumber(),
            (a[2] + (b[2] - a[2]) * lf).toNumber(),
        ]);
    }

    function rgb(c as Array<Number>) as Number {
        return (c[0] << 16) | (c[1] << 8) | c[2];
    }

    function warnBanner(dc as Graphics.Dc, cx as Float, s as Float, titleBottom as Number,
                         severity as String?, moderateRes as ResourceId, severeRes as ResourceId) as Void {
        if (severity == null) { return; }
        var text = null;
        var colour = Theme.OVER;
        if (severity.equals("Severe") || severity.equals("Extreme")) {
            text = Pages.res(severeRes);
            colour = Theme.HOT;
        } else if (severity.equals("Moderate")) {
            text = Pages.res(moderateRes);
        }
        if (text == null) { return; }
        text = text.toUpper();

        var iconS = SZ(s, 18);
        var textFont = Graphics.FONT_XTINY;
        var textW = dc.getTextWidthInPixels(text, textFont);
        var textH = dc.getFontHeight(textFont);
        var textScale = 0.82;
        var scaledTextW = (textW * textScale).toNumber();
        var scaledTextH = (textH * textScale).toNumber();

        var ref = Graphics.createBufferedBitmap({ :width => textW, :height => textH });
        var textBmp = ref.get();
        var bdc = textBmp.getDc();
        bdc.setColor(0x3a1414, 0x3a1414);
        bdc.clear();
        bdc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        bdc.drawText(0, 0, textFont, text, Graphics.TEXT_JUSTIFY_LEFT);

        var padL = SZ(s, 10);
        var iconGap = SZ(s, 6);
        var padR = SZ(s, 12);
        var chipW = padL + iconS + iconGap + scaledTextW + padR;
        var chipH = SZ(s, 32);
        var x = SX(cx, s, 240) - chipW / 2;
        var y = titleBottom + SZ(s, 6);
        dc.setColor(0x3a1414, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, chipW, chipH, SZ(s, 8));
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y, chipW, chipH, SZ(s, 8));
        Icons.warning(dc, x + padL, y + (chipH - iconS) / 2, iconS, colour);
        dc.drawScaledBitmap(x + padL + iconS + iconGap, y + (chipH - scaledTextH) / 2,
            scaledTextW, scaledTextH, textBmp);
    }
}
