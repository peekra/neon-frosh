import Toybox.Lang;

//! Pure helpers without API calls. This is where most unit tests go.
module TextFormat {

    const MISSING = "--";

    //! 7 -> "07"
    function pad2(value as Number) as String {
        return value.format("%02d");
    }

    //! Number as text, "--" for null.
    function numberOrDash(value as Number or Null) as String {
        if (value == null) {
            return MISSING;
        }
        return value.format("%d");
    }

    //! "DD-MM-YYYY"
    function date(day as Number, month as Number, year as Number) as String {
        return pad2(day) + "-" + pad2(month) + "-" + year.format("%04d");
    }

    //! Hour on a 12 h clock: 0 -> 12, 13 -> 1, 12 -> 12.
    function hour12(hour as Number) as Number {
        var h = hour % 12;
        return h == 0 ? 12 : h;
    }

    //! Time of day as drawn: 24 h "07:05" / "10:08"; 12 h "7:05" (1..12 without leading zero, no AM/PM).
    function time(hour as Number, minute as Number, is24Hour as Boolean) as String {
        if (is24Hour) {
            return pad2(hour) + ":" + pad2(minute);
        }
        return hour12(hour).format("%d") + ":" + pad2(minute);
    }

    //! A name from the system for the date line: upper case, a trailing dot removed ("Aug." -> "AUG").
    function dateName(name as String) as String {
        var text = name;
        var length = text.length();
        if (length > 0) {
            var last = text.substring(length - 1, length);
            if (last != null && last.equals(".")) {
                text = text.substring(0, length - 1) as String;
            }
        }
        return text.toUpper();
    }

    //! Date line from the language's pattern (string resource DateFormat: $1$ weekday, $2$ day, $3$ month),
    //! e.g. "$1$, $2$ $3$" -> "SATURDAY, 29 AUG", "$1$, $2$. $3$" -> "SAMSTAG, 29. AUG".
    //! The names come from the system; they are upper-cased and lose a trailing dot here.
    function dateLine(pattern as String, weekday as String, day as Number, month as String) as String {
        return Lang.format(pattern, [dateName(weekday), day.format("%d"), dateName(month)]);
    }

    //! Hours as drawn: 24 h "07" / "10"; 12 h "7" (1..12, no leading zero, no AM/PM).
    function hoursText(hour as Number, is24Hour as Boolean) as String {
        return is24Hour ? pad2(hour) : hour12(hour).format("%d");
    }

    //! Short date from the language's pattern (string resource DateFormat: $1$ month, $2$ day),
    //! e.g. "$1$ $2$" -> "AUG 29", "$2$. $1$" -> "29. AUG". The month name is upper-cased and loses a trailing dot.
    function dateShort(pattern as String, month as String, day as Number) as String {
        return Lang.format(pattern, [dateName(month), day.format("%d")]);
    }

    //! A stored property value as Boolean; anything else gives the default.
    function booleanOrDefault(value as Object or Null, defaultValue as Boolean) as Boolean {
        if (value instanceof Boolean) {
            return value;
        }
        return defaultValue;
    }

    //! A stored property value as Number inside 0..count-1; anything else gives the default.
    function indexOrDefault(value as Object or Null, count as Number, defaultValue as Number) as Number {
        if (value instanceof Number && value >= 0 && value < count) {
            return value;
        }
        return defaultValue;
    }
}
