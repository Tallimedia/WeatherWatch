import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

//! AMOLED-styled Sea page — third page of the C5s graphics overhaul
//! (FI-WEATHER-ROADMAP.md), same approach as AmoledLand.mc/AmoledForecast.mc:
//! sim-only test hook in PageView.mc, no device-tier split yet. Reuses
//! Land's proven shapes directly (crown gauge, top warning banner, hero
//! icon-beside-number, icon-then-value rows) rather than re-deriving them
//! from the old 4-page Artifact mockup — that mockup used a rose and a
//! different warning-chip position that Land itself moved away from
//! during real sim iteration, so this follows what's actually proven, not
//! the original sketch.
(:amoledTheme)
module AmoledSea {

    const WIND_MAX = 25.0;
    const ARC_START = 158.0;
    const ARC_END = 22.0;

    var _windBmp = null;
    var _tempBmp = null;

    function windBmp() as WatchUi.BitmapResource {
        if (_windBmp == null) { _windBmp = WatchUi.loadResource(Rez.Drawables.IconWindBitmap); }
        return _windBmp;
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
        var titleBottom = title(dc, cx, cy, s, Pages.res(Rez.Strings.PageSea));

        if (m == null) {
            if (!Pages.loading(dc, Api.marineState)) { Pages.failureMessage(dc); }
            Pages.drawPager(dc, pageIndex, pageCount);
            return;
        }

        var ms = Api.v(m, "stWind");
        var gust = Api.v(m, "stGust");
        var dir = Api.v(m, "stDir");
        var stName = Api.v(m, "stName");

        arcGauge(dc, cx, cy, s, ms);
        warnBanner(dc, cx, s, titleBottom, Api.v(m, "windWarn"),
            Rez.Strings.SeaWindModerate, Rez.Strings.SeaWindSevere);

        var readingTop = SY(cy, s, 128);
        var readingH = dc.getFontHeight(Graphics.FONT_NUMBER_MILD);
        dc.setColor(Theme.windColour(ms, gust, Config.seaWind(), Config.seaGust()),
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(SX(cx, s, 218), readingTop, Graphics.FONT_NUMBER_MILD,
            Fmt.windValue(ms), Graphics.TEXT_JUSTIFY_CENTER);
        // Same fix as Pages.mc's own iconRowUnit() (2026-10-13): centring
        // via TOP-anchored box math doesn't actually level two different
        // fonts' baselines, since FONT_NUMBER_MILD and FONT_XTINY have
        // different internal ascent/descent proportions — the real fix is
        // TEXT_JUSTIFY_VCENTER against the number's own vertical midline.
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SX(cx, s, 218) + dc.getTextWidthInPixels(Fmt.windValue(ms), Graphics.FONT_NUMBER_MILD) / 2 + SZ(s, 8),
            readingTop + readingH / 2,
            Graphics.FONT_XTINY, Fmt.windUnitLabel(),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var y = readingTop + readingH + SZ(s, 2);

        var wbmp = windBmp();
        var tempIconH = (readingH * 0.45).toNumber();
        var tempIconW = (tempIconH * wbmp.getWidth() / wbmp.getHeight()).toNumber();
        dc.drawScaledBitmap(SX(cx, s, 64), readingTop + (readingH - tempIconH) / 2, tempIconW, tempIconH, wbmp);

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

        // Direction arrow + gust, one row, centred as a whole cluster (not
        // left-anchored at x=104 like Land's wind row — that row balances
        // against an icon on its left, this one has nothing there, so the
        // same left anchor just read as hugging the edge). Font dropped to
        // FONT_XTINY, same as the rest of this page's secondary rows.
        var rowFont = Graphics.FONT_XTINY;
        var rowH = dc.getFontHeight(rowFont);
        var gustText = Pages.res(Rez.Strings.Gust) + " " + Fmt.windValue(gust) + " " + Fmt.windUnitLabel();
        var gustW = dc.getTextWidthInPixels(gustText, rowFont);
        var arrowR = SZ(s, 13);
        var gustTotalW = gustW + SZ(s, 16) + arrowR * 2;
        var gustLeft = SX(cx, s, 240) - gustTotalW / 2;
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(gustLeft, y, rowFont, gustText, Graphics.TEXT_JUSTIFY_LEFT);
        Pages.arrow(dc, gustLeft + gustW + SZ(s, 16) + arrowR, y + rowH / 2, arrowR, dir);
        y += rowH + SZ(s, 8);

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(SX(cx, s, 90), y, SX(cx, s, 390), y);
        y += SZ(s, 8);

        var temp = Api.v(m, "stTemp");
        if (temp != null) {
            var tbmp = tempBmp();
            var airIconH = (dc.getFontHeight(Graphics.FONT_XTINY) * 0.85).toNumber();
            var airIconW = (airIconH * tbmp.getWidth() / tbmp.getHeight()).toNumber();
            var airText = Pages.res(Rez.Strings.AirTemp) + " " + Fmt.temp(temp);
            var airTw = dc.getTextWidthInPixels(airText, Graphics.FONT_XTINY);
            var airLeft = SX(cx, s, 240) - (airIconW + SZ(s, 6) + airTw) / 2;
            dc.drawScaledBitmap(airLeft, y, airIconW, airIconH, tbmp);
            dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(airLeft + airIconW + SZ(s, 6), y, Graphics.FONT_XTINY,
                airText, Graphics.TEXT_JUSTIFY_LEFT);
            y += dc.getFontHeight(Graphics.FONT_XTINY) + SZ(s, 4);
        }

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SX(cx, s, 240), y, Graphics.FONT_XTINY,
            Fmt.age(Api.v(m, "stAt")), Graphics.TEXT_JUSTIFY_CENTER);

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

    //! Same stepped-colour-sweep technique as Land's arcGauge — a true
    //! stroke gradient isn't available, so this walks the sweep in short
    //! flat-colour segments.
    function arcGauge(dc as Graphics.Dc, cx as Float, cy as Float, s as Float, ms as Numeric?) as Void {
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

        if (ms == null) { return; }
        var frac = ms / WIND_MAX;
        if (frac < 0.0) { frac = 0.0; }
        if (frac > 1.0) { frac = 1.0; }
        var angle = Math.toRadians(ARC_START - frac * (ARC_START - ARC_END));
        var mx = cx + r * Math.cos(angle);
        var my = cy - r * Math.sin(angle);
        dc.setColor(gradColour(frac), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx.toNumber(), my.toNumber(), SZ(s, 5));
    }

    //! Cold->mild->warm->hot, same stops as Land's temp arc — wind speed
    //! reads intuitively on the same calm-to-dangerous ramp.
    function gradColour(f as Float) as Number {
        var stops = [[0x3f, 0xa6, 0xff], [0x28, 0xc7, 0xa4], [0xff, 0x9a, 0x3d], [0xff, 0x4d, 0x4d]];
        if (f <= 0.0) { return rgb(stops[0]); }
        if (f >= 1.0) { return rgb(stops[3]); }
        var seg = f * 3.0;
        var i = seg.toNumber();
        if (i > 2) { i = 2; }
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

    //! Marine CAP-feed warning banner, same chip/positioning as Land's
    //! roadIceBanner — generalised to take the severity string + both
    //! resource ids since Sea and Waves each pass their own pair (same
    //! split Pages.drawSeaWarning() already uses for the MIP pages).
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
