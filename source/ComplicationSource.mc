import Toybox.Complications;
import Toybox.Lang;

//! Subscribes to the VO2 max, weekly run distance, weekly bike distance and body battery complications
//! and caches their values.
//! The system calls onComplicationChanged() whenever a value changes, so reading is free.
//! Also opens the system view behind a data kind (exitToKind).
class ComplicationSource {
    private var _vo2maxId as Complications.Id or Null = null;
    private var _weeklyRunId as Complications.Id or Null = null;
    private var _weeklyBikeId as Complications.Id or Null = null;
    private var _bodyBatteryId as Complications.Id or Null = null;
    private var _vo2max as Number or Null = null;
    private var _weeklyRunKm as Float or Null = null;
    private var _weeklyBikeKm as Float or Null = null;
    private var _bodyBattery as Number or Null = null;
    private var _started as Boolean = false;

    function initialize() {
        if (Toybox has :Complications) {
            _vo2maxId = new Complications.Id(Complications.COMPLICATION_TYPE_VO2MAX_RUN);
            _weeklyRunId = new Complications.Id(Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE);
            _weeklyBikeId = new Complications.Id(Complications.COMPLICATION_TYPE_WEEKLY_BIKE_DISTANCE);
            _bodyBatteryId = new Complications.Id(Complications.COMPLICATION_TYPE_BODY_BATTERY);
        }
    }

    //! Registers the change callback, subscribes and reads the initial values. Runs only once.
    function start() as Void {
        if (_started || !(Toybox has :Complications)) {
            return;
        }
        _started = true;
        Complications.registerComplicationChangeCallback(method(:onComplicationChanged));
        subscribe(_vo2maxId);
        subscribe(_weeklyRunId);
        subscribe(_weeklyBikeId);
        subscribe(_bodyBatteryId);
        refresh(_vo2maxId);
        refresh(_weeklyRunId);
        refresh(_weeklyBikeId);
        refresh(_bodyBatteryId);
    }

    //! Running VO2 max from the complication, or null.
    function getVo2max() as Number or Null {
        return _vo2max;
    }

    //! Weekly run distance in km from the complication, or null.
    function getWeeklyRunKm() as Float or Null {
        return _weeklyRunKm;
    }

    //! Weekly bike distance in km from the complication, or null.
    function getWeeklyBikeKm() as Float or Null {
        return _weeklyBikeKm;
    }

    //! Body battery (0..100) from the complication, or null.
    function getBodyBattery() as Number or Null {
        return _bodyBattery;
    }

    //! True if touch and hold on a slot of this data kind opens a view of the watch (typeForKind != null).
    static function opensView(kind as Number) as Boolean {
        return kind == DataKind.WEATHER || kind == DataKind.BODY_BATTERY || kind == DataKind.HEART_RATE
            || kind == DataKind.ACTIVE_CAL || kind == DataKind.CALORIES || kind == DataKind.STEPS
            || kind == DataKind.VO2MAX || kind == DataKind.RUN_KM || kind == DataKind.BIKE_KM
            || kind == DataKind.DATE;
    }

    //! Complication type whose view belongs to a data kind; null for kinds without a view (NONE, SWIM_M,
    //! CLIMB_H, TRAINING_H). Active and total calories share the one calories view. Only call it where
    //! Toybox has :Complications (the constants do not exist otherwise).
    static function typeForKind(kind as Number) as Complications.Type or Null {
        if (kind == DataKind.WEATHER) {
            return Complications.COMPLICATION_TYPE_CURRENT_WEATHER;
        } else if (kind == DataKind.BODY_BATTERY) {
            return Complications.COMPLICATION_TYPE_BODY_BATTERY;
        } else if (kind == DataKind.HEART_RATE) {
            return Complications.COMPLICATION_TYPE_HEART_RATE;
        } else if (kind == DataKind.ACTIVE_CAL || kind == DataKind.CALORIES) {
            return Complications.COMPLICATION_TYPE_CALORIES;
        } else if (kind == DataKind.STEPS) {
            return Complications.COMPLICATION_TYPE_STEPS;
        } else if (kind == DataKind.VO2MAX) {
            return Complications.COMPLICATION_TYPE_VO2MAX_RUN;
        } else if (kind == DataKind.RUN_KM) {
            return Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE;
        } else if (kind == DataKind.BIKE_KM) {
            return Complications.COMPLICATION_TYPE_WEEKLY_BIKE_DISTANCE;
        } else if (kind == DataKind.DATE) {
            return Complications.COMPLICATION_TYPE_CALENDAR_EVENTS;
        }
        return null;
    }

    //! Opens the view of the watch behind a data kind. True only if the system accepted the request;
    //! false for kinds without a view, if unavailable or on any error. Never throws.
    function exitToKind(kind as Number) as Boolean {
        if (!opensView(kind) || !(Toybox has :Complications) || !(Complications has :exitTo)) {
            return false;
        }
        try {
            var type = typeForKind(kind);
            if (type == null) {
                return false;
            }
            Complications.exitTo(new Complications.Id(type));
        } catch (e) {
            // e.g. the watch has no such view
            return false;
        }
        return true;
    }

    //! Complication change callback (Complications.ComplicationChangedCallback).
    function onComplicationChanged(id as Complications.Id) as Void {
        refresh(id);
    }

    private function subscribe(id as Complications.Id or Null) as Void {
        if (id == null) {
            return;
        }
        try {
            Complications.subscribeToUpdates(id);
        } catch (e) {
            // Not available on this device or too many subscriptions: value stays null.
        }
    }

    //! Reads the current value of a complication into the cache. Unavailable -> null.
    private function refresh(id as Complications.Id or Null) as Void {
        if (id == null) {
            return;
        }
        var value = null;
        try {
            value = Complications.getComplication(id).value;
        } catch (e) {
            value = null;
        }
        if (id.equals(_vo2maxId)) {
            _vo2max = DataConversions.toPositiveNumberOrNull(value);
        } else if (id.equals(_weeklyRunId)) {
            _weeklyRunKm = DataConversions.metersToKm(value);
        } else if (id.equals(_weeklyBikeId)) {
            _weeklyBikeKm = DataConversions.metersToKm(value);
        } else if (id.equals(_bodyBatteryId)) {
            _bodyBattery = DataConversions.toPercentOrNull(value);
        }
    }
}
