import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class FIWeatherWatchApp extends Application.AppBase {

    hidden var _view as PageView?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        // Show the last reading immediately rather than a spinner: for a marine
        // app the phone is often out of range, and stale-but-labelled beats
        // empty (RESEARCH.md §17).
        Api.restore();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        _view = new PageView();
        return [_view, new PageDelegate(_view)];
    }

    function getGlanceView() {
        return [new FIWeatherGlanceView()];
    }

    //! Settings are phone-edited, so this fires whenever the user changes one.
    function onSettingsChanged() as Void {
        Api.refreshAll();
        WatchUi.requestUpdate();
    }
}
