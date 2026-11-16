import Toybox.Lang;

//! Data kinds a data field can show. They are the values of the properties Slot1..Slot6
//! (resources/settings/properties.xml), so the numbers are stored on the watch and must never change.
//! The order is the order of the choice menu. Same list and numbers as in the user's earlier faces
//! plus DATE (user decision 2026-11-15). Interface module: changes go through the lead.
module DataKind {
    const NONE = 0;
    const WEATHER = 1;       // icon and temperature in the unit of the watch
    const BODY_BATTERY = 2;  // 0..100
    const HEART_RATE = 3;
    const ACTIVE_CAL = 4;    // calculated: total calories minus the basal share of the day so far
    const CALORIES = 5;      // total calories of the day incl. basal metabolic rate
    const STEPS = 6;
    const RUN_KM = 7;        // weekly run distance (km)
    const BIKE_KM = 8;       // weekly bike distance (km)
    const SWIM_M = 9;        // weekly swim distance (m)
    const CLIMB_H = 10;      // weekly climbing time, only where the watch records climbing
    const TRAINING_H = 11;   // weekly time of "training" activities (strength, cardio, yoga, pilates)
    const VO2MAX = 12;       // running VO2 max as a number
    const DATE = 13;         // date as text ("AUG 29") in a panel, day number with the month above in a round field
    const COUNT = 14;

    // The six slots, index = slot number - 1.
    const TOP = 0;          // top panel
    const UPPER_LEFT = 1;   // round fields
    const UPPER_RIGHT = 2;
    const LOWER_LEFT = 3;
    const LOWER_RIGHT = 4;
    const BOTTOM = 5;       // bottom panel
    const SLOT_COUNT = 6;

    // Default assignment, as on the reference picture.
    const DEFAULT_SLOTS = [DATE, WEATHER, BODY_BATTERY, HEART_RATE, ACTIVE_CAL, STEPS] as Array<Number>;
}
