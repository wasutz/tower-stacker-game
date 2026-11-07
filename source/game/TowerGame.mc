import Toybox.Lang;

enum Phase {
    PHASE_START,
    PHASE_SLIDING,
    PHASE_PAUSED,
    PHASE_TOPPLING,
    PHASE_OVER
}

enum DropResult {
    DROP_IGNORED,
    DROP_PERFECT,
    DROP_CUT,
    DROP_MISSED
}

//! The rules, free of timers, buttons and drawing. Lengths are the design's pixels on its 256 px display: x grows
//! from the left edge of the screen. Floors are counted in levels upwards from the base, which is level 0.
//! Time is in milliseconds.
//!
//! The slide is simulated in fixed 10 ms steps whatever the frame rate, so the floor moves the same way on every
//! watch and the unit tests replay exactly what a player sees.
class TowerGame {
    public const BASE_LEFT = 68.0;
    public const BASE_WIDTH = 120.0;
    public const FLOOR_PITCH = 14.0;
    public const STEP_MS = 10;
    //! A drop this close to the floor below counts as perfect: it lands aligned and wins back some width.
    public const PERFECT_TOLERANCE = 3.0;
    public const PERFECT_GROWTH = 4.0;
    public const START_SPEED = 80.0;
    public const SPEED_PER_FLOOR = 3.0;
    public const MAX_SPEED = 190.0;

    //! The sliding floor's centre swings this far either side of the screen's centre, which keeps a full-width
    //! floor inside the round display. Early floors cannot miss outright, an on-ramp before the tower narrows.
    private const SLIDE_CENTER = 128.0;
    private const SLIDE_REACH = 64.0;
    //! A sliver this thin would be invisible on small screens, so it counts as a miss.
    private const MIN_OVERLAP = 2.0;
    private const MAX_FRAME_MS = 100;
    private const TOPPLE_MS = 900;
    //! The camera rises once the tower stands this many floors above the base, keeping the top floor in view.
    private const LEVELS_BELOW_CAMERA = 5;
    private const CAMERA_SPEED = 120.0;
    //! Floors below these are off the bottom of the screen at any camera height.
    private const KEPT_FLOORS = 12;

    public var phase as Phase = PHASE_START;
    public var best as Number;
    //! Floors placed on the base, which is the score.
    public var floors as Number = 0;
    //! The top of the tower, base first while it is still on screen; the last floor is at level `floors`.
    public var stack as Array<Floor> = [] as Array<Floor>;
    public var slider as Floor = new Floor(BASE_LEFT, BASE_WIDTH);
    public var debris as Array<Debris> = [] as Array<Debris>;
    //! How far the camera has risen above the base.
    public var lift as Float = 0.0;
    public var toppledMs as Number = 0;

    private var _direction as Number = 1;
    private var _unsimulatedMs as Number = 0;
    private var _bestBeforeGame as Number;

    function initialize(best as Number) {
        self.best = best;
        _bestBeforeGame = best;
    }

    //! Time moves on: the floor slides or the tower topples.
    function isInPlay() as Boolean {
        return phase == PHASE_SLIDING || phase == PHASE_TOPPLING;
    }

    function isNewBest() as Boolean {
        return best > _bestBeforeGame;
    }

    function top() as Floor {
        return stack[stack.size() - 1];
    }

    //! +1 while the floor slides right, -1 while it slides left.
    function direction() as Number {
        return _direction;
    }

    //! How far the sliding floor's left edge is right of the top floor's.
    function offset() as Float {
        return slider.left - top().left;
    }

    function sliderLevel() as Number {
        return floors + 2;
    }

    //! Slide speed in px per second.
    function speed() as Float {
        var speed = START_SPEED + SPEED_PER_FLOOR * floors;
        return speed < MAX_SPEED ? speed : MAX_SPEED;
    }

    //! Where the sliding floor's left edge was `distance` px of travel ago, bounces included.
    function sliderLeftBehind(distance as Float) as Float {
        var left = slider.left - _direction * distance;
        var min = minSliderLeft();
        var max = maxSliderLeft();
        if (left < min) {
            return 2 * min - left;
        }
        if (left > max) {
            return 2 * max - left;
        }
        return left;
    }

    function start() as Void {
        phase = PHASE_SLIDING;
        floors = 0;
        stack = [new Floor(BASE_LEFT, BASE_WIDTH)] as Array<Floor>;
        debris = [] as Array<Debris>;
        lift = 0.0;
        toppledMs = 0;
        _unsimulatedMs = 0;
        _bestBeforeGame = best;
        spawnSlider();
    }

    function drop() as DropResult {
        if (phase != PHASE_SLIDING) {
            return DROP_IGNORED;
        }
        var below = top();
        var offset = offset();
        var side = offset > 0 ? 1 : -1;
        if (side * offset <= PERFECT_TOLERANCE) {
            var width = below.width + PERFECT_GROWTH;
            width = width < BASE_WIDTH ? width : BASE_WIDTH;
            place(new Floor(below.left - (width - below.width) / 2, width));
            return DROP_PERFECT;
        }
        var left = slider.left > below.left ? slider.left : below.left;
        var right = slider.right() < below.right() ? slider.right() : below.right();
        if (right - left < MIN_OVERLAP) {
            debris.add(new Debris(slider.left, slider.width, floors + 1, side, true));
            phase = PHASE_TOPPLING;
            toppledMs = 0;
            return DROP_MISSED;
        }
        var cutWidth = slider.width - (right - left);
        debris.add(new Debris(side > 0 ? right : slider.left, cutWidth, floors + 1, side, false));
        place(new Floor(left, right - left));
        return DROP_CUT;
    }

