import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

//! Only entry point of the view into the UI. computeLayout() does all geometry, draw*() only draws and never
//! allocates (except a new value text when a shown value changed). Elements, top to bottom (CLAUDE.md, "Design
//! specification"): Bluetooth and battery, top panel (slot 0), round fields (slots 1..4), time, bottom panel (slot 5).
//!
//! Fonts: bitmap fonts per resolution (resources-round-*/fonts, design/drafts/fonts/make_fonts.swift): Hours (solid
//! digits), Minutes (the same digits as an inner outline), Value and Panel (digits, Latin capitals, signs), Icons.
//! A date or month text with a character outside the bitmap fonts (other scripts) falls back to a system font.
class FaceRenderer {
    private const CENTER = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
    private const RIGHT = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;
    private const LEFT = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
    //! Characters of the fonts Value and Panel (keep in step with textChars in make_fonts.swift).
    private const TEXT_CHARS = "0123456789 .,:-+%/°ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÜÅÉÈÊÁÀÂÍÓÔÚÇÑ";
    //! Always-on: FaceView passes minuteOffset = minute % 5; step k moves the time by (SHIFT_X[k], SHIFT_Y[k]) x
    //! UiSizes.AOD_SHIFT, so no pixel of the outline stays lit for more than a minute in the same place.
    private const SHIFT_X = [0, 1, 0, -1, 0] as Array<Number>;
    private const SHIFT_Y = [0, 0, 1, 0, -1] as Array<Number>;
    // Bluetooth rune of design/battery_bluetooth.svg: "M7 17l10-10-5-5v20l5-5-10-10" as absolute points
    private const BT_SVG_X = [7, 17, 12, 12, 17, 7] as Array<Number>;
    private const BT_SVG_Y = [17, 7, 2, 22, 17, 7] as Array<Number>;
    // Charge bars of the SVG (x of the bar centres, 3 units wide, y 8..16)
    private const BAR_SVG_X = [40, 47, 54] as Array<Number>;

    // Fonts
    private var _hoursFont as Graphics.FontType;
    private var _minutesFont as Graphics.FontType;
    private var _valueFont as Graphics.FontType;
    private var _panelFont as Graphics.FontType;
    private var _iconFont as Graphics.FontType;

    // Centre and pens
    private var _cx as Number = 0;
    private var _cy as Number = 0;
    private var _outline as Number = 2;
    private var _fieldPen as Number = 1;
    private var _arcPen as Number = 2;

    // Bluetooth and battery
    private var _btX as Array<Number> = [] as Array<Number>;
    private var _btY as Array<Number> = [] as Array<Number>;
    private var _statusPen as Number = 1;
    private var _batX as Number = 0;          // outer box of the battery outline
    private var _batY as Number = 0;
    private var _batW as Number = 0;
    private var _batH as Number = 0;
    private var _batR as Number = 1;
    private var _nubX as Number = 0;          // contact on the right
    private var _nubY as Number = 0;
    private var _nubW as Number = 1;
    private var _nubH as Number = 1;
    private var _barX as Array<Number> = [] as Array<Number>;
    private var _barY as Number = 0;
    private var _barW as Number = 1;
    private var _barH as Number = 1;

    // Time
    private var _timeY as Number = 0;
    private var _colonGap as Number = 0;
    private var _colonSize as Number = 0;
    private var _colonDy as Number = 0;
    private var _aodShift as Number = 0;

    // Slots, index = DataKind.TOP .. DataKind.BOTTOM; x/y = field centre (round fields only)
    private var _kinds as Array<Number> = [] as Array<Number>;
    private var _glyphs as Array<String> = [] as Array<String>;
    private var _labels as Array<String> = [] as Array<String>;
    private var _fx as Array<Number> = [] as Array<Number>;
    private var _fy as Array<Number> = [] as Array<Number>;
    private var _fieldR as Number = 0;
    private var _cutR as Number = 0;
    private var _iconDy as Number = 0;
    private var _valueDy as Number = 0;
    private var _weatherSize as Number = 0;
    // Value text cache: the text is formatted again only when the shown value changes
    private var _texts as Array<String> = [] as Array<String>;
    private var _keys as Array<Number or Null> = [] as Array<Number or Null>;

