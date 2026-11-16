import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;
import Toybox.Weather;
import Toybox.WatchUi;

//! Fills the single WatchData instance in place.
//!
//! Every second only data.second and data.phoneConnected change. Everything else (time and date text, battery, the data kinds)
//! is read when the minute changes, after invalidate() (start, onShow, settings change) and, for the heart
//! rate only, after refreshHeartRate() (wake-up). Each data kind is read only while a slot shows it;
//! the values of the other kinds stay null.
//! Every read is guarded (has, try/catch): a missing value becomes null, nothing here throws.
class DataProvider {
    private const NO_MINUTE = -1;
    private const MINUTES_PER_HOUR = 60;
    //! Upper bound of history samples inspected for the heart rate fallback.
    private const HR_HISTORY_MAX_SAMPLES = 10;
    private const FALLBACK_DATE_PATTERN = "$1$ $2$";

    private var _complications as ComplicationSource;
    private var _datePattern as String = FALLBACK_DATE_PATTERN;
    private var _lastMinuteOfDay as Number = NO_MINUTE;
    private var _stale as Boolean = true;
    private var _heartRateStale as Boolean = false;
    private var _year as Number = 2026;

    // Which kinds the six slots show (setSlots).
    private var _needsHeartRate as Boolean = false;
    private var _needsSteps as Boolean = false;
    private var _needsCalories as Boolean = false;
    private var _needsActiveCalories as Boolean = false;
    private var _needsBodyBattery as Boolean = false;
    private var _needsWeather as Boolean = false;
    private var _needsRun as Boolean = false;
    private var _needsBike as Boolean = false;
    private var _needsWeeklySums as Boolean = false;
    private var _needsVo2max as Boolean = false;

    function initialize() {
        _complications = new ComplicationSource();
        _complications.start();
        try {
            var pattern = WatchUi.loadResource(Rez.Strings.DateFormat);
            if (pattern instanceof String) {
                _datePattern = pattern;
            }
        } catch (e) {
            _datePattern = FALLBACK_DATE_PATTERN;
        }
    }

    //! Tells the provider which DataKind each field shows (FaceSettings.slots), so only those kinds are
    //! read. Call invalidate() afterwards.
    function setSlots(slots as Array<Number>) as Void {
        _needsHeartRate = DataConversions.slotsContain(slots, DataKind.HEART_RATE);
        _needsSteps = DataConversions.slotsContain(slots, DataKind.STEPS);
        _needsCalories = DataConversions.slotsContain(slots, DataKind.CALORIES);
        _needsActiveCalories = DataConversions.slotsContain(slots, DataKind.ACTIVE_CAL);
        _needsBodyBattery = DataConversions.slotsContain(slots, DataKind.BODY_BATTERY);
        _needsWeather = DataConversions.slotsContain(slots, DataKind.WEATHER);
        _needsRun = DataConversions.slotsContain(slots, DataKind.RUN_KM);
        _needsBike = DataConversions.slotsContain(slots, DataKind.BIKE_KM);
        _needsWeeklySums = DataConversions.slotsNeedActivityHistory(slots);
        _needsVo2max = DataConversions.slotsContain(slots, DataKind.VO2MAX);
    }

    //! Opens the view of the watch behind a data kind (ComplicationSource.exitToKind). Never throws.
    function exitToKind(kind as Number) as Boolean {
        return _complications.exitToKind(kind);
    }

    //! Forces a refresh of all values on the next update (start, onShow, settings change).
    function invalidate() as Void {
        _stale = true;
    }

    //! Reads the heart rate again on the next update (wake-up), without the other values.
    function refreshHeartRate() as Void {
        _heartRateStale = true;
    }

    //! Updates data. Per second data.second and the phone connection; the rest once per minute. Never throws.
    function update(data as WatchData) as Void {
        var clock = System.getClockTime();
        data.second = clock.sec;
        refreshPhoneConnected(data);
        var minuteOfDay = clock.hour * MINUTES_PER_HOUR + clock.min;
        if (_stale || minuteOfDay != _lastMinuteOfDay) {
            _lastMinuteOfDay = minuteOfDay;
            _stale = false;
            _heartRateStale = false;
            data.hour = clock.hour;
            data.minute = clock.min;
            refreshMinute(data, minuteOfDay);
        } else if (_heartRateStale) {
            _heartRateStale = false;
            refreshHeartRateValue(data);
        }
    }

