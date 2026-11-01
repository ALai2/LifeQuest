import Toybox.Application;
import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Math;

class LifeQuestState {
    const STORAGE_KEY = "lifeQuestState";
    const SCHEMA_VERSION = 4;

    var data as Dictionary;

    function initialize() {
        data = {
            "schemaVersion" => SCHEMA_VERSION,
            "lastDay" => -1,
            "lastSleepDay" => -1,
            "characterLevel" => 1,
            "characterXp" => 0.0,
            "fatigue" => newFatigueState(),
            "activitySession" => newActivitySession(),
            "stats" => {
                "STR" => newStat(),
                "INT" => newStat(),
                "AGI" => newStat(),
                "VIT" => newStat(),
                "PER" => newStat()
            },
            "quests" => newQuestState()
        };
    }

    function load() as Void {
        var saved = Application.Storage.getValue(STORAGE_KEY);
        if (saved != null && saved.hasKey("stats") && saved.hasKey("quests")) {
            data = saved as Dictionary;
            if (!data.hasKey("fatigue")) {
                data["fatigue"] = newFatigueState();
            }
            if (!data.hasKey("lastSleepDay")) {
                data["lastSleepDay"] = -1;
            }
            if (!data.hasKey("activitySession")) {
                data["activitySession"] = newActivitySession();
            }
            if (!data.hasKey("characterLevel")) {
                data["characterLevel"] = 1;
                data["characterXp"] = 0.0;
            }
            var savedQuests = data["quests"] as Dictionary;
            if (!savedQuests.hasKey("readingMinutes")) {
                savedQuests["readingMinutes"] = 0;
            }
        }
    }

    function save() as Void {
        Application.Storage.setValue(STORAGE_KEY, data);
    }

    function reconcileDay() as Void {
        var currentDay = currentDayKey();
        var lastDay = data["lastDay"] as Number;

        if (lastDay == -1) {
            data["lastDay"] = currentDay;
            save();
            return;
        }

        if (currentDay == lastDay) {
            return;
        }

        var quests = data["quests"] as Dictionary;

        var missed = !isQuestComplete(quests["stepsComplete"] as Boolean,
            quests["readingComplete"] as Boolean,
            quests["workoutComplete"] as Boolean);

        var nextQuests = newQuestState();
        nextQuests["penaltyActive"] = missed;
        data["quests"] = nextQuests;
        data["fatigue"] = fatigueForMissedQuests(quests);
        data["lastDay"] = currentDay;
        save();
    }

    function addXp(statId as Symbol, amount as Float) as Void {
        if (amount <= 0) {
            return;
        }

        var stats = data["stats"] as Dictionary;
        var stat = stats[statKey(statId)] as Dictionary;
        var xp = stat["xp"] as Float;
        var level = stat["level"] as Number;
        var earnedXp = amount * fatigueMultiplier(statId);
        xp += earnedXp;
        addCharacterXp(earnedXp);

        var required = nextLevelXp(level);
        while (xp >= required) {
            xp -= required;
            level += 1;
            required = nextLevelXp(level);
        }

        stat["xp"] = xp;
        stat["level"] = level;
        stat["value"] = level.toFloat();
        save();
    }

    function awardQuestXp(statId as Symbol, amount as Float) as Void {
        addXp(statId, amount);
    }

    function totalLevel() as Number {
        return data["characterLevel"] as Number;
    }

    function characterXp() as Float {
        return data["characterXp"] as Float;
    }

    function characterNextLevelXp() as Float {
        return nextLevelXp(totalLevel());
    }

    function rank() as String {
        var level = totalLevel();
        if (level <= 10) {
            return "F";
        } else if (level <= 20) {
            return "E";
        } else if (level <= 35) {
            return "D";
        } else if (level <= 50) {
            return "C";
        } else if (level <= 70) {
            return "B";
        } else if (level <= 100) {
            return "A";
        } else if (level <= 150) {
            return "S";
        } else if (level <= 250) {
            return "SS";
        }
        return "SSS";
    }

    function completeStepsQuest() as Void {
        var quests = data["quests"] as Dictionary;
        if (quests["stepsComplete"] as Boolean) {
            return;
        }
        quests["stepsComplete"] = true;
        addXp(:VIT, 10.0);
        addXp(:AGI, 10.0);
        save();
    }

    function currentSteps() as Number {
        var info = ActivityMonitor.getInfo();
        if (info != null && info has :steps && info.steps != null) {
            return info.steps as Number;
        }
        return 0;
    }

    function syncSteps() as Void {
        var quests = data["quests"] as Dictionary;
        if (quests["stepsComplete"] as Boolean) {
            return;
        }
        if (currentSteps() >= 10000) {
            completeStepsQuest();
        }
    }

