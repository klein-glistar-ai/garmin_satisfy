import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class TacticalSettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }

    function onSelect(item as MenuItem) as Void {
        if (item instanceof ToggleMenuItem) {
            var t = item as ToggleMenuItem;
            var id = t.getId();
            if ((id instanceof String) && (id as String).equals("invert")) {
                Application.Properties.setValue("invert", t.isEnabled());
                WatchUi.requestUpdate();
            }
        }
    }
}

class TacticalFaceDelegate extends WatchUi.WatchFaceDelegate {
    private var _view as TacticalFaceView;

    function initialize(view as TacticalFaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onPress(clickEvent as WatchUi.ClickEvent) as Boolean {
        var c = clickEvent.getCoordinates();
        if (_view.hitThemeToggle(c[0], c[1])) {
            _view.toggleInvert();
            return true;
        }
        if (_view.hitMetricRows(c[0], c[1])) {
            _view.toggleMetricPage();
            return true;
        }
        return false;
    }

    function onPowerBudgetExceeded(powerInfo as WatchUi.WatchFacePowerInfo) as Void {
        _view.trimForBudget();
    }
}
