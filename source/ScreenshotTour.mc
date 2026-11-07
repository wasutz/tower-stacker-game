import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! Screenshot builds only (tools/screenshots.py, tools/tour.jungle): plays scripted games through the real rules
//! and prints "SHOT <name>" once each screen has been drawn, so the script can capture the simulator.
//!
//! Each goal advances the game by one step and reports whether its screen is ready. The watchdog stops any
//! callback that runs too long, so a tick plays a bounded number of steps and the next tick carries on.
(:tour)
class ScreenshotTour extends TowerView {
    private const SAMPLE_BEST = 42;
    //! Where each of the first floors is dropped, relative to the floor below: a mix of perfect drops and cuts.
    private const SAMPLE_OFFSETS = [0, 6, -4, 0, 8, 0, -5, 0, 4, 0, -6, 0, 0, 5, 0, -4, 0, 7];
    //! The play shot catches the floor this far past the tower, and the last cut piece still falling.
    private const PLAY_SHOT_OFFSET = 26.0;
    //! Big cuts narrow the tower until a floor can miss it.
    private const NARROWING_OFFSET = 30.0;
    private const MID_FALL_MS = 200;
    private const TICK_MS = 50;
    private const STEPS_PER_TICK = 150;
    private const HOLD_TICKS = 50;

    private var _timer as Timer.Timer = new Timer.Timer();
    private var _goals as Array<Symbol> = [:reachPlay, :reachPaused, :reachToppled, :reachOver, :reachNewBest];
    private var _shots as Array<String> = ["play", "paused", "toppled", "over", "new-best"];
    private var _index as Number = 0;
    private var _holdTicks as Number = HOLD_TICKS;
    private var _shot as String = "start";

    function initialize() {
        TowerView.initialize(new TowerGame(SAMPLE_BEST));
    }

    function onShow() as Void {
        _timer.start(method(:onTick), TICK_MS, true);
    }

    function onUpdate(dc) as Void {
        TowerView.onUpdate(dc);
        if (!_shot.equals("")) {
            System.println("SHOT " + _shot);
            _shot = "";
        }
    }

    function onTick() as Void {
        if (_holdTicks > 0) {
            _holdTicks--;
            return;
        }
        if (_index == _goals.size()) {
            _timer.stop();
            System.println("TOUR DONE");
            return;
        }
        var goal = method(_goals[_index]);
        for (var i = 0; i < STEPS_PER_TICK; i++) {
            if (goal.invoke() as Boolean) {
                _shot = _shots[_index];
                _index++;
                _holdTicks = HOLD_TICKS;
                WatchUi.requestUpdate();
                return;
            }
        }
    }

    function reachPlay() as Boolean {
        if (_game.phase != PHASE_SLIDING) {
            _game.start();
        }
        if (_game.floors < SAMPLE_OFFSETS.size()) {
            dropAt(SAMPLE_OFFSETS[_game.floors].toFloat());
            return false;
        }
        if (_game.direction() > 0 && _game.offset() >= PLAY_SHOT_OFFSET) {
            return true;
        }
        _game.advance(_game.STEP_MS);
        return false;
    }

    function reachPaused() as Boolean {
        _game.pause();
        return true;
    }

    function reachToppled() as Boolean {
        _game.resume();
        if (_game.phase == PHASE_TOPPLING && _game.toppledMs >= MID_FALL_MS) {
            return true;
        }
        if (_game.phase == PHASE_TOPPLING) {
            _game.advance(_game.STEP_MS);
        } else {
            narrowUntilMiss();
        }
        return false;
    }

    function reachOver() as Boolean {
        if (_game.phase == PHASE_OVER) {
            return true;
        }
        _game.advance(_game.STEP_MS);
        return false;
    }

    function reachNewBest() as Boolean {
        switch (_game.phase) {
            case PHASE_OVER:
                if (_game.isNewBest()) {
                    return true;
                }
                _game.start();
                break;
            case PHASE_SLIDING:
                if (_game.floors <= SAMPLE_BEST) {
                    dropAt(0.0);
                } else {
                    narrowUntilMiss();
                }
                break;
            default:
                _game.advance(_game.STEP_MS);
                break;
        }
        return false;
    }

    //! Drops as the floor passes the given offset, or steps it closer.
    private function dropAt(target as Float) as Void {
        var offset = _game.offset();
        if (_game.direction() > 0 ? offset >= target : offset <= target) {
            _game.drop();
        } else {
            _game.advance(_game.STEP_MS);
        }
    }

    private function narrowUntilMiss() as Void {
        var offset = _game.offset();
        var distance = offset > 0 ? offset : -offset;
        if (distance > _game.slider.width) {
            _game.drop();
        } else {
            dropAt(_game.direction() * NARROWING_OFFSET);
        }
    }
}
