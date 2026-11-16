import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Application entry point (manifest entry="FaceApp").
class FaceApp extends Application.AppBase {
    private var _view as FaceView or Null = null;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary or Null) as Void {
    }

    function onStop(state as Dictionary or Null) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new FaceView();
        _view = view;
        return [view, new FaceDelegate(view)];
    }

    //! On-device settings: "Customize" in the system watch face menu. Works for sideloaded apps too.
    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        return [new SettingsMenu(), new SettingsMenuDelegate()];
    }

    //! Settings changed in the phone app (store and beta installs) or in an on-device menu:
    //! reload, recompute the layout, redraw.
    function onSettingsChanged() as Void {
        var view = _view;
        if (view != null) {
            view.applySettings();
        }
        WatchUi.requestUpdate();
    }
}
