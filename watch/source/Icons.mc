import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Small drawn glyphs.
//!
//! Vector primitives rather than bitmaps: one set of code scales to whatever
//! size a device needs, where bitmaps would mean a resource per resolution
//! across the 70 products the release targets.
//!
//! Each icon draws inside a box of side `s` with its top-left at (x, y), so the
//! caller lays them out against text without knowing what the glyph is. They
//! render at roughly 10-16 px, so silhouette matters far more than detail —
//! anything fiddly turns to mush at this size.
(:glance)
module Icons {

    //! Thermometer: a thick capsule stem sitting in a bulb wider than it.
    //! Reference shape is a solid silhouette — thin strokes with tick marks
    //! read as a music note at this size, which is what the first attempt did.
    //!
    //! A flat one-colour fill read as a featureless grey blob at this icon's
    //! actual size on Land (the biggest icon in the app, not a glance-sized
    //! one) — Nico's call, 2026-10-21. Added an inset "mercury" fill in
    //! `fillColour` (Theme.tempColour — white/blue/red, the same colour
    //! already used for the number beside it) so the shape reads as a
    //! thermometer by contrast, not just outline, and ties the icon to the
    //! actual reading the way the Forecast page's weather icons tie colour
    //! to condition.
    function temp(dc as Graphics.Dc, x as Number, y as Number, s as Number,
                  colour as Number, fillColour as Number) as Void {
        var cx = x + (s * 0.42).toNumber();
        var stemW = (s * 0.30).toNumber();
        if (stemW < 3) { stemW = 3; }
        var bulbR = (s * 0.24).toNumber();
        if (bulbR < stemW / 2 + 1) { bulbR = stemW / 2 + 1; }
        var bulbY = y + s - bulbR;
        var topY = y + stemW / 2 + 1;

        // Outer silhouette: cap, stem, bulb — same solid-shape rule as every
        // other icon in this file, nothing here is a thin stroke.
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, topY, stemW / 2);
        dc.fillRectangle(cx - stemW / 2, topY, stemW, bulbY - topY);
        dc.fillCircle(cx, bulbY, bulbR);

        // Mercury: solid fill starting just below the cap's own hollow neck,
        // down into the bulb — Nico's reference PNG (2026-10-21) shows the
        // stem filled almost its whole length, only the rounded cap itself
        // is hollow. The first pass here filled from 45% down, which left
        // the ticks bunched into a short gap near the top on real hardware.
        var holeW = (stemW * 0.55).toNumber();
        if (holeW < 1) { holeW = 1; }
        var holeTop = topY + (stemW * 0.3).toNumber();
        var fillTopY = holeTop + (stemW * 0.5).toNumber();
        var innerStemW = (stemW * 0.42).toNumber();
        if (innerStemW < 2) { innerStemW = 2; }
        var innerBulbR = (bulbR * 0.55).toNumber();
        if (innerBulbR < innerStemW / 2 + 1) { innerBulbR = innerStemW / 2 + 1; }
        dc.setColor(fillColour, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - innerStemW / 2, fillTopY, innerStemW, bulbY - fillTopY);
        dc.fillCircle(cx, bulbY, innerBulbR);

