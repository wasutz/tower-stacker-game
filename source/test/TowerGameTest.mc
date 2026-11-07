import Toybox.Lang;
import Toybox.Test;

(:test)
module TowerGameTest {
    function startedGame(best as Number) as TowerGame {
        var game = new TowerGame(best);
        game.start();
        return game;
    }

    function abs(value as Float) as Float {
        return value < 0 ? -value : value;
    }

    //! Slides until the floor passes the given offset in its direction of travel, then drops it.
    function dropAt(game as TowerGame, target as Float) as DropResult {
        while (game.direction() > 0 ? game.offset() < target : game.offset() > target) {
            game.advance(game.STEP_MS);
        }
        return game.drop();
    }

    //! Slides to the end of the swing, where the floor is furthest from the tower, then drops it.
    function dropAtFarthest(game as TowerGame) as DropResult {
        var direction = game.direction();
        while (game.direction() == direction) {
            game.advance(game.STEP_MS);
        }
        return game.drop();
    }

    //! advance() caps each call at one long frame, so longer spans go in frame-sized pieces.
    function advanceBy(game as TowerGame, ms as Number) as Void {
        for (var left = ms; left > 0; left -= 50) {
            game.advance(left < 50 ? left : 50);
        }
    }

    function stackPerfectly(game as TowerGame, floors as Number) as Void {
        while (game.floors < floors) {
            dropAt(game, 0.0);
        }
    }

    function narrowAndMiss(game as TowerGame) as Void {
        while (game.phase == PHASE_SLIDING) {
            if (game.slider.width < 50) {
                dropAtFarthest(game);
            } else {
                dropAt(game, game.direction() * 30.0);
            }
        }
    }

    (:test)
    function startStandsTheBaseWithAFullWidthFloorAboveIt(logger as Logger) as Boolean {
        var game = startedGame(0);
        return game.phase == PHASE_SLIDING && game.floors == 0 && game.stack.size() == 1
            && game.top().width == game.BASE_WIDTH && game.slider.width == game.BASE_WIDTH
            && game.sliderLevel() == 2 && game.direction() == 1;
    }

    (:test)
    function floorSlidesAtTheStartSpeed(logger as Logger) as Boolean {
        var game = startedGame(0);
        var left = game.slider.left;
        game.advance(100);
        return abs(game.slider.left - left - game.START_SPEED / 10) < 0.01;
    }

    (:test)
    function floorBouncesAtTheEndsOfItsSwing(logger as Logger) as Boolean {
        var game = startedGame(0);
        var start = game.slider.left;
        var farthest = start;
        while (game.direction() > 0) {
            game.advance(game.STEP_MS);
            farthest = game.slider.left > farthest ? game.slider.left : farthest;
        }
        while (game.direction() < 0) {
            game.advance(game.STEP_MS);
        }
        var swing = farthest - start;
        return abs(swing - 128.0) < 2.0 && abs(game.slider.left - start) < 2.0;
    }

    (:test)
    function nextFloorEntersFromTheOtherSide(logger as Logger) as Boolean {
        var game = startedGame(0);
        var firstLeft = game.slider.left;
        dropAt(game, 0.0);
        return game.direction() == -1 && game.slider.left > firstLeft;
    }

    (:test)
    function perfectDropLandsAlignedAndKeepsFullWidth(logger as Logger) as Boolean {
        var game = startedGame(0);
        var result = dropAt(game, 0.0);
        return result == DROP_PERFECT && game.floors == 1 && game.top().left == game.BASE_LEFT
            && game.top().width == game.BASE_WIDTH && game.debris.size() == 0;
    }

    (:test)
    function offsetDropCutsTheOverhangOff(logger as Logger) as Boolean {
        var game = startedGame(0);
        var result = dropAt(game, 20.0);
        var piece = game.debris[0];
        var top = game.top();
        var cut = game.BASE_WIDTH - top.width;
        return result == DROP_CUT && cut >= 20.0 && cut < 22.0 && abs(top.left - game.BASE_LEFT - cut) < 0.01
            && piece.side == 1 && !piece.isWholeFloor && abs(piece.width - cut) < 0.01
            && abs(piece.left - (game.BASE_LEFT + game.BASE_WIDTH)) < 0.01 && piece.level == 1
            && game.slider.width == top.width;
    }

    (:test)
    function overhangOnTheLeftFallsLeft(logger as Logger) as Boolean {
        var game = startedGame(0);
        dropAt(game, -15.0);
        var piece = game.debris[0];
        return piece.side == -1 && game.top().left == game.BASE_LEFT && abs(piece.left + piece.width - game.BASE_LEFT) < 0.01;
    }

    (:test)
    function perfectDropWinsBackWidthUpToTheBase(logger as Logger) as Boolean {
        var game = startedGame(0);
        dropAt(game, 10.0);
        var cutWidth = game.top().width;
        var cutCenter = game.top().left + cutWidth / 2;
        dropAt(game, 0.0);
        var grown = game.top();
        var restored = abs(grown.width - cutWidth - game.PERFECT_GROWTH) < 0.01 && abs(grown.left + grown.width / 2 - cutCenter) < 0.01;
        stackPerfectly(game, 6);
        return restored && game.top().width == game.BASE_WIDTH;
    }

