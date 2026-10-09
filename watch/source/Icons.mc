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
    function temp(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var cx = x + s / 2;
        var stemW = (s * 0.36).toNumber();
        if (stemW < 3) { stemW = 3; }
        var bulbR = (s * 0.30).toNumber();
        if (bulbR < stemW / 2 + 1) { bulbR = stemW / 2 + 1; }
        var bulbY = y + s - bulbR;
        var topY = y + stemW / 2 + 1;
        // Rounded cap, stem, then the bulb — drawn as one solid silhouette.
        dc.fillCircle(cx, topY, stemW / 2);
        dc.fillRectangle(cx - stemW / 2, topY, stemW, bulbY - topY);
        dc.fillCircle(cx, bulbY, bulbR);
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
}
