import Toybox.Application;
import Toybox.Lang;

//! Property IDs (resources/settings/properties.xml) and safe access to them.
//! The only place that touches Application.Properties.
module SettingsStore {

    const DARK_BACKGROUND = "DarkBackground";
    const COLOR1 = "Color1";
    const COLOR2 = "Color2";
    //! Property IDs of the six slots, index = DataKind.TOP .. DataKind.BOTTOM. Each stores a DataKind value.
    const SLOT_KEYS = ["Slot1", "Slot2", "Slot3", "Slot4", "Slot5", "Slot6"] as Array<String>;

    const DEFAULT_DARK_BACKGROUND = true;

    //! Returns the stored Boolean, or defaultValue if the key is missing or has the wrong type.
    //! Never throws.
    function readBoolean(key as String, defaultValue as Boolean) as Boolean {
        var value = null;
        try {
            value = Application.Properties.getValue(key);
        } catch (e) {
            value = null;
        }
        return TextFormat.booleanOrDefault(value, defaultValue);
    }

    //! Stores a Boolean property (for an on-device menu). Returns false if it could not be stored.
    function writeBoolean(key as String, value as Boolean) as Boolean {
        try {
            Application.Properties.setValue(key, value);
        } catch (e) {
            return false;
        }
        return true;
    }

    //! Returns the stored index inside 0..count-1, or defaultValue if the key is missing, has the wrong
    //! type or is out of range. Never throws.
    function readIndex(key as String, count as Number, defaultValue as Number) as Number {
        var value = null;
        try {
            value = Application.Properties.getValue(key);
        } catch (e) {
            value = null;
        }
        return TextFormat.indexOrDefault(value, count, defaultValue);
    }

    //! Stores a Number property. Returns false if it could not be stored.
    function writeNumber(key as String, value as Number) as Boolean {
        try {
            Application.Properties.setValue(key, value);
        } catch (e) {
            return false;
        }
        return true;
    }

    //! Slot index (0-based) for a property ID such as "Slot2", or -1 if the key is no slot key.
    function slotIndexOfKey(key as Object or Null) as Number {
        if (!(key instanceof String)) {
            return -1;
        }
        for (var i = 0; i < SLOT_KEYS.size(); i++) {
            if (key.equals(SLOT_KEYS[i])) {
                return i;
            }
        }
        return -1;
    }

    //! Stored DataKind of a slot (0-based index). A missing, wrongly typed or out of range value, or a kind
    //! this device cannot show (CLIMB_H without DeviceSports.HAS_CLIMBING), gives the slot's default
    //! (DataKind.DEFAULT_SLOTS). Never throws.
    function readSlot(slotIndex as Number) as Number {
        if (slotIndex < 0 || slotIndex >= SLOT_KEYS.size()) {
            return DataKind.NONE;
        }
        var value = null;
        try {
            value = Application.Properties.getValue(SLOT_KEYS[slotIndex]);
        } catch (e) {
            value = null;
        }
        return DataConversions.toSlotKind(value, DataKind.DEFAULT_SLOTS[slotIndex], DeviceSports.HAS_CLIMBING);
    }

    //! Stores the DataKind of a slot. Returns false for an invalid field or a kind this device cannot show,
    //! or if storing failed.
    function writeSlot(slotIndex as Number, kind as Number) as Boolean {
        if (slotIndex < 0 || slotIndex >= SLOT_KEYS.size()
                || !DataConversions.kindAvailable(kind, DeviceSports.HAS_CLIMBING)) {
            return false;
        }
        return writeNumber(SLOT_KEYS[slotIndex], kind);
    }
}
