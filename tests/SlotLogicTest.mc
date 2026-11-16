import Toybox.Lang;
import Toybox.Test;

// Unit tests for the slot logic of Neon Frosh: texts, scale, kinds, settings defaults.
(:test)
module SlotLogicTest {

    (:test)
    function testHoursText(logger as Test.Logger) as Boolean {
        var ok = TestCheck.str(logger, "24h 7", TextFormat.hoursText(7, true), "07");
        ok = TestCheck.str(logger, "24h 0", TextFormat.hoursText(0, true), "00") && ok;
        ok = TestCheck.str(logger, "24h 23", TextFormat.hoursText(23, true), "23") && ok;
        ok = TestCheck.str(logger, "12h 0", TextFormat.hoursText(0, false), "12") && ok;
        ok = TestCheck.str(logger, "12h 7", TextFormat.hoursText(7, false), "7") && ok;
        ok = TestCheck.str(logger, "12h 12", TextFormat.hoursText(12, false), "12") && ok;
        ok = TestCheck.str(logger, "12h 13", TextFormat.hoursText(13, false), "1") && ok;
        ok = TestCheck.str(logger, "12h 23", TextFormat.hoursText(23, false), "11") && ok;
        return ok;
    }

    (:test)
    function testDateShort(logger as Test.Logger) as Boolean {
        var ok = TestCheck.str(logger, "EN", TextFormat.dateShort("$1$ $2$", "Aug", 29), "AUG 29");
        ok = TestCheck.str(logger, "DE", TextFormat.dateShort("$2$. $1$", "Aug.", 29), "29. AUG") && ok;
        ok = TestCheck.str(logger, "day 5", TextFormat.dateShort("$1$ $2$", "Mär", 5), "MÄR 5") && ok;
        return ok;
    }

    (:test)
    function testSlotTextDate(logger as Test.Logger) as Boolean {
        var data = new WatchData();
        data.day = 29;
        var ok = TestCheck.num(logger, "valueOf DATE", SlotText.valueOf(DataKind.DATE, data) as Number, 29);
        ok = TestCheck.str(logger, "format 29", SlotText.format(DataKind.DATE, 29, false), "29") && ok;
        ok = TestCheck.str(logger, "format 5", SlotText.format(DataKind.DATE, 5, false), "5") && ok;
        ok = TestCheck.str(logger, "format null", SlotText.format(DataKind.DATE, null, false), "--") && ok;
        return ok;
    }

    (:test)
    function testIsDataKind(logger as Test.Logger) as Boolean {
        var ok = TestCheck.bool(logger, "13", DataConversions.isDataKind(13), true);
        ok = TestCheck.bool(logger, "0", DataConversions.isDataKind(0), true) && ok;
        ok = TestCheck.bool(logger, "14", DataConversions.isDataKind(14), false) && ok;
        ok = TestCheck.bool(logger, "-1", DataConversions.isDataKind(-1), false) && ok;
        ok = TestCheck.bool(logger, "null", DataConversions.isDataKind(null), false) && ok;
        ok = TestCheck.bool(logger, "string", DataConversions.isDataKind("13"), false) && ok;
        ok = TestCheck.num(logger, "COUNT", DataKind.COUNT, 14) && ok;
        return ok;
    }

    (:test)
    function testToSlotKind(logger as Test.Logger) as Boolean {
        var ok = TestCheck.num(logger, "DATE kept", DataConversions.toSlotKind(13, 6, true), 13);
        ok = TestCheck.num(logger, "DATE no climb", DataConversions.toSlotKind(13, 6, false), 13) && ok;
        ok = TestCheck.num(logger, "14 -> default", DataConversions.toSlotKind(14, 6, true), 6) && ok;
        ok = TestCheck.num(logger, "null -> default", DataConversions.toSlotKind(null, 1, true), 1) && ok;
        ok = TestCheck.num(logger, "CLIMB no climb", DataConversions.toSlotKind(DataKind.CLIMB_H, 6, false), 6) && ok;
        ok = TestCheck.num(logger, "CLIMB climb", DataConversions.toSlotKind(DataKind.CLIMB_H, 6, true), 10) && ok;
        return ok;
    }

    (:test)
    function testScaleActiveCal(logger as Test.Logger) as Boolean {
        var data = new WatchData();
        data.activeCalories = 0;
        var ok = TestCheck.frac(logger, "0", SlotScale.fraction(DataKind.ACTIVE_CAL, data), 0.0);
        data.activeCalories = 500;
        ok = TestCheck.frac(logger, "500", SlotScale.fraction(DataKind.ACTIVE_CAL, data), 0.5) && ok;
        data.activeCalories = 1000;
        ok = TestCheck.frac(logger, "1000", SlotScale.fraction(DataKind.ACTIVE_CAL, data), 1.0) && ok;
        data.activeCalories = 1500;
        ok = TestCheck.frac(logger, "1500", SlotScale.fraction(DataKind.ACTIVE_CAL, data), 1.0) && ok;
        data.activeCalories = null;
        ok = TestCheck.frac(logger, "null", SlotScale.fraction(DataKind.ACTIVE_CAL, data), null) && ok;
        ok = TestCheck.frac(logger, "DATE none", SlotScale.fraction(DataKind.DATE, data), null) && ok;
        ok = TestCheck.frac(logger, "CALORIES none", SlotScale.fraction(DataKind.CALORIES, data), null) && ok;
        return ok;
    }

    (:test)
    function testFaceSettingsDefaults(logger as Test.Logger) as Boolean {
        var settings = new FaceSettings();
        var ok = TestCheck.bool(logger, "dark", settings.darkBackground, true);
        ok = TestCheck.num(logger, "color1", settings.color1, 0) && ok;
        ok = TestCheck.num(logger, "color2", settings.color2, 4) && ok;
        ok = TestCheck.num(logger, "slot count", settings.slots.size(), 6) && ok;
        var expected = [DataKind.DATE, DataKind.WEATHER, DataKind.BODY_BATTERY, DataKind.HEART_RATE,
            DataKind.ACTIVE_CAL, DataKind.STEPS] as Array<Number>;
        for (var i = 0; i < expected.size() && i < settings.slots.size(); i++) {
            ok = TestCheck.num(logger, "slot " + i, settings.slots[i], expected[i]) && ok;
        }
        // The copy must not alias the constant.
        settings.slots[0] = DataKind.NONE;
        ok = TestCheck.num(logger, "no alias", DataKind.DEFAULT_SLOTS[0], DataKind.DATE) && ok;
        return ok;
    }
}
