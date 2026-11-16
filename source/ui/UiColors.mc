import Toybox.Lang;

//! Colour palettes (0xRRGGBB). PROPOSAL of the UI designer (2026-11-15), the user must confirm the values:
//! see design/drafts/palette.md for every value with its WCAG contrast.
//! Every colour exists once per background (dark, light) and once per display type, selected at compile time by
//! the annotations in monkey.jungle. MIP values use only the 64 MIP colours (each channel 00, 55, AA, FF).
//! Tables are indexed by ColorChoice (0 red .. 7 pink). apply() copies one set into the active variables that the
//! drawers use. tests/ColorTest.mc checks every pair.
module UiColors {
    (:amoled) const IS_MIP = false;
    (:mip) const IS_MIP = true;

    const DARK_BACKGROUND = 0x000000;
    const DARK_INK = 0xFFFFFF;
    const LIGHT_BACKGROUND = 0xFFFFFF;
    const LIGHT_INK = 0x000000;

    // Colour 1 / colour 2 (hours and arcs / minutes, colon, Bluetooth). At least 3:1 against the background.
    //                                red       orange    yellow    green     teal      blue      purple    pink
    (:amoled) const DARK_COLORS =   [0xFF3B30, 0xFF8C1A, 0xFFD60A, 0x34C759, 0x3DD6C6, 0x3D9BFF, 0xB57BFF, 0xFF5FA8] as Array<Number>;
    (:amoled) const LIGHT_COLORS =  [0xD70015, 0xC25400, 0x8F6B00, 0x1E7F3A, 0x00807A, 0x0062CC, 0x7A3DD6, 0xC2186B] as Array<Number>;
    (:mip) const DARK_COLORS =      [0xFF0000, 0xFF5500, 0xFFFF00, 0x00FF00, 0x00AAAA, 0x55AAFF, 0xAA55FF, 0xFF55AA] as Array<Number>;
    (:mip) const LIGHT_COLORS =     [0xAA0000, 0xAA5500, 0x555500, 0x00AA00, 0x005555, 0x0000FF, 0x5500AA, 0xFF00AA] as Array<Number>;

    // Panel fill: dimmed colour 2 behind the panel texts. Ink on it at least 4.5:1, the fill against the background at
    // least 1.5:1 (the panel must be visible).
    (:amoled) const DARK_FILLS =    [0x5C1512, 0x5C3009, 0x4D4000, 0x0F4A22, 0x0E4D49, 0x12355C, 0x3D2766, 0x5C1A3A] as Array<Number>;
    (:amoled) const LIGHT_FILLS =   [0xF5C2C7, 0xEBC8AD, 0xDACEAB, 0xB7D6C0, 0xADD6D4, 0xB5D1F0, 0xD8C7F3, 0xEFC3D9] as Array<Number>;
    (:mip) const DARK_FILLS =       [0xAA0000, 0xAA5500, 0x555500, 0x005500, 0x005555, 0x0000AA, 0x5500AA, 0xAA0055] as Array<Number>;
    (:mip) const LIGHT_FILLS =      [0xFFAAAA, 0xFFAA55, 0xAAAA00, 0x55AA55, 0x55AAAA, 0x55AAFF, 0xAAAAFF, 0xFFAAFF] as Array<Number>;

    // Panel label ("STEP"): colour 2 where it reaches 3:1 on its own fill, else ink (light orange and some MIP colours).
    (:amoled) const DARK_LABELS =   DARK_COLORS;
    (:amoled) const LIGHT_LABELS =  [0xD70015, 0x000000, 0x8F6B00, 0x1E7F3A, 0x00807A, 0x0062CC, 0x7A3DD6, 0xC2186B] as Array<Number>;
    (:mip) const DARK_LABELS =      [0xFFFFFF, 0xFFFFFF, 0xFFFF00, 0x00FF00, 0x00AAAA, 0x55AAFF, 0xFFFFFF, 0xFFFFFF] as Array<Number>;
    (:mip) const LIGHT_LABELS =     [0xAA0000, 0x000000, 0x555500, 0x000000, 0x005555, 0x0000FF, 0x5500AA, 0x000000] as Array<Number>;

    // Battery outline at 0..15 % charge
    (:amoled) const DARK_WARNING = 0xFF453A;
    (:amoled) const LIGHT_WARNING = 0xD70015;
    (:mip) const DARK_WARNING = 0xFF5555;
    (:mip) const LIGHT_WARNING = 0xAA0000;

    // Track: weak, never used for text (reserved, the reference shows no track under the progress arc)
    (:amoled) const DARK_TRACK = 0x333333;
    (:amoled) const LIGHT_TRACK = 0xD0D0D0;
    (:mip) const DARK_TRACK = 0x555555;
    (:mip) const LIGHT_TRACK = 0xAAAAAA;

    // Bluetooth rune while the phone is not connected: grey, weak on purpose
    (:amoled) const DARK_BT_OFF = 0x777777;
    (:amoled) const LIGHT_BT_OFF = 0x888888;
    (:mip) const DARK_BT_OFF = 0x555555;
    (:mip) const LIGHT_BT_OFF = 0xAAAAAA;

    //! Always-on view (AMOLED only, always on black): always white, independent of the chosen colours
    //! (user decision 2026-11-15).
    const ALWAYS_ON_INK = 0xFFFFFF;

    var background as Number = DARK_BACKGROUND;
    var ink as Number = DARK_INK;
    var color1 as Number = DARK_COLORS[0];
    var color2 as Number = DARK_COLORS[4];
    var panelFill as Number = DARK_FILLS[4];
    var panelLabel as Number = DARK_LABELS[4];
    var track as Number = DARK_TRACK;
    var btOff as Number = DARK_BT_OFF;
    var warning as Number = DARK_WARNING;
    //! Always-on outline colours of hours and minutes: both ALWAYS_ON_INK (white) on black.
    var aod1 as Number = 0;
    var aod2 as Number = 0;

    //! Index outside 0..ColorChoice.COUNT-1 gives the default of that role.
    function apply(dark as Boolean, color1Index as Number, color2Index as Number) as Void {
        var i1 = valid(color1Index, ColorChoice.DEFAULT_1);
        var i2 = valid(color2Index, ColorChoice.DEFAULT_2);
        background = dark ? DARK_BACKGROUND : LIGHT_BACKGROUND;
        ink = dark ? DARK_INK : LIGHT_INK;
        color1 = dark ? DARK_COLORS[i1] : LIGHT_COLORS[i1];
        color2 = dark ? DARK_COLORS[i2] : LIGHT_COLORS[i2];
        panelFill = dark ? DARK_FILLS[i2] : LIGHT_FILLS[i2];
        panelLabel = dark ? DARK_LABELS[i2] : LIGHT_LABELS[i2];
        track = dark ? DARK_TRACK : LIGHT_TRACK;
        btOff = dark ? DARK_BT_OFF : LIGHT_BT_OFF;
        warning = dark ? DARK_WARNING : LIGHT_WARNING;
        aod1 = ALWAYS_ON_INK;
        aod2 = ALWAYS_ON_INK;
    }

    function valid(index as Number, fallback as Number) as Number {
        return (index >= 0 && index < ColorChoice.COUNT) ? index : fallback;
    }
}
