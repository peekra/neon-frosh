import Toybox.Lang;
import Toybox.Test;

// Readability of the palettes of this build (AMOLED or MIP, see monkey.jungle) on the light and the dark face, for
// every pair of colour 1 and colour 2 (8 x 8). Run it on one AMOLED and one MIP device. A new colour role belongs
// into this loop. Values and contrast numbers: design/drafts/palette.md.
(:test)
module ColorTest {

    //! Checks every role of the active palette after UiColors.apply(dark, c1, c2).
    function checkActive(logger as Test.Logger, where as String) as Boolean {
        var ok = TestCheck.contrast(logger, "ink on " + where, UiColors.ink, UiColors.background,
            ColorMath.MIN_TEXT);
        // large digits, arcs, outline digits: 3:1
        ok = TestCheck.contrast(logger, "colour 1 on " + where, UiColors.color1, UiColors.background,
            ColorMath.MIN_LARGE) && ok;
        ok = TestCheck.contrast(logger, "colour 2 on " + where, UiColors.color2, UiColors.background,
            ColorMath.MIN_LARGE) && ok;
        // panel text is ink on the fill: 4.5:1
        ok = TestCheck.contrast(logger, "ink on panel fill, " + where, UiColors.ink, UiColors.panelFill,
            ColorMath.MIN_TEXT) && ok;
        // small bold label: colour 2 where it reaches 3:1 on the fill, else ink
        ok = TestCheck.contrast(logger, "label on panel fill, " + where, UiColors.panelLabel, UiColors.panelFill,
            ColorMath.MIN_LARGE) && ok;
        ok = TestCheck.bool(logger, "label is colour 2 or ink, " + where,
            UiColors.panelLabel == UiColors.color2 || UiColors.panelLabel == UiColors.ink, true) && ok;
        // the panel must stand out from the background
        ok = TestCheck.contrast(logger, "panel fill on " + where, UiColors.panelFill, UiColors.background,
            ColorMath.MIN_TRACK) && ok;
        ok = TestCheck.contrast(logger, "warning on " + where, UiColors.warning, UiColors.background,
            ColorMath.MIN_LARGE) && ok;
        ok = TestCheck.contrast(logger, "track on " + where, UiColors.track, UiColors.background,
            ColorMath.MIN_TRACK) && ok;
        ok = TestCheck.contrast(logger, "btOff on " + where, UiColors.btOff, UiColors.background,
            ColorMath.MIN_INACTIVE) && ok;
        ok = TestCheck.bool(logger, "btOff differs from colour 2 on " + where,
            UiColors.btOff != UiColors.color2, true) && ok;
        if (!UiColors.IS_MIP) {
            // always-on: dimmed outline digits on black
            ok = TestCheck.contrast(logger, "always-on colour 1, " + where, UiColors.aod1, 0x000000,
                ColorMath.MIN_LARGE) && ok;
            ok = TestCheck.contrast(logger, "always-on colour 2, " + where, UiColors.aod2, 0x000000,
                ColorMath.MIN_LARGE) && ok;
        }
        return ok;
    }

    (:test)
    function testContrast(logger as Test.Logger) as Boolean {
        var ok = true;
        for (var dark = 0; dark < 2; dark++) {
            for (var c1 = 0; c1 < ColorChoice.COUNT; c1++) {
                for (var c2 = 0; c2 < ColorChoice.COUNT; c2++) {
                    UiColors.apply(dark == 1, c1, c2);
                    ok = checkActive(logger, (dark == 1 ? "dark" : "light") + ", colours " + c1 + "/" + c2) && ok;
                }
            }
        }
        return ok;
    }

    //! MIP builds only: a colour outside the 64 is replaced by the system and can lose its contrast.
    (:test)
    function testMipColors(logger as Test.Logger) as Boolean {
        if (!UiColors.IS_MIP) {
            return true;
        }
        var ok = true;
        for (var dark = 0; dark < 2; dark++) {
            for (var c = 0; c < ColorChoice.COUNT; c++) {
                UiColors.apply(dark == 1, c, c);
                var where = (dark == 1 ? "dark" : "light") + ", colour " + c;
                ok = TestCheck.mipColor(logger, "background " + where, UiColors.background) && ok;
                ok = TestCheck.mipColor(logger, "ink " + where, UiColors.ink) && ok;
                ok = TestCheck.mipColor(logger, "colour " + where, UiColors.color1) && ok;
                ok = TestCheck.mipColor(logger, "panel fill " + where, UiColors.panelFill) && ok;
                ok = TestCheck.mipColor(logger, "panel label " + where, UiColors.panelLabel) && ok;
                ok = TestCheck.mipColor(logger, "warning " + where, UiColors.warning) && ok;
                ok = TestCheck.mipColor(logger, "track " + where, UiColors.track) && ok;
                ok = TestCheck.mipColor(logger, "btOff " + where, UiColors.btOff) && ok;
            }
        }
        return ok;
    }

    //! Each table has one entry per ColorChoice, and the eight colours of one background differ.
    (:test)
    function testTables(logger as Test.Logger) as Boolean {
        var ok = true;
        var tables = [UiColors.DARK_COLORS, UiColors.LIGHT_COLORS, UiColors.DARK_FILLS, UiColors.LIGHT_FILLS,
            UiColors.DARK_LABELS, UiColors.LIGHT_LABELS] as Array<Array<Number>>;
        for (var t = 0; t < tables.size(); t++) {
            ok = TestCheck.bool(logger, "table " + t + " has COUNT entries",
                tables[t].size() == ColorChoice.COUNT, true) && ok;
        }
        for (var t = 0; t < 2; t++) {
            var colors = tables[t];
            for (var i = 0; i < colors.size(); i++) {
                for (var j = i + 1; j < colors.size(); j++) {
                    ok = TestCheck.bool(logger, "table " + t + ": colours " + i + " and " + j + " differ",
                        colors[i] != colors[j], true) && ok;
                }
            }
        }
        return ok;
    }

    (:test)
    function testColorMath(logger as Test.Logger) as Boolean {
        var ok = TestCheck.bool(logger, "black on white is 21", ColorMath.contrast(0x000000, 0xFFFFFF) > 20.9, true);
        ok = TestCheck.bool(logger, "same colour is 1", ColorMath.contrast(0x55AAFF, 0x55AAFF) < 1.01, true) && ok;
        ok = TestCheck.bool(logger, "0xFFAA00 is MIP", ColorMath.isMipColor(0xFFAA00), true) && ok;
        ok = TestCheck.bool(logger, "0xE9E5DA is not MIP", ColorMath.isMipColor(0xE9E5DA), false) && ok;
        return ok;
    }

    //! Out-of-range indices give the default colour of each role.
    (:test)
    function testOutOfRange(logger as Test.Logger) as Boolean {
        UiColors.apply(true, ColorChoice.DEFAULT_1, ColorChoice.DEFAULT_2);
        var c1 = UiColors.color1;
        var c2 = UiColors.color2;
        UiColors.apply(true, 99, -1);
        var ok = TestCheck.bool(logger, "invalid colour 1 gives the default", UiColors.color1 == c1, true);
        ok = TestCheck.bool(logger, "invalid colour 2 gives the default", UiColors.color2 == c2, true) && ok;
        return ok;
    }
}
