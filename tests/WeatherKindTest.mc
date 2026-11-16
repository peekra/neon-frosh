import Toybox.Lang;
import Toybox.Test;
import Toybox.Weather;

// Unit tests for the weather condition to icon mapping. Compiled only with -t (scripts/test.sh).
(:test)
module WeatherKindTest {

    function check(logger as Test.Logger, label as String, condition as Number or Null, expected as Number) as Boolean {
        var actual = WeatherKind.iconOf(condition);
        if (actual == expected) {
            return true;
        }
        logger.error(label + ": expected " + expected + ", got " + actual);
        return false;
    }

    (:test)
    function testMapping(logger as Test.Logger) as Boolean {
        var ok = check(logger, "clear", Weather.CONDITION_CLEAR, WeatherKind.SUN);
        ok = check(logger, "light rain", Weather.CONDITION_LIGHT_RAIN, WeatherKind.SHOWERS) && ok;
        ok = check(logger, "heavy rain", Weather.CONDITION_HEAVY_RAIN, WeatherKind.RAIN) && ok;
        ok = check(logger, "fog", Weather.CONDITION_FOG, WeatherKind.CLOUDY) && ok;
        ok = check(logger, "windy", Weather.CONDITION_WINDY, WeatherKind.CLOUDY) && ok;
        ok = check(logger, "thunderstorms", Weather.CONDITION_THUNDERSTORMS, WeatherKind.THUNDER) && ok;
        ok = check(logger, "snow", Weather.CONDITION_SNOW, WeatherKind.SNOW) && ok;
        ok = check(logger, "partly cloudy", Weather.CONDITION_PARTLY_CLOUDY, WeatherKind.PARTLY) && ok;
        ok = check(logger, "null", null, WeatherKind.NONE) && ok;
        return ok;
    }

    (:test)
    function testEveryKindHasShape(logger as Test.Logger) as Boolean {
        return TestCheck.bool(logger, "7 shapes", WeatherIcons.SHAPES.size() == 7, true);
    }
}
