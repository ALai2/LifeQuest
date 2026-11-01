import Toybox.Activity;
import Toybox.Lang;

class LifeQuestActivityDetector {
    function sync(state as LifeQuestState) as Void {
        var info = Activity.getActivityInfo();
        if (info == null || info.timerState == null || info.timerTime == null) {
            return;
        }

        var timerStateOn = (Activity has :TIMER_STATE_ON) ? Activity.TIMER_STATE_ON : 3;
        if (info.timerState != timerStateOn) {
            return;
        }

        var profile = Activity.getProfileInfo();
        var activity = activityForProfile(profile, info); // Pass info as a reliable fallback
        if (activity == null) {
            return;
        }

        var session = state.data["activitySession"] as Dictionary;
        var timerTime = info.timerTime as Number;
        
        // Safe profileId generation fallback if profile metadata is null
        var profileId = (profile != null && profile.uniqueIdentifier != null) ? profile.uniqueIdentifier : 0;
        var isNewSession = session["profileId"] != profileId
            || timerTime < (session["lastTimerTime"] as Number);

        if (isNewSession) {
            session["profileId"] = profileId;
            session["lastTimerTime"] = 0;
            session["lastDistance"] = 0.0;
            session["workoutAwarded"] = false;
        }

        var previousTimerTime = session["lastTimerTime"] as Number;
        var elapsedDelta = timerTime - previousTimerTime;
        if (elapsedDelta <= 0) {
            return;
        }

        var minutes = elapsedDelta.toFloat() / 60000.0;
        if (activity == :running && info has :elapsedDistance && info.elapsedDistance != null) {
            var distance = info.elapsedDistance;
            state.recordContinuousRun(distance); // Pass directly without double-casting
            session["lastDistance"] = distance;
        }
        
        var averageHeartRate = 0.0;
        var maxHeartRate = 0.0;
        var averageCadence = 0.0;
        var maxCadence = 0.0;
        var averagePower = 0.0;

        if (info has :averageHeartRate && info.averageHeartRate != null) {
            averageHeartRate = (info.averageHeartRate as Number).toFloat();
        }
        if (info has :maxHeartRate && info.maxHeartRate != null) {
            maxHeartRate = (info.maxHeartRate as Number).toFloat();
        }
        if (info has :averageCadence && info.averageCadence != null) {
            averageCadence = (info.averageCadence as Number).toFloat();
        }
        if (info has :maxCadence && info.maxCadence != null) {
            maxCadence = (info.maxCadence as Number).toFloat();
        }
        if (info has :averagePower && info.averagePower != null) {
            averagePower = (info.averagePower as Number).toFloat();
        }

        // 1. Live real-time stream processing loop (awards XP ticks continuously)
        state.awardActivityMetrics(activity, minutes, averageHeartRate,
            maxHeartRate, averageCadence, maxCadence, averagePower);

        // 2. Threshold execution milestone (runs exactly once at 10 minutes)
        if (!(session["workoutAwarded"] as Boolean) && timerTime >= 600000) {
            state.completeWorkoutQuestForActivity(activity);
            session["workoutAwarded"] = true;
        }

        // 3. Penalty Quest escape option: 20-minute workout (1,200,000 ms) of any sport
        if (timerTime >= 1200000) {
            state.recordPenaltyWorkout(activity, (timerTime / 1000).toNumber());
        }

        session["lastTimerTime"] = timerTime;
        state.save();
    }

    function activityForProfile(profile as Activity.ProfileInfo or Null, info as Activity.Info) as Symbol or Null {
        if (info has :sport && info.sport != null) {
            var subSport = (info has :subSport) ? info.subSport : null;
            var stateHelper = getApp().getCharacterState();
            return stateHelper.activitySymbolForSportAndSubSport(info.sport as Activity.Sport, subSport);
        }

        if (profile == null || profile.name == null) {
            return :cardio;
        }

        var name = profile.name.toLower();
        if (name.find("run") != null) {
            return :running;
        } else if (name.find("cycl") != null || name.find("bike") != null) {
            return :cycling;
        } else if (name.find("swim") != null) {
            return :swimming;
        } else if (name.find("hiit") != null) {
            return :hiit;
        } else if (name.find("climb") != null || name.find("boulder") != null) {
            return :climbing;
        } else if (name.find("row") != null || name.find("kayak") != null || name.find("paddl") != null) {
            return :rowing;
        } else if (name.find("tennis") != null || name.find("pickle") != null || name.find("badminton") != null || name.find("squash") != null) {
            return :racquet;
        } else if (name.find("box") != null || name.find("mma") != null || name.find("martial") != null) {
            return :martial_arts;
        } else if (name.find("ski") != null || name.find("snow") != null || name.find("skate") != null) {
            return :winter_sport;
        } else if (name.find("surf") != null || name.find("wake") != null) {
            return :board_sport;
        } else if (name.find("pilates") != null || name.find("core") != null) {
            return :pilates;
        } else if (name.find("yoga") != null || name.find("stretch") != null) {
            return :yoga;
        } else if (name.find("meditat") != null || name.find("breath") != null) {
            return :mindfulness;
        } else if (name.find("hike") != null || name.find("ruck") != null) {
            return :hiking;
        } else if (name.find("walk") != null) {
            return :walking;
        } else if (name.find("golf") != null) {
            return :golf;
        } else if (name.find("dance") != null) {
            return :dance;
        } else if (name.find("strength") != null || name.find("weight") != null || name.find("lift") != null) {
            return :strength;
        }
        return :cardio;
    }
}
