import Toybox.Graphics;
import Toybox.Lang;

//! Colours. Thresholds drive these, so a breached reading stands out without
//! the user reading the number (RESEARCH.md §17).
module Theme {
    const INK = Graphics.COLOR_WHITE;
    const DIM = Graphics.COLOR_LT_GRAY;
    const FAINT = Graphics.COLOR_DK_GRAY;
    const BG = Graphics.COLOR_BLACK;
    const OVER = Graphics.COLOR_ORANGE;      // above a wind / wave limit
    const COLD = Graphics.COLOR_BLUE;
    const HOT = Graphics.COLOR_RED;

    //! Wind colour: over the limit, or over the derived gust limit.
    function windColour(ms as Numeric?, gust as Numeric?, limit as Number, gustLimit as Number) as Number {
        if (ms != null && ms >= limit) { return OVER; }
        if (gust != null && gust >= gustLimit) { return OVER; }
        return INK;
    }

    function tempColour(c as Numeric?) as Number {
        if (c == null) { return INK; }
        if (c <= Config.landCold()) { return COLD; }
        if (c >= Config.landHot()) { return HOT; }
        return INK;
    }

    function waveColour(m as Numeric?) as Number {
        if (m != null && m >= Config.seaWave()) { return OVER; }
        return INK;
    }
}
