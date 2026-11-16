import Toybox.Lang;
import Toybox.Math;
import Toybox.UserProfile;

//! Active calories. Garmin gives no active calories to a watch face, so they are calculated:
//! active = max(0, total - resting calories * minutes since midnight / 1440).
//! The resting calories per day come from the user profile with the formula that was reverse-engineered
//! for Garmin in the Connect IQ developer forum (thread "Active calories",
//! https://forums.garmin.com/developer/connect-iq/f/discussion/208338/active-calories). It is not
//! official Garmin data, so the value can still differ slightly from the one Garmin Connect shows.
module ActiveCalories {
    const MINUTES_PER_DAY = 1440;
    const GRAMS_PER_KG = 1000.0f;

    // Resting calories (forum formula): 12.2 * kg + 7.628 * cm - 6.116 * age + offset (kcal per day).
    const PER_KG = 12.2f;
    const PER_CM = 7.628f;
    const PER_YEAR = 6.116f;
    const OFFSET_MALE = 5.2f;
    const OFFSET_FEMALE = -197.6f;
    const OFFSET_UNSPECIFIED = -96.2f;   // mean of the two

    //! Resting calories in kcal per day. The age is the year minus the birth year (the profile has no
    //! birthday). Null if the weight (grams), height (cm) or birth year is missing or implausible
    //! (not positive, birth year not before the current year). A gender other than male or female
    //! (also null) uses the mean offset.
    function bmrPerDay(weightG as Number or Null, heightCm as Number or Null, birthYear as Number or Null,
            gender as Number or Null, year as Number) as Float or Null {
        if (weightG == null || weightG <= 0 || heightCm == null || heightCm <= 0) {
            return null;
        }
        if (birthYear == null || birthYear >= year) {
            return null;
        }
        var offset = OFFSET_UNSPECIFIED;
        if (gender == UserProfile.GENDER_MALE) {
            offset = OFFSET_MALE;
        } else if (gender == UserProfile.GENDER_FEMALE) {
            offset = OFFSET_FEMALE;
        }
        var kg = weightG.toFloat() / GRAMS_PER_KG;
        return PER_KG * kg + PER_CM * heightCm.toFloat() - PER_YEAR * (year - birthYear).toFloat() + offset;
    }

    //! Active kcal so far: the total of the day minus the basal share up to minutesOfDay (clamped to
    //! 0..1440), rounded, never negative. Null if the total or the basal rate is missing.
    function active(totalKcal as Number or Null, bmrPerDay as Float or Null, minutesOfDay as Number) as Number or Null {
        if (totalKcal == null || bmrPerDay == null) {
            return null;
        }
        var minutes = minutesOfDay;
        if (minutes < 0) {
            minutes = 0;
        } else if (minutes > MINUTES_PER_DAY) {
            minutes = MINUTES_PER_DAY;
        }
        var basalShare = bmrPerDay * minutes.toFloat() / MINUTES_PER_DAY.toFloat();
        var active = Math.round(totalKcal.toFloat() - basalShare).toNumber();
        return active < 0 ? 0 : active;
    }
}
