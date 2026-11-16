import Toybox.Lang;
import Toybox.Math;

// Colour arithmetic for the palette tests: contrast after WCAG 2 (relative luminance of sRGB) and the
// check for the 64 colours of MIP displays. Only compiled with -t, so it costs nothing on the watch.
(:test)
module ColorMath {

    //! Smallest contrast for text and thin lines.
    const MIN_TEXT = 4.5;
    //! Smallest contrast for large digits, icons and filled shapes.
    const MIN_LARGE = 3.0;
    //! Smallest contrast for the unfilled track of an arc: visible, but weak on purpose.
    const MIN_TRACK = 1.5;
    //! Smallest contrast for an inactive icon (Bluetooth not connected): readable, but dimmed on purpose.
    const MIN_INACTIVE = 2.0;

    //! Relative luminance 0.0 (black) .. 1.0 (white) of a 0xRRGGBB colour.
    function luminance(color as Number) as Float {
        return 0.2126 * linear((color >> 16) & 0xFF) + 0.7152 * linear((color >> 8) & 0xFF)
            + 0.0722 * linear(color & 0xFF);
    }

    //! Contrast ratio 1.0 (same colour) .. 21.0 (black on white). The order of the colours does not matter.
    function contrast(first as Number, second as Number) as Float {
        var a = luminance(first);
        var b = luminance(second);
        return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
    }

    //! True if every channel is 00, 55, AA or FF: one of the 64 colours a MIP display shows unchanged.
    function isMipColor(color as Number) as Boolean {
        return ((color >> 16) & 0xFF) % 0x55 == 0 && ((color >> 8) & 0xFF) % 0x55 == 0
            && (color & 0xFF) % 0x55 == 0;
    }

    //! One sRGB channel 0..255 as linear light 0.0..1.0.
    function linear(channel as Number) as Float {
        var value = channel / 255.0;
        if (value <= 0.03928) {
            return value / 12.92;
        }
        return Math.pow((value + 0.055) / 1.055, 2.4).toFloat();
    }
}
