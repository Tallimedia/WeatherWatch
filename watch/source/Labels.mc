import Toybox.Lang;
import Toybox.System;

//! Glance captions.
//!
//! The glance process cannot reach `Rez` — loading a resource there fails with
//! "Could not access symbol 'Rez'". These few words are therefore held in code
//! rather than in strings.xml, so the glance stays translated. Everything
//! outside the glance uses resources as normal.
(:glance)
module Labels {

    function isFi() as Boolean {
        return System.getDeviceSettings().systemLanguage == System.LANGUAGE_FIN;
    }

    function isSv() as Boolean {
        return System.getDeviceSettings().systemLanguage == System.LANGUAGE_SWE;
    }

    function pick(en as String, fi as String, sv as String) as String {
        if (isFi()) { return fi; }
        if (isSv()) { return sv; }
        return en;
    }

    // Shortened from "Land temp"/"Maan lämpö"/"Landtemp" — Nico's call,
    // 2026-10-21: the glance column already clipped it to "Maan lämp",
    // which read oddly, and the slot the user picked already tells them
    // it's the land reading, not the sea one below it.
    function land() as String     { return pick("Temp", "Lämpö", "Temp"); }
    function landWind() as String { return pick("Land wind", "Tuuli maalla", "Vind land"); }
    function seaWind() as String  { return pick("Sea wind", "Merituuli", "Havsvind"); }
    function seaGust() as String  { return pick("Sea gust", "Puuska", "Havsby"); }
    function wave() as String     { return pick("Waves", "Aallot", "Vågor"); }
    function water() as String    { return pick("Water", "Vesi", "Vatten"); }
}
