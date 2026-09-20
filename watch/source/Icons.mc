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

    //! Thermometer: a narrow filled stem rising from a round bulb.
    //! The bulb must be clearly wider than the stem or the whole thing reads as
    //! a pin rather than a thermometer.
    function temp(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var cx = x + s / 2;
        var bulbR = (s * 0.26).toNumber();
        if (bulbR < 3) { bulbR = 3; }
        var bulbY = y + s - bulbR;
        var stemW = (s * 0.22).toNumber();
        if (stemW < 2) { stemW = 2; }
        // Stem, drawn as a filled bar so it reads solid at small sizes.
        dc.fillRectangle(cx - stemW / 2, y + 1, stemW, bulbY - y);
        dc.fillCircle(cx, bulbY, bulbR);
        // Two scale marks off the right of the stem.
        dc.setPenWidth(1);
        var tickX = cx + stemW / 2;
        var tickLen = (s * 0.26).toNumber();
        dc.drawLine(tickX, y + (s * 0.22).toNumber(), tickX + tickLen, y + (s * 0.22).toNumber());
        dc.drawLine(tickX, y + (s * 0.42).toNumber(), tickX + tickLen, y + (s * 0.42).toNumber());
    }

    //! Wind: three streaming lines of unequal length. The staggered ends are
    //! what make it read as moving air rather than a list or a menu glyph.
    function wind(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var pen = (s * 0.14).toNumber();
        if (pen < 2) { pen = 2; }
        dc.setPenWidth(pen);
        var y1 = y + (s * 0.26).toNumber();
        var y2 = y + (s * 0.52).toNumber();
        var y3 = y + (s * 0.78).toNumber();
        dc.drawLine(x, y1, x + (s * 0.72).toNumber(), y1);
        dc.drawLine(x, y2, x + s, y2);                       // longest in the middle
        dc.drawLine(x, y3, x + (s * 0.52).toNumber(), y3);
        dc.setPenWidth(1);
    }

    //! Waves: two stacked ripples. Stacked, never side by side — two arcs next
    //! to each other read as something else entirely.
    function wave(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        var pen = (s * 0.13).toNumber();
        if (pen < 2) { pen = 2; }
        dc.setPenWidth(pen);
        ripple(dc, x, y + (s * 0.34).toNumber(), s);
        ripple(dc, x, y + (s * 0.70).toNumber(), s);
        dc.setPenWidth(1);
    }

    //! One ripple: crest then trough, like a tilde.
    function ripple(dc as Graphics.Dc, x as Number, midY as Number, s as Number) as Void {
        var r = (s * 0.25).toNumber();
        if (r < 2) { r = 2; }
        dc.drawArc(x + r, midY, r, Graphics.ARC_COUNTER_CLOCKWISE, 20, 160);
        dc.drawArc(x + r * 3, midY, r, Graphics.ARC_CLOCKWISE, 200, 340);
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
