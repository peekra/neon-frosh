import Toybox.Lang;

//! Typed copy of the user settings with defaults. load() never throws: every value is validated by
//! SettingsStore, a slot kind the device cannot show falls back to the slot's default.
//! Interface class: changes go through the lead.
class FaceSettings {
    // true = dark face (default), false = light face
    public var darkBackground as Boolean = true;
    // ColorChoice.*: colour 1 (hours, arcs) and colour 2 (minute outline, colon, panels)
    public var color1 as Number = ColorChoice.DEFAULT_1;
    public var color2 as Number = ColorChoice.DEFAULT_2;

    // DataKind per slot, index = DataKind.TOP .. DataKind.BOTTOM
    public var slots as Array<Number>;

    function initialize() {
        slots = DataKind.DEFAULT_SLOTS.slice(0, null);
    }

    //! Reads all settings from the application properties.
    function load() as Void {
        darkBackground = SettingsStore.readBoolean(
            SettingsStore.DARK_BACKGROUND, SettingsStore.DEFAULT_DARK_BACKGROUND);
        color1 = SettingsStore.readIndex(SettingsStore.COLOR1, ColorChoice.COUNT, ColorChoice.DEFAULT_1);
        color2 = SettingsStore.readIndex(SettingsStore.COLOR2, ColorChoice.COUNT, ColorChoice.DEFAULT_2);
        for (var i = 0; i < DataKind.SLOT_COUNT; i++) {
            slots[i] = SettingsStore.readSlot(i);
        }
    }

    //! True if the data kind can be offered on this device (CLIMB_H only where the watch records climbing).
    static function kindAvailable(kind as Number) as Boolean {
        return DataConversions.kindAvailable(kind, DeviceSports.HAS_CLIMBING);
    }
}
