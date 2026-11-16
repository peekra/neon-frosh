import Toybox.Lang;

//! Selectable colours. The values are stored in the properties "Color1" and "Color2" and index the tables
//! of UiColors, so they never change. Interface module: changes go through the lead.
module ColorChoice {
    const RED = 0;
    const ORANGE = 1;
    const YELLOW = 2;
    const GREEN = 3;
    const TEAL = 4;
    const BLUE = 5;
    const PURPLE = 6;
    const PINK = 7;
    const COUNT = 8;

    //! Colour 1 (hours, progress arcs) and colour 2 (minute outline, colon, panels, Bluetooth).
    const DEFAULT_1 as Number = RED;
    const DEFAULT_2 as Number = TEAL;
}
