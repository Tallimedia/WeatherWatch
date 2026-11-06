import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! AMOLED-styled Forecast page — second page of the C5s graphics overhaul
//! (FI-WEATHER-ROADMAP.md), following the same approach as AmoledLand.mc:
//! wired in as a sim-only test hook in PageView.mc, no device-tier split
//! yet. Unlike Land, this page has no finished Artifact mockup behind it
//! (the earlier 4-page gallery's Forecast card was a rough sketch, not
//! iterated on) — built directly from Land's proven technique instead:
//! fractions of the real screen width/height plus row-stacking from
//! measured font/icon heights, same as Pages.drawForecast's own existing
//! (MIP) layout already uses.
//!
//! Condition icons: still Pages.drawWx() (the hand-drawn Icons.mc vector
//! set), not the new downloaded bitmaps. The bitmap set only has full
//! coverage for :clear and :rain so far — no plain "cloudy" (fully
//! overcast, no sun) or :snow bitmap exists yet, and this page needs all
//! four categories across three different days. Land could get away with
//! a single fixed "partly cloudy" bitmap because the test data happened
//! to match; Forecast can't fake that. Wind/rain icons DO use the
//! bitmaps, same as Land, since those aren't condition-dependent.
(:amoledTheme)
module AmoledForecast {

    function draw(dc as Graphics.Dc, pageIndex as Number, pageCount as Number) as Void {
        dc.setColor(Theme.INK, Theme.BG);
        dc.clear();
        rim(dc);
        title(dc);

        if (Pages.loading(dc, Api.forecast3State)) {
            Pages.drawPager(dc, pageIndex, pageCount);
            return;
        }
        var d = Api.forecast3;
        if (d == null) {
            Pages.message(dc, Rez.Strings.NoData);
            Pages.drawPager(dc, pageIndex, pageCount);
            return;
        }

        var hi = Api.v(d, "hi");
        var lo = Api.v(d, "lo");
        var sym = Api.v(d, "sym");
        var rain = Api.v(d, "rain");
        var wind = Api.v(d, "wind");
        var gust = Api.v(d, "gust");
        var pop = Api.v(d, "pop");
        if (!(pop instanceof Array)) { pop = [null, null, null, null]; }
        // Same day-bucket shift as the MIP page (Pages.mc, 2026-10-20):
        // once Today has nothing left, Tomorrow becomes the big row.
        var base = (hi[0] == null && hi.size() > 3) ? 1 : 0;

        var w = Pages.w(dc);
        var h = Pages.h(dc);
        var cx = (w / 2).toNumber();
        var xtinyH = dc.getFontHeight(Graphics.FONT_XTINY);
        var numH = dc.getFontHeight(Graphics.FONT_NUMBER_MILD);

        var top = (h * 0.2).toNumber();
        // "Today" is implied — it's the hero row, the default state, same
        // posture as dropping "SW" next to Land's direction arrow. Only
        // shown when the day-bucket shift (Pages.mc, 2026-10-20) actually
        // happens: without the label there'd be no way to tell the hero
        // row became Tomorrow instead.
        if (base != 0) {
            dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, top, Graphics.FONT_XTINY, Pages.res(Rez.Strings.Tomorrow),
                Graphics.TEXT_JUSTIFY_CENTER);
            top += xtinyH + 2;
        }

        // Hero row: bigger than the MIP page's equivalent (h*0.1) — this
        // page has no crown arc competing for room, so the headline can
        // afford more weight, same reasoning as Land's hero reading.
        var heroIcon = (h * 0.12).toNumber();
        var hiLoText = Pages.hiLo(hi[base], lo[base]);
        var tw = dc.getTextWidthInPixels(hiLoText, Graphics.FONT_NUMBER_MILD);
        var heroRowH = heroIcon > numH ? heroIcon : numH;
        var heroLeft = cx - ((heroIcon + 10 + tw) / 2).toNumber();
        Pages.drawWx(dc, sym[base], heroLeft, top + ((heroRowH - heroIcon) / 2).toNumber(), heroIcon);
        dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(heroLeft + heroIcon + 10, top + ((heroRowH - numH) / 2).toNumber(),
            Graphics.FONT_NUMBER_MILD, hiLoText, Graphics.TEXT_JUSTIFY_LEFT);
        top += heroRowH + 2;

