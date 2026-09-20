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
    function wave(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var pen = (s * 0.14).toNumber();
        if (pen < 2) { pen = 2; }
        dc.setPenWidth(pen);
        ripple(dc, x, y + (s * 0.33).toNumber(), s);
        ripple(dc, x, y + (s * 0.72).toNumber(), s);
        dc.setPenWidth(1);
    }

    //! One sine period across the width, trough first so it leads with water
    //! rather than with a hill.
    function ripple(dc as Graphics.Dc, x as Number, midY as Number, s as Number) as Void {
        var amp = (s * 0.17).toFloat();
        var steps = 8;
        var prevX = x;
        var prevY = midY + amp;
        for (var i = 1; i <= steps; i += 1) {
            var t = i.toFloat() / steps;
            var px = (x + s * t).toNumber();
            var py = (midY + amp * Math.cos(t * 2 * Math.PI)).toNumber();
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
}
