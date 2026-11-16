import Toybox.Lang;

//! All proportions of the face as fractions of the display diameter D, positions relative to the centre (y down).
//! Measured from design/reference.jpg (display about 690 px there) and fitted to the smallest display (218 px).
//! The bitmap font sizes (*_CAP, OUTLINE) are set in design/drafts/fonts/make_fonts.swift and must match.
//! design/drafts/mockup.swift reads this file to draw the PNG mock-ups.
module UiSizes {
    // ---- Battery and Bluetooth (design/battery_bluetooth.svg, viewBox 74 x 24, stroke 2) ----
    const STATUS_Y = -0.405;        // centre of the row (SVG y 12)
    const STATUS_UNIT = 0.0022;     // one SVG unit; the group (SVG x 6..67) is 0.13 D wide, centred on SVG x 36.5
    const STATUS_CX = 36.5;         // SVG x that lands on the display centre

    // ---- Time ----
    const TIME_Y = 0.0;             // centre of the digits (font Hours / Minutes, cap 0.195 D)
    const TIME_CAP = 0.195;
    const COLON_GAP = 0.045;        // colon centre to the inner edge of hours and minutes
    const COLON_SIZE = 0.030;       // outlined squares, outline OUTLINE thick
    const COLON_DY = 0.042;         // square centres above and below TIME_Y
    const OUTLINE = 0.0085;         // outline of the minute digits and the colon (at least OUTLINE_MIN px)
    const OUTLINE_MIN = 2;

    // ---- Round fields (slots 1..4): centres at (+-FIELD_X, +-FIELD_Y) ----
    const FIELD_X = 0.275;
    const FIELD_Y = 0.235;
    const FIELD_R = 0.100;          // radius of the outline (stroke centre)
    const FIELD_PEN = 0.006;        // ink outline (at least 1 px)
    const ARC_PEN = 0.016;          // progress arc in colour 1, on the outline, clockwise from 12 o'clock
    const FIELD_GAP = 0.022;        // background gap between a field and a panel
    const FIELD_ICON_Y = -0.042;    // icon centre relative to the field centre (also the month of DATE)
    const FIELD_VALUE_Y = 0.030;    // value centre (font Value, cap 0.040 D)
    const ICON_SIZE = 0.050;        // visible icon size (font Icons, box 24/20 of it)
    const WEATHER_SIZE = 0.062;     // weather icon box (WeatherIcons, 100 units; the cloud fills about 95 of them, as wide as the other icons)

    // ---- Panels (slot 0 top, slot 5 bottom, mirrored) ----
    // Outer edge: circle around the display centre. Inner edge (towards the time): circle centred PANEL_INNER_CY
    // beyond the centre, so the edge is concave seen from the time. Sides: cut by the field circles + FIELD_GAP.
    const PANEL_OUTER_R = 0.360;
    const PANEL_INNER_CY = 0.500;
    const PANEL_INNER_R = 0.690;    // inner edge at x = 0: 0.190 D from the centre
    const PANEL_HALF_W = 0.275;     // polygon from -0.275 to 0.275 D (the ends lie under the field cut-outs)
    const PANEL_STEPS = 12;         // points per edge
    const PANEL_VALUE_Y = 0.255;    // value centre (font Panel, cap 0.058 D), distance from the centre
    const PANEL_LABEL_Y = 0.316;    // label centre (font Value), outside the value
    const PANEL_SINGLE_Y = 0.275;   // value centre without a label (DATE)
    const PANEL_ICON_GAP = 0.012;   // weather icon to temperature in a panel

    // ---- Always-on: offsets of the five steps (FaceView: minuteOffset = minute % 5) in units of AOD_SHIFT ----
    const AOD_SHIFT = 0.012;
}
