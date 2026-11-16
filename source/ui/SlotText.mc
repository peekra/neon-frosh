import Toybox.Lang;
import Toybox.Math;

//! Value texts of the data fields, formatted from the raw values in WatchData. Pure functions.
//! Two steps so that the renderer formats a text only when the shown value changed:
//!   valueOf(kind, data)       the value in the resolution it is shown in, as a Number (null: missing)
//!   format(kind, value, data) the text of that value
//! Units: none except the temperature ("17°C"), as in the reference picture; the icon names the kind.
module SlotText {
    const MISSING = "--";

    //! Number grouping and decimal mark. Provisional default as in the reference ("3.420"), German style;
    //! see the open question about the watch language in the designer report.
    const THOUSANDS = ".";
    const DECIMAL = ",";

    const DEGREE_C = "°C";
    const DEGREE_F = "°F";

    //! Widest realistic texts of a field, used to choose the value font (FaceRenderer.computeLayout).
    const WIDEST = ["88.888", "-88°F", "888,8", "88:88"] as Array<String>;
    //! Widest realistic temperatures, used for the larger font of the middle field when it shows the weather.
    const WIDEST_WEATHER = ["-88°C", "-88°F", "108°F"] as Array<String>;

    //! Shown value as a Number: kilometres in tenths, durations in minutes, everything else as is.
    //! WEATHER: the temperature. null for missing data, NONE and unknown kinds.
    function valueOf(kind as Number, data as WatchData) as Number or Null {
        switch (kind) {
            case DataKind.WEATHER:
                return data.temperature;
            case DataKind.BODY_BATTERY:
                return data.bodyBattery;
            case DataKind.HEART_RATE:
                return data.heartRate;
            case DataKind.ACTIVE_CAL:
                return data.activeCalories;
            case DataKind.CALORIES:
                return data.calories;
            case DataKind.STEPS:
                return data.steps;
            case DataKind.RUN_KM:
                return tenths(data.weeklyRunKm);
            case DataKind.BIKE_KM:
                return tenths(data.weeklyBikeKm);
            case DataKind.SWIM_M:
                return data.weeklySwimM;
            case DataKind.CLIMB_H:
                return data.weeklyClimbMin;
            case DataKind.TRAINING_H:
                return data.weeklyTrainingMin;
            case DataKind.VO2MAX:
                return data.vo2max;
            case DataKind.DATE:
                return data.day;
            default:
                return null;
        }
    }

    //! Text of a value from valueOf(). fahrenheit picks the temperature unit. null gives "--".
    function format(kind as Number, value as Number or Null, fahrenheit as Boolean) as String {
        if (value == null) {
            return MISSING;
        }
        switch (kind) {
            case DataKind.WEATHER:
                return value.format("%d") + (fahrenheit ? DEGREE_F : DEGREE_C);
            case DataKind.ACTIVE_CAL:
            case DataKind.CALORIES:
            case DataKind.STEPS:
            case DataKind.SWIM_M:
                return grouped(value);
            case DataKind.RUN_KM:
            case DataKind.BIKE_KM:
                return decimalTenths(value);
            case DataKind.CLIMB_H:
            case DataKind.TRAINING_H:
                return hoursMinutes(value);
            default:
                return value.format("%d");
        }
    }

    //! 3420 -> "3.420", 1234567 -> "1.234.567", -1200 -> "-1.200".
    function grouped(value as Number) as String {
        var sign = value < 0 ? "-" : "";
        var rest = value < 0 ? -value : value;
        if (rest < 1000) {
            return sign + rest.format("%d");
        }
        var text = (rest % 1000).format("%03d");
        rest = rest / 1000;
        while (rest >= 1000) {
            text = (rest % 1000).format("%03d") + THOUSANDS + text;
            rest = rest / 1000;
        }
        return sign + rest.format("%d") + THOUSANDS + text;
    }

    //! Tenths as a decimal: 124 -> "12,4", 5 -> "0,5".
    function decimalTenths(value as Number) as String {
        var rest = value < 0 ? -value : value;
        return (value < 0 ? "-" : "") + (rest / 10).format("%d") + DECIMAL + (rest % 10).format("%d");
    }

    //! Minutes as "H:MM": 195 -> "3:15", 5 -> "0:05". Negative gives "--".
    function hoursMinutes(minutes as Number) as String {
        if (minutes < 0) {
            return MISSING;
        }
        return (minutes / 60).format("%d") + ":" + (minutes % 60).format("%02d");
    }

    //! Kilometres rounded to tenths; null and NaN give null.
    function tenths(km as Float or Null) as Number or Null {
        if (km == null || km != km) {
            return null;
        }
        return Math.round(km * 10.0).toNumber();
    }
}
