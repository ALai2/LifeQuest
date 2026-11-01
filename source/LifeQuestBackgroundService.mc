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

        var sport = activity[:sport];
        var subSport = null;
        if (activity hasKey :subSport) {
            subSport = activity[:subSport];
        }

        var activityType = activityForSport(sport, subSport);
        if (activityType != null) {
            state.completeWorkoutQuestForActivity(activityType);
        }

        state.save();
        Background.exit(null);
    }

    function activityForSport(sport as Activity.Sport, subSport as Object or Null) as Symbol or Null {
        if (sport == Activity.SPORT_RUNNING) {
            return :running;
        } else if (sport == Activity.SPORT_CYCLING) {
            return :cycling;
        } else if (sport == Activity.SPORT_SWIMMING) {
            return :swimming;
        } else if (sport == Activity.SPORT_TRAINING) {
            if (subSport != null) {
                if (subSport == Activity.SUB_SPORT_STRENGTH_TRAINING) {
                    return :strength;
                } else if (subSport == Activity.SUB_SPORT_YOGA || subSport == Activity.SUB_SPORT_PILATES) {
                    return :yoga;
                } else if (subSport == Activity.SUB_SPORT_CARDIO_TRAINING || subSport == Activity.SUB_SPORT_HIIT) {
                    return :cardio;
                }
            }
            return :strength;
        } else if (sport == Activity.SPORT_FITNESS_EQUIPMENT) {
            return :cardio;
        } else if (sport == Activity.SPORT_WALKING || sport == Activity.SPORT_HIKING) {
            return :walking;
        }
        // Fallback for any other recorded sport (e.g. rowing, sports, martial arts)
        return :generic;
    }
}
