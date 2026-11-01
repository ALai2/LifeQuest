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
        var state = new LifeQuestState();
        state.load();
        state.reconcileDay();

        var activityType = activityForSport(activity[:sport]);
        if (activityType != null) {
            state.completeWorkoutQuestForActivity(activityType);
        }

        state.save();
        Background.exit(null);
    }

    function activityForSport(sport as Activity.Sport) as Symbol or Null {
        if (sport == Activity.SPORT_RUNNING) {
            return :running;
        } else if (sport == Activity.SPORT_CYCLING) {
            return :cycling;
        } else if (sport == Activity.SPORT_SWIMMING) {
            return :swimming;
        }
        return null;
    }
}