        // Hollow neck: cut from the background just below the cap, same
        // cut-out technique Icons.warning() already uses for its
        // exclamation mark, so it survives a 1-bit screen the same way.
        if (fillTopY > holeTop) {
            dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - holeW / 2, holeTop, holeW, fillTopY - holeTop);
        }

        // Scale ticks: short solid marks outside the stem's left edge,
        // spanning most of the stem's length (reference PNG), not just the
        // short hollow neck above the fill line — real-hardware feedback
        // was that stopping them at the old (much higher) fill line bunched
        // them into too short a gap near the top.
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var tickLen = (s * 0.14).toNumber();
        if (tickLen < 2) { tickLen = 2; }
        var tickH = (s * 0.03).toNumber();
        if (tickH < 1) { tickH = 1; }
        var tickTop = holeTop;
        var tickBottom = topY + ((bulbY - topY) * 0.75).toNumber() - tickH;
        var tickCount = 5;
        if (tickBottom > tickTop) {
            for (var i = 0; i < tickCount; i += 1) {
                var ty = tickTop + ((tickBottom - tickTop) * i / (tickCount - 1).toFloat()).toNumber();
                dc.fillRectangle(cx - stemW / 2 - tickLen - 2, ty, tickLen, tickH);
            }
        }

        // Degree ring: a small hollow circle beside the cap, same cut-out
        // technique as the mercury-line hollow above.
        var degR = (s * 0.09).toNumber();
        if (degR < 3) { degR = 3; }
        var degCx = cx + stemW / 2 + degR + 3;
        var degCy = topY;
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(degCx, degCy, degR);
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(degCx, degCy, (degR * 0.5).toNumber());
    }

    //! Wind: three streaming lines, each ending in a curl. The curls are what
    //! make it wind rather than a list glyph — straight lines alone did not
    //! read.
    function wind(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var pen = (s * 0.15).toNumber();
        if (pen < 2) { pen = 2; }
        dc.setPenWidth(pen);
        var curlR = (s * 0.17).toNumber();
        if (curlR < 2) { curlR = 2; }

        gust(dc, x, y + (s * 0.24).toNumber(), (s * 0.62).toNumber(), curlR, true);
        gust(dc, x, y + (s * 0.52).toNumber(), (s * 0.86).toNumber(), curlR, false);
        gust(dc, x, y + (s * 0.80).toNumber(), (s * 0.50).toNumber(), curlR, false);
        dc.setPenWidth(1);
    }

    //! One streaming line with a hook curling off its right end.
    function gust(dc as Graphics.Dc, x as Number, y as Number, len as Number,
                  r as Number, up as Boolean) as Void {
        var endX = x + len;
        dc.drawLine(x, y, endX, y);
        if (up) {
            dc.drawArc(endX, y - r, r, Graphics.ARC_CLOCKWISE, 270, 100);
        } else {
            dc.drawArc(endX, y + r, r, Graphics.ARC_COUNTER_CLOCKWISE, 90, 260);
        }
    }

    //! Waves: two stacked sine curves.
    //!
    //! Drawn as sampled polylines rather than paired arcs. Two arcs side by
    //! side looked like something else entirely; two arcs stacked still read as
    //! hills. A continuous sine reads as water because the curve never breaks.
    //! How wide a glyph actually draws, in units of its box side. Water is a
    //! wide, shallow shape and needs the room; the layout has to know that or
    //! the icon runs under the text beside it.
    function widthFactor(kind as Symbol) as Float {
        if (kind == :wave) { return 1.25; }
        // Room for the tick marks on the left and the degree ring on the
        // right — both sit outside the stem+bulb footprint the old plain
        // silhouette used.
        if (kind == :temp) { return 1.35; }
        return 1.0;
    }

    //! Wave height: a rippled surface with an arrow reaching up to it.
    //!
    //! This says *height of the water*, where a bare ripple only says water —
    //! which matters on a page whose headline number is significant wave
    //! height. Drawn with a narrow stroke; the thick-bar version of the same
    //! shape loses its gaps at this size and turns into a blob.
    //!
    //! Earlier attempts, kept on record: two arcs side by side read as
    //! something else entirely, two stacked arcs read as hills, and a narrow
    //! sine in a square box folded into chevrons for want of horizontal room.
    function wave(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        // Thinner than the other glyphs on purpose: this one carries two
        // shapes in the same box, so a heavier stroke closes the gap between
        // them and they merge back into a blob.
        var pen = (s * 0.09).toNumber();
        if (pen < 1) { pen = 1; }
        dc.setPenWidth(pen);

        var width = (s * widthFactor(:wave)).toNumber();
        ripple(dc, x, y + (s * 0.18).toNumber(), width);

        // Arrow rising toward the surface, kept clear of it — when the head
        // crosses the ripple the two shapes tangle and neither reads.
        var cx = x + width / 2;
        var tipY = y + (s * 0.52).toNumber();
        var baseY = y + s;
        var wing = (s * 0.22).toNumber();
        dc.drawLine(cx, baseY, cx, tipY);
        dc.drawLine(cx - wing, tipY + wing, cx, tipY);
        dc.drawLine(cx + wing, tipY + wing, cx, tipY);
        dc.setPenWidth(1);
    }

    //! One sine period across the width, trough first so it leads with water
    //! rather than with a hill.
    function ripple(dc as Graphics.Dc, x as Number, midY as Number, s as Number) as Void {
        var amp = (s * 0.13).toFloat();
        if (amp < 1.5) { amp = 1.5; }
        var steps = 16;   // enough segments that the curve reads as curved
        var prevX = x;
        var prevY = midY + amp;   // start in a trough
        for (var i = 1; i <= steps; i += 1) {
            var t = i.toFloat() / steps;
            var px = (x + s * t).toNumber();
            var py = (midY + amp * Math.cos(t * 3 * Math.PI)).toNumber();
            dc.drawLine(prevX, prevY.toNumber(), px, py);
            prevX = px;
            prevY = py;
        }
    }

    //! Clock, for the forecast strip.
    function clock(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var r = (s * 0.42).toNumber();
        var cx = x + s / 2;
        var cy = y + s / 2;
        dc.drawCircle(cx, cy, r);
        dc.drawLine(cx, cy, cx, cy - (r * 0.55).toNumber());
        dc.drawLine(cx, cy, cx + (r * 0.45).toNumber(), cy);
        dc.setPenWidth(1);
    }

    //! Download: an arrow dropping onto a baseline. Marks the row that says
    //! when the reading was last pulled.
    function download(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var pen = (s * 0.13).toNumber();
        if (pen < 2) { pen = 2; }
        dc.setPenWidth(pen);
        var cx = x + s / 2;
        var tipY = y + (s * 0.62).toNumber();
        var wing = (s * 0.26).toNumber();
        dc.drawLine(cx, y + 1, cx, tipY);
        dc.drawLine(cx - wing, tipY - wing, cx, tipY);
        dc.drawLine(cx + wing, tipY - wing, cx, tipY);
        dc.drawLine(x + (s * 0.12).toNumber(), y + s - 1,
                    x + (s * 0.88).toNumber(), y + s - 1);
        dc.setPenWidth(1);
    }

    //! Ice: a six-spoke snowflake, three lines through the centre 60° apart
    //! with a short branch near each outer end.
    //!
    //! A snowflake reads as "ice" at a glance without a word attached, which
    //! matters here specifically: the road-ice row always pairs the icon with
    //! text (RESEARCH.md §16), because the icon alone would read as "icy
    //! outside" rather than "icy road" — this glyph is the flag, the word
    //! next to it is what says *road*. Branches kept short; at 10-16 px a
    //! full ice-crystal outline smears into a blob the way the wind glyph's
    //! first attempt did with straight lines (see wind() above).
    function ice(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var pen = (s * 0.12).toNumber();
        if (pen < 2) { pen = 2; }
        dc.setPenWidth(pen);

        var cx = x + s / 2;
        var cy = y + s / 2;
        var r = s * 0.44;
        var branchAt = r * 0.58;
        var branchLen = r * 0.28;
        var angles = [0.0, 60.0, 120.0];

        for (var i = 0; i < 3; i += 1) {
            var rad = angles[i] * Math.PI / 180.0;
            var dx = Math.cos(rad) * r;
            var dy = Math.sin(rad) * r;
            dc.drawLine((cx - dx).toNumber(), (cy - dy).toNumber(),
                        (cx + dx).toNumber(), (cy + dy).toNumber());

            var pRad = rad + Math.PI / 3;
            var pdx = Math.cos(pRad) * branchLen;
            var pdy = Math.sin(pRad) * branchLen;
            var bx = Math.cos(rad) * branchAt;
            var by = Math.sin(rad) * branchAt;
            // A short V at each outer end, both directions along the arm.
            dc.drawLine((cx + bx).toNumber(), (cy + by).toNumber(),
                        (cx + bx + pdx).toNumber(), (cy + by + pdy).toNumber());
            dc.drawLine((cx + bx).toNumber(), (cy + by).toNumber(),
                        (cx + bx - pdx).toNumber(), (cy + by - pdy).toNumber());
            dc.drawLine((cx - bx).toNumber(), (cy - by).toNumber(),
                        (cx - bx + pdx).toNumber(), (cy - by + pdy).toNumber());
            dc.drawLine((cx - bx).toNumber(), (cy - by).toNumber(),
                        (cx - bx - pdx).toNumber(), (cy - by - pdy).toNumber());
        }
        dc.setPenWidth(1);
    }

    //! Pin, marking the reporting station's distance.
    function station(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var r = (s * 0.28).toNumber();
        var cx = x + s / 2;
        var cy = y + r + 1;
        dc.drawCircle(cx, cy, r);
        dc.drawLine(cx, cy + r, cx, y + s);
        dc.setPenWidth(1);
    }

    //! Warning triangle with an exclamation mark — the FMI marine warning row
    //! on the Sea and Waves pages. Reusing :wind or :wave here would sit right
    //! below that page's own normal reading and read as a second number, not
    //! an alert; the universal triangle avoids any ambiguity about what kind
    //! of row this is, the same reason road-ice got its own glyph rather than
    //! reusing :temp.
    function warning(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var cx = x + s / 2;
        var top = y + (s * 0.04).toNumber();
        var bottom = y + s;
        var halfW = (s * 0.5).toFloat();
        dc.fillPolygon([
            [cx, top],
            [(cx + halfW).toNumber(), bottom],
            [(cx - halfW).toNumber(), bottom],
        ]);
        // The exclamation mark is cut out of the filled triangle rather than
        // drawn in a second colour, so it survives a 1-bit screen (§24) —
        // same reasoning as every other glyph in this module.
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        var stemW = (s * 0.09).toNumber();
        if (stemW < 2) { stemW = 2; }
        var stemTop = y + (s * 0.32).toNumber();
        var stemBottom = y + (s * 0.68).toNumber();
        dc.fillRectangle(cx - stemW / 2, stemTop, stemW, stemBottom - stemTop);
        var dotR = (stemW * 0.65).toNumber();
        if (dotR < 1) { dotR = 1; }
        dc.fillCircle(cx, y + (s * 0.84).toNumber(), dotR);
    }

    //! Weather-condition glyphs for the Forecast page (v1.2, RESEARCH.md §27)
    //! — the app's first. Deliberately a minimal four categories (clear,
    //! cloudy, rain, snow), not FMI's full ~20-category smartsymbol set: this
    //! page draws them at real size (one per summary row, not a 13px corner
    //! badge), but two other icons failed at small size earlier the same day
    //! — a thermometer whose bulb-vs-stem contrast collapsed, a snowflake
    //! whose branches smeared — so the bar here is "simple enough to survive
    //! being drawn small on the worst-case device", not "as detailed as the
    //! web's icon set can afford to be".

    //! Sun: a filled circle plus four short cardinal rays.
    //!
    //! A plain disc read as an unexplained dot once coloured (2026-10-16
    //! feedback) rather than a sun — but thin ray *strokes* are exactly
    //! what collapsed on the two icons that failed earlier the same week
    //! (RESEARCH.md §27 history, this file's own wxRain/wxSnow notes).
    //! These rays are solid filled rectangles instead, axis-aligned so no
    //! rotated-polygon math is needed, the same "a filled shape survives
    //! where a thin line doesn't" fix used throughout this module.
    //! A filled circle, no rays — tried twice (2026-10-16), both as a
    //! crosshair-reaching-near-centre version and a stubby-petal version,
    //! and both still read as a crosshair rather than a sun at this icon's
    //! actual size (~24px on this device). Same wall every other glyph in
    //! this file hit: a feature this thin doesn't have room to read as
    //! distinct from the disc, whatever its proportions. Colour (WX_SUN)
    //! alone was the part that actually fixed the original complaint — a
    //! flat Theme.DIM grey dot — so that's what's carrying "sun" now, not
    //! shape.
    function wxClear(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var r = s * 0.42;
        dc.fillCircle((x + s / 2).toNumber(), (y + s / 2).toNumber(), r.toNumber());
    }

    //! Cloud: three circles sharing one bottom tangent, sized small-large-
    //! medium left to right — the shared base shape for wxCloudy/wxRain/
    //! wxSnow below.
    //!
    //! Replaces the earlier two-circle-on-a-rectangle construction,
    //! 2026-10-15 (tester feedback: the FC page icons were unclear). That
    //! version's circles and base rectangle filled as one flat colour with
    //! no visible seam between them, so it read as a rounded blob rather
    //! than a cloud. Here every circle's centre sits at `baseline - r`, so
    //! all three bottoms land on the exact same line regardless of radius
    //! — no rectangle needed to fake a flat base — and consecutive circles
    //! overlap by more than either radius, so the silhouette has no gap
    //! between bumps. Bumpy top, flat bottom, one continuous shape: the
    //! standard cloud glyph construction, not a cloud-specific invention.
    function _cloud(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var baseline = y + (s * 0.76).toNumber();
        var r1 = (s * 0.22).toNumber();
        var r2 = (s * 0.30).toNumber();
        var r3 = (s * 0.24).toNumber();
        dc.fillCircle((x + s * 0.30).toNumber(), baseline - r1, r1);
        dc.fillCircle((x + s * 0.54).toNumber(), baseline - r2, r2);
        dc.fillCircle((x + s * 0.75).toNumber(), baseline - r3, r3);
    }

    function wxCloudy(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        _cloud(dc, x, y, s, colour);
    }

    //! Cloud plus short straight drops — lines, not the curved-stroke rain
    //! the web uses, since a short straight segment holds its shape at any
    //! size where a curve or a fine stroke might not.
    function wxRain(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        _cloud(dc, x, y, s, colour);
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var pen = (s * 0.08).toNumber();
        if (pen < 2) { pen = 2; }
        dc.setPenWidth(pen);
        // A small gap below the cloud's own baseline (0.76s, matching
        // _cloud above), so the drops read as falling from it rather than
        // touching it.
        var dropY = y + (s * 0.80).toNumber();
        var dropLen = (s * 0.16).toNumber();
        var xs = [x + (s * 0.28).toNumber(), x + (s * 0.5).toNumber(), x + (s * 0.72).toNumber()];
        for (var i = 0; i < xs.size(); i += 1) {
            dc.drawLine(xs[i], dropY, xs[i], dropY + dropLen);
        }
        dc.setPenWidth(1);
    }

    //! Cloud plus small filled dots — not the thin cross-stroke snowflake
    //! that already failed small today (Pages.mc §16/§27); a dot holds its
    //! shape at any size a line cannot.
    function wxSnow(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        _cloud(dc, x, y, s, colour);
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var r = (s * 0.045).toNumber();
        if (r < 1) { r = 1; }
        var dotY = y + (s * 0.84).toNumber();
        var xs = [x + (s * 0.28).toNumber(), x + (s * 0.5).toNumber(), x + (s * 0.72).toNumber()];
        for (var i = 0; i < xs.size(); i += 1) {
            dc.fillCircle(xs[i], dotY, r);
        }
    }
}
