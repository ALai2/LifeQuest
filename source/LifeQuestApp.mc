import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.WatchUi;

class LifeQuestApp extends Application.AppBase {
    var characterState as LifeQuestState;
    var lifeQuestView as LifeQuestView;

    function initialize() {
        AppBase.initialize();
        characterState = new LifeQuestState();
        characterState.load();
        lifeQuestView = new LifeQuestView();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        if (Background has :registerForActivityCompletedEvent
            && !Background.getActivityCompletedEventRegistered()) {
            Background.registerForActivityCompletedEvent();
        }
        characterState.reconcileDay();
        characterState.syncSleepScore();
        characterState.syncSteps();
        new LifeQuestActivityDetector().sync(characterState);
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        characterState.save();
    }

    function getCharacterState() as LifeQuestState {
        return characterState;
    }

    function getLifeQuestView() as LifeQuestView {
        return lifeQuestView;
    }

    function nextPage() as Void {
        lifeQuestView.nextPage();
    }

    function previousPage() as Void {
        lifeQuestView.previousPage();
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ lifeQuestView, new LifeQuestDelegate() ];
    }

}

function getApp() as LifeQuestApp {
    return Application.getApp() as LifeQuestApp;
}