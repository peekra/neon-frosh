import Toybox.Lang;
import Toybox.Weather;

//! The seven weather icons of the face and the mapping from Weather.CONDITION_* to them.
module WeatherKind {
    //! No icon: unknown condition or no weather data.
    const NONE = -1;
    const SUN = 0;
    const PARTLY = 1;     // slightly cloudy
    const CLOUDY = 2;
    const RAIN = 3;
    const SNOW = 4;
    const THUNDER = 5;
    const SHOWERS = 6;    // sun behind a cloud with rain

    //! Icon for a Weather.CONDITION_* value. null, "unknown" and values outside the SDK list give NONE.
    function iconOf(condition as Number or Null) as Number {
        if (condition == null) {
            return NONE;
        }
        switch (condition) {
            case Weather.CONDITION_CLEAR:
            case Weather.CONDITION_FAIR:
            case Weather.CONDITION_MOSTLY_CLEAR:
                return SUN;
            case Weather.CONDITION_PARTLY_CLEAR:
            case Weather.CONDITION_PARTLY_CLOUDY:
            case Weather.CONDITION_THIN_CLOUDS:
                return PARTLY;
            case Weather.CONDITION_CLOUDY:
            case Weather.CONDITION_MOSTLY_CLOUDY:
            case Weather.CONDITION_FOG:
            case Weather.CONDITION_MIST:
            case Weather.CONDITION_HAZE:
            case Weather.CONDITION_HAZY:
            case Weather.CONDITION_SMOKE:
            case Weather.CONDITION_DUST:
            case Weather.CONDITION_SAND:
            case Weather.CONDITION_SANDSTORM:
            case Weather.CONDITION_VOLCANIC_ASH:
            case Weather.CONDITION_WINDY:
            case Weather.CONDITION_SQUALL:
                return CLOUDY;
            case Weather.CONDITION_LIGHT_RAIN:
            case Weather.CONDITION_LIGHT_SHOWERS:
            case Weather.CONDITION_SHOWERS:
            case Weather.CONDITION_SCATTERED_SHOWERS:
            case Weather.CONDITION_CHANCE_OF_SHOWERS:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN:
            case Weather.CONDITION_DRIZZLE:
                return SHOWERS;
            case Weather.CONDITION_RAIN:
            case Weather.CONDITION_HEAVY_RAIN:
            case Weather.CONDITION_HEAVY_SHOWERS:
            case Weather.CONDITION_HAIL:
            case Weather.CONDITION_UNKNOWN_PRECIPITATION:
                return RAIN;
            case Weather.CONDITION_SNOW:
            case Weather.CONDITION_LIGHT_SNOW:
            case Weather.CONDITION_HEAVY_SNOW:
            case Weather.CONDITION_FLURRIES:
            case Weather.CONDITION_CHANCE_OF_SNOW:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW:
            case Weather.CONDITION_RAIN_SNOW:
            case Weather.CONDITION_LIGHT_RAIN_SNOW:
            case Weather.CONDITION_HEAVY_RAIN_SNOW:
            case Weather.CONDITION_CHANCE_OF_RAIN_SNOW:
            case Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW:
            case Weather.CONDITION_SLEET:
            case Weather.CONDITION_WINTRY_MIX:
            case Weather.CONDITION_FREEZING_RAIN:
            case Weather.CONDITION_ICE:
            case Weather.CONDITION_ICE_SNOW:
                return SNOW;
            case Weather.CONDITION_THUNDERSTORMS:
            case Weather.CONDITION_SCATTERED_THUNDERSTORMS:
            case Weather.CONDITION_CHANCE_OF_THUNDERSTORMS:
            case Weather.CONDITION_TROPICAL_STORM:
            case Weather.CONDITION_HURRICANE:
            case Weather.CONDITION_TORNADO:
                return THUNDER;
            default:
                return NONE;   // CONDITION_UNKNOWN and anything else
        }
    }
}
