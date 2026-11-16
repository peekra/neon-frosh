import Toybox.Lang;

//! Which sports this device can record, selected at compile time by the "climb" / "noclimb"
//! annotations in monkey.jungle. A data kind is only offered where the watch can record the activity.
module DeviceSports {
    (:climb) const HAS_CLIMBING = true;
    (:noclimb) const HAS_CLIMBING = false;
}