    // Panels
    private var _topPoly as Array<Graphics.Point2D> = [] as Array<Graphics.Point2D>;
    private var _bottomPoly as Array<Graphics.Point2D> = [] as Array<Graphics.Point2D>;
    private var _panelValueDy as Number = 0;
    private var _panelLabelDy as Number = 0;
    private var _panelSingleDy as Number = 0;
    private var _panelIconGap as Number = 0;

    // Date and month texts: do the bitmap fonts have every character? Checked only when the text changes.
    private var _lastDate as String = "";
    private var _dateFont as Graphics.FontType = Graphics.FONT_SMALL;
    private var _lastMonth as String = "";
    private var _monthFont as Graphics.FontType = Graphics.FONT_XTINY;

    //! Settings-independent work: the fonts (one size per resolution).
    function initialize() {
        _hoursFont = WatchUi.loadResource(Rez.Fonts.Hours) as Graphics.FontType;
        _minutesFont = WatchUi.loadResource(Rez.Fonts.Minutes) as Graphics.FontType;
        _valueFont = WatchUi.loadResource(Rez.Fonts.Value) as Graphics.FontType;
        _panelFont = WatchUi.loadResource(Rez.Fonts.Panel) as Graphics.FontType;
        _iconFont = WatchUi.loadResource(Rez.Fonts.Icons) as Graphics.FontType;
        _dateFont = _panelFont;
        _monthFont = _valueFont;
    }

    //! From View.onLayout() and after a settings change. Allocations are allowed here, never in draw*().
    function computeLayout(width as Number, height as Number, settings as FaceSettings) as Void {
        UiColors.apply(settings.darkBackground, settings.color1, settings.color2);
        var d = (width < height ? width : height).toFloat();
        _cx = width / 2;
        _cy = height / 2;
        _outline = px(UiSizes.OUTLINE, d);
        if (_outline < UiSizes.OUTLINE_MIN) {
            _outline = UiSizes.OUTLINE_MIN;
        }
        _fieldPen = atLeast1(UiSizes.FIELD_PEN * d);
        _arcPen = atLeast1(UiSizes.ARC_PEN * d);

        layoutStatus(d);

        _timeY = _cy + px(UiSizes.TIME_Y, d);
        _colonGap = px(UiSizes.COLON_GAP, d);
        _colonSize = px(UiSizes.COLON_SIZE, d);
        if (_colonSize < 2 * _outline + 2) {
            _colonSize = 2 * _outline + 2;
        }
        _colonDy = px(UiSizes.COLON_DY, d);
        _aodShift = atLeast1(UiSizes.AOD_SHIFT * d);

        // Slots
        var n = DataKind.SLOT_COUNT;
        _kinds = new Array<Number>[n];
        _glyphs = new Array<String>[n];
        _labels = new Array<String>[n];
        _texts = new Array<String>[n];
        _keys = new Array<Number or Null>[n];
        for (var i = 0; i < n; i++) {
            var kind = i < settings.slots.size() ? settings.slots[i] : DataKind.NONE;
            if (kind < 0 || kind >= DataKind.COUNT) {
                kind = DataKind.NONE;
            }
            _kinds[i] = kind;
            _glyphs[i] = IconGlyphs.forKind(kind);
            _labels[i] = SlotLabels.forKind(kind);
            _texts[i] = SlotText.MISSING;
            _keys[i] = null;
        }
        var fx = px(UiSizes.FIELD_X, d);
        var fy = px(UiSizes.FIELD_Y, d);
        _fx = new Array<Number>[n];
        _fy = new Array<Number>[n];
        for (var i = 0; i < n; i++) {
            _fx[i] = _cx;
            _fy[i] = _cy;
        }
        _fx[DataKind.UPPER_LEFT] = _cx - fx;
        _fy[DataKind.UPPER_LEFT] = _cy - fy;
        _fx[DataKind.UPPER_RIGHT] = _cx + fx;
        _fy[DataKind.UPPER_RIGHT] = _cy - fy;
        _fx[DataKind.LOWER_LEFT] = _cx - fx;
        _fy[DataKind.LOWER_LEFT] = _cy + fy;
        _fx[DataKind.LOWER_RIGHT] = _cx + fx;
        _fy[DataKind.LOWER_RIGHT] = _cy + fy;
        _fieldR = px(UiSizes.FIELD_R, d);
        _cutR = _fieldR + px(UiSizes.FIELD_GAP, d) + (_arcPen + 1) / 2;
        _iconDy = px(UiSizes.FIELD_ICON_Y, d);
        _valueDy = px(UiSizes.FIELD_VALUE_Y, d);
        _weatherSize = px(UiSizes.WEATHER_SIZE, d);

        // Panels: outer edge left to right, then the inner edge right to left
        _topPoly = panelPolygon(d, -1);
        _bottomPoly = panelPolygon(d, 1);
        _panelValueDy = px(UiSizes.PANEL_VALUE_Y, d);
        _panelLabelDy = px(UiSizes.PANEL_LABEL_Y, d);
        _panelSingleDy = px(UiSizes.PANEL_SINGLE_Y, d);
        _panelIconGap = px(UiSizes.PANEL_ICON_GAP, d);

        _lastDate = "";
        _lastMonth = "";
    }

