import Toybox.Lang;
import Toybox.Test;

// Unit tests for the pure helpers. Compiled only with -t (scripts/test.sh).
(:test)
module TextFormatTest {

    (:test)
    function testPad2(logger as Test.Logger) as Boolean {
        var ok = TestCheck.str(logger, "pad2(7)", TextFormat.pad2(7), "07");
        ok = TestCheck.str(logger, "pad2(23)", TextFormat.pad2(23), "23") && ok;
        return ok;
    }

    (:test)
    function testMissingValue(logger as Test.Logger) as Boolean {
        var ok = TestCheck.str(logger, "null", TextFormat.numberOrDash(null), "--");
        ok = TestCheck.str(logger, "13426", TextFormat.numberOrDash(13426), "13426") && ok;
        return ok;
    }

    (:test)
    function testDate(logger as Test.Logger) as Boolean {
        return TestCheck.str(logger, "date", TextFormat.date(3, 11, 2026), "03-11-2026");
    }

    (:test)
    function testBooleanOrDefault(logger as Test.Logger) as Boolean {
        var ok = TestCheck.bool(logger, "true", TextFormat.booleanOrDefault(true, false), true);
        ok = TestCheck.bool(logger, "null", TextFormat.booleanOrDefault(null, true), true) && ok;
        ok = TestCheck.bool(logger, "wrong type", TextFormat.booleanOrDefault(1, false), false) && ok;
        return ok;
    }

    (:test)
    function testIndexOrDefault(logger as Test.Logger) as Boolean {
        var ok = TestCheck.bool(logger, "in range", TextFormat.indexOrDefault(2, 3, 0) == 2, true);
        ok = TestCheck.bool(logger, "too large", TextFormat.indexOrDefault(3, 3, 0) == 0, true) && ok;
        ok = TestCheck.bool(logger, "negative", TextFormat.indexOrDefault(-1, 3, 1) == 1, true) && ok;
        ok = TestCheck.bool(logger, "null", TextFormat.indexOrDefault(null, 3, 1) == 1, true) && ok;
        ok = TestCheck.bool(logger, "wrong type", TextFormat.indexOrDefault("2", 3, 1) == 1, true) && ok;
        return ok;
    }
}
