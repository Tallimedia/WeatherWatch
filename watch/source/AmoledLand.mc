import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

//! AMOLED-styled Land page — first page of the C5s graphics overhaul
//! (FI-WEATHER-ROADMAP.md). AMOLED-only, via the module's own :amoledTheme
//! tag plus monkey.jungle's excludeAnnotations — PageView.mc's drawPage()
//! picks this or Pages.drawLand() at compile time, per device.
//!
//! Every position/size below is the published Artifact mockup's own 480x480
//! coordinate scaled to the real device's actual width, via SX/SY/SZ — so
//! this is a direct transcription of the approved design, not a re-guess.
//!
//! Deliberately simplified vs. the mockup for this first pass, to get
//! something into the sim quickly rather than spend the whole pass on the
//! hardest unknowns up front:
//!   - Page title: plain horizontal text, not the curved left-bezel label.
//!     A true curved/rotated label needs a buffered bitmap + drawBitmap2's
//!     :rotationDegrees, which is real extra plumbing — worth it once the
//!     rest of the layout is confirmed to hold up, not before.
//!   - Rain gauge fill: solid colour, not the mockup's blue gradient —
//!     Dc has no gradient fill; a true gradient would need a manual
//!     scanline fill, deferred for the same reason as the title.
//!   - Hero sky icon: Icons.wxClear + Icons.wxCloudy composited (cloud
//!     drawn last, naturally occluding the sun behind it) — no sun rays
//!     yet, reusing the exact icon language already proven on Forecast.
(:amoledTheme)
module AmoledLand {

    const TEMP_MIN = -20.0;
    const TEMP_MAX = 30.0;
    const ARC_START = 158.0;   // degrees, Garmin convention: CCW from 3 o'clock
    const ARC_END = 22.0;

    // Downloaded flat-icon art (Nico, 2026-10-27), cached after first load —
    // loadResource() on every onUpdate() would be wasteful. Full-colour
    // illustrations, not tinted like Icons.mc's single-colour hand-drawn
    // shapes.
    var _windBmp = null;
    var _rainBmp = null;
    var _tempBmp = null;
    var _arrowBmp = null;
    var _skyClearBmp = null;
    var _updateBmp = null;
    var _snowBmp = null;

    function windBmp() as WatchUi.BitmapResource {
        if (_windBmp == null) { _windBmp = WatchUi.loadResource(Rez.Drawables.IconWindBitmap); }
        return _windBmp;
    }
    function rainBmp() as WatchUi.BitmapResource {
        if (_rainBmp == null) { _rainBmp = WatchUi.loadResource(Rez.Drawables.IconRainBitmap); }
        return _rainBmp;
    }
    function tempBmp() as WatchUi.BitmapResource {
        if (_tempBmp == null) { _tempBmp = WatchUi.loadResource(Rez.Drawables.IconTempBitmap); }
        return _tempBmp;
    }
    function arrowBmp() as WatchUi.BitmapResource {
        if (_arrowBmp == null) { _arrowBmp = WatchUi.loadResource(Rez.Drawables.IconArrowBitmap); }
        return _arrowBmp;
    }
    function skyClearBmp() as WatchUi.BitmapResource {
        if (_skyClearBmp == null) { _skyClearBmp = WatchUi.loadResource(Rez.Drawables.IconSkyClearBitmap); }
        return _skyClearBmp;
    }
    function updateBmp() as WatchUi.BitmapResource {
        if (_updateBmp == null) { _updateBmp = WatchUi.loadResource(Rez.Drawables.IconUpdateBitmap); }
        return _updateBmp;
    }
    function snowBmp() as WatchUi.BitmapResource {
        if (_snowBmp == null) { _snowBmp = WatchUi.loadResource(Rez.Drawables.IconSnowBitmap); }
        return _snowBmp;
    }