    (:test)
    function fullWidthFloorCannotMissTheBase(logger as Logger) as Boolean {
        var game = startedGame(0);
        var result = dropAtFarthest(game);
        return result == DROP_CUT && game.phase == PHASE_SLIDING;
    }

    (:test)
    function missTopplesThenEndsTheGame(logger as Logger) as Boolean {
        var game = startedGame(0);
        narrowAndMiss(game);
        var floors = game.floors;
        var toppling = game.phase == PHASE_TOPPLING;
        var piece = game.debris[game.debris.size() - 1];
        var fell = piece.isWholeFloor && piece.level == floors + 1;
        var ignored = game.drop() == DROP_IGNORED;
        advanceBy(game, 890);
        var stillFalling = game.phase == PHASE_TOPPLING;
        game.advance(game.STEP_MS);
        return toppling && fell && ignored && stillFalling && game.phase == PHASE_OVER && game.floors == floors
            && game.debris.size() == 0;
    }

    (:test)
    function cutPiecesFallAwayAndAreForgotten(logger as Logger) as Boolean {
        var game = startedGame(0);
        dropAt(game, 20.0);
        var piece = game.debris[0];
        advanceBy(game, 200);
        var falling = piece.fallen() > 0 && piece.drift() > 0 && piece.degrees() > 0;
        advanceBy(game, 600);
        return falling && game.debris.size() == 0;
    }

    (:test)
    function speedRisesWithEveryFloorUpToTheCap(logger as Logger) as Boolean {
        var game = startedGame(0);
        stackPerfectly(game, 2);
        var early = game.speed() == game.START_SPEED + 2 * game.SPEED_PER_FLOOR;
        stackPerfectly(game, 60);
        return early && game.speed() == game.MAX_SPEED;
    }

    (:test)
    function cameraRisesToKeepTheTopFloorInView(logger as Logger) as Boolean {
        var game = startedGame(0);
        stackPerfectly(game, 5);
        game.advance(100);
        var stayed = game.lift == 0.0;
        dropAt(game, 0.0);
        var risingAtOnce = game.lift < game.FLOOR_PITCH;
        advanceBy(game, 200);
        return stayed && risingAtOnce && game.lift == game.FLOOR_PITCH;
    }

    (:test)
    function towerKeepsOnlyTheFloorsOnScreen(logger as Logger) as Boolean {
        var game = startedGame(0);
        stackPerfectly(game, 30);
        return game.floors == 30 && game.stack.size() == 12 && game.top().width == game.BASE_WIDTH;
    }

    (:test)
    function longStallIsCappedNotSimulated(logger as Logger) as Boolean {
        var game = startedGame(0);
        var left = game.slider.left;
        game.advance(5000);
        return abs(game.slider.left - left - game.START_SPEED / 10) < 0.01;
    }

    (:test)
    function pauseFreezesTheFloorUntilResumed(logger as Logger) as Boolean {
        var game = startedGame(0);
        game.pause();
        var left = game.slider.left;
        game.advance(100);
        var frozen = game.slider.left == left && game.drop() == DROP_IGNORED;
        game.resume();
        game.advance(100);
        return frozen && game.phase == PHASE_SLIDING && game.slider.left > left;
    }

    (:test)
    function bestIsRecordedAsSoonAsAFloorBeatsIt(logger as Logger) as Boolean {
        var game = startedGame(2);
        stackPerfectly(game, 2);
        var unchanged = game.best == 2 && !game.isNewBest();
        stackPerfectly(game, 3);
        return unchanged && game.best == 3 && game.isNewBest();
    }

    (:test)
    function retryKeepsBestAndResetsTheTower(logger as Logger) as Boolean {
        var game = startedGame(0);
        stackPerfectly(game, 8);
        narrowAndMiss(game);
        game.advance(100);
        game.finishTopple();
        var hadNewBest = game.isNewBest();
        var best = game.best;
        game.start();
        return hadNewBest && best >= 8 && game.best == best && !game.isNewBest() && game.floors == 0
            && game.stack.size() == 1 && game.lift == 0.0 && game.debris.size() == 0;
    }

    (:test)
    function finishToppleEndsAFallInProgressOnly(logger as Logger) as Boolean {
        var game = startedGame(0);
        game.finishTopple();
        var untouched = game.phase == PHASE_SLIDING;
        narrowAndMiss(game);
        game.finishTopple();
        return untouched && game.phase == PHASE_OVER;
    }

    (:test)
    function trailFollowsThePathBackAroundABounce(logger as Logger) as Boolean {
        var game = startedGame(0);
        var start = game.slider.left;
        game.advance(100);
        var moved = game.slider.left - start;
        var straight = abs(game.sliderLeftBehind(moved / 2) - (start + moved / 2)) < 0.01;
        var bounced = abs(game.sliderLeftBehind(moved + 4.0) - (start + 4.0)) < 0.01;
        return straight && bounced;
    }
}
