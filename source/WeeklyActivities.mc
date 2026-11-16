import Toybox.Activity;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;

//! Weekly sums that no complication delivers (swim distance, climbing time, training time),
//! summed from the user activity history (UserProfile.getUserActivityHistory(), API 3.3.0).
//!
//! The sums are an Array<Number> with the layout SUM_SWIM_M, SUM_CLIMB_SEC, SUM_TRAINING_SEC.
//! The week starts at local midnight of the first day of the week set on the watch.
//!
//! Everything above "Device API" is pure (plain numbers and arrays, no API calls) and unit
//! tested. NOT VERIFIED (SDK documentation is silent): the order of the history entries, how far
//! back the history reaches, and whether indoor climbing / bouldering is reported as sport 31.
module WeeklyActivities {

    //! Layout of the sums array.
    const SUM_SWIM_M = 0;          // meters, sport Activity.SPORT_SWIMMING
    const SUM_CLIMB_SEC = 1;       // seconds, sport Activity.SPORT_ROCK_CLIMBING
    const SUM_TRAINING_SEC = 2;    // seconds, sport Activity.SPORT_TRAINING (strength, cardio, yoga, pilates)
    const SUM_COUNT = 3;

    const SECONDS_PER_MINUTE = 60;
    const SECONDS_PER_DAY = 86400;
    const DAYS_PER_WEEK = 7;

    //! Upper bound of history entries inspected per read (watchdog). The order of the entries is
    //! undocumented, so a longer history than this may leave out activities of this week.
    const MAX_ENTRIES = 100;

    //! Week start used when the watch reports no valid first day of the week.
    const FALLBACK_FIRST_DAY_OF_WEEK = Gregorian.DAY_MONDAY;

    //! A new, empty sums array.
    function newSums() as Array<Number> {
        return [0, 0, 0] as Array<Number>;
    }

    //! True if value is a Gregorian day of week: DAY_SUNDAY (1) .. DAY_SATURDAY (7).
    function isDayOfWeek(value as Object or Null) as Boolean {
        if (!(value instanceof Number)) {
            return false;
        }
        return value >= Gregorian.DAY_SUNDAY && value <= Gregorian.DAY_SATURDAY;
    }

    //! Number of days from the start of the week to today (0..6), or null if today's day of week is
    //! invalid. An invalid firstDayOfWeek falls back to FALLBACK_FIRST_DAY_OF_WEEK (Monday).
    function daysSinceWeekStart(dayOfWeek as Number or Null, firstDayOfWeek as Number or Null) as Number or Null {
        if (!isDayOfWeek(dayOfWeek)) {
            return null;
        }
        var first = isDayOfWeek(firstDayOfWeek) ? firstDayOfWeek as Number : FALLBACK_FIRST_DAY_OF_WEEK;
        return ((dayOfWeek as Number) - first + DAYS_PER_WEEK) % DAYS_PER_WEEK;
    }

    //! Start of the current week in seconds (same epoch as Moment.value()): midnight of today minus the
    //! days since the start of the week. Null if today's day of week is invalid.
    //! A daylight saving change inside the current week shifts the result by one hour (accepted).
    function weekStartSeconds(todayMidnightSeconds as Number, dayOfWeek as Number or Null,
            firstDayOfWeek as Number or Null) as Number or Null {
        var days = daysSinceWeekStart(dayOfWeek, firstDayOfWeek);
        if (days == null) {
            return null;
        }
        return todayMidnightSeconds - days * SECONDS_PER_DAY;
    }

    //! Adds one history entry to sums if it started at or after weekStartSecs. Entries without a sport
    //! or start time are skipped; a missing or negative distance / duration counts as 0.
    //! Sports other than swimming, rock climbing and training are ignored.
    function addActivity(sums as Array<Number>, sport as Number or Null, distanceM as Number or Null,
            durationSec as Number or Null, startSec as Number or Null, weekStartSecs as Number) as Void {
        if (sport == null || startSec == null || startSec < weekStartSecs) {
            return;
        }
        if (sport == Activity.SPORT_SWIMMING) {
            sums[SUM_SWIM_M] = sums[SUM_SWIM_M] + nonNegative(distanceM);
        } else if (sport == Activity.SPORT_ROCK_CLIMBING) {
            sums[SUM_CLIMB_SEC] = sums[SUM_CLIMB_SEC] + nonNegative(durationSec);
        } else if (sport == Activity.SPORT_TRAINING) {
            sums[SUM_TRAINING_SEC] = sums[SUM_TRAINING_SEC] + nonNegative(durationSec);
        }
    }

    //! Whole minutes in a number of seconds (rounded down). Negative input gives 0.
    function secondsToMinutes(seconds as Number) as Number {
        if (seconds <= 0) {
            return 0;
        }
        return seconds / SECONDS_PER_MINUTE;
    }

    //! value, or 0 for null and negative values.
    function nonNegative(value as Number or Null) as Number {
        if (value == null || value < 0) {
            return 0;
        }
        return value;
    }

    // ---- Device API (not unit tested) ----

    //! Start of the current week in seconds from the watch clock and the watch's first-day-of-week
    //! setting, or null if unavailable. Never throws.
    function currentWeekStartSeconds() as Number or Null {
        try {
            var settings = System.getDeviceSettings();
            var firstDay = null;
            if (settings has :firstDayOfWeek) {
                firstDay = settings.firstDayOfWeek;
            }
            var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var dayOfWeek = info.day_of_week;
            if (!(dayOfWeek instanceof Number)) {
                return null;
            }
            return weekStartSeconds(Time.today().value(), dayOfWeek, firstDay);
        } catch (e) {
            return null;
        }
    }

    //! Sums (SUM_* layout) of the activities in the user activity history that started at or after
    //! weekStartSecs. Null if the history is unavailable or reading failed; all zeros if it is
    //! available but holds no matching activity. At most MAX_ENTRIES entries are inspected.
    //! Never throws.
    function readSums(weekStartSecs as Number) as Array<Number> or Null {
        if (!(Toybox has :UserProfile) || !(UserProfile has :getUserActivityHistory)) {
            return null;
        }
        try {
            var iterator = UserProfile.getUserActivityHistory() as UserProfile.UserActivityHistoryIterator or Null;
            if (iterator == null) {
                return null;
            }
            var sums = newSums();
            for (var i = 0; i < MAX_ENTRIES; i++) {
                var activity = iterator.next() as UserProfile.UserActivity or Null;
                if (activity == null) {
                    break;
                }
                var start = activity.startTime;
                var duration = activity.duration;
                addActivity(sums, activity.type, activity.distance,
                    duration == null ? null : duration.value(),
                    start == null ? null : start.value(),
                    weekStartSecs);
            }
            return sums;
        } catch (e) {
            return null;
        }
    }
}