        // Wind + rain, same icon-then-value language as Land's rows, both
        // clusters centred together as one group (same technique the MIP
        // page's own version already proved).
        var windText = Fmt.windRound(wind[base]) + " (" + Fmt.windRound(gust[base]) + ")";
        var rainText = Fmt.one(rain[base]) + " mm" + Pages.popSuffix(pop[base]);
        var rowIconH = (xtinyH * 0.85).toNumber();
        var wbmp = windBmp();
        var windIconW = (rowIconH * wbmp.getWidth() / wbmp.getHeight()).toNumber();
        var rbmp = rainBmp();
        var rainIconW = (rowIconH * rbmp.getWidth() / rbmp.getHeight()).toNumber();
        var iconGap = SZ2(w, 6);
        var clusterGap = SZ2(w, 14);
        var windTw = dc.getTextWidthInPixels(windText, Graphics.FONT_XTINY);
        var rainTw = dc.getTextWidthInPixels(rainText, Graphics.FONT_XTINY);
        var totalW = windIconW + iconGap + windTw + clusterGap + rainIconW + iconGap + rainTw;
        var rowLeft2 = cx - (totalW / 2).toNumber();
        var iy2 = top + ((xtinyH - rowIconH) / 2).toNumber();
        dc.drawScaledBitmap(rowLeft2, iy2, windIconW, rowIconH, wbmp);
        dc.setColor(Theme.windColour(wind[base], gust[base], Config.landWind(), Config.landGust()),
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(rowLeft2 + windIconW + iconGap, top, Graphics.FONT_XTINY, windText,
            Graphics.TEXT_JUSTIFY_LEFT);
        var rainX = rowLeft2 + windIconW + iconGap + windTw + clusterGap;
        dc.drawScaledBitmap(rainX, iy2, rainIconW, rowIconH, rbmp);
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rainX + rainIconW + iconGap, top, Graphics.FONT_XTINY, rainText,
            Graphics.TEXT_JUSTIFY_LEFT);
        top += xtinyH + 6;

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine((w * 0.22).toNumber(), top, (w * 0.78).toNumber(), top);
        top += 8;

        // Two smaller columns — same ±0.17w split and content as the MIP
        // page's own proven layout (Pages.mc, 2026-10-13: pulled in from
        // ±0.25w after Nico found the full split crowded the round bezel).
        var colOffset = (w * 0.17).toNumber();
        var smallIcon = (h * 0.06).toNumber();
        for (var i = 0; i < 2; i += 1) {
            var colCx = i == 0 ? cx - colOffset : cx + colOffset;
            var y = top;
            var dayN = base + i + 1;
            var colLabel = dayN == 1 ? Pages.res(Rez.Strings.Tomorrow)
                : "+" + dayN.toString() + " " + Pages.res(Rez.Strings.DayAbbrev);
            dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(colCx, y, Graphics.FONT_XTINY, colLabel, Graphics.TEXT_JUSTIFY_CENTER);
            y += xtinyH + 2;
            Pages.drawWx(dc, sym[base + i + 1], (colCx - smallIcon / 2).toNumber(), y, smallIcon);
            y += smallIcon + 2;
            dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(colCx, y, Graphics.FONT_XTINY,
                Pages.hiLo(hi[base + i + 1], lo[base + i + 1]), Graphics.TEXT_JUSTIFY_CENTER);
            y += xtinyH + 1;
            // Icon+text clusters tried here (2026-10-28) and reverted —
            // too tight at this column width, the right column's icon
            // bled past the rim into the pager dots. Plain text only,
            // same as the MIP page's own proven version.
            dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(colCx, y, Graphics.FONT_XTINY,
                Fmt.one(rain[base + i + 1]) + " mm", Graphics.TEXT_JUSTIFY_CENTER);
            y += xtinyH + 1;
            dc.drawText(colCx, y, Graphics.FONT_XTINY,
                Pages.fit(dc, Fmt.windRound(wind[base + i + 1]) + " (" + Fmt.windRound(gust[base + i + 1]) + ")",
                    Graphics.FONT_XTINY, (w * 0.26).toNumber()),
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        Pages.drawPager(dc, pageIndex, pageCount);
    }

    function rim(dc as Graphics.Dc) as Void {
        var w = Pages.w(dc);
        dc.setColor(0x141A1D, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawCircle((w / 2).toNumber(), (Pages.h(dc) / 2).toNumber(), SZ2(w, 222));
        dc.setPenWidth(1);
    }

    //! Rotated left-bezel title tried here 2026-10-28 (BufferedBitmap +
    //! drawBitmap2's :rotationDegrees, to sidestep the compiled-PNG palette
    //! issue that blocked the wind-arrow bitmap) — reverted, Nico's call.
    //! The rotation didn't even visibly apply in the sim (text rendered
    //! horizontal, just mispositioned over the wind row), and it wasn't
    //! worth chasing given the reaction. Plain centred label stays the
    //! standard for every AMOLED page until/unless a real curved-title
    //! pass is worth the investment.
    function title(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((Pages.w(dc) / 2).toNumber(), (Pages.h(dc) * 0.11).toNumber(), Graphics.FONT_XTINY,
            Pages.res(Rez.Strings.PageForecast), Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Scales a Land-mockup-reference (480px-canvas) length to this
    //! screen's actual width, same ratio AmoledLand.mc's own SZ() uses —
    //! kept local rather than shared yet, same as the rest of this file's
    //! light duplication with AmoledLand.mc (worth factoring out once a
    //! third page needs it).
    function SZ2(w as Numeric, len as Numeric) as Number {
        return (len * w / 480.0).toNumber();
    }

    var _windBmp = null;
    var _rainBmp = null;

    function windBmp() as WatchUi.BitmapResource {
        if (_windBmp == null) { _windBmp = WatchUi.loadResource(Rez.Drawables.IconWindBitmap); }
        return _windBmp;
    }
    function rainBmp() as WatchUi.BitmapResource {
        if (_rainBmp == null) { _rainBmp = WatchUi.loadResource(Rez.Drawables.IconRainBitmap); }
        return _rainBmp;
    }
}
