import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Choice of the data kind of one slot: "Off" plus the data kinds this device can show
//! (FaceSettings.kindAvailable), in DataKind order, the current choice focused.
//! The item ids are the DataKind values.
class SlotMenu extends WatchUi.Menu2 {

    function initialize(slotIndex as Number, currentKind as Number) {
        // Focus = position of the current kind among the available ones (0 = "Off" if it is not offered).
        var focus = 0;
        if (FaceSettings.kindAvailable(currentKind)) {
            for (var kind = 0; kind < currentKind; kind++) {
                if (FaceSettings.kindAvailable(kind)) {
                    focus++;
                }
            }
        }
        Menu2.initialize({ :title => SettingsMenu.slotLabel(slotIndex), :focus => focus });
        for (var kind = 0; kind < DataKind.COUNT; kind++) {
            if (FaceSettings.kindAvailable(kind)) {
                addItem(new WatchUi.MenuItem(SettingsMenu.kindLabel(kind), null, kind, null));
            }
        }
    }
}

//! Input handler of SlotMenu. The choice is stored at once, applied to the face, shown as sub label of the
//! slot item in the parent menu, and the menu closes. Back closes it without a change.
class SlotMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _slotIndex as Number;
    private var _parentItem as WatchUi.MenuItem;

    function initialize(slotIndex as Number, parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _slotIndex = slotIndex;
        _parentItem = parentItem;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var kind = item.getId();
        if (kind instanceof Number && SettingsStore.writeSlot(_slotIndex, kind)) {
            _parentItem.setSubLabel(SettingsMenu.kindLabel(kind));
            // Reloads the settings, recomputes the layout and requests a redraw (also of the menu).
            Application.getApp().onSettingsChanged();
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
