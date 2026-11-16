import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Test;

// Touch and hold on fields: which kinds open a view, and FaceRenderer.kindAt hit testing.
(:test)
module TouchTest {

    (:test)
    function testOpensView(logger as Test.Logger) as Boolean {
        var ok = true;
        var yes = [1, 2, 3, 4, 5, 6, 7, 8, 12, 13] as Array<Number>;
        var no = [0, 9, 10, 11, -1, 14] as Array<Number>;
        for (var i = 0; i < yes.size(); i++) {
            ok = TestCheck.bool(logger, "opensView " + yes[i], ComplicationSource.opensView(yes[i]), true) && ok;
        }
        for (var i = 0; i < no.size(); i++) {
            ok = TestCheck.bool(logger, "opensView " + no[i], ComplicationSource.opensView(no[i]), false) && ok;
        }
        return ok;
    }

    (:test)
    function testTypeForKind(logger as Test.Logger) as Boolean {
        if (!(Toybox has :Complications)) {
            logger.debug("no Complications on this device, skipped");
            return true;
        }
        var ok = true;
        for (var kind = -1; kind <= DataKind.COUNT; kind++) {
            var type = ComplicationSource.typeForKind(kind);
            ok = TestCheck.bool(logger, "type null? kind " + kind, type != null,
                ComplicationSource.opensView(kind)) && ok;
        }
        ok = TestCheck.bool(logger, "ACTIVE_CAL == CALORIES",
            ComplicationSource.typeForKind(DataKind.ACTIVE_CAL) == ComplicationSource.typeForKind(DataKind.CALORIES),
            true) && ok;
        ok = TestCheck.bool(logger, "STEPS != HEART_RATE",
            ComplicationSource.typeForKind(DataKind.STEPS) == ComplicationSource.typeForKind(DataKind.HEART_RATE),
            false) && ok;
        return ok;
    }

    (:test)
    function testKindAtBeforeLayout(logger as Test.Logger) as Boolean {
        var renderer = new FaceRenderer();
        var ok = TestCheck.num(logger, "centre", renderer.kindAt(100, 100), DataKind.NONE);
        ok = TestCheck.num(logger, "origin", renderer.kindAt(0, 0), DataKind.NONE) && ok;
        return ok;
    }

    (:test)
    function testKindAtLayout(logger as Test.Logger) as Boolean {
        var size = System.getDeviceSettings().screenWidth;
        var d = size.toFloat();
        var settings = new FaceSettings();
        var renderer = new FaceRenderer();
        renderer.computeLayout(size, size, settings);
        var c = size / 2;
        var fx = Math.round(UiSizes.FIELD_X * d).toNumber();
        var fy = Math.round(UiSizes.FIELD_Y * d).toNumber();
        var fr = Math.round(UiSizes.FIELD_R * d).toNumber();
        var ok = true;

        // field centres and a ring of points inside each field (also proves the panels do not reach into the fields)
        var cxs = [c - fx, c + fx, c - fx, c + fx] as Array<Number>;
        var cys = [c - fy, c - fy, c + fy, c + fy] as Array<Number>;
        for (var f = 0; f < 4; f++) {
            var expected = settings.slots[DataKind.UPPER_LEFT + f];
            ok = TestCheck.num(logger, "field " + f + " centre", renderer.kindAt(cxs[f], cys[f]), expected) && ok;
            for (var a = 0; a < 12; a++) {
                var angle = a * Math.PI / 6.0;
                var px = cxs[f] + Math.round(0.9 * fr * Math.cos(angle)).toNumber();
                var py = cys[f] + Math.round(0.9 * fr * Math.sin(angle)).toNumber();
                ok = TestCheck.num(logger, "field " + f + " ring " + a, renderer.kindAt(px, py), expected) && ok;
            }
        }

        // panels (value text centre) and the empty places
        var panelY = Math.round(UiSizes.PANEL_SINGLE_Y * d).toNumber();
        ok = TestCheck.num(logger, "top panel", renderer.kindAt(c, c - panelY), settings.slots[DataKind.TOP]) && ok;
        ok = TestCheck.num(logger, "bottom panel", renderer.kindAt(c, c + panelY), settings.slots[DataKind.BOTTOM]) && ok;
        ok = TestCheck.num(logger, "time centre", renderer.kindAt(c, c), DataKind.NONE) && ok;
        ok = TestCheck.num(logger, "left edge", renderer.kindAt(0, c), DataKind.NONE) && ok;
        ok = TestCheck.num(logger, "top edge", renderer.kindAt(c, 0), DataKind.NONE) && ok;
        ok = TestCheck.num(logger, "corner", renderer.kindAt(size - 1, size - 1), DataKind.NONE) && ok;
        return ok;
    }

    (:test)
    function testKindAtNoneSlot(logger as Test.Logger) as Boolean {
        var size = System.getDeviceSettings().screenWidth;
        var d = size.toFloat();
        var settings = new FaceSettings();
        for (var i = 0; i < settings.slots.size(); i++) {
            settings.slots[i] = DataKind.NONE;
        }
        var renderer = new FaceRenderer();
        renderer.computeLayout(size, size, settings);
        var c = size / 2;
        var fx = Math.round(UiSizes.FIELD_X * d).toNumber();
        var fy = Math.round(UiSizes.FIELD_Y * d).toNumber();
        var panelY = Math.round(UiSizes.PANEL_SINGLE_Y * d).toNumber();
        var ok = TestCheck.num(logger, "field none", renderer.kindAt(c - fx, c - fy), DataKind.NONE);
        ok = TestCheck.num(logger, "top none", renderer.kindAt(c, c - panelY), DataKind.NONE) && ok;
        ok = TestCheck.num(logger, "bottom none", renderer.kindAt(c, c + panelY), DataKind.NONE) && ok;
        return ok;
    }
}