    function isFatigued(statId as Symbol) as Boolean {
        var fatigue = data["fatigue"] as Dictionary;
        var key = statKey(statId);
        if (fatigue != null && fatigue.hasKey(key) && fatigue[key] as Boolean) {
            return true;
        }
        return false;
    }

    function hasAnyFatigue() as Boolean {
        var fatigue = data["fatigue"] as Dictionary;
        if (fatigue == null) {
            return false;
        }
        var keys = fatigue.keys();
        for (var i = 0; i < keys.size(); i++) {
            if (fatigue[keys[i]] as Boolean) {
                return true;
            }
        }
        return false;
    }

    function completeReadingQuest() as Void {
        var quests = data["quests"] as Dictionary;
        if (quests["readingComplete"] as Boolean) {
            return;
        }
        quests["readingComplete"] = true;
        addXp(:INT, 20.0);
        save();
    }

    function completeWorkoutQuest(workoutStat as Symbol) as Void {
        var quests = data["quests"] as Dictionary;
        if (quests["workoutComplete"] as Boolean) {
            return;
        }
        quests["workoutComplete"] = true;
        addXp(workoutStat, 20.0);
        save();
    }

    function completeWorkoutQuestForActivity(activity as Symbol) as Void {
        var quests = data["quests"] as Dictionary;
        if (quests["workoutComplete"] as Boolean) {
            return;
        }
        quests["workoutComplete"] = true;
        awardActivity(activity, 20.0);
        save();
    }

    function completePenaltyQuest() as Void {
        var quests = data["quests"] as Dictionary;
        if (!(quests["penaltyActive"] as Boolean)) {
            return;
        }
        quests["penaltyComplete"] = true;
        save();
    }

    function recordContinuousRun(distanceMeters as Float) as Void {
        var quests = data["quests"] as Dictionary;
        if (!(quests["penaltyActive"] as Boolean)
            || (quests["penaltyComplete"] as Boolean)) {
            return;
        }

        if (distanceMeters >= 1609.34) {
            completePenaltyQuest();
        }
    }

    function recordReading(minutes as Number) as Void {
        var quests = data["quests"] as Dictionary;
        var readingMinutes = quests["readingMinutes"] as Number;
        readingMinutes += minutes;
        quests["readingMinutes"] = readingMinutes;
        addXp(:INT, minutes.toFloat() / 10.0);
        if (readingMinutes >= 20 && !(quests["readingComplete"] as Boolean)) {
            completeReadingQuest();
        }
    }

    function readingGoalMinutes() as Number {
        return 20;
    }

    function awardActivity(activity as Symbol, xpPool as Float) as Void {
        if (xpPool <= 0) {
            return;
        }

        if (activity == :running) {
            awardWeighted(xpPool, :VIT, 0.7, :AGI, 0.3);
        } else if (activity == :cycling) {
            awardWeighted(xpPool, :VIT, 0.5, :AGI, 0.3);
            addXp(:STR, xpPool * 0.2);
        } else if (activity == :swimming) {
            awardWeighted(xpPool, :STR, 0.5, :VIT, 0.5);
        } else if (activity == :strength) {
            awardWeighted(xpPool, :STR, 0.8, :VIT, 0.2);
        } else if (activity == :yoga) {
            awardWeighted(xpPool, :AGI, 0.8, :VIT, 0.2);
        } else if (activity == :cardio) {
            awardWeighted(xpPool, :VIT, 0.6, :AGI, 0.4);
        } else if (activity == :walking) {
            awardWeighted(xpPool, :VIT, 0.7, :AGI, 0.3);
        } else {
            awardWeighted(xpPool, :VIT, 0.5, :STR, 0.5);
        }
    }

    function awardActivityMetrics(activity as Symbol,
        durationMinutes as Float,
        averageHeartRate as Float,
        maxHeartRate as Float,
        averageCadence as Float,
        maxCadence as Float,
        averagePower as Float) as Void {
        if (durationMinutes <= 0.0) {
            return;
        }

        var intensityTotal = 0.0;
        var metricCount = 0;

        if (averageHeartRate > 0.0 && maxHeartRate > 0.0) {
            intensityTotal += heartRateIntensity(averageHeartRate / maxHeartRate);
            metricCount += 1;
        }

        if (averageCadence > 0.0) {
            var cadenceTarget = 90.0;
            if (activity == :running) {
                cadenceTarget = 180.0;
            }
            var cadenceIntensity = averageCadence / cadenceTarget;
            if (maxCadence > averageCadence) {
                cadenceIntensity = (cadenceIntensity * 0.8)
                    + ((maxCadence / cadenceTarget) * 0.2);
            }
            intensityTotal += clamp(cadenceIntensity, 0.0, 1.0);
            metricCount += 1;
        }

        if (averagePower > 0.0) {
            intensityTotal += clamp(averagePower / 250.0, 0.0, 1.25);
            metricCount += 1;
        }

        var intensity = 0.5;
        if (metricCount > 0) {
            intensity = intensityTotal / metricCount.toFloat();
        }

        var xpPool = durationMinutes * (0.5 + (0.5 * intensity));
        awardActivity(activity, xpPool);
    }

