import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

//! Keeps test games from overwriting the best score saved in the simulator.
(:test)
class UnsavedBestScore extends BestScore {
    function initialize() {
        BestScore.initialize();
    }

    function load() as Number {
        return 0;
    }

    function save(best as Number) as Void {
    }
}

//! Firmware does not document whether onKey lands before or after onKeyReleased, so presses are tested both ways.
(:test)
module TowerDelegateTest {
    function keyEvent(key as WatchUi.Key) as KeyEvent {
        return new WatchUi.KeyEvent(key, WatchUi.PRESS_TYPE_ACTION);
    }

    function tapEvent() as ClickEvent {
        return new WatchUi.ClickEvent(100, 100, WatchUi.CLICK_TYPE_TAP);
    }

    function press(delegate as TowerDelegate, key as WatchUi.Key) as Boolean {
        var pressed = delegate.onKeyPressed(keyEvent(key));
        var released = delegate.onKeyReleased(keyEvent(key));
        var trailing = delegate.onKey(keyEvent(key));
        return pressed || released || trailing;
    }

    function slidingController() as TowerController {
        var controller = new TowerController(new UnsavedBestScore());
        controller.startGame();
        return controller;
    }

    function toppledController() as TowerController {
        var controller = slidingController();
        var game = controller.game;
        while (game.phase == PHASE_SLIDING) {
            game.advance(game.STEP_MS);
            var offset = game.offset();
            if ((offset > 0 ? offset : -offset) >= 30.0) {
                controller.drop();
            }
        }
        return controller;
    }

    (:test)
    function startBeginsOneGameAndSwallowsTheTrailingKey(logger as Logger) as Boolean {
        var controller = new TowerController(new UnsavedBestScore());
        var delegate = new TowerDelegate(controller);
        var pressed = delegate.onKeyPressed(keyEvent(WatchUi.KEY_ENTER));
        var trailing = delegate.onKey(keyEvent(WatchUi.KEY_ENTER));
        var game = controller.game;
        var sliding = game.phase == PHASE_SLIDING && game.floors == 0;
        controller.suspend();
        return pressed && trailing && sliding;
    }

    (:test)
    function startDropsOneFloorPerPress(logger as Logger) as Boolean {
        var controller = slidingController();
        var delegate = new TowerDelegate(controller);
        press(delegate, WatchUi.KEY_ENTER);
        var floors = controller.game.floors;
        controller.suspend();
        return floors == 1;
    }

    (:test)
    function keyWithoutPressEventStillDrops(logger as Logger) as Boolean {
        var controller = slidingController();
        var delegate = new TowerDelegate(controller);
        var handled = delegate.onKey(keyEvent(WatchUi.KEY_ENTER));
        var floors = controller.game.floors;
        controller.suspend();
        return handled && floors == 1;
    }

    (:test)
    function backPausesWithoutReachingTheSystem(logger as Logger) as Boolean {
        var controller = slidingController();
        var delegate = new TowerDelegate(controller);
        var pressed = delegate.onKeyPressed(keyEvent(WatchUi.KEY_ESC));
        var trailing = delegate.onKey(keyEvent(WatchUi.KEY_ESC));
        var paused = controller.game.phase == PHASE_PAUSED;
        controller.suspend();
        return pressed && trailing && paused;
    }

    (:test)
    function backWhilePausedQuits(logger as Logger) as Boolean {
        var controller = slidingController();
        var delegate = new TowerDelegate(controller);
        press(delegate, WatchUi.KEY_ESC);
        var consumed = press(delegate, WatchUi.KEY_ESC);
        controller.suspend();
        return !consumed;
    }

    (:test)
    function startWhilePausedResumes(logger as Logger) as Boolean {
        var controller = slidingController();
        var delegate = new TowerDelegate(controller);
        press(delegate, WatchUi.KEY_ESC);
        press(delegate, WatchUi.KEY_ENTER);
        var game = controller.game;
        var resumed = game.phase == PHASE_SLIDING && game.floors == 0;
        controller.suspend();
        return resumed;
    }

    (:test)
    function buttonsAreSwallowedWhileToppling(logger as Logger) as Boolean {
        var controller = toppledController();
        var delegate = new TowerDelegate(controller);
        var start = press(delegate, WatchUi.KEY_ENTER);
        var back = press(delegate, WatchUi.KEY_ESC);
        var stillToppling = controller.game.phase == PHASE_TOPPLING;
        controller.suspend();
        return start && back && stillToppling;
    }

    (:test)
    function startRetriesAfterGameOver(logger as Logger) as Boolean {
        var controller = toppledController();
        controller.suspend();
        var delegate = new TowerDelegate(controller);
        var over = controller.game.phase == PHASE_OVER;
        press(delegate, WatchUi.KEY_ENTER);
        var game = controller.game;
        var retried = game.phase == PHASE_SLIDING && game.floors == 0;
        controller.suspend();
        return over && retried;
    }

    (:test)
    function backExitsFromStartScreen(logger as Logger) as Boolean {
        var controller = new TowerController(new UnsavedBestScore());
        var delegate = new TowerDelegate(controller);
        return !press(delegate, WatchUi.KEY_ESC);
    }

    (:test)
    function upAndDownDoNothingOnStartScreen(logger as Logger) as Boolean {
        var controller = new TowerController(new UnsavedBestScore());
        var delegate = new TowerDelegate(controller);
        press(delegate, WatchUi.KEY_UP);
        press(delegate, WatchUi.KEY_DOWN);
        return controller.game.phase == PHASE_START;
    }

    (:test)
    function tapStartsDropsAndResumes(logger as Logger) as Boolean {
        var controller = new TowerController(new UnsavedBestScore());
        var delegate = new TowerDelegate(controller);
        var game = controller.game;
        delegate.onTap(tapEvent());
        var started = game.phase == PHASE_SLIDING;
        delegate.onTap(tapEvent());
        var dropped = game.floors == 1;
        controller.pause();
        delegate.onTap(tapEvent());
        var resumed = game.phase == PHASE_SLIDING && game.floors == 1;
        controller.suspend();
        return started && dropped && resumed;
    }

    (:test)
    function swipeIsSwallowedOnlyDuringPlay(logger as Logger) as Boolean {
        var controller = new TowerController(new UnsavedBestScore());
        var delegate = new TowerDelegate(controller);
        var swipe = new WatchUi.SwipeEvent(WatchUi.SWIPE_RIGHT);
        var atStart = delegate.onSwipe(swipe);
        controller.startGame();
        var inGame = delegate.onSwipe(swipe);
        controller.suspend();
        return !atStart && inGame;
    }

    (:test)
    function suspendPausesAGameAndFinishesATopple(logger as Logger) as Boolean {
        var sliding = slidingController();
        sliding.suspend();
        var toppled = toppledController();
        toppled.suspend();
        return sliding.game.phase == PHASE_PAUSED && toppled.game.phase == PHASE_OVER;
    }
}
