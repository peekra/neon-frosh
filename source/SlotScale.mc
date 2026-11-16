import Toybox.Lang;

//! Fill of an arc for the data kind of the field next to it (user decision 2026-11-14: "the arc follows
//! the field"). Pure functions. Interface module: changes go through the lead.
module SlotScale {

    //! Fixed goal of the active calories ring in kcal (user decision 2026-11-15).
    const ACTIVE_CAL_GOAL = 1000;

    //! Fraction 0.0..1.0 for the kinds that have a scale: heart rate of the maximum heart rate, steps of
    //! the step goal, Body Battery of 100. null for every other kind (DATE and the other kinds without a
    //! fraction) and for missing data: the progress arc is not drawn.
    function fraction(kind as Number, data as WatchData) as Float or Null {
        if (kind == DataKind.HEART_RATE) {
            return ratio(data.heartRate, data.heartRateMax);
        } else if (kind == DataKind.STEPS) {
            return ratio(data.steps, data.stepGoal);
        } else if (kind == DataKind.BODY_BATTERY) {
            return ratio(data.bodyBattery, 100);
        } else if (kind == DataKind.ACTIVE_CAL) {
            return ratio(data.activeCalories, ACTIVE_CAL_GOAL);
        }
        return null;
    }

    //! value / full, limited to 0.0..1.0. null if a value is missing or full is not positive.
    function ratio(value as Number or Null, full as Number or Null) as Float or Null {
        if (value == null || full == null || full <= 0) {
            return null;
        }
        var result = value.toFloat() / full.toFloat();
        if (result < 0.0) {
            return 0.0;
        }
        return result > 1.0 ? 1.0 : result;
    }
}