    function pause() as Void {
        if (phase == PHASE_SLIDING) {
            phase = PHASE_PAUSED;
        }
    }

    function resume() as Void {
        if (phase == PHASE_PAUSED) {
            phase = PHASE_SLIDING;
        }
    }

    //! Ends the fall at once, for when the app loses the screen mid-topple.
    function finishTopple() as Void {
        if (phase == PHASE_TOPPLING) {
            debris = [] as Array<Debris>;
            phase = PHASE_OVER;
        }
    }

    //! Moves the game on by the real time since the last frame. A long stall (a busy watch, a dropped frame) is
    //! capped rather than simulated, so the floor never jumps unseen past the spot the player was waiting for.
    function advance(elapsedMs as Number) as Void {
        _unsimulatedMs += elapsedMs < MAX_FRAME_MS ? elapsedMs : MAX_FRAME_MS;
        while (_unsimulatedMs >= STEP_MS && isInPlay()) {
            _unsimulatedMs -= STEP_MS;
            if (phase == PHASE_SLIDING) {
                slide();
            } else {
                toppledMs += STEP_MS;
                if (toppledMs >= TOPPLE_MS) {
                    debris = [] as Array<Debris>;
                    phase = PHASE_OVER;
                    return;
                }
            }
            moveDebris();
            moveCamera();
        }
    }

    private function place(floor as Floor) as Void {
        stack.add(floor);
        if (stack.size() > KEPT_FLOORS) {
            stack = stack.slice(1, null);
        }
        floors++;
        if (floors > best) {
            best = floors;
        }
        spawnSlider();
    }

    //! Each floor enters from the side opposite the last, so the player cannot settle into one rhythm.
    private function spawnSlider() as Void {
        slider = new Floor(0.0, top().width);
        _direction = floors % 2 == 0 ? 1 : -1;
        slider.left = _direction > 0 ? minSliderLeft() : maxSliderLeft();
    }

    private function slide() as Void {
        slider.left += _direction * speed() * STEP_MS / 1000;
        var min = minSliderLeft();
        var max = maxSliderLeft();
        if (slider.left > max) {
            slider.left = 2 * max - slider.left;
            _direction = -1;
        } else if (slider.left < min) {
            slider.left = 2 * min - slider.left;
            _direction = 1;
        }
    }

    private function moveDebris() as Void {
        var falling = [] as Array<Debris>;
        for (var i = 0; i < debris.size(); i++) {
            var piece = debris[i];
            piece.ageMs += STEP_MS;
            if (!piece.isGone()) {
                falling.add(piece);
            }
        }
        debris = falling;
    }

    private function moveCamera() as Void {
        var levelsAbove = floors - LEVELS_BELOW_CAMERA;
        var target = levelsAbove > 0 ? FLOOR_PITCH * levelsAbove : 0.0;
        var step = CAMERA_SPEED * STEP_MS / 1000;
        lift = target - lift > step ? lift + step : target;
    }

    private function minSliderLeft() as Float {
        return SLIDE_CENTER - SLIDE_REACH - slider.width / 2;
    }

    private function maxSliderLeft() as Float {
        return SLIDE_CENTER + SLIDE_REACH - slider.width / 2;
    }
}

//! One floor of the tower, in the design's pixels.
class Floor {
    public var left as Float;
    public var width as Float;

    function initialize(left as Float, width as Float) {
        self.left = left;
        self.width = width;
    }

    function right() as Float {
        return left + width;
    }
}

//! A piece cut off the tower, or a whole floor that missed it, falling and spinning away from the tower.
class Debris {
    private const GRAVITY = 900.0;
    private const DRIFT_SPEED = 30.0;
    private const SPIN_DEGREES_PER_S = 240.0;
    //! Long enough to fall past the bottom of the screen from the top of the tower.
    private const LIFETIME_MS = 800;

    public var left as Float;
    public var width as Float;
    public var level as Number;
    //! +1 when it fell off the tower's right side, -1 the left.
    public var side as Number;
    public var isWholeFloor as Boolean;
    public var ageMs as Number = 0;

    function initialize(left as Float, width as Float, level as Number, side as Number, isWholeFloor as Boolean) {
        self.left = left;
        self.width = width;
        self.level = level;
        self.side = side;
        self.isWholeFloor = isWholeFloor;
    }

    function fallen() as Float {
        var seconds = ageMs / 1000.0;
        return GRAVITY * seconds * seconds / 2;
    }

    function drift() as Float {
        return side * DRIFT_SPEED * ageMs / 1000;
    }

    //! Clockwise, so a piece leaving the right side tips outwards.
    function degrees() as Float {
        return side * SPIN_DEGREES_PER_S * ageMs / 1000;
    }

    function isGone() as Boolean {
        return ageMs >= LIFETIME_MS;
    }
}
