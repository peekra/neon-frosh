import Toybox.Lang;

//! Plain data object between logic and UI. One instance, updated in place by DataProvider.
//! A metric of null means "not available": the UI shows "--" and an empty arc.
//! Interface class: changes go through the lead.
class WatchData {
    // Time of day, 0..23 / 0..59. second is the position of the second dot.
    public var hour as Number = 0;
    public var minute as Number = 0;
    public var second as Number = 0;
    //! Whole time as one text, e.g. "10:08" (kept from the copied face; the UI draws hoursText/minutesText).
    public var timeText as String = "";
    //! Ready to draw, follow the 12/24 h setting of the watch: "10" / "7" (12 h, no leading zero) and
    //! "08" (always 2 digits).
    public var hoursText as String = "";
    public var minutesText as String = "";
    //! Ready to draw, upper case, in the language of the watch, e.g. "AUG 29" (order from DateFormat).
    public var dateText as String = "";
    //! Day of the month 1..31 and the short month name, upper case, e.g. "AUG".
    public var day as Number = 1;
    public var monthText as String = "";

    //! Charge of the watch 0..100.
    public var batteryPercent as Number or Null = null;
    //! Bluetooth connection to the phone; false when unknown.
    public var phoneConnected as Boolean = false;

    // Values of the data kinds (DataKind). Only the kinds of the six slots are kept current.
    public var heartRate as Number or Null = null;         // bpm
    public var heartRateMax as Number or Null = null;      // bpm, from the user profile: full left/right arc
    public var steps as Number or Null = null;
    public var stepGoal as Number or Null = null;          // step goal of the watch: full arc
    public var bodyBattery as Number or Null = null;       // 0..100
    public var calories as Number or Null = null;          // kcal, total incl. basal rate
    public var activeCalories as Number or Null = null;    // kcal, calculated
    public var weeklyRunKm as Float or Null = null;
    public var weeklyBikeKm as Float or Null = null;
    public var weeklySwimM as Number or Null = null;
    public var weeklyClimbMin as Number or Null = null;
    public var weeklyTrainingMin as Number or Null = null;
    public var vo2max as Number or Null = null;
    //! Rounded, in the unit of the watch: fahrenheit says which.
    public var temperature as Number or Null = null;
    public var fahrenheit as Boolean = false;
    //! WeatherKind.*; WeatherKind.NONE when unknown or no weather data.
    public var weatherIcon as Number = WeatherKind.NONE;

    function initialize() {
    }
}
