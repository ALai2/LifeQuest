import Toybox.Lang;
import Toybox.Graphics;
import Toybox.WatchUi;

class LifeQuestDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(),
            new LifeQuestMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }

    function onNextPage() as Boolean {
        getApp().nextPage();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() as Boolean {
        getApp().previousPage();
        WatchUi.requestUpdate();
        return true;
    }
}

class LifeQuestMenuDelegate extends WatchUi.MenuInputDelegate {
    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :reading_5) {
            logReading(5);
        } else if (item == :reading_10) {
            logReading(10);
        } else if (item == :reading_20) {
            logReading(20);
        } else if (item == :log_reading) {
            openReadingPicker();
        }
    }

    function logReading(minutes as Number) as Void {
        var state = getApp().getCharacterState();
        state.recordReading(minutes);
    }

    function openReadingPicker() as Void {
        var picker = new WatchUi.Picker({
            :title => new WatchUi.Text({
                :text => "Minutes",
                :font => Graphics.FONT_SMALL,
                :locX => 0,
                :locY => 0
            }),
            :pattern => [ new LifeQuestMinutePickerFactory() ],
            :defaults => [ 1 ]
        });
        WatchUi.pushView(picker, new LifeQuestReadingPickerDelegate(),
            WatchUi.SLIDE_UP);
    }
}

class LifeQuestMinutePickerFactory extends WatchUi.PickerFactory {
    function initialize() {
        PickerFactory.initialize();
    }

    function getSize() as Number {
        return 24;
    }

    function getValue(item as Number) as Object or Null {
        return (item + 1) * 5;
    }

    function getDrawable(item as Number,
        isSelected as Boolean) as WatchUi.Drawable or Null {
        return new WatchUi.Text({
            :text => ((item + 1) * 5).toString(),
            :font => Graphics.FONT_MEDIUM,
            :locX => 0,
            :locY => 0,
            :justification => Graphics.TEXT_JUSTIFY_CENTER
        });
    }
}

class LifeQuestReadingPickerDelegate extends WatchUi.PickerDelegate {
    function initialize() {
        PickerDelegate.initialize();
    }

    function onAccept(values as Array) as Boolean {
        var minutes = values[0] as Number;
        var state = getApp().getCharacterState();
        state.recordReading(minutes);
        return true;
    }

    function onCancel() as Boolean {
        return true;
    }
}
