import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! Watch face view: owns data, settings, provider and renderer and drives the update cycle.
//! All drawing is delegated to FaceRenderer.
class FaceView extends WatchUi.WatchFace {
    private const BURN_IN_STEPS = 5;

    private var _data as WatchData;
    private var _settings as FaceSettings;
    private var _provider as DataProvider;
    private var _renderer as FaceRenderer;
    private var _width as Number = 0;
    private var _height as Number = 0;
    private var _hasLayout as Boolean = false;
    private var _sleeping as Boolean = false;

    function initialize() {
        WatchFace.initialize();
        _data = new WatchData();
        _settings = new FaceSettings();
        _settings.load();
        _provider = new DataProvider();
        _provider.setSlots(_settings.slots);
        _renderer = new FaceRenderer();
    }

    //! Computes all geometry once per screen size.
    function onLayout(dc as Dc) as Void {
        _width = dc.getWidth();
        _height = dc.getHeight();
        _hasLayout = true;
        _renderer.computeLayout(_width, _height, _settings);
    }

    //! Back on screen: read every value again on the next update.
    function onShow() as Void {
        _provider.invalidate();
    }

    //! Once per minute in low power; every second in high power, but the face shows no seconds and the
    //! provider reads its values only when the minute changed.
    function onUpdate(dc as Dc) as Void {
        _provider.update(_data);
        if (_sleeping && isAlwaysOnActive()) {
            _renderer.drawAlwaysOn(dc, _data, burnInOffset(_data.minute));
        } else {
            _renderer.drawFace(dc, _data);
        }
    }

    //! High power mode (about 10 s after a wrist turn): onUpdate runs every second.
    function onExitSleep() as Void {
        _sleeping = false;
        // The heart rate may be up to a minute old after the low power phase.
        _provider.refreshHeartRate();
        WatchUi.requestUpdate();
    }

    //! Low power mode: onUpdate runs once per minute, no seconds.
    function onEnterSleep() as Void {
        _sleeping = true;
        WatchUi.requestUpdate();
    }

    //! Called by the app after the user changed the settings.
    function applySettings() as Void {
        _settings.load();
        if (_hasLayout) {
            _renderer.computeLayout(_width, _height, _settings);
        }
        _provider.setSlots(_settings.slots);
        _provider.invalidate();
    }

    //! Touch and hold at (x, y): opens the view of the watch behind the slot there. True only if a view was
    //! opened; never in the always-on view, where no slot is drawn.
    function openFieldAt(x as Number, y as Number) as Boolean {
        if (!_hasLayout || (_sleeping && isAlwaysOnActive())) {
            return false;
        }
        return _provider.exitToKind(_renderer.kindAt(x, y));
    }

    //! Burn-in shift step of the always-on view: minute % 5, so the position changes every minute and
    //! repeats after five. The renderer maps 0..4 to a small pixel offset (see FaceRenderer.drawAlwaysOn).
    private function burnInOffset(minute as Number) as Number {
        return minute % BURN_IN_STEPS;
    }

    //! True only if the user switched "always on" on: requiresBurnInProtection alone is always true on
    //! AMOLED, so the display mode decides. MIP watches have no burn-in protection and keep the full face.
    private function isAlwaysOnActive() as Boolean {
        var deviceSettings = System.getDeviceSettings();
        if (!(deviceSettings has :requiresBurnInProtection) || !deviceSettings.requiresBurnInProtection) {
            return false;
        }
        if (System has :getDisplayMode) {
            return System.getDisplayMode() == System.DISPLAY_MODE_LOW_POWER;
        }
        return true;
    }
}
