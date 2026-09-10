import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class TacticalFaceApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state as Dictionary?) as Void {}
    function onStop(state as Dictionary?) as Void {}
    function onSettingsChanged() as Void { WatchUi.requestUpdate(); }
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new TacticalFaceView();
        if ((WatchUi has :WatchFaceDelegate) && (WatchUi.WatchFaceDelegate has :onPress)) {
            return [view, new TacticalFaceDelegate(view)];
        }
        return [view];
    }

    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        var menu = new WatchUi.Menu2({:title => WatchUi.loadResource(Rez.Strings.AppName) as String});
        var inv = false;
        try {
            var v = Application.Properties.getValue("invert");
            if (v instanceof Boolean) { inv = v as Boolean; }
            else if (v instanceof Number) { inv = (v as Number) != 0; }
        } catch (e) {}
        menu.addItem(new WatchUi.ToggleMenuItem(
            WatchUi.loadResource(Rez.Strings.InvertTitle) as String,
            WatchUi.loadResource(Rez.Strings.InvertHint) as String,
            "invert",
            inv,
            null
        ));
        return [menu, new TacticalSettingsDelegate()];
    }
}