    private function refreshMinute(data as WatchData, minuteOfDay as Number) as Void {
        var settings = System.getDeviceSettings();
        data.timeText = TextFormat.time(data.hour, data.minute, settings.is24Hour);
        data.hoursText = TextFormat.hoursText(data.hour, settings.is24Hour);
        data.minutesText = TextFormat.pad2(data.minute);
        refreshDate(data);
        refreshBattery(data);
        refreshActivityMonitor(data, minuteOfDay);
        refreshHeartRateValue(data);
        data.heartRateMax = _needsHeartRate ? readMaxHeartRate() : null;
        refreshComplications(data);
        refreshWeeklySums(data);
        refreshWeather(data, settings);
    }

    //! Short date in the language of the watch: month short (FORMAT_MEDIUM) and day, order from the string
    //! resource DateFormat, e.g. "AUG 29". Also sets day and monthText. On any error the old values stay.
    private function refreshDate(data as WatchData) as Void {
        try {
            var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            _year = info.year;
            var month = info.month;
            if (month instanceof String) {
                data.day = info.day;
                data.monthText = TextFormat.dateName(month);
                data.dateText = TextFormat.dateShort(_datePattern, month, info.day);
            }
        } catch (e) {
            // keep the previous values
        }
    }

    //! Per second, so the Bluetooth icon changes colour right after the connection changes.
    private function refreshPhoneConnected(data as WatchData) as Void {
        try {
            data.phoneConnected = System.getDeviceSettings().phoneConnected == true;
        } catch (e) {
            data.phoneConnected = false;
        }
    }

    private function refreshBattery(data as WatchData) as Void {
        try {
            data.batteryPercent = DataConversions.toPercentOrNull(System.getSystemStats().battery);
        } catch (e) {
            data.batteryPercent = null;
        }
    }

    //! Steps with goal, total and active calories from ActivityMonitor; each only while a field shows it.
    private function refreshActivityMonitor(data as WatchData, minuteOfDay as Number) as Void {
        data.steps = null;
        data.stepGoal = null;
        data.calories = null;
        data.activeCalories = null;
        if (!_needsSteps && !_needsCalories && !_needsActiveCalories) {
            return;
        }
        try {
            // Declared non-null, but treated as nullable to never crash on odd firmware.
            var info = ActivityMonitor.getInfo() as ActivityMonitor.Info or Null;
            if (info == null) {
                return;
            }
            if (_needsSteps) {
                data.steps = info.steps;
                data.stepGoal = info.stepGoal;
            }
            var calories = info.calories;
            if (_needsCalories) {
                data.calories = calories;
            }
            if (_needsActiveCalories) {
                data.activeCalories = ActiveCalories.active(calories, readBmrPerDay(), minuteOfDay);
            }
        } catch (e) {
            // values stay null
        }
    }

    //! Heart rate, only while a field shows it: the current value, else the newest valid history sample.
    private function refreshHeartRateValue(data as WatchData) as Void {
        if (!_needsHeartRate) {
            data.heartRate = null;
            return;
        }
        try {
            var current = readCurrentHeartRate();
            var fallback = DataConversions.isValidHeartRate(current) ? null : readHistoryHeartRate();
            data.heartRate = DataConversions.pickHeartRate(current, fallback);
        } catch (e) {
            data.heartRate = null;
        }
    }

    //! Values cached by the complication callbacks: copying them is cheap.
    private function refreshComplications(data as WatchData) as Void {
        data.weeklyRunKm = _needsRun ? _complications.getWeeklyRunKm() : null;
        data.weeklyBikeKm = _needsBike ? _complications.getWeeklyBikeKm() : null;
        data.bodyBattery = _needsBodyBattery ? _complications.getBodyBattery() : null;
        data.vo2max = null;
        if (_needsVo2max) {
            var fromComplication = _complications.getVo2max();
            data.vo2max = DataConversions.pickVo2max(fromComplication,
                fromComplication == null ? readProfileVo2max() : null);
        }
    }

