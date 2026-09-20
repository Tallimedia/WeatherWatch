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
//! caller can lay them out against text without knowing what the glyph is.
(:glance)
module Icons {

    //! Thermometer.
    function temp(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var cx = x + s / 2;
        var bulbR = (s * 0.22).toNumber();
        var bulbY = y + s - bulbR - 1;
        dc.drawLine(cx, y + 2, cx, bulbY);
        dc.fillCircle(cx, bulbY, bulbR);
        // Two scale ticks, enough to read as a thermometer at this size.
        dc.drawLine(cx + 2, y + 4, cx + (s * 0.30).toNumber(), y + 4);
        dc.drawLine(cx + 2, y + (s * 0.32).toNumber(), cx + (s * 0.30).toNumber(),
                    y + (s * 0.32).toNumber());
        dc.setPenWidth(1);
    }

    //! Wind — two streaming lines with a curl.
    function wind(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var y1 = y + (s * 0.34).toNumber();
        var y2 = y + (s * 0.64).toNumber();
        dc.drawLine(x, y1, x + (s * 0.68).toNumber(), y1);
        dc.drawArc(x + (s * 0.68).toNumber(), y1 + (s * 0.16).toNumber(),
                   (s * 0.17).toNumber(), Graphics.ARC_CLOCKWISE, 90, 200);
        dc.drawLine(x, y2, x + (s * 0.46).toNumber(), y2);
        dc.drawArc(x + (s * 0.46).toNumber(), y2 - (s * 0.14).toNumber(),
                   (s * 0.15).toNumber(), Graphics.ARC_COUNTER_CLOCKWISE, 270, 20);
        dc.setPenWidth(1);
    }

    //! Wave — a single swell crest.
    function wave(dc as Graphics.Dc, x as Number, y as Number, s as Number, colour as Number) as Void {
        dc.setColor(colour, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        var mid = y + s / 2;
        var q = (s * 0.25).toNumber();
        dc.drawArc(x + q, mid, q, Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
        dc.drawArc(x + q * 3, mid, q, Graphics.ARC_CLOCKWISE, 180, 360);
        dc.setPenWidth(1);
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