    //! DataKind of the slot under (x, y): a round field (circle around its centre, up to the cut-out of the
    //! arc), the top or the bottom panel (its polygon). DataKind.NONE where no slot is shown, for a slot set to
    //! NONE and before computeLayout. No allocation.
    function kindAt(x as Number, y as Number) as Number {
        if (_kinds.size() < DataKind.SLOT_COUNT) {
            return DataKind.NONE;
        }
        // Round fields first: they cut into the panel polygons (drawn on top), so a point in a field circle
        // belongs to the field even where the panel polygon reaches under it.
        for (var i = DataKind.UPPER_LEFT; i <= DataKind.LOWER_RIGHT; i++) {
            var dx = x - _fx[i];
            var dy = y - _fy[i];
            if (dx * dx + dy * dy <= _cutR * _cutR) {
                return _kinds[i];
            }
        }
        if (inPolygon(_topPoly, x, y)) {
            return _kinds[DataKind.TOP];
        }
        if (inPolygon(_bottomPoly, x, y)) {
            return _kinds[DataKind.BOTTOM];
        }
        return DataKind.NONE;
    }

    //! Even-odd test of a point against a polygon.
    private function inPolygon(poly as Array<Graphics.Point2D>, x as Number, y as Number) as Boolean {
        var inside = false;
        var n = poly.size();
        if (n < 3) {
            return false;
        }
        var j = n - 1;
        for (var i = 0; i < n; i++) {
            var pi = poly[i];
            var pj = poly[j];
            if ((pi[1] > y) != (pj[1] > y)
                    && x < (pj[0] - pi[0]) * (y - pi[1]).toFloat() / (pj[1] - pi[1]) + pi[0]) {
                inside = !inside;
            }
            j = i;
        }
        return inside;
    }

