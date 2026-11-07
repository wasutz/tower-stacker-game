import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! Runs the game in real time: drives TowerGame from a frame timer while the floor slides or the tower topples,
//! and turns its transitions into redraws, haptics and saved scores. The timer stops on every still screen to spare
//! the battery.
class TowerController {
    //! 20 frames a second. The rules run in fixed steps of real time, so a watch that draws slower only looks less smooth.
    private const FRAME_MS = 50;

    public var game as TowerGame;

    private var _frameTimer as Timer.Timer = new Timer.Timer();
    private var _isFrameTimerRunning as Boolean = false;
    private var _lastFrameAt as Number = 0;
    private var _bestScore as BestScore;
    private var _savedBest as Number;

    function initialize(bestScore as BestScore) {
        _bestScore = bestScore;
        _savedBest = bestScore.load();
        game = new TowerGame(_savedBest);
    }

    function startGame() as Void {
        game.start();
        startFrames();
    }

    //! Drops the floor where the player saw it on the last frame drawn.
    function drop() as Void {
        switch (game.drop()) {
            case DROP_PERFECT:
                Haptics.playPerfect();
                break;
            case DROP_CUT:
                Haptics.playFloor();
                break;
            case DROP_MISSED:
                Haptics.playTopple();
                saveBest();
                break;
        }
        WatchUi.requestUpdate();
    }

    function pause() as Void {
        game.pause();
        stopFrames();
        saveBest();
    }

    function resume() as Void {
        game.resume();
        startFrames();
    }

    //! The app has lost the screen: a game waits paused, a topple in progress lands on the game-over screen.
    function suspend() as Void {
        game.pause();
        game.finishTopple();
        stopFrames();
        saveBest();
    }

    function onFrame() as Void {
        var now = System.getTimer();
        game.advance(now - _lastFrameAt);
        _lastFrameAt = now;
        if (!game.isInPlay()) {
            stopFrames();
        }
        WatchUi.requestUpdate();
    }

    private function saveBest() as Void {
        if (game.best != _savedBest) {
            _savedBest = game.best;
            _bestScore.save(_savedBest);
        }
    }

    private function startFrames() as Void {
        if (!_isFrameTimerRunning) {
            _isFrameTimerRunning = true;
            _lastFrameAt = System.getTimer();
            _frameTimer.start(method(:onFrame), FRAME_MS, true);
        }
        WatchUi.requestUpdate();
    }

    private function stopFrames() as Void {
        _frameTimer.stop();
        _isFrameTimerRunning = false;
        WatchUi.requestUpdate();
    }
}
