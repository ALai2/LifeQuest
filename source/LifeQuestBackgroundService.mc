import Toybox.Activity;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

(:background)
class LifeQuestBackgroundService extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onActivityCompleted(activity as {
        :sport as Activity.Sport,
        :subSport as Activity.SubSport
    }) as Void {
        var payload = {
            "sport" => activity[:sport],
            "subSport" => activity[:subSport]
        };
        Background.exit(payload);
    }
}