    //! Full face, high and low power (no seconds anywhere).
    function drawFace(dc as Graphics.Dc, data as WatchData) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(UiColors.ink, UiColors.background);
        dc.clear();
        drawPanelShapes(dc);
        drawBluetooth(dc, data.phoneConnected);
        drawBattery(dc, data.batteryPercent);
        drawTime(dc, data, 0, 0, _hoursFont, UiColors.color1, UiColors.color2, UiColors.background);
        for (var i = DataKind.UPPER_LEFT; i <= DataKind.LOWER_RIGHT; i++) {
            drawField(dc, data, i);
        }
        drawPanel(dc, data, DataKind.TOP, -1);
        drawPanel(dc, data, DataKind.BOTTOM, 1);
    }

    //! Always-on (AMOLED): only the time as thin outline digits on black, hours in dimmed colour 1, minutes and colon
    //! in dimmed colour 2, moved by step minuteOffset (0..4, see SHIFT_X). Ignores the light/dark setting.
    function drawAlwaysOn(dc as Graphics.Dc, data as WatchData, minuteOffset as Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(UiColors.aod2, Graphics.COLOR_BLACK);
        dc.clear();
        var step = minuteOffset % SHIFT_X.size();
        if (step < 0) {
            step += SHIFT_X.size();
        }
        drawTime(dc, data, SHIFT_X[step] * _aodShift, SHIFT_Y[step] * _aodShift, _minutesFont, UiColors.aod1,
            UiColors.aod2, Graphics.COLOR_BLACK);
    }

    // ---- elements ----

    //! Hours right of the colon gap in hoursFont, minutes as outline digits, colon as two outlined squares.
    private function drawTime(dc as Graphics.Dc, data as WatchData, dx as Number, dy as Number,
            hoursFont as Graphics.FontType, hoursColor as Number, minutesColor as Number, back as Number) as Void {
        var y = _timeY + dy;
        dc.setColor(hoursColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + dx - _colonGap, y, hoursFont, data.hoursText, RIGHT);
        dc.setColor(minutesColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx + dx + _colonGap, y, _minutesFont, data.minutesText, LEFT);
        var s = _colonSize;
        var x0 = _cx + dx - s / 2;
        var inner = s - 2 * _outline;
        for (var k = -1; k <= 1; k += 2) {
            var y0 = y + k * _colonDy - s / 2;
            dc.setColor(minutesColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0, y0, s, s);
            dc.setColor(back, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x0 + _outline, y0 + _outline, inner, inner);
        }
    }

    //! Panel fills, then the background gap around every field (cuts the concave sides of the panels).
    private function drawPanelShapes(dc as Graphics.Dc) as Void {
        dc.setColor(UiColors.panelFill, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(_topPoly);
        dc.fillPolygon(_bottomPoly);
        dc.setColor(UiColors.background, Graphics.COLOR_TRANSPARENT);
        for (var i = DataKind.UPPER_LEFT; i <= DataKind.LOWER_RIGHT; i++) {
            dc.fillCircle(_fx[i], _fy[i], _cutR);
        }
    }

    //! Bluetooth rune: colour 2 while the phone is connected, btOff otherwise.
    private function drawBluetooth(dc as Graphics.Dc, connected as Boolean) as Void {
        dc.setColor(connected ? UiColors.color2 : UiColors.btOff, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_statusPen);
        for (var i = 1; i < _btX.size(); i++) {
            dc.drawLine(_btX[i - 1], _btY[i - 1], _btX[i], _btY[i]);
        }
        dc.setPenWidth(1);
    }

    //! Outline with contact in ink and 0..3 bars by charge; 0..15 % no bar and the outline in the warning colour.
    //! null: outline only.
    private function drawBattery(dc as Graphics.Dc, percent as Number or Null) as Void {
        var bars = 0;
        var color = UiColors.ink;
        if (percent != null) {
            if (percent <= 15) {
                color = UiColors.warning;
            } else if (percent <= 40) {
                bars = 1;
            } else if (percent <= 70) {
                bars = 2;
            } else {
                bars = 3;
            }
        }
        var pen = _statusPen;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(_batX, _batY, _batW, _batH, _batR);
        dc.fillRectangle(_nubX, _nubY, _nubW, _nubH);
        dc.setColor(UiColors.background, Graphics.COLOR_TRANSPARENT);
        var innerR = _batR - pen;
        dc.fillRoundedRectangle(_batX + pen, _batY + pen, _batW - 2 * pen, _batH - 2 * pen, innerR < 0 ? 0 : innerR);
        if (bars > 0) {
            dc.setColor(UiColors.ink, Graphics.COLOR_TRANSPARENT);
            for (var i = 0; i < bars; i++) {
                dc.fillRectangle(_barX[i], _barY, _barW, _barH);
            }
        }
    }

    //! Round field: ink outline, progress arc in colour 1 (clockwise from 12 o'clock) where the kind has a fraction,
    //! icon (or month) above the value. NONE: outline only. Missing value: "--", the icon stays.
    private function drawField(dc as Graphics.Dc, data as WatchData, i as Number) as Void {
        var x = _fx[i];
        var y = _fy[i];
        dc.setColor(UiColors.ink, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(_fieldPen);
        dc.drawCircle(x, y, _fieldR);
        var kind = _kinds[i];
        if (kind == DataKind.NONE) {
            dc.setPenWidth(1);
            return;
        }
        var fraction = SlotScale.fraction(kind, data);
        if (fraction != null && fraction > 0.0) {
            dc.setColor(UiColors.color1, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(_arcPen);
            var sweep = Math.round(360 * fraction).toNumber();
            if (sweep >= 360) {
                dc.drawCircle(x, y, _fieldR);
            } else if (sweep > 0) {
                var end = 90 - sweep;
                if (end < 0) {
                    end += 360;
                }
                dc.drawArc(x, y, _fieldR, Graphics.ARC_CLOCKWISE, 90, end);
            }
        }
        dc.setPenWidth(1);

        if (kind == DataKind.WEATHER) {
            var weather = data.weatherIcon == WeatherKind.NONE ? WeatherKind.CLOUDY : data.weatherIcon;
            WeatherIcons.draw(dc, weather, x, y + _iconDy, _weatherSize, UiColors.background);
        } else if (kind == DataKind.DATE) {
            checkMonth(data.monthText);
            dc.setColor(UiColors.ink, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y + _iconDy, _monthFont, data.monthText, CENTER);
        } else {
            dc.setColor(UiColors.ink, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y + _iconDy, _iconFont, _glyphs[i], CENTER);
        }
        dc.setColor(UiColors.ink, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + _valueDy, _valueFont, valueText(data, i), CENTER);
    }

    //! Panel content; side -1 = top, 1 = bottom. Value in ink, label (outside the value) in the label colour.
    private function drawPanel(dc as Graphics.Dc, data as WatchData, slot as Number, side as Number) as Void {
        var kind = _kinds[slot];
        if (kind == DataKind.NONE) {
            return;
        }
        if (kind == DataKind.DATE) {
            checkDate(data.dateText);
            dc.setColor(UiColors.ink, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _cy + side * _panelSingleDy, _dateFont, data.dateText, CENTER);
            return;
        }
        var text = valueText(data, slot);
        if (kind == DataKind.WEATHER) {
            // icon left of the temperature, the pair centred
            var y = _cy + side * _panelSingleDy;
            var w = dc.getTextWidthInPixels(text, _panelFont);
            var left = _cx - (_weatherSize + _panelIconGap + w) / 2;
            var weather = data.weatherIcon == WeatherKind.NONE ? WeatherKind.CLOUDY : data.weatherIcon;
            WeatherIcons.draw(dc, weather, left + _weatherSize / 2, y, _weatherSize, UiColors.panelFill);
            dc.setColor(UiColors.ink, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left + _weatherSize + _panelIconGap, y, _panelFont, text, LEFT);
            return;
        }
        dc.setColor(UiColors.ink, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy + side * _panelValueDy, _panelFont, text, CENTER);
        dc.setColor(UiColors.panelLabel, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _cy + side * _panelLabelDy, _valueFont, _labels[slot], CENTER);
    }

    //! Value text of a slot, formatted again only when the shown value changed.
    private function valueText(data as WatchData, i as Number) as String {
        var kind = _kinds[i];
        var value = SlotText.valueOf(kind, data);
        var key = value;
        if (kind == DataKind.WEATHER && value != null) {
            key = value * 2 + (data.fahrenheit ? 1 : 0);
        }
        if (key != _keys[i]) {
            _texts[i] = SlotText.format(kind, value, data.fahrenheit);
            _keys[i] = key;
        }
        return _texts[i];
    }

    //! Font of the date: Panel if it has every character, else a system font. Runs only when the text changed.
    private function checkDate(text as String) as Void {
        if (!text.equals(_lastDate)) {
            _lastDate = text;
            _dateFont = covered(text) ? _panelFont : Graphics.FONT_SMALL;
        }
    }

    private function checkMonth(text as String) as Void {
        if (!text.equals(_lastMonth)) {
            _lastMonth = text;
            _monthFont = covered(text) ? _valueFont : Graphics.FONT_XTINY;
        }
    }

    //! True if every character of text is in the bitmap fonts Value and Panel.
    private function covered(text as String) as Boolean {
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            if (TEXT_CHARS.find(chars[i].toString()) == null) {
                return false;
            }
        }
        return true;
    }

    // ---- layout helpers ----

    //! Bluetooth rune and battery from the SVG geometry (viewBox 74 x 24), scaled by UiSizes.STATUS_UNIT.
    private function layoutStatus(d as Float) as Void {
        var u = UiSizes.STATUS_UNIT * d;
        var midY = _cy + UiSizes.STATUS_Y * d;
        _statusPen = atLeast1(2 * u);
        _btX = new Array<Number>[BT_SVG_X.size()];
        _btY = new Array<Number>[BT_SVG_X.size()];
        for (var i = 0; i < BT_SVG_X.size(); i++) {
            _btX[i] = svgX(BT_SVG_X[i], u);
            _btY[i] = svgY(BT_SVG_Y[i], u, midY);
        }
        // rect x 35..65, y 4..20, stroke 2: outer box 34..66 x 3..21, corner radius 2 + 1
        _batX = svgX(34, u);
        _batY = svgY(3, u, midY);
        _batW = svgX(66, u) - _batX;
        _batH = svgY(21, u, midY) - _batY;
        _batR = atLeast1(3 * u);
        // contact: the SVG draws it on the right edge (x 65, stroke 3, y 9..15); here a nub right of the outline
        _nubX = _batX + _batW;
        _nubW = atLeast1(1.5 * u);
        _nubY = svgY(9, u, midY);
        _nubH = svgY(15, u, midY) - _nubY;
        // bars: 3 units wide around x 40/47/54, y 8..16 (round caps: 6.5..17.5)
        _barW = atLeast1(3 * u);
        _barX = new Array<Number>[BAR_SVG_X.size()];
        for (var i = 0; i < BAR_SVG_X.size(); i++) {
            _barX[i] = svgX(BAR_SVG_X[i], u) - _barW / 2;
        }
        _barY = svgY(7, u, midY);
        _barH = svgY(17, u, midY) - _barY;
        var innerBottom = _batY + _batH - _statusPen;
        if (_barY < _batY + _statusPen + 1) {
            _barY = _batY + _statusPen + 1;
        }
        if (_barY + _barH > innerBottom - 1) {
            _barH = innerBottom - 1 - _barY;
        }
        if (_barH < 1) {
            _barH = 1;
        }
    }

    private function svgX(x as Number, u as Float) as Number {
        return Math.round(_cx + (x - UiSizes.STATUS_CX) * u).toNumber();
    }

    private function svgY(y as Number, u as Float, midY as Float) as Number {
        return Math.round(midY + (y - 12) * u).toNumber();
    }

    //! Panel polygon; side -1 = top, 1 = bottom (mirrored). Outer edge on the circle PANEL_OUTER_R around the centre,
    //! inner edge on the circle PANEL_INNER_R around the point PANEL_INNER_CY on the other side of the centre.
    private function panelPolygon(d as Float, side as Number) as Array<Graphics.Point2D> {
        var steps = UiSizes.PANEL_STEPS;
        var poly = new Array<Graphics.Point2D>[2 * steps];
        var halfW = UiSizes.PANEL_HALF_W;
        var outerR = UiSizes.PANEL_OUTER_R;
        var innerR = UiSizes.PANEL_INNER_R;
        for (var k = 0; k < steps; k++) {
            var x = -halfW + 2 * halfW * k / (steps - 1);
            var yo = Math.sqrt(outerR * outerR - x * x);
            poly[k] = [Math.round(_cx + x * d).toNumber(), Math.round(_cy + side * yo * d).toNumber()] as Graphics.Point2D;
            var xi = -x;
            var yi = UiSizes.PANEL_INNER_CY - Math.sqrt(innerR * innerR - xi * xi);
            poly[steps + k] = [Math.round(_cx + xi * d).toNumber(), Math.round(_cy - side * yi * d).toNumber()] as Graphics.Point2D;
        }
        return poly;
    }

    private function px(fraction as Float, d as Float) as Number {
        return Math.round(fraction * d).toNumber();
    }

    private function atLeast1(pixels as Float) as Number {
        var n = Math.round(pixels).toNumber();
        return n < 1 ? 1 : n;
    }
}