    function draw(dc as Graphics.Dc, pageIndex as Number, pageCount as Number) as Void {
        var w = dc.getWidth();
        var cx = w / 2.0;
        var cy = dc.getHeight() / 2.0;
        var s = w / 480.0;

        var d = Api.land;
        if (d == null) {
            dc.setColor(Theme.INK, Theme.BG);
            dc.clear();
            dc.drawText(cx.toNumber(), cy.toNumber(), Graphics.FONT_SMALL,
                Pages.res(Rez.Strings.PageLand), Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var t = Api.v(d, "temp");
        var ms = Api.v(d, "wind");
        var gust = Api.v(d, "gust");
        var dir = Api.v(d, "dir");
        var name = Api.v(d, "name");
        var km = Api.v(d, "dist");
        var shortName = Fmt.dropPrefix(name, Config.landPlace());

        dc.setColor(Theme.INK, Theme.BG);
        dc.clear();

        rim(dc, cx, cy, s);
        arcGauge(dc, cx, cy, s, t);
        var titleBottom = title(dc, cx, cy, s, Pages.res(Rez.Strings.PageLand));
        roadIceBanner(dc, cx, s, titleBottom);

        // Monkey C's drawText anchors y at the TOP of the text, not an SVG
        // baseline — so unlike the shape helpers above (rim/arc/rose, which
        // are plain geometry and scale cleanly from the mockup's 480px
        // coordinates), every text row here is stacked from the previous
        // row's actual measured bottom edge, same technique Pages.mc's own
        // stackStart/_y pattern already uses elsewhere in this app.
        var readingTop = SY(cy, s, 128);
        var readingH = dc.getFontHeight(Graphics.FONT_NUMBER_MILD);
        dc.setColor(Theme.tempColour(t), Graphics.COLOR_TRANSPARENT);
        dc.drawText(SX(cx, s, 218), readingTop, Graphics.FONT_NUMBER_MILD,
            Fmt.tempValue(t) + "°", Graphics.TEXT_JUSTIFY_CENTER);
        var y = readingTop + readingH + SZ(s, 2);

        // Thermometer icon on the hero reading itself — Nico's call,
        // mirroring the sun/cloud icon's placement on the other side of
        // the number.
        var tbmp = tempBmp();
        var tempIconH = (readingH * 0.45).toNumber();
        var tempIconW = (tempIconH * tbmp.getWidth() / tbmp.getHeight()).toNumber();
        dc.drawScaledBitmap(SX(cx, s, 64), readingTop + (readingH - tempIconH) / 2, tempIconW, tempIconH, tbmp);

        heroSky(dc, SX(cx, s, 366), readingTop + readingH / 2, SZ(s, 70));

        if (shortName != null) {
            // Centred on the dial's true centre (240), not the hero
            // number's own off-centre mock position (200) — the place
            // name shouldn't have inherited that asymmetry. Found on real
            // hardware, 2026-10-28.
            dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(SX(cx, s, 240), y, Graphics.FONT_XTINY,
                shortName + " · " + Fmt.dist(km), Graphics.TEXT_JUSTIFY_CENTER);
        }
        y += dc.getFontHeight(Graphics.FONT_XTINY) + SZ(s, 8);

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(SX(cx, s, 90), y, SX(cx, s, 390), y);
        y += SZ(s, 8);

        var windFont = Graphics.FONT_XTINY;
        var windRowH = dc.getFontHeight(windFont);
        var windRowCy = y + windRowH / 2;
        var windIconX = SX(cx, s, 104);

        var snow = Api.v(d, "snow");

        var wbmp = windBmp();
        var windIconH = (windRowH * 0.85).toNumber();
        var windIconW = (windIconH * wbmp.getWidth() / wbmp.getHeight()).toNumber();
        dc.drawScaledBitmap(windIconX, y + (windRowH - windIconH) / 2, windIconW, windIconH, wbmp);
        var windTextX = windIconX + windIconW + SZ(s, 6);
        var windText = Fmt.windRound(ms) + " (" + Fmt.windRound(gust) + ") " + Fmt.windUnitLabel();
        dc.setColor(Theme.windColour(ms, gust, Config.landWind(), Config.landGust()),
            Graphics.COLOR_TRANSPARENT);
        dc.drawText(windTextX, y, windFont, windText,
            Graphics.TEXT_JUSTIFY_LEFT);

        // Arrow at the end of the row, after "m/s" — fits now that the
        // values are rounded (no decimals) and shorter than before.
        var arrowR = SZ(s, 13);
        var windTextW = dc.getTextWidthInPixels(windText, windFont);
        var arrowCx = windTextX + windTextW + SZ(s, 10) + arrowR;
        Pages.arrow(dc, arrowCx, windRowCy, arrowR, dir);

        // Snow depth, right of the wind row's own content (after the
        // direction arrow) — automatic: absent (null/NaN at the station, or
        // summer) it draws nothing and the row is pixel-identical to before
        // this existed. Moved here from the left side of the wind icon
        // (Nico's call, 2026-11-06) — reads better running in the same
        // direction as the rest of the row instead of leading it.
        if (snow != null && snow > 0.0) {
            var snowText = Math.round(snow).toNumber().toString() + "cm";
            // Plain six-armed snowflake (new Recraft generation) — went
            // through two rejects first: Icons.snowflake()'s hand-drawn
            // vector collapsed into a plain "+" at this size, and the master
            // set's post+badge icon_snow_amount.png read as too busy/heavy
            // against the row's other flat icons (Nico's calls, 2026-11-06).
            var sbmp = snowBmp();
            var snowIconH = (windRowH * 1.05).toNumber();
            var snowIconW = (snowIconH * sbmp.getWidth() / sbmp.getHeight()).toNumber();
            var snowGap = SZ(s, 4);
            var snowX = arrowCx + arrowR + SZ(s, 14);
            dc.drawScaledBitmap(snowX, y + (windRowH - snowIconH) / 2, snowIconW, snowIconH, sbmp);
            dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(snowX + snowIconW + snowGap, y, windFont, snowText,
                Graphics.TEXT_JUSTIFY_LEFT);
        }

        // No separate "SW" row — the arrow already carries direction, and
        // repeating it as a compass letter was redundant (Nico's call).
        y += windRowH + SZ(s, 8);

        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(SX(cx, s, 90), y, SX(cx, s, 390), y);
        y += SZ(s, 8);

        var pop1h = Api.v(Api.forecast, "pop1h");
        var pop3h = Api.v(Api.forecast, "pop3h");
        var isSnow = t != null && t < 0.0;
        // Icon only, no "Sade" word — same move as the wind row: the icon
        // plus "1h"/"3h" on the pills themselves already says what this
        // row is, so the label was redundant.
        var pillH = SZ(s, 22);
        var rainIconH = (pillH * 0.85).toNumber();
        var rainIconY = y + (pillH - rainIconH) / 2;
        if (isSnow) {
            Icons.snowflake(dc, SX(cx, s, 108), rainIconY, rainIconH, Theme.DIM);
        } else {
            var rbmp = rainBmp();
            var rainIconW = (rainIconH * rbmp.getWidth() / rbmp.getHeight()).toNumber();
            dc.drawScaledBitmap(SX(cx, s, 108), rainIconY, rainIconW, rainIconH, rbmp);
        }
        rainPill(dc, SX(cx, s, 135), y, SZ(s, 10), pillH, pop1h, "1h");
        rainPill(dc, SX(cx, s, 260), y, SZ(s, 10), pillH, pop3h, "3h");
        y += pillH + SZ(s, 8);

        // Small, always-visible footer indicator — independent of the top
        // banner slot, which a real weather warning can occupy for days
        // at a time in winter (Nico's call, 2026-10-28): the update notice
        // needs a spot that isn't at the mercy of road-ice season.
        var ageText = Fmt.age(Api.v(d, "atW"));
        // Off until C5i's backend half (a real `latest_version` field on
        // /v1/observations, compared against Config.VERSION) is actually
        // built — this was a hardcoded `true` sim-only test fake that
        // nearly shipped in v1.2.4 as a permanent "update available" nag
        // for every user, found on the production info page 2026-11-06.
        var updateAvailable = false;
        if (updateAvailable) {
            var footerIconH = SZ(s, 11);
            var ubmp2 = updateBmp();
            var footerIconW = (footerIconH * ubmp2.getWidth() / ubmp2.getHeight()).toNumber();
            var ageW = dc.getTextWidthInPixels(ageText, Graphics.FONT_XTINY);
            var footerGap = SZ(s, 6);
            var footerLeft = SX(cx, s, 240) - (ageW + footerGap + footerIconW) / 2;
            dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(footerLeft, y, Graphics.FONT_XTINY, ageText, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawScaledBitmap(footerLeft + ageW + footerGap,
                y + (dc.getFontHeight(Graphics.FONT_XTINY) - footerIconH) / 2,
                footerIconW, footerIconH, ubmp2);
        } else {
            dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(SX(cx, s, 240), y, Graphics.FONT_XTINY, ageText, Graphics.TEXT_JUSTIFY_CENTER);
        }

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

    //! Stepped-colour arc (cold -> mild -> warm -> hot) standing in for a
    //! true stroke gradient — Dc has no gradient stroke, so this walks the
    //! sweep in short segments, each one a flat RGB-interpolated colour.
    function arcGauge(dc as Graphics.Dc, cx as Float, cy as Float, s as Float, t as Numeric?) as Void {
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

        if (t == null) { return; }
        var frac = (t - TEMP_MIN) / (TEMP_MAX - TEMP_MIN);
        if (frac < 0.0) { frac = 0.0; }
        if (frac > 1.0) { frac = 1.0; }
        var angle = Math.toRadians(ARC_START - frac * (ARC_START - ARC_END));
        var mx = cx + r * Math.cos(angle);
        var my = cy - r * Math.sin(angle);
        dc.setColor(gradColour(frac), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx.toNumber(), my.toNumber(), SZ(s, 5));
    }

    //! Cold->mild->warm->hot, matching the mockup's --cold/--mild/--warm/--hot.
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

    //! Plain horizontal label for now — see the module header note on the
    //! curved bezel title being deferred to a later pass. Tried all-caps at
    //! FONT_SMALL (2026-10-28) — Nico's call that it looked worse, reverted.
    //! Returns the title's own bottom edge (real measured font height, not
    //! a mockup pixel guess) so roadIceBanner() can sit a real gap below
    //! it instead of a fixed coordinate that assumed the title's original
    //! curved-arc position — found colliding with a real (forced-for-test)
    //! warning 2026-10-28; Finland had no live ice all session before that,
    //! so this was a dormant bug the whole time.
    function title(dc as Graphics.Dc, cx as Float, cy as Float, s as Float, text as String) as Number {
        var y = SY(cy, s, 54);
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(SX(cx, s, 240), y, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER);
        return y + dc.getFontHeight(Graphics.FONT_XTINY);
    }

    //! Returns whether it actually drew a banner — the update badge below
    //! shares this slot and only shows when a real weather warning isn't
    //! already using it (safety info outranks a software nag).
    function roadIceBanner(dc as Graphics.Dc, cx as Float, s as Float, titleBottom as Number) as Boolean {
        var level = Api.v(Api.road, "level");
        if (level == null) { return false; }
        var text = null;
        var colour = Theme.OVER;
        if (level.equals("high")) {
            text = Pages.res(Rez.Strings.BlackIceWarning);
            colour = Theme.HOT;
        } else if (level.equals("moderate")) {
            text = Pages.res(Rez.Strings.IcyRoadWarning);
        }
        if (text == null) { return false; }
        text = text.toUpper();

        // Chip width sized to the actual (scaled) text, not a fixed guess
        // — the original fixed 150px chip clipped "MUSTAA JÄÄTÄ" past its
        // own border (found 2026-10-28, same real-warning-exposed-it story
        // as the other bugs just above). FONT_XTINY is already the
        // smallest built-in size, so "a tad smaller" (Nico's call) means
        // rendering it into a small BufferedBitmap and scaling that down —
        // same drawScaledBitmap mechanism already used for every icon on
        // this page, just not rotated this time, so none of the
        // compiled-PNG palette trouble applies.
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
        // Icons.warning() leaves the Dc's colour in whatever state its own
        // last draw call used — found invisible against the chip 2026-10-28
        // (the colour bug), stacked with a second bug (y+chipH/2 used as
        // the text's TOP edge instead of a vertically-centred anchor).
        // Both only ever surfaced once a real warning (even a forced-for-
        // test one) actually rendered — Finland had no live ice all
        // session before that.
        dc.drawScaledBitmap(x + padL + iconS + iconGap, y + (chipH - scaledTextH) / 2,
            scaledTextW, scaledTextH, textBmp);
        return true;
    }

    //! Pre-composited illustration (gradient-shaded sun behind a cloud),
    //! not the hand-built Icons.wxClear+wxCloudy overlap used elsewhere —
    //! one real baked image beats faking depth with two flat shapes.
    function heroSky(dc as Graphics.Dc, cx as Number, cy as Number, targetH as Number) as Void {
        var bmp = skyClearBmp();
        var h = targetH;
        var w = (h * bmp.getWidth() / bmp.getHeight()).toNumber();
        dc.drawScaledBitmap(cx - w / 2, cy - h / 2, w, h, bmp);
    }

    //! Text only, no gauge at all — first tried with a track shown only
    //! when empty (read as a stray mark at 0%, dropped), then with the
    //! blue fill shown only once there was a real amount (looked fine once
    //! real non-zero test data finally came through, but Nico's call
    //! 2026-10-28 was to drop the whole gauge concept, not just the empty
    //! state). `w`/`h` kept in the signature only to keep both call sites'
    //! column spacing (x + w + 8) unchanged, not because anything is drawn
    //! with them now.
    function rainPill(dc as Graphics.Dc, x as Number, y as Number, w as Number, h as Number,
                              pop as Numeric?, label as String) as Void {
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        var popText = pop == null ? Fmt.DASH : Math.round(pop).toNumber().toString() + "%";
        dc.drawText(x + w + 8, y + h / 2 - dc.getFontHeight(Graphics.FONT_XTINY) / 2,
            Graphics.FONT_XTINY, label + " " + popText, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
