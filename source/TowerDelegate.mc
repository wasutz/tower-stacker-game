import Toybox.Lang;
import Toybox.WatchUi;

//! Buttons act on press, so the floor drops the instant START goes down. Firmware then also sends onKey for the
//! same press, which must be swallowed: after BACK has paused a game, a BACK that reached the system would exit
//! the app.
class TowerDelegate extends WatchUi.InputDelegate {
    private const NO_KEY = -1;

    private var _controller as TowerController;
    private var _handledKey as Number = NO_KEY;

    function initialize(controller as TowerController) {
        InputDelegate.initialize();
        _controller = controller;
    }

    function onKeyPressed(event as KeyEvent) as Boolean {
        _handledKey = NO_KEY;
        var key = event.getKey();
        var handled = handlePress(key);
        if (handled) {
            _handledKey = key;
        }
        return handled;
    }

    //! Also the only event some firmware sends for a press.
    function onKey(event as KeyEvent) as Boolean {
        var key = event.getKey();
        if (key == _handledKey) {
            _handledKey = NO_KEY;
            return true;
        }
        return handlePress(key);
    }

    function onTap(event as ClickEvent) as Boolean {
        switch (_controller.game.phase) {
            case PHASE_SLIDING:
                _controller.drop();
                break;
            case PHASE_PAUSED:
                _controller.resume();
                break;
            case PHASE_START:
            case PHASE_OVER:
                _controller.startGame();
                break;
        }
        return true;
    }

    //! A slipped tap must not swipe the player out of a game.
    function onSwipe(event as SwipeEvent) as Boolean {
        return _controller.game.isInPlay();
    }

    private function handlePress(key as Number) as Boolean {
        switch (_controller.game.phase) {
            case PHASE_SLIDING:
                if (key == KEY_ENTER) {
                    _controller.drop();
                } else if (key == KEY_ESC) {
                    _controller.pause();
                }
                return true;
            case PHASE_TOPPLING:
                return true;
            case PHASE_PAUSED:
                if (key == KEY_ENTER) {
                    _controller.resume();
                    return true;
                }
                return false;
        }
        if (key == KEY_ENTER) {
            _controller.startGame();
            return true;
        }
        return false;
    }
}
