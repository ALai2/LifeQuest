import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

(:background, :glance)
class LifeQuestApp extends Application.AppBase {
    var characterState as LifeQuestState or Null;
    var lifeQuestView as LifeQuestView or Null;
    var foregroundSynced as Boolean = false;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        // Intentionally empty because onStart() also runs in the background ServiceDelegate VM.
        // Foreground initialization happens safely in ensureForegroundReady().
    }

    function onStop(state as Dictionary?) as Void {
    }

    (:glance)
    function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [ new LifeQuestGlanceView() ];
    }

    function ensureForegroundReady() as LifeQuestState {
        if (characterState == null) {
            var st = new LifeQuestState();
            st.load();
            characterState = st;
        }
        var state = characterState as LifeQuestState;
        var currentDay = state.currentDayKey();
        var lastDay = state.data.hasKey("lastDay") ? (state.data["lastDay"] as Number) : -1;

        if (!foregroundSynced || lastDay != currentDay) {
            foregroundSynced = true;
            // Sync completed workouts BEFORE reconcileDay so late-night workouts from yesterday
            // credit yesterday's ledger before rollover evaluates missed quests (Bug 1 fix)
            state.syncCompletedActivities();
            if (lastDay != currentDay) {
                state.reconcileDay();
                state.syncCompletedActivities();
            }
            new LifeQuestActivityDetector().sync(state);
            state.syncSleepScore();
            state.syncSteps();
            state.syncExternalSettings();
            state.save();

            if (Toybox has :Background && Background has :registerForActivityCompletedEvent) {
                try {
                    Background.registerForActivityCompletedEvent();
                } catch (e) {
                    // Ignore if not supported on target
                }
            }
        }
        return state;
    }

    function onBackgroundData(bgData as Application.PersistableType) as Void {
        var state = ensureForegroundReady();
        // Sync completed activities from UserProfile history first (deduplicated via lastHistoryActivityTime)
        state.syncCompletedActivities();

        // Fallback if UserProfile history didn't already mark workoutComplete
        var quests = state.data["quests"] as Dictionary;
        if (!(quests["workoutComplete"] as Boolean) && (bgData instanceof Dictionary)) {
            var dict = bgData as Dictionary;
            if (dict.hasKey("sport") && dict["sport"] != null) {
                var subSp = dict.hasKey("subSport") ? (dict["subSport"] as Toybox.Activity.SubSport or Null) : null;
                var actType = state.activitySymbolForSportAndSubSport(dict["sport"] as Toybox.Activity.Sport, subSp);
                state.completeWorkoutQuestForActivity(actType);
            }
        }
        state.save();
        WatchUi.requestUpdate();
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new LifeQuestBackgroundService() ];
    }

    function getCharacterState() as LifeQuestState {
        return ensureForegroundReady();
    }

    function getLifeQuestView() as LifeQuestView or Null {
        return lifeQuestView;
    }

    function nextPage() as Void {
        if (lifeQuestView != null) {
            lifeQuestView.nextPage();
        }
    }

    function previousPage() as Void {
        if (lifeQuestView != null) {
            lifeQuestView.previousPage();
        }
    }

    function onSettingsChanged() as Void {
        var state = ensureForegroundReady();
        state.syncExternalSettings();
        WatchUi.requestUpdate();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        ensureForegroundReady();
        lifeQuestView = new LifeQuestView();
        return [ lifeQuestView, new LifeQuestDelegate() ];
    }
}

function getApp() as LifeQuestApp {
    return Application.getApp() as LifeQuestApp;
}
