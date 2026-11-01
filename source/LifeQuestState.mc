import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.UserProfile;

class LifeQuestState {
    const STORAGE_KEY = "lifeQuestState";
    const SCHEMA_VERSION = 4;
    const GARMIN_EPOCH_OFFSET = 631065600;

    // Reverted back to a standard strict Dictionary to match your view access layers
    var data as Dictionary;

    function initialize() {
        data = {
            "schemaVersion" => SCHEMA_VERSION,
            "lastDay" => -1,
            "lastSleepDay" => -1,
            "lastSleepScore" => 0.0,
            "lastHistoryActivityTime" => 0,
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
            "quests" => newQuestState(),
            "dailyLog" => [] as Array,
            "unlockedTitles" => [] as Array,
            "equippedTitle" => "AUTO",
            "streakDays" => 0,
            "penaltiesCleared" => 0,
            "lastRaidWeek" => -1,
            "weeklyRaidCleared" => false,
            "studyTimerStart" => 0
        };
    }

    function load() as Void {
        var saved = Application.Storage.getValue(STORAGE_KEY);
        if (saved != null && (saved instanceof Dictionary) && saved.hasKey("stats") && saved.hasKey("quests")) {
            data = saved as Dictionary;

            if (!data.hasKey("fatigue") || !(data["fatigue"] instanceof Dictionary)) {
                data["fatigue"] = newFatigueState();
            }
            if (!data.hasKey("lastSleepDay") || !(data["lastSleepDay"] instanceof Number)) {
                data["lastSleepDay"] = -1;
            }
            if (!data.hasKey("lastSleepScore") || (!(data["lastSleepScore"] instanceof Float) && !(data["lastSleepScore"] instanceof Number))) {
                data["lastSleepScore"] = 0.0;
            }
            if (!data.hasKey("lastHistoryActivityTime") || !(data["lastHistoryActivityTime"] instanceof Number)) {
                data["lastHistoryActivityTime"] = 0;
            }
            if (!data.hasKey("activitySession") || !(data["activitySession"] instanceof Dictionary)) {
                data["activitySession"] = newActivitySession();
            } else {
                var sess = data["activitySession"] as Dictionary;
                if (!sess.hasKey("profileId")) { sess["profileId"] = -1; }
                if (!sess.hasKey("lastTimerTime")) { sess["lastTimerTime"] = 0; }
                if (!sess.hasKey("lastDistance")) { sess["lastDistance"] = 0.0; }
                if (!sess.hasKey("workoutAwarded")) { sess["workoutAwarded"] = false; }
            }
            if (!data.hasKey("characterLevel") || !(data["characterLevel"] instanceof Number)) {
                data["characterLevel"] = 1;
                data["characterXp"] = 0.0;
            }
            if (!data.hasKey("dailyLog") || !(data["dailyLog"] instanceof Array)) {
                data["dailyLog"] = [] as Array;
            }
            if (!data.hasKey("unlockedTitles") || !(data["unlockedTitles"] instanceof Array)) {
                data["unlockedTitles"] = [] as Array;
            }
            if (!data.hasKey("equippedTitle") || !(data["equippedTitle"] instanceof String)) {
                data["equippedTitle"] = "AUTO";
            }
            if (!data.hasKey("streakDays") || !(data["streakDays"] instanceof Number)) {
                data["streakDays"] = 0;
            }
            if (!data.hasKey("penaltiesCleared") || !(data["penaltiesCleared"] instanceof Number)) {
                data["penaltiesCleared"] = 0;
            }
            if (!data.hasKey("lastRaidWeek") || !(data["lastRaidWeek"] instanceof Number)) {
                data["lastRaidWeek"] = -1;
            }
            if (!data.hasKey("weeklyRaidCleared") || !(data["weeklyRaidCleared"] instanceof Boolean)) {
                data["weeklyRaidCleared"] = false;
            }
            if (!data.hasKey("studyTimerStart") || !(data["studyTimerStart"] instanceof Number)) {
                data["studyTimerStart"] = 0;
            }
            checkStatAndLevelTitles();

            if (!(data["quests"] instanceof Dictionary)) {
                data["quests"] = newQuestState();
            } else {
                var savedQuests = data["quests"] as Dictionary;
                if (!savedQuests.hasKey("stepsComplete")) { savedQuests["stepsComplete"] = false; }
                if (!savedQuests.hasKey("readingComplete")) { savedQuests["readingComplete"] = false; }
                if (!savedQuests.hasKey("workoutComplete")) { savedQuests["workoutComplete"] = false; }
                if (!savedQuests.hasKey("penaltyActive")) { savedQuests["penaltyActive"] = false; }
                if (!savedQuests.hasKey("penaltyComplete")) { savedQuests["penaltyComplete"] = false; }
                if (!savedQuests.hasKey("readingMinutes")) { savedQuests["readingMinutes"] = 0; }
                if (!savedQuests.hasKey("readingXpAwarded")) { savedQuests["readingXpAwarded"] = 0.0; }
            }
        } else {
            initialize();
        }
    }

    function save() as Void {
        if (data != null) {
            Application.Storage.setValue(STORAGE_KEY, data);
            updateGlanceCache();
        }
    }