    function awardSleepScore(score as Float) as Void {
        var boundedScore = score;
        if (boundedScore < 0.0) {
            boundedScore = 0.0;
        } else if (boundedScore > 100.0) {
            boundedScore = 100.0;
        }
        addXp(:PER, (boundedScore / 100.0) * 50.0);
    }

    function syncSleepScore() as Void {
        var info = ActivityMonitor.getInfo();
        if (info == null || !(info has :sleepScore)) {
            return;
        }

        var score = info.sleepScore;
        if (score == null) {
            return;
        }

        var sleepDay = currentDayKey() - 1;
        if ((data["lastSleepDay"] as Number) == sleepDay) {
            return;
        }

        awardSleepScore(score.toFloat());
        data["lastSleepDay"] = sleepDay;
        save();
    }

    function nextLevelXp(level as Number) as Float {
        return (Math.pow(level.toFloat(), 1.5) * 1000.0) as Float;
    }

    function addCharacterXp(amount as Float) as Void {
        var characterXpValue = data["characterXp"] as Float;
        var characterLevelValue = data["characterLevel"] as Number;
        characterXpValue += amount;

        var required = nextLevelXp(characterLevelValue);
        while (characterXpValue >= required) {
            characterXpValue -= required;
            characterLevelValue += 1;
            required = nextLevelXp(characterLevelValue);
        }

        data["characterXp"] = characterXpValue;
        data["characterLevel"] = characterLevelValue;
    }

    function newStat() as Dictionary {
        return {
            "value" => 1.0,
            "xp" => 0.0,
            "level" => 1
        };
    }

    function newQuestState() as Dictionary {
        return {
            "stepsComplete" => false,
            "readingComplete" => false,
            "readingMinutes" => 0,
            "workoutComplete" => false,
            "penaltyActive" => false,
            "penaltyComplete" => false
        };
    }

    function newFatigueState() as Dictionary {
        return {
            "STR" => false,
            "INT" => false,
            "AGI" => false,
            "VIT" => false,
            "PER" => false
        };
    }

    function newActivitySession() as Dictionary {
        return {
            "profileId" => -1,
            "lastTimerTime" => 0,
            "lastDistance" => 0.0,
            "workoutAwarded" => false
        };
    }

    function currentDayKey() as Number {
        return Time.now().value() / 86400;
    }

    function isQuestComplete(stepsComplete as Boolean,
        readingComplete as Boolean,
        workoutComplete as Boolean) as Boolean {
        return stepsComplete && readingComplete && workoutComplete;
    }

    function fatigueMultiplier(statId as Symbol) as Float {
        var fatigue = data["fatigue"] as Dictionary;
        if (fatigue[statKey(statId)] as Boolean) {
            return 0.5;
        }
        return 1.0;
    }

    function fatigueForMissedQuests(quests as Dictionary) as Dictionary {
        var fatigue = newFatigueState();
        if (!(quests["stepsComplete"] as Boolean)) {
            fatigue["VIT"] = true;
            fatigue["AGI"] = true;
        }
        if (!(quests["readingComplete"] as Boolean)) {
            fatigue["INT"] = true;
        }
        if (!(quests["workoutComplete"] as Boolean)) {
            fatigue["STR"] = true;
            fatigue["VIT"] = true;
        }
        return fatigue;
    }

    function statKey(statId as Symbol) as String {
        return statId.toString();
    }

    function awardWeighted(xpPool as Float,
        firstStat as Symbol,
        firstWeight as Float,
        secondStat as Symbol,
        secondWeight as Float) as Void {
        addXp(firstStat, xpPool * firstWeight);
        addXp(secondStat, xpPool * secondWeight);
    }

    function heartRateIntensity(zoneRatio as Float) as Float {
        if (zoneRatio < 0.6) {
            return 0.25;
        } else if (zoneRatio < 0.7) {
            return 0.5;
        } else if (zoneRatio < 0.8) {
            return 0.75;
        } else if (zoneRatio < 0.9) {
            return 1.0;
        }
        return 1.1;
    }

    function clamp(value as Float, minimum as Float, maximum as Float) as Float {
        if (value < minimum) {
            return minimum;
        } else if (value > maximum) {
            return maximum;
        }
        return value;
    }
}