    //! Swim distance, climbing and training time of this week from the activity history.
    //! Read only while a field shows one of them; unavailable -> null.
    private function refreshWeeklySums(data as WatchData) as Void {
        data.weeklySwimM = null;
        data.weeklyClimbMin = null;
        data.weeklyTrainingMin = null;
        if (!_needsWeeklySums) {
            return;
        }
        var weekStart = WeeklyActivities.currentWeekStartSeconds();
        var sums = weekStart == null ? null : WeeklyActivities.readSums(weekStart);
        if (sums == null) {
            return;
        }
        data.weeklySwimM = sums[WeeklyActivities.SUM_SWIM_M];
        data.weeklyClimbMin = WeeklyActivities.secondsToMinutes(sums[WeeklyActivities.SUM_CLIMB_SEC]);
        data.weeklyTrainingMin = WeeklyActivities.secondsToMinutes(sums[WeeklyActivities.SUM_TRAINING_SEC]);
    }

    //! Temperature (rounded, in the unit of the watch) and icon of the latest cached weather, however old
    //! it is. Read only while a field shows the weather; no data -> null and WeatherKind.NONE.
    private function refreshWeather(data as WatchData, settings as System.DeviceSettings) as Void {
        data.temperature = null;
        data.weatherIcon = WeatherKind.NONE;
        data.fahrenheit = (settings has :temperatureUnits) && settings.temperatureUnits == System.UNIT_STATUTE;
        if (!_needsWeather || !(Toybox has :Weather) || !(Weather has :getCurrentConditions)) {
            return;
        }
        try {
            var conditions = Weather.getCurrentConditions() as Weather.CurrentConditions or Null;
            if (conditions == null) {
                return;
            }
            data.temperature = DataConversions.temperatureIn(conditions.temperature, data.fahrenheit);
            data.weatherIcon = WeatherKind.iconOf(conditions.condition);
        } catch (e) {
            data.temperature = null;
            data.weatherIcon = WeatherKind.NONE;
        }
    }

    private function readCurrentHeartRate() as Number or Null {
        var info = Activity.getActivityInfo() as Activity.Info or Null;
        if (info == null) {
            return null;
        }
        return info.currentHeartRate;
    }

    private function readHistoryHeartRate() as Number or Null {
        if (!(ActivityMonitor has :getHeartRateHistory)) {
            return null;
        }
        var iterator = ActivityMonitor.getHeartRateHistory(HR_HISTORY_MAX_SAMPLES, true)
            as ActivityMonitor.HeartRateIterator or Null;
        if (iterator == null) {
            return null;
        }
        for (var i = 0; i < HR_HISTORY_MAX_SAMPLES; i++) {
            var sample = iterator.next();
            if (sample == null) {
                return null;
            }
            var bpm = sample.heartRate;
            if (DataConversions.isValidHeartRate(bpm)) {
                return bpm;
            }
        }
        return null;
    }

    //! Maximum heart rate: last entry of the generic sport heart rate zones of the user profile.
    private function readMaxHeartRate() as Number or Null {
        if (!(Toybox has :UserProfile) || !(UserProfile has :getHeartRateZones)) {
            return null;
        }
        try {
            return DataConversions.maxHeartRateOf(UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC));
        } catch (e) {
            return null;
        }
    }

    //! Running VO2 max of the user profile (fallback when the complication has no value).
    private function readProfileVo2max() as Number or Null {
        var profile = readProfile();
        if (profile == null) {
            return null;
        }
        return (profile has :vo2maxRunning) ? profile.vo2maxRunning : null;
    }

    //! Resting calories per day from the user profile (ActiveCalories.bmrPerDay), or null.
    private function readBmrPerDay() as Float or Null {
        var profile = readProfile();
        if (profile == null) {
            return null;
        }
        var weight = (profile has :weight) ? profile.weight : null;
        var height = (profile has :height) ? profile.height : null;
        var birthYear = (profile has :birthYear) ? profile.birthYear : null;
        var gender = (profile has :gender) ? profile.gender : null;
        return ActiveCalories.bmrPerDay(weight, height, birthYear, gender, _year);
    }

    private function readProfile() as UserProfile.Profile or Null {
        if (!(Toybox has :UserProfile)) {
            return null;
        }
        try {
            return UserProfile.getProfile();
        } catch (e) {
            return null;
        }
    }
}
