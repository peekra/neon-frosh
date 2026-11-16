import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.Math;

//! Pure helper functions without device API calls, so they can be unit tested.
//! Includes temperature and heart rate zone helpers.
module DataConversions {

    const METERS_PER_KM = 1000.0f;

    //! Converts any numeric value to Float. Returns null for null and non-numeric values.
    function toFloatOrNull(value as Object or Null) as Float or Null {
        if (value instanceof Float) {
            return value;
        }
        if (value instanceof Number) {
            return value.toFloat();
        }
        if (value instanceof Long) {
            return value.toFloat();
        }
        if (value instanceof Double) {
            return value.toFloat();
        }
        return null;
    }

    //! Converts a distance in meters to kilometers.
    //! Returns null for null, non-numeric or negative input.
    function metersToKm(meters as Object or Null) as Float or Null {
        var value = toFloatOrNull(meters);
        if (value == null) {
            return null;
        }
        if (value < 0.0f) {
            return null;
        }
        return value / METERS_PER_KM;
    }

    //! Converts a numeric value to a rounded positive Number.
    //! Returns null for null, non-numeric, zero or negative input.
    function toPositiveNumberOrNull(value as Object or Null) as Number or Null {
        var asFloat = toFloatOrNull(value);
        if (asFloat == null) {
            return null;
        }
        var rounded = Math.round(asFloat).toNumber();
        if (rounded <= 0) {
            return null;
        }
        return rounded;
    }

    //! A heart rate sample is valid if it is set, positive and not INVALID_HR_SAMPLE.
    function isValidHeartRate(bpm as Number or Null) as Boolean {
        if (bpm == null) {
            return false;
        }
        if (bpm <= 0) {
            return false;
        }
        return bpm != ActivityMonitor.INVALID_HR_SAMPLE;
    }

    //! Returns the current heart rate if valid, else the fallback if valid, else null.
    function pickHeartRate(current as Number or Null, fallback as Number or Null) as Number or Null {
        if (isValidHeartRate(current)) {
            return current;
        }
        if (isValidHeartRate(fallback)) {
            return fallback;
        }
        return null;
    }

    //! Maximum heart rate from heart rate zones (UserProfile.getHeartRateZones): the last entry, if it is a
    //! positive Number. null for null, an empty array or an invalid last entry.
    function maxHeartRateOf(zones as Array<Number> or Null) as Number or Null {
        if (zones == null || zones.size() == 0) {
            return null;
        }
        return toPositiveNumberOrNull(zones[zones.size() - 1]);
    }

    //! Returns the complication VO2 max if positive, else the profile value if positive, else null.
    function pickVo2max(fromComplication as Number or Null, fromProfile as Number or Null) as Number or Null {
        if (fromComplication != null && fromComplication > 0) {
            return fromComplication;
        }
        if (fromProfile != null && fromProfile > 0) {
            return fromProfile;
        }
        return null;
    }

    //! True if value is a Number in the range of the DataKind values (0..DataKind.COUNT-1).
    function isDataKind(value as Object or Null) as Boolean {
        if (!(value instanceof Number)) {
            return false;
        }
        return value >= 0 && value < DataKind.COUNT;
    }

    //! True if the data kind can be shown on this device: a valid DataKind, and DataKind.CLIMB_H only
    //! where the watch can record climbing. Never throws.
    function kindAvailable(kind as Object or Null, climbingAvailable as Boolean) as Boolean {
        if (!isDataKind(kind)) {
            return false;
        }
        return climbingAvailable || kind != DataKind.CLIMB_H;
    }

    //! A stored slot value as DataKind: the value if it is a kind this device can show, else defaultKind.
    function toSlotKind(value as Object or Null, defaultKind as Number, climbingAvailable as Boolean) as Number {
        if (kindAvailable(value, climbingAvailable)) {
            return value as Number;
        }
        return defaultKind;
    }

    //! Converts a numeric value to a rounded Number. Unlike toPositiveNumberOrNull, zero and negative
    //! values are kept (temperatures). Returns null for null and non-numeric values.
    function toRoundedNumberOrNull(value as Object or Null) as Number or Null {
        var asFloat = toFloatOrNull(value);
        if (asFloat == null) {
            return null;
        }
        return Math.round(asFloat).toNumber();
    }

    //! Temperature in the unit of the watch, rounded: degrees Celsius as given, or converted to
    //! Fahrenheit. null for null and non-numeric input.
    function temperatureIn(celsius as Object or Null, fahrenheit as Boolean) as Number or Null {
        var value = toFloatOrNull(celsius);
        if (value == null) {
            return null;
        }
        if (fahrenheit) {
            value = value * 9.0f / 5.0f + 32.0f;
        }
        return Math.round(value).toNumber();
    }

    //! Converts a percentage (body battery, battery level) to a rounded Number in 0..100. Zero is valid.
    //! Returns null for null, non-numeric values and values outside 0..100 after rounding.
    function toPercentOrNull(value as Object or Null) as Number or Null {
        var rounded = toRoundedNumberOrNull(value);
        if (rounded == null || rounded < 0 || rounded > 100) {
            return null;
        }
        return rounded;
    }

    //! True if one of the slots shows this DataKind.
    function slotsContain(slots as Array<Number>, kind as Number) as Boolean {
        for (var i = 0; i < slots.size(); i++) {
            if (slots[i] == kind) {
                return true;
            }
        }
        return false;
    }

    //! True if one of the slots shows a value that is summed from the activity history
    //! (swim distance, climbing time, training time). Only then the history has to be read.
    function slotsNeedActivityHistory(slots as Array<Number>) as Boolean {
        return slotsContain(slots, DataKind.SWIM_M) || slotsContain(slots, DataKind.CLIMB_H)
            || slotsContain(slots, DataKind.TRAINING_H);
    }
}
