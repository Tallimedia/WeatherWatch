import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! AMOLED-styled About/Tietoja page — C5s (FI-WEATHER-ROADMAP.md), same
//! sim-test-hook approach as the other AmoledX pages. No crown gauge or
//! warning banner here — this page is static reference info, not a live
//! reading — so it's simpler: rim, title, app name/version, the
//! update-available pill (C5i, finally given a visual home once Land's
//! footer icon turned out to need a second, always-visible spot — see
//! AmoledLand.mc's footer indicator), then the FMI attribution.
(:amoledTheme)
module AmoledAbout {

    var _updateBmp = null;

    function updateBmp() as WatchUi.BitmapResource {
        if (_updateBmp == null) { _updateBmp = WatchUi.loadResource(Rez.Drawables.IconUpdateBitmap); }
        return _updateBmp;
    }

    function draw(dc as Graphics.Dc, pageIndex as Number, pageCount as Number) as Void {
        var w = dc.getWidth();
        var cx = w / 2.0;
        var cy = dc.getHeight() / 2.0;
        var s = w / 480.0;

        dc.setColor(Theme.INK, Theme.BG);
        dc.clear();
        rim(dc, cx, cy, s);
        title(dc, cx, cy, s, Pages.res(Rez.Strings.PageAbout));

        var top = SY(cy, s, 150);
        dc.setColor(Theme.INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SX(cx, s, 240), top, Graphics.FONT_MEDIUM, "FIWeatherWatch",
            Graphics.TEXT_JUSTIFY_CENTER);
        top += dc.getFontHeight(Graphics.FONT_MEDIUM) + SZ(s, 2);

        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SX(cx, s, 240), top, Graphics.FONT_XTINY, "v" + Config.VERSION,
            Graphics.TEXT_JUSTIFY_CENTER);
        top += dc.getFontHeight(Graphics.FONT_XTINY) + SZ(s, 14);

        // TEMP sim-only fake — remove before committing (or replace with
        // the real latest_version-vs-Config.VERSION check once C5i's
        // backend half, the `latest_version` field on /v1/observations,
        // is actually wired up).
        var updateAvailable = true;
        if (updateAvailable) {
            top = updatePill(dc, cx, s, top) + SZ(s, 14);
        }

        var xtinyH = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        var lines = Pages.wrap(dc, Pages.res(Rez.Strings.Attribution), Graphics.FONT_XTINY,
            (w * 0.7).toNumber());
        for (var i = 0; i < lines.size(); i += 1) {
            dc.drawText(SX(cx, s, 240), top + i * xtinyH, Graphics.FONT_XTINY, lines[i],
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        top += lines.size() * xtinyH;
        dc.drawText(SX(cx, s, 240), top, Graphics.FONT_XTINY, "CC BY 4.0",
            Graphics.TEXT_JUSTIFY_CENTER);

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

    function title(dc as Graphics.Dc, cx as Float, cy as Float, s as Float, text as String) as Void {
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SX(cx, s, 240), SY(cy, s, 54), Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    //! Same dynamic-width pill as AmoledLand.mc's warning chips — green
    //! instead of red/orange, the update-illustration bitmap instead of
    //! Icons.warning(). Returns its own bottom edge so the attribution
    //! text below can stack off a real measured position, same technique
    //! every other AmoledX row uses. English text for every language —
    //! Nico's call, a software nag doesn't need translation.
    function updatePill(dc as Graphics.Dc, cx as Float, s as Float, top as Number) as Number {
        var text = Pages.res(Rez.Strings.UpdateAvailable).toUpper();
        var ubmp = updateBmp();
        var iconH = SZ(s, 18);
        var iconW = (iconH * ubmp.getWidth() / ubmp.getHeight()).toNumber();
        var textFont = Graphics.FONT_XTINY;
        var textW = dc.getTextWidthInPixels(text, textFont);
        var textH = dc.getFontHeight(textFont);
        var textScale = 0.82;
        var scaledTextW = (textW * textScale).toNumber();
        var scaledTextH = (textH * textScale).toNumber();

        var ref = Graphics.createBufferedBitmap({ :width => textW, :height => textH });
        var textBmp = ref.get();
        var bdc = textBmp.getDc();
        bdc.setColor(0x123a1e, 0x123a1e);
        bdc.clear();
        bdc.setColor(Theme.UPDATE, Graphics.COLOR_TRANSPARENT);
        bdc.drawText(0, 0, textFont, text, Graphics.TEXT_JUSTIFY_LEFT);

        var padL = SZ(s, 10);
        var iconGap = SZ(s, 6);
        var padR = SZ(s, 12);
        var chipW = padL + iconW + iconGap + scaledTextW + padR;
        var chipH = SZ(s, 32);
        var x = SX(cx, s, 240) - chipW / 2;
        var y = top;
        dc.setColor(0x123a1e, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, chipW, chipH, SZ(s, 8));
        dc.setColor(Theme.UPDATE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(x, y, chipW, chipH, SZ(s, 8));
        dc.drawScaledBitmap(x + padL, y + (chipH - iconH) / 2, iconW, iconH, ubmp);
        dc.drawScaledBitmap(x + padL + iconW + iconGap, y + (chipH - scaledTextH) / 2,
            scaledTextW, scaledTextH, textBmp);
        return y + chipH;
    }
}
