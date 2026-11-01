import Toybox.Activity;
import Toybox.Lang;

class LifeQuestActivityDetector {
    function sync(state as LifeQuestState) as Void {
        var info = Activity.getActivityInfo();
        var profile = Activity.getProfileInfo();
        if (info == null || profile == null || info.timerState == null
            || info.timerTime == null) {
            return;
        }

        if (info.timerState != 3) {
            return;
        }

        var activity = activityForProfile(profile);
        if (activity == null) {
            return;
        }

        var session = state.data["activitySession"] as Dictionary;
        var timerTime = info.timerTime as Number;
        var profileId = profile.uniqueIdentifier;
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
        if (activity == :running && info has :elapsedDistance
            && info.elapsedDistance != null) {
            var distance = info.elapsedDistance as Float;
            state.recordContinuousRun(distance);
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

        state.awardActivityMetrics(activity, minutes, averageHeartRate,
            maxHeartRate, averageCadence, maxCadence, averagePower);

        if (!(session["workoutAwarded"] as Boolean)
            && timerTime >= 600000) {
            state.completeWorkoutQuestForActivity(activity);
            session["workoutAwarded"] = true;
        }

        session["lastTimerTime"] = timerTime;
        state.save();
    }

    function activityForProfile(profile as Activity.ProfileInfo) as Symbol or Null {
        var name = profile.name.toLower();
        if (name.find("run") != null) {
            return :running;
        } else if (name.find("cycl") != null || name.find("bike") != null) {
            return :cycling;
        } else if (name.find("swim") != null) {
            return :swimming;
        } else if (name.find("strength") != null || name.find("weight") != null
            || name.find("lift") != null) {
            return :strength;
        } else if (name.find("yoga") != null || name.find("stretch") != null
            || name.find("pilates") != null) {
            return :yoga;
        } else if (name.find("cardio") != null || name.find("hiit") != null
            || name.find("row") != null || name.find("elliptical") != null
            || name.find("stair") != null) {
            return :cardio;
        } else if (name.find("walk") != null || name.find("hike") != null) {
            return :walking;
        }
        return :generic;
    }
}