    function updateGlanceCache() as Void {
        if (data == null || !data.hasKey("quests")) {
            return;
        }
        var quests = data["quests"] as Dictionary;
        var currentLvl = totalLevel();
        var currentXp = characterXp();
        var nextXp = characterNextLevelXp();
        var pct = (nextXp > 0.0) ? (currentXp / nextXp) : 0.0;
        if (pct < 0.0) { pct = 0.0; }
        if (pct > 1.0) { pct = 1.0; }

        var penaltyActive = (quests["penaltyActive"] as Boolean) && !(quests["penaltyComplete"] as Boolean);
        var actTitle = activeTitle();
        var summary = {
            "lvl"    => currentLvl,
            "rank"   => rank(),
            "title"  => actTitle,
            "tColor" => titleColorFor(actTitle),
            "xpPct"  => pct,
            "steps"  => quests["stepsComplete"] as Boolean,
            "read"   => quests["readingComplete"] as Boolean,
            "wkt"    => quests["workoutComplete"] as Boolean,
            "alert"  => penaltyActive
        };
        Application.Storage.setValue("glanceSummary", summary);
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
        var daysElapsed = currentDay - lastDay;

        // If >1 day elapsed, the intervening day(s) had no completed quests
        var effectiveQuests = (daysElapsed > 1) ? newQuestState() : quests;
        var missed = !isQuestComplete(effectiveQuests["stepsComplete"] as Boolean,
            effectiveQuests["readingComplete"] as Boolean,
            effectiveQuests["workoutComplete"] as Boolean);

        var prevStreak = data.hasKey("streakDays") ? (data["streakDays"] as Number) : 0;
        if (!missed && daysElapsed == 1) {
            prevStreak += 1;
            data["streakDays"] = prevStreak;
            if (prevStreak >= 7) {
                unlockTitle("UNSTOPPABLE");
            }
        } else {
            data["streakDays"] = 0;
        }

        var nextQuests = newQuestState();
        nextQuests["penaltyActive"] = missed;
        data["quests"] = nextQuests;
        data["fatigue"] = fatigueForMissedQuests(effectiveQuests);
        data["lastDay"] = currentDay;
        data["dailyLog"] = [] as Array;
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
        var earnedXp = amount * fatigueMultiplier(statId) * titleBuffMultiplier(statId);
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
        checkStatAndLevelTitles();
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

    function hunterTitle() as String {
        var level = totalLevel();
        if (level <= 10) {
            return "NOVICE";
        } else if (level <= 20) {
            return "APPRENTICE";
        } else if (level <= 35) {
            return "ADVENTURER";
        } else if (level <= 50) {
            return "WARRIOR";
        } else if (level <= 70) {
            return "KNIGHT";
        } else if (level <= 100) {
            return "CHAMPION";
        } else if (level <= 150) {
            return "HERO";
        } else if (level <= 250) {
            return "LEGEND";
        }
        return "MYTHIC";
    }

    function activeTitle() as String {
        if (data.hasKey("equippedTitle") && (data["equippedTitle"] instanceof String)) {
            var eq = data["equippedTitle"] as String;
            if (!eq.equals("AUTO") && eq.length() > 0 && isTitleUnlocked(eq)) {
                return eq;
            }
        }
        return hunterTitle();
    }

    function equipTitle(titleName as String) as Void {
        if (titleName.equals("AUTO") || isTitleUnlocked(titleName)) {
            data["equippedTitle"] = titleName;
            save();
        }
    }

    function isTitleUnlocked(titleName as String) as Boolean {
        if (!data.hasKey("unlockedTitles") || !(data["unlockedTitles"] instanceof Array)) {
            return false;
        }
        var unlocked = data["unlockedTitles"] as Array;
        for (var i = 0; i < unlocked.size(); i++) {
            if (unlocked[i].toString().equals(titleName)) {
                return true;
            }
        }
        return false;
    }

    function unlockTitle(titleName as String) as Void {
        if (isTitleUnlocked(titleName)) {
            return;
        }
        if (!data.hasKey("unlockedTitles") || !(data["unlockedTitles"] instanceof Array)) {
            data["unlockedTitles"] = [] as Array;
        }
        var unlocked = data["unlockedTitles"] as Array;
        unlocked.add(titleName);
        logDailyActivity("Title: " + titleName);
        save();
    }

    function getAllAchievementTitles() as Array {
        return [
            { "id" => "CAPED BALDY",    "buff" => "+7% AGI/VIT", "hint" => "10km Run",     "color" => 0x00FF66 }, // AGI/VIT
            { "id" => "SHADOW MONARCH", "buff" => "+7% STR/AGI", "hint" => "9PM+ Wkt",     "color" => 0xCC66FF }, // STR/AGI
            { "id" => "OVER 9000!",     "buff" => "+5% ALL",     "hint" => "Total LV.10",  "color" => 0xFFD700 }, // All Stats
            { "id" => "SURVIVOR",       "buff" => "+7% VIT/STR", "hint" => "Clr Penalty",  "color" => 0xFFD700 }, // VIT/STR
            { "id" => "SAGE",           "buff" => "+7% INT/PER", "hint" => "Read 60m/Day", "color" => 0x00D9FF }, // INT/PER
            { "id" => "WELL RESTED",    "buff" => "+10% PER",    "hint" => "Sleep >= 90",  "color" => 0xFF3333 }, // PER
            { "id" => "UNSTOPPABLE",    "buff" => "+5% ALL",     "hint" => "7-Day Streak", "color" => 0xFFD700 }, // All Stats
            { "id" => "IRON BODY",      "buff" => "+10% STR",    "hint" => "STR LV.10",    "color" => 0xFF9900 }, // STR
            { "id" => "WINDRUNNER",     "buff" => "+10% AGI",    "hint" => "AGI LV.10",    "color" => 0x00FF66 }, // AGI
            { "id" => "ARCHMAGE",       "buff" => "+10% INT",    "hint" => "INT LV.10",    "color" => 0x00D9FF }, // INT
            { "id" => "RAID SLAYER",    "buff" => "+5% ALL",     "hint" => "Weekly Raid",  "color" => 0xCC66FF }  // All Stats
        ] as Array;
    }

    function autoRankBuffPercent() as Number {
        var r = rank();
        if (r.equals("SSS")) { return 10; }
        if (r.equals("SS"))  { return 8; }
        if (r.equals("S"))   { return 7; }
        if (r.equals("A"))   { return 6; }
        if (r.equals("B"))   { return 5; }
        if (r.equals("C"))   { return 4; }
        if (r.equals("D"))   { return 3; }
        return 2; // F & E Rank
    }

    function titleBuffMultiplier(statId as Symbol) as Float {
        var eq = data.hasKey("equippedTitle") ? (data["equippedTitle"] as String) : "AUTO";
        if (eq.equals("AUTO") || !isTitleUnlocked(eq)) {
            return 1.0 + (autoRankBuffPercent().toFloat() / 100.0);
        }

        // 1. All-Stat Milestone / Boss Titles (+5% to ALL 5 stats)
        if (eq.equals("OVER 9000!") || eq.equals("UNSTOPPABLE") || eq.equals("RAID SLAYER")) {
            return 1.05;
        }

        // 2. Dual-Stat Hybrid Titles (+7% to 2 matching stats)
        if (eq.equals("CAPED BALDY") && (statId == :AGI || statId == :VIT)) {
            return 1.07;
        }
        if (eq.equals("SHADOW MONARCH") && (statId == :STR || statId == :AGI)) {
            return 1.07;
        }
        if (eq.equals("SURVIVOR") && (statId == :VIT || statId == :STR)) {
            return 1.07;
        }
        if (eq.equals("SAGE") && (statId == :INT || statId == :PER)) {
            return 1.07;
        }

        // 3. Single-Stat Specialist Titles (+10% to 1 matching stat)
        if (eq.equals("IRON BODY") && statId == :STR) {
            return 1.10;
        }
        if (eq.equals("WINDRUNNER") && statId == :AGI) {
            return 1.10;
        }
        if (eq.equals("ARCHMAGE") && statId == :INT) {
            return 1.10;
        }
        if (eq.equals("WELL RESTED") && statId == :PER) {
            return 1.10;
        }

        return 1.0;
    }

    function titleColorFor(titleName as String) as Number {
        var all = getAllAchievementTitles();
        for (var i = 0; i < all.size(); i++) {
            var item = all[i] as Dictionary;
            if ((item["id"] as String).equals(titleName)) {
                return item["color"] as Number;
            }
        }
        // Fallback to rank color for Auto Rank Titles
        var r = rank();
        if (r.equals("S") || r.equals("SS") || r.equals("SSS")) {
            return 0xFFD700;
        } else if (r.equals("A") || r.equals("B")) {
            return 0xCC66FF;
        } else if (r.equals("C") || r.equals("D")) {
            return 0x00D9FF;
        }
        return 0xFF9900;
    }

    function checkStatAndLevelTitles() as Void {
        if (totalLevel() >= 10) {
            unlockTitle("OVER 9000!");
        }
        var stats = data["stats"] as Dictionary;
        if (((stats["STR"] as Dictionary)["level"] as Number) >= 10) {
            unlockTitle("IRON BODY");
        }
        if (((stats["AGI"] as Dictionary)["level"] as Number) >= 10) {
            unlockTitle("WINDRUNNER");
        }
        if (((stats["INT"] as Dictionary)["level"] as Number) >= 10) {
            unlockTitle("ARCHMAGE");
        }
    }

    function completeStepsQuest() as Void {
        var quests = data["quests"] as Dictionary;
        if (quests["stepsComplete"] as Boolean) {
            return;
        }
        quests["stepsComplete"] = true;
        logDailyActivity("Steps: +5 VIT +5 AGI");
        addXp(:VIT, 5.0);
        addXp(:AGI, 5.0);
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
        var steps = currentSteps();
        if (!(quests["stepsComplete"] as Boolean) && steps >= 10000) {
            completeStepsQuest();
        }
        if (isPenaltyActiveNow() && steps >= 12000) {
            completePenaltyQuest();
            logDailyActivity("Penalty: +5 VIT +5 AGI");
            addXp(:VIT, 5.0);
            addXp(:AGI, 5.0);
            save();
        }
        syncWeeklyRaid();
    }

    function currentWeekKey() as Number {
        // Epoch day 0 (1970-01-01) was a Thursday; +3 aligns week boundaries to Monday 00:00 local time
        return ((currentDayKey() + 3) / 7) as Number;
    }

    function currentWeeklyActiveMinutes() as Number {
        var info = ActivityMonitor.getInfo();
        if (info != null && (info has :activeMinutesWeek) && info.activeMinutesWeek != null) {
            var amw = info.activeMinutesWeek;
            if ((amw has :total) && amw.total != null) {
                return (amw.total as Number);
            }
        }
        return 0;
    }

    function weeklyActiveMinutesGoal() as Number {
        var info = ActivityMonitor.getInfo();
        if (info != null && (info has :activeMinutesWeekGoal) && info.activeMinutesWeekGoal != null) {
            var goal = info.activeMinutesWeekGoal as Number;
            if (goal > 0) {
                return goal;
            }
        }
        return 150;
    }

    function isWeeklyRaidComplete() as Boolean {
        var weekKey = currentWeekKey();
        var savedWeek = data.hasKey("lastRaidWeek") ? (data["lastRaidWeek"] as Number) : -1;
        if (savedWeek != weekKey) {
            return false;
        }
        return data.hasKey("weeklyRaidCleared") ? (data["weeklyRaidCleared"] as Boolean) : false;
    }

    function syncWeeklyRaid() as Void {
        var weekKey = currentWeekKey();
        var savedWeek = data.hasKey("lastRaidWeek") ? (data["lastRaidWeek"] as Number) : -1;
        if (savedWeek != weekKey) {
            data["lastRaidWeek"] = weekKey;
            data["weeklyRaidCleared"] = false;
        }

        if (data["weeklyRaidCleared"] as Boolean) {
            return;
        }

        var currentMins = currentWeeklyActiveMinutes();
        var goalMins = weeklyActiveMinutesGoal();
        if (currentMins >= goalMins && goalMins > 0) {
            data["weeklyRaidCleared"] = true;
            unlockTitle("RAID SLAYER");
            logDailyActivity("Raid: +10 ALL STATS");
            addXp(:STR, 10.0);
            addXp(:AGI, 10.0);
            addXp(:VIT, 10.0);
            addXp(:INT, 10.0);
            addXp(:PER, 10.0);
            save();
        }
    }

    function isPenaltyActiveNow() as Boolean {
        var quests = data["quests"] as Dictionary;
        var isPenaltyActive = quests["penaltyActive"];
        var isPenaltyComplete = quests["penaltyComplete"];
        if (isPenaltyActive == null || !(isPenaltyActive as Boolean)) {
            return false;
        }
        if (isPenaltyComplete != null && (isPenaltyComplete as Boolean)) {
            return false;
        }
        return true;
    }

    function isFatigued(statId as Symbol) as Boolean {
        var fatigue = data["fatigue"];
        if (fatigue == null || !(fatigue instanceof Dictionary)) {
            return false;
        }
        var fatigueDict = fatigue as Dictionary;
        var key = statKey(statId);
        if (fatigueDict.hasKey(key) && (fatigueDict[key] instanceof Boolean)) {
            return fatigueDict[key] as Boolean;
        }
        return false;
    }

    function hasAnyFatigue() as Boolean {
        var fatigue = data["fatigue"];
        if (fatigue == null || !(fatigue instanceof Dictionary)) {
            return false;
        }
        var fatigueDict = fatigue as Dictionary;
        var keys = fatigueDict.keys();
        for (var i = 0; i < keys.size(); i++) {
            var val = fatigueDict[keys[i]];
            if ((val instanceof Boolean) && (val as Boolean)) {
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
        var earned = 20.0 * fatigueMultiplier(:INT) * titleBuffMultiplier(:INT);
        var prevAwarded = quests.hasKey("readingXpAwarded") ? (quests["readingXpAwarded"] as Float) : 0.0;
        quests["readingXpAwarded"] = prevAwarded + earned;
        logDailyActivity("Read: +20 INT");
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
        var hour = System.getClockTime().hour;
        if (hour >= 21 || hour < 4) {
            unlockTitle("SHADOW MONARCH");
        }
        awardActivity(activity, 20.0);
        save();
    }

    function completePenaltyQuest() as Void {
        var quests = data["quests"] as Dictionary;
        var isPenaltyActive = quests["penaltyActive"];
        if (isPenaltyActive == null || !(isPenaltyActive as Boolean)) {
            return;
        }
        quests["penaltyComplete"] = true;
        data["fatigue"] = newFatigueState();
        var cleared = data.hasKey("penaltiesCleared") ? (data["penaltiesCleared"] as Number) : 0;
        data["penaltiesCleared"] = cleared + 1;
        unlockTitle("SURVIVOR");
        save();
    }

    function recordContinuousRun(distanceMeters as Numeric) as Void {
        var dist = distanceMeters.toFloat();
        // One Punch Man Easter Egg: 10km (10,000 meters) run unlocks "CAPED BALDY"
        if (dist >= 10000.0) {
            unlockTitle("CAPED BALDY");
        }

        if (!isPenaltyActiveNow()) {
            return;
        }

        // Option 1: 1.0 Mile Run (1609.34 meters)
        if (dist >= 1609.0) {
            completePenaltyQuest();
            logDailyActivity("Penalty: +5 AGI +5 VIT");
            addXp(:AGI, 5.0);
            addXp(:VIT, 5.0);
            save();
        }
    }

    function recordPenaltyWorkout(activity as Symbol, durationSeconds as Number) as Void {
        if (!isPenaltyActiveNow()) {
            return;
        }

        // Option 2: 20-Minute Workout (1200 seconds, any sport)
        if (durationSeconds >= 1200) {
            completePenaltyQuest();
            logDailyActivity("Penalty: +5 STR +5 VIT");
            addXp(:STR, 5.0);
            addXp(:VIT, 5.0);
            save();
        }
    }

    function recordReading(minutes as Number) as Void {
        if (minutes <= 0) {
            return;
        }
        var quests = data["quests"] as Dictionary;
        var readingMinutes = quests["readingMinutes"] as Number;
        readingMinutes += minutes;
        quests["readingMinutes"] = readingMinutes;

        var baseXp = minutes.toFloat() / 10.0;
        var earned = baseXp * fatigueMultiplier(:INT) * titleBuffMultiplier(:INT);
        var prevAwarded = quests.hasKey("readingXpAwarded") ? (quests["readingXpAwarded"] as Float) : 0.0;
        quests["readingXpAwarded"] = prevAwarded + earned;

        addXp(:INT, baseXp);
        if (readingMinutes >= readingGoalMinutes() && !(quests["readingComplete"] as Boolean)) {
            completeReadingQuest();
        }
        if (readingMinutes >= 60) {
            unlockTitle("SAGE");
        }
        save();
    }

    // Option A: Reset reading minutes AND reverse any INT / character XP awarded from reading today
    function resetReading() as Void {
        var quests = data["quests"] as Dictionary;
        var readingMinutes = quests.hasKey("readingMinutes") ? (quests["readingMinutes"] as Number) : 0;
        var readingComplete = quests.hasKey("readingComplete") ? (quests["readingComplete"] as Boolean) : false;
        var xpToRemove = quests.hasKey("readingXpAwarded") ? (quests["readingXpAwarded"] as Float) : 0.0;

        // Fallback calculation if reading was logged prior to readingXpAwarded tracking
        if (xpToRemove <= 0.0 && (readingMinutes > 0 || readingComplete)) {
            var baseFallback = (readingMinutes.toFloat() / 10.0) + (readingComplete ? 20.0 : 0.0);
            xpToRemove = baseFallback * fatigueMultiplier(:INT);
        }

        if (xpToRemove > 0.0) {
            removeXp(:INT, xpToRemove);
        }

        quests["readingMinutes"] = 0;
        quests["readingComplete"] = false;
        quests["readingXpAwarded"] = 0.0;

        // Remove "Read:" / "Reading:" entry from today's dailyLog if present
        if (data.hasKey("dailyLog") && (data["dailyLog"] instanceof Array)) {
            var oldLog = data["dailyLog"] as Array;
            var newLog = [] as Array;
            for (var i = 0; i < oldLog.size(); i++) {
                var item = oldLog[i].toString();
                if (item.find("Read:") == null && item.find("Reading:") == null) {
                    newLog.add(item);
                }
            }
            data["dailyLog"] = newLog;
        }

        save();
    }

    function removeXp(statId as Symbol, amount as Float) as Void {
        if (amount <= 0.0) {
            return;
        }
        var stats = data["stats"] as Dictionary;
        var stat = stats[statKey(statId)] as Dictionary;
        var xp = (stat["xp"] as Numeric).toFloat() - amount;
        var level = stat["level"] as Number;

        while (xp < 0.0 && level > 1) {
            level -= 1;
            xp += nextLevelXp(level);
        }
        if (xp < 0.0) {
            xp = 0.0;
        }

        stat["xp"] = xp;
        stat["level"] = level;
        stat["value"] = level.toFloat();

        removeCharacterXp(amount);
    }

    function removeCharacterXp(amount as Float) as Void {
        if (amount <= 0.0) {
            return;
        }
        var characterXpValue = (data["characterXp"] as Numeric).toFloat() - amount;
        var characterLevelValue = data["characterLevel"] as Number;

        while (characterXpValue < 0.0 && characterLevelValue > 1) {
            characterLevelValue -= 1;
            characterXpValue += nextLevelXp(characterLevelValue);
        }
        if (characterXpValue < 0.0) {
            characterXpValue = 0.0;
        }

        data["characterXp"] = characterXpValue;
        data["characterLevel"] = characterLevelValue;
    }

    function readingGoalMinutes() as Number {
        if (Application has :Properties) {
            try {
                var customGoal = Application.Properties.getValue("dailyReadingGoal");
                if (customGoal != null && (customGoal instanceof Number) && (customGoal as Number) >= 5) {
                    return customGoal as Number;
                }
            } catch (e) {
                // Fallback to 20 min default
            }
        }
        return 20;
    }

    function syncExternalSettings() as Void {
        if (!(Application has :Properties)) {
            return;
        }
        try {
            var extMins = Application.Properties.getValue("externalStudyMinutes");
            if (extMins != null && (extMins instanceof Number) && (extMins as Number) > 0) {
                var mins = extMins as Number;
                Application.Properties.setValue("externalStudyMinutes", 0);
                recordReading(mins);
            }
        } catch (e) {
            // Safely ignore if property not present
        }
    }

    function syncCompletedActivities() as Void {
        if (!(Toybox has :UserProfile) || !(UserProfile has :getUserActivityHistory)) {
            return;
        }

        var iter = UserProfile.getUserActivityHistory();
        if (iter == null) {
            return;
        }

        var clock = System.getClockTime();
        var tzOffset = clock.timeZoneOffset + clock.dst;
        var currentDay = currentDayKey();
        var lastDay = data.hasKey("lastDay") ? (data["lastDay"] as Number) : -1;
        var lastProcessedTime = data.hasKey("lastHistoryActivityTime")
            ? (data["lastHistoryActivityTime"] as Number)
            : 0;
        var maxProcessedTime = lastProcessedTime;
        var quests = data["quests"] as Dictionary;

        var sample = iter.next();
        while (sample != null) {
            if (sample.startTime != null && sample.type != null) {
                var rawTime = sample.startTime.value();
                // Normalize Garmin epoch (seconds since 1989-12-31) to Unix epoch if needed
                var normTime = (rawTime < 1400000000) ? (rawTime + GARMIN_EPOCH_OFFSET) : rawTime;
                var sampleDay = ((normTime + tzOffset) / 86400) as Number;

                // Match activities for active ledger day (or yesterday before reconcileDay rolls over)
                var isActiveLedgerDay = (sampleDay == currentDay)
                    || (lastDay != -1 && sampleDay == lastDay && normTime > lastProcessedTime);

                if (isActiveLedgerDay) {
                    var actSymbol = activitySymbolForSport(sample.type as Activity.Sport);
                    var durationSec = (sample.duration != null) ? sample.duration.value() : 0;
                    var distanceMeters = (sample.distance != null) ? sample.distance.toFloat() : 0.0;

                    // Check penalty clearance for any run >= 1.0 mile or workout >= 20 mins on the active ledger day
                    if (actSymbol == :running && distanceMeters > 0.0) {
                        recordContinuousRun(distanceMeters);
                    }
                    if (durationSec >= 1200) {
                        recordPenaltyWorkout(actSymbol, durationSec);
                    }

                    // Ensure daily workout quest is marked complete for any workout >= 5 mins
                    if (!(quests["workoutComplete"] as Boolean) && durationSec >= 300) {
                        completeWorkoutQuestForActivity(actSymbol);
                    }

                    // Check Night Workout title ("SHADOW MONARCH") for any workout >= 5 mins started 9 PM - 4 AM local time
                    if (durationSec >= 300) {
                        var localSecOfDay = ((normTime + tzOffset) % 86400);
                        if (localSecOfDay < 0) { localSecOfDay += 86400; }
                        var localHour = (localSecOfDay / 3600).toNumber();
                        if (localHour >= 21 || localHour < 4) {
                            unlockTitle("SHADOW MONARCH");
                        }
                    }

                    // Award duration XP and log once per new completed activity
                    if (normTime > lastProcessedTime && durationSec > 0) {
                        var durationMin = durationSec.toFloat() / 60.0;
                        var xpPool = durationMin * 0.75;
                        logActivitySummary(actSymbol, xpPool);
                        awardActivity(actSymbol, xpPool);
                        if (normTime > maxProcessedTime) {
                            maxProcessedTime = normTime;
                        }
                    }
                }
            }
            sample = iter.next();
        }

        if (maxProcessedTime > lastProcessedTime) {
            data["lastHistoryActivityTime"] = maxProcessedTime;
            save();
        }
    }

    // Phase 4: 20+ Sport Dynamic Stat Distribution Engine
    function activitySymbolForSport(sport as Activity.Sport) as Symbol {
        return activitySymbolForSportAndSubSport(sport, null);
    }

    function activitySymbolForSportAndSubSport(sport as Activity.Sport, subSport as Activity.SubSport or Null) as Symbol {
        // 1. Check SubSport specialization first when available (e.g. under SPORT_TRAINING or SPORT_FITNESS_EQUIPMENT)
        if (subSport != null) {
            if ((Activity has :SUB_SPORT_YOGA && subSport == Activity.SUB_SPORT_YOGA)) {
                return :yoga;
            }
            if ((Activity has :SUB_SPORT_PILATES && subSport == Activity.SUB_SPORT_PILATES)) {
                return :pilates;
            }
            if ((Activity has :SUB_SPORT_BREATHWORKS && subSport == Activity.SUB_SPORT_BREATHWORKS)
                || (Activity has :SUB_SPORT_MEDITATION && subSport == Activity.SUB_SPORT_MEDITATION)) {
                return :mindfulness;
            }
            if ((Activity has :SUB_SPORT_STRENGTH_TRAINING && subSport == Activity.SUB_SPORT_STRENGTH_TRAINING)) {
                return :strength;
            }
            if ((Activity has :SUB_SPORT_HIIT && subSport == Activity.SUB_SPORT_HIIT)) {
                return :hiit;
            }
            if ((Activity has :SUB_SPORT_INDOOR_ROWING && subSport == Activity.SUB_SPORT_INDOOR_ROWING)) {
                return :rowing;
            }
            if ((Activity has :SUB_SPORT_INDOOR_CLIMBING && subSport == Activity.SUB_SPORT_INDOOR_CLIMBING)
                || (Activity has :SUB_SPORT_BOULDERING && subSport == Activity.SUB_SPORT_BOULDERING)) {
                return :climbing;
            }
            if ((Activity has :SUB_SPORT_PICKLEBALL && subSport == Activity.SUB_SPORT_PICKLEBALL)
                || (Activity has :SUB_SPORT_PADEL && subSport == Activity.SUB_SPORT_PADEL)
                || (Activity has :SUB_SPORT_SQUASH && subSport == Activity.SUB_SPORT_SQUASH)
                || (Activity has :SUB_SPORT_BADMINTON && subSport == Activity.SUB_SPORT_BADMINTON)
                || (Activity has :SUB_SPORT_TABLE_TENNIS && subSport == Activity.SUB_SPORT_TABLE_TENNIS)) {
                return :racquet;
            }
            if ((Activity has :SUB_SPORT_CARDIO_TRAINING && subSport == Activity.SUB_SPORT_CARDIO_TRAINING)
                || (Activity has :SUB_SPORT_ELLIPTICAL && subSport == Activity.SUB_SPORT_ELLIPTICAL)
                || (Activity has :SUB_SPORT_STAIR_CLIMBING && subSport == Activity.SUB_SPORT_STAIR_CLIMBING)) {
                return :cardio;
            }
        }

        // 2. Primary Sport Classification across 20+ Garmin Sport Types
        if (sport == 43 || (Activity has :SPORT_YOGA && sport == Activity.SPORT_YOGA)) {
            return :yoga;
        } else if (Activity has :SPORT_PILATES && sport == Activity.SPORT_PILATES) {
            return :pilates;
        } else if ((Activity has :SPORT_MEDITATION && sport == Activity.SPORT_MEDITATION)
            || (Activity has :SPORT_BREATHWORK && sport == Activity.SPORT_BREATHWORK)) {
            return :mindfulness;
        } else if (sport == Activity.SPORT_RUNNING) {
            return :running;
        } else if (sport == Activity.SPORT_CYCLING) {
            return :cycling;
        } else if (sport == Activity.SPORT_SWIMMING) {
            return :swimming;
        } else if (Activity has :SPORT_HIKING && sport == Activity.SPORT_HIKING) {
            return :hiking;
        } else if (Activity has :SPORT_WALKING && sport == Activity.SPORT_WALKING) {
            return :walking;
        } else if (Activity has :SPORT_HIIT && sport == Activity.SPORT_HIIT) {
            return :hiit;
        } else if ((Activity has :SPORT_ROCK_CLIMBING && sport == Activity.SPORT_ROCK_CLIMBING)
            || (Activity has :SPORT_MOUNTAINEERING && sport == Activity.SPORT_MOUNTAINEERING)) {
            return :climbing;
        } else if ((Activity has :SPORT_ROWING && sport == Activity.SPORT_ROWING)
            || (Activity has :SPORT_KAYAKING && sport == Activity.SPORT_KAYAKING)
            || (Activity has :SPORT_PADDLING && sport == Activity.SPORT_PADDLING)
            || (Activity has :SPORT_STAND_UP_PADDLEBOARDING && sport == Activity.SPORT_STAND_UP_PADDLEBOARDING)) {
            return :rowing;
        } else if ((Activity has :SPORT_TENNIS && sport == Activity.SPORT_TENNIS)
            || (Activity has :SPORT_RACKET && sport == Activity.SPORT_RACKET)) {
            return :racquet;
        } else if ((Activity has :SPORT_BASKETBALL && sport == Activity.SPORT_BASKETBALL)
            || (Activity has :SPORT_SOCCER && sport == Activity.SPORT_SOCCER)
            || (Activity has :SPORT_VOLLEYBALL && sport == Activity.SPORT_VOLLEYBALL)
            || (Activity has :SPORT_AMERICAN_FOOTBALL && sport == Activity.SPORT_AMERICAN_FOOTBALL)
            || (Activity has :SPORT_ICE_HOCKEY && sport == Activity.SPORT_ICE_HOCKEY)
            || (Activity has :SPORT_FIELD_HOCKEY && sport == Activity.SPORT_FIELD_HOCKEY)
            || (Activity has :SPORT_RUGBY && sport == Activity.SPORT_RUGBY)
            || (Activity has :SPORT_LACROSSE && sport == Activity.SPORT_LACROSSE)
            || (Activity has :SPORT_ULTIMATE_DISC && sport == Activity.SPORT_ULTIMATE_DISC)
            || (Activity has :SPORT_BASEBALL && sport == Activity.SPORT_BASEBALL)
            || (Activity has :SPORT_SOFTBALL && sport == Activity.SPORT_SOFTBALL)) {
            return :team_sport;
        } else if ((Activity has :SPORT_BOXING && sport == Activity.SPORT_BOXING)
            || (Activity has :SPORT_MMA && sport == Activity.SPORT_MMA)
            || (Activity has :SPORT_MARTIAL_ARTS && sport == Activity.SPORT_MARTIAL_ARTS)) {
            return :martial_arts;
        } else if ((Activity has :SPORT_ALPINE_SKIING && sport == Activity.SPORT_ALPINE_SKIING)
            || (Activity has :SPORT_SNOWBOARDING && sport == Activity.SPORT_SNOWBOARDING)
            || (Activity has :SPORT_CROSS_COUNTRY_SKIING && sport == Activity.SPORT_CROSS_COUNTRY_SKIING)
            || (Activity has :SPORT_SNOWSHOEING && sport == Activity.SPORT_SNOWSHOEING)
            || (Activity has :SPORT_ICE_SKATING && sport == Activity.SPORT_ICE_SKATING)) {
            return :winter_sport;
        } else if ((Activity has :SPORT_SURFING && sport == Activity.SPORT_SURFING)
            || (Activity has :SPORT_WINDSURFING && sport == Activity.SPORT_WINDSURFING)
            || (Activity has :SPORT_KITESURFING && sport == Activity.SPORT_KITESURFING)
            || (Activity has :SPORT_WAKEBOARDING && sport == Activity.SPORT_WAKEBOARDING)
            || (Activity has :SPORT_WATER_SKIING && sport == Activity.SPORT_WATER_SKIING)) {
            return :board_sport;
        } else if ((Activity has :SPORT_GOLF && sport == Activity.SPORT_GOLF)
            || (Activity has :SPORT_DISC_GOLF && sport == Activity.SPORT_DISC_GOLF)) {
            return :golf;
        } else if (Activity has :SPORT_DANCE && sport == Activity.SPORT_DANCE) {
            return :dance;
        } else if ((Activity has :SPORT_WEIGHT_TRAINING && sport == Activity.SPORT_WEIGHT_TRAINING)
            || (Activity has :SPORT_TRAINING && sport == Activity.SPORT_TRAINING)
            || (Activity has :SPORT_FITNESS_EQUIPMENT && sport == Activity.SPORT_FITNESS_EQUIPMENT)) {
            return :strength;
        }
        return :cardio;
    }

    function getActivityConfig(activity as Symbol) as Dictionary {
        if (activity == :running) {
            return { "label" => "Run",   "s1" => :VIT, "w1" => 0.7, "s2" => :AGI, "w2" => 0.3 };
        } else if (activity == :cycling) {
            return { "label" => "Bike",  "s1" => :VIT, "w1" => 0.5, "s2" => :AGI, "w2" => 0.3, "s3" => :STR, "w3" => 0.2 };
        } else if (activity == :swimming) {
            return { "label" => "Swim",  "s1" => :STR, "w1" => 0.5, "s2" => :VIT, "w2" => 0.5 };
        } else if (activity == :strength) {
            return { "label" => "Gym",   "s1" => :STR, "w1" => 0.8, "s2" => :VIT, "w2" => 0.2 };
        } else if (activity == :hiit) {
            return { "label" => "HIIT",  "s1" => :VIT, "w1" => 0.4, "s2" => :STR, "w2" => 0.4, "s3" => :AGI, "w3" => 0.2 };
        } else if (activity == :yoga) {
            return { "label" => "Yoga",  "s1" => :AGI, "w1" => 0.6, "s2" => :PER, "w2" => 0.2, "s3" => :VIT, "w3" => 0.2 };
        } else if (activity == :pilates) {
            return { "label" => "Core",  "s1" => :AGI, "w1" => 0.5, "s2" => :STR, "w2" => 0.3, "s3" => :PER, "w3" => 0.2 };
        } else if (activity == :mindfulness) {
            return { "label" => "Mind",  "s1" => :PER, "w1" => 0.6, "s2" => :INT, "w2" => 0.4 };
        } else if (activity == :climbing) {
            return { "label" => "Climb", "s1" => :STR, "w1" => 0.5, "s2" => :AGI, "w2" => 0.3, "s3" => :PER, "w3" => 0.2 };
        } else if (activity == :rowing) {
            return { "label" => "Row",   "s1" => :STR, "w1" => 0.5, "s2" => :VIT, "w2" => 0.5 };
        } else if (activity == :racquet) {
            return { "label" => "Court", "s1" => :AGI, "w1" => 0.5, "s2" => :PER, "w2" => 0.3, "s3" => :VIT, "w3" => 0.2 };
        } else if (activity == :team_sport) {
            return { "label" => "Sport", "s1" => :AGI, "w1" => 0.5, "s2" => :VIT, "w2" => 0.4, "s3" => :PER, "w3" => 0.1 };
        } else if (activity == :martial_arts) {
            return { "label" => "Fight", "s1" => :STR, "w1" => 0.4, "s2" => :AGI, "w2" => 0.4, "s3" => :PER, "w3" => 0.2 };
        } else if (activity == :winter_sport) {
            return { "label" => "Snow",  "s1" => :AGI, "w1" => 0.4, "s2" => :VIT, "w2" => 0.4, "s3" => :STR, "w3" => 0.2 };
        } else if (activity == :board_sport) {
            return { "label" => "Surf",  "s1" => :AGI, "w1" => 0.6, "s2" => :STR, "w2" => 0.2, "s3" => :PER, "w3" => 0.2 };
        } else if (activity == :hiking) {
            return { "label" => "Hike",  "s1" => :VIT, "w1" => 0.6, "s2" => :STR, "w2" => 0.2, "s3" => :PER, "w3" => 0.2 };
        } else if (activity == :walking) {
            return { "label" => "Walk",  "s1" => :VIT, "w1" => 0.7, "s2" => :AGI, "w2" => 0.3 };
        } else if (activity == :golf) {
            return { "label" => "Golf",  "s1" => :PER, "w1" => 0.5, "s2" => :VIT, "w2" => 0.3, "s3" => :AGI, "w3" => 0.2 };
        } else if (activity == :dance) {
            return { "label" => "Dance", "s1" => :AGI, "w1" => 0.7, "s2" => :VIT, "w2" => 0.3 };
        }
        return { "label" => "Cardio", "s1" => :VIT, "w1" => 0.6, "s2" => :AGI, "w2" => 0.4 };
    }

    function logActivitySummary(activity as Symbol, xpPool as Float) as Void {
        var cfg = getActivityConfig(activity);
        var label = cfg["label"] as String;
        var s1 = cfg["s1"] as Symbol;
        var w1 = cfg["w1"] as Float;
        var s2 = cfg["s2"] as Symbol;
        var w2 = cfg["w2"] as Float;

        var xp1 = (xpPool * w1).toNumber();
        var xp2 = (xpPool * w2).toNumber();
        if (xp1 < 1) { xp1 = 1; }
        if (xp2 < 1) { xp2 = 1; }

        var logText = label + ": +" + xp1.toString() + " " + statKey(s1) + " +" + xp2.toString() + " " + statKey(s2);
        logDailyActivity(logText);
    }

    function awardActivity(activity as Symbol, xpPool as Float) as Void {
        if (xpPool <= 0.0) {
            return;
        }

        var cfg = getActivityConfig(activity);
        addXp(cfg["s1"] as Symbol, xpPool * (cfg["w1"] as Float));
        addXp(cfg["s2"] as Symbol, xpPool * (cfg["w2"] as Float));
        if (cfg.hasKey("s3") && cfg.hasKey("w3")) {
            addXp(cfg["s3"] as Symbol, xpPool * (cfg["w3"] as Float));
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

        var session = data["activitySession"] as Dictionary;
        if (session != null && !(session["workoutAwarded"] as Boolean) && (durationMinutes >= 10.0)) {
            logActivitySummary(activity, xpPool);
        }

        // Award base sport attributes + dynamic biometric bonus (high power -> STR, high cadence -> AGI, Zone 4-5 HR -> VIT)
        awardActivity(activity, xpPool * 0.85);
        var bioPool = xpPool * 0.15;
        if (averagePower >= 220.0) {
            addXp(:STR, bioPool);
        } else if (averageCadence >= 175.0 || (activity != :running && averageCadence >= 95.0)) {
            addXp(:AGI, bioPool);
        } else if (averageHeartRate > 0.0 && maxHeartRate > 0.0 && (averageHeartRate / maxHeartRate) >= 0.82) {
            addXp(:VIT, bioPool);
        } else {
            awardActivity(activity, bioPool);
        }
    }

    function awardSleepScore(score as Float) as Void {
        var boundedScore = score;
        if (boundedScore < 0.0) {
            boundedScore = 0.0;
        } else if (boundedScore > 100.0) {
            boundedScore = 100.0;
        }
        if (boundedScore >= 90.0) {
            unlockTitle("WELL RESTED");
        }
        var perXp = (boundedScore / 100.0) * 50.0;
        logDailyActivity("Sleep: +" + perXp.toNumber().toString() + " PER");
        addXp(:PER, perXp);
    }

    function syncSleepScore() as Void {
        var currentDay = currentDayKey();
        var lastSleepDay = data["lastSleepDay"];
        var alreadySyncedToday = (lastSleepDay != null && (lastSleepDay instanceof Number) && (lastSleepDay as Number) == currentDay);
        var prevSleepScore = data.hasKey("lastSleepScore") ? (data["lastSleepScore"] as Numeric).toFloat() : 0.0;

        var score = null as Float or Null;
        var info = ActivityMonitor.getInfo();

        // 1. Check direct sleepScore / sleepDuration if exposed by simulator/SDK
        if (info != null && info has :sleepScore && info.sleepScore != null) {
            score = (info.sleepScore as Numeric).toFloat();
        } else if (info != null && info has :sleepDuration && info.sleepDuration != null) {
            var sleepMinutes = (info.sleepDuration as Numeric).toFloat() / 60.0;
            if (sleepMinutes > 0.0) {
                score = (sleepMinutes / 480.0) * 100.0;
                if (score > 100.0) { score = 100.0; }
            }
        }

        // Guard against premature 12 AM - 4:59 AM fallback lockout before the user has woken up
        var clockHour = System.getClockTime().hour;
        if ((score == null || score <= 0.0) && clockHour >= 5) {
            // 2. Physical Garmin watch fallback: Morning peak Body Battery (0-100 overnight sleep recovery score)
            if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
                var bbIter = SensorHistory.getBodyBatteryHistory({
                    :period => new Time.Duration(43200), // Last 12 hours (overnight + morning)
                    :order => SensorHistory.ORDER_NEWEST_FIRST
                });
                if (bbIter != null) {
                    var peakBb = 0.0;
                    var count = 0;
                    var sample = bbIter.next();
                    while (sample != null && count < 40) {
                        if (sample.data != null) {
                            var val = (sample.data as Numeric).toFloat();
                            if (val > peakBb) {
                                peakBb = val;
                            }
                        }
                        count += 1;
                        sample = bbIter.next();
                    }
                    if (peakBb > 0.0) {
                        score = peakBb;
                    }
                }
            }

            // 3. Secondary fallback: inverse stress score (100 - stressScore) if available
            if ((score == null || score <= 0.0) && info != null && (info has :stressScore) && info.stressScore != null) {
                var stress = (info.stressScore as Numeric).toFloat();
                if (stress >= 0.0 && stress <= 100.0) {
                    score = 100.0 - (stress * 0.5);
                }
            }
        }

        if (score == null || score <= 0.0) {
            return;
        }
        if (score > 100.0) {
            score = 100.0;
        }

        if (!alreadySyncedToday) {
            awardSleepScore(score);
            data["lastSleepDay"] = currentDay;
            data["lastSleepScore"] = score;
            save();
        } else if (score > prevSleepScore + 2.0) {
            // Award differential PER XP if a higher morning recovery score finalized later
            var diffScore = score - prevSleepScore;
            addXp(:PER, (diffScore / 100.0) * 50.0);
            data["lastSleepScore"] = score;
            save();
        }
    }

    function nextLevelXp(level as Number) as Float {
        if (level <= 0) {
            return 1000.0;
        }
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
            "workoutComplete" => false,
            "penaltyActive" => false,
            "penaltyComplete" => false,
            "readingMinutes" => 0,
            "readingXpAwarded" => 0.0
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
            "workoutAwarded" => false,
            "lastTimerTime" => 0,
            "lastDistance" => 0.0
        };
    }

    function currentDayKey() as Number {
        var clock = System.getClockTime();
        var localEpochTime = Time.now().value() + clock.timeZoneOffset + clock.dst;
        return (localEpochTime / 86400) as Number;
    }

    function isQuestComplete(stepsComplete as Boolean,
        readingComplete as Boolean,
        workoutComplete as Boolean) as Boolean {
        return stepsComplete && readingComplete && workoutComplete;
    }

    function fatigueMultiplier(id as Symbol) as Float {
        return isFatigued(id) ? 0.5 : 1.0;
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

    function statKey(id as Symbol) as String {
        return id.toString();
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

    function logDailyActivity(entry as String) as Void {
        if (!data.hasKey("dailyLog") || !(data["dailyLog"] instanceof Array)) {
            data["dailyLog"] = [] as Array;
        }
        var log = data["dailyLog"] as Array;
        if (log.size() < 5) {
            log.add(entry);
        }
        save();
    }

    public function getData() as Dictionary or Null {
        return data;
    }

}
