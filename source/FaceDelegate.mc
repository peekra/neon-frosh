import Toybox.Lang;
import Toybox.WatchUi;

//! Input of the watch face. Watch faces only receive touch and hold (onPress), and only on watches with a
//! touchscreen. Touch and hold on a slot whose kind has a system view opens that view; everywhere else the
//! press is not handled and the system default stays.
class FaceDelegate extends WatchUi.WatchFaceDelegate {
    private var _view as FaceView;

    function initialize(view as FaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    //! Touch and hold. True only if a view of the watch was opened.
    function onPress(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var xy = clickEvent.getCoordinates();
        return _view.openFieldAt(xy[0], xy[1]);
    }
}
