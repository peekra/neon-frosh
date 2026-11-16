import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! On-device settings menu, shown by the system for "Customize" in the watch face menu
//! (AppBase.getSettingsView()). Item ids are the property keys. Same order as the phone settings:
//! dark background, colour 1, colour 2, then the six slots (top panel .. bottom panel).
//! Built once per opening; allocations are fine here because it is not the face's draw path.
class SettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({ :title => Rez.Strings.AppName });
        var settings = new FaceSettings();
        settings.load();
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.DarkBackgroundTitle, null, SettingsStore.DARK_BACKGROUND,
            settings.darkBackground, null));
        addItem(new WatchUi.MenuItem(Rez.Strings.Color1Title, colorLabel(settings.color1),
            SettingsStore.COLOR1, null));
        addItem(new WatchUi.MenuItem(Rez.Strings.Color2Title, colorLabel(settings.color2),
            SettingsStore.COLOR2, null));
        for (var i = 0; i < DataKind.SLOT_COUNT; i++) {
            addItem(new WatchUi.MenuItem(slotLabel(i), kindLabel(settings.slots[i]),
                SettingsStore.SLOT_KEYS[i], null));
        }
    }

    //! Name of a colour (ColorChoice.*). An invalid value gives the name of colour 1's default.
    static function colorLabel(color as Number) as ResourceId {
        // Index = ColorChoice value.
        var labels = [Rez.Strings.ColorRed, Rez.Strings.ColorOrange, Rez.Strings.ColorYellow,
            Rez.Strings.ColorGreen, Rez.Strings.ColorTeal, Rez.Strings.ColorBlue, Rez.Strings.ColorPurple,
            Rez.Strings.ColorPink] as Array<ResourceId>;
        return labels[(color >= 0 && color < ColorChoice.COUNT) ? color : ColorChoice.DEFAULT_1];
    }

    //! Title of a slot (0-based index, DataKind.TOP..BOTTOM). An invalid index gives the top panel.
    static function slotLabel(slotIndex as Number) as ResourceId {
        var labels = [Rez.Strings.SlotTopTitle, Rez.Strings.SlotUpperLeftTitle, Rez.Strings.SlotUpperRightTitle,
            Rez.Strings.SlotLowerLeftTitle, Rez.Strings.SlotLowerRightTitle, Rez.Strings.SlotBottomTitle]
            as Array<ResourceId>;
        return labels[(slotIndex >= 0 && slotIndex < labels.size()) ? slotIndex : DataKind.TOP];
    }

    //! Name of a data kind (DataKind value). An invalid kind is shown as "Off".
    static function kindLabel(kind as Number) as ResourceId {
        // Index = DataKind value (DataKind.mc).
        var labels = [Rez.Strings.KindNone, Rez.Strings.KindWeather, Rez.Strings.KindBodyBattery,
            Rez.Strings.KindHeartRate, Rez.Strings.KindActiveCal, Rez.Strings.KindCalories,
            Rez.Strings.KindSteps, Rez.Strings.KindRunKm, Rez.Strings.KindBikeKm, Rez.Strings.KindSwimM,
            Rez.Strings.KindClimbH, Rez.Strings.KindTrainingH, Rez.Strings.KindVo2max, Rez.Strings.KindDate] as Array<ResourceId>;
        return labels[DataConversions.isDataKind(kind) ? kind : DataKind.NONE];
    }
}

//! Stores each change at once and lets the app apply it, so the face behind the menu is already right.
//! A slot item opens the SlotMenu ; Back is not overridden and closes the menu.
class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (!(id instanceof String)) {
            return;
        }
        var slotIndex = SettingsStore.slotIndexOfKey(id);
        if (slotIndex >= 0) {
            openSlotMenu(item, slotIndex);
            return;
        }
        if (item instanceof WatchUi.ToggleMenuItem) {
            SettingsStore.writeBoolean(id, item.isEnabled());
        } else if (id.equals(SettingsStore.COLOR1) || id.equals(SettingsStore.COLOR2)) {
            // Each press selects the next colour; the sub label shows the choice.
            var isFirst = id.equals(SettingsStore.COLOR1);
            var next = (SettingsStore.readIndex(id, ColorChoice.COUNT,
                isFirst ? ColorChoice.DEFAULT_1 : ColorChoice.DEFAULT_2) + 1) % ColorChoice.COUNT;
            SettingsStore.writeNumber(id, next);
            item.setSubLabel(SettingsMenu.colorLabel(next));
            WatchUi.requestUpdate();
        }
        Application.getApp().onSettingsChanged();
    }

    //! Pushes the choice menu of a slot with the stored kind focused. A failing push leaves the menu as it is.
    private function openSlotMenu(item as WatchUi.MenuItem, slotIndex as Number) as Void {
        try {
            WatchUi.pushView(new SlotMenu(slotIndex, SettingsStore.readSlot(slotIndex)),
                new SlotMenuDelegate(slotIndex, item), WatchUi.SLIDE_LEFT);
        } catch (e) {
            // Nothing to do: the slot keeps its data kind.
        }
    }
}
