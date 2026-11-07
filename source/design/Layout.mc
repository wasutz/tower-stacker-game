import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Maps the design's 256 px round display onto the largest centred circle of any screen. Values below are
//! the design's pixels, kept literal so they can be checked against it.
class Layout {
    private const DESIGN_DIAMETER = 256.0;
    private const DESIGN_CENTER = 128.0;

    public const EDGE_RADIUS = 122.0;
    public const EDGE_WIDTH = 4.0;
    public const EDGE_NEAR_DEGREES = 20;
    public const EDGE_FAR_DEGREES = 40;

    public const FLOOR_HEIGHT = 12.0;
    public const FLOOR_RADIUS = 2.0;
    //! Top edge of the base floor before the camera rises.
    public const BASE_TOP = 200.0;
    //! The alignment ticks under the sliding floor, measured up from the top floor's top edge.
    public const GUIDE_FAR = 8.0;
    public const GUIDE_NEAR = 2.0;
    public const GUIDE_STROKE = 1.0;
    public const TRAIL_SPACING = 14.0;

    public const START_TITLE_TOP = 58.0;
    public const START_BEST_TOP = 98.0;
    public const START_PROMPT_TOP = 196.0;
    //! The three floors on the start screen, top first: [left, top, width] each.
    public const START_FLOORS = [[98.0, 136.0, 60.0], [93.0, 150.0, 70.0], [88.0, 164.0, 80.0]];

    public const PLAY_SCORE_TOP = 26.0;
    public const PLAY_CAPTION_TOP = 60.0;

    public const PAUSE_VERDICT_TOP = 60.0;
    public const PAUSE_HINT_TOP = 84.0;

    public const OVER_VERDICT_TOP = 50.0;
    public const OVER_SCORE_TOP = 68.0;
    public const OVER_UNIT_TOP = 136.0;
    public const OVER_DIVIDER_Y = 164.0;
    public const OVER_DIVIDER_HALF_WIDTH = 40.0;
    public const OVER_BEST_TOP = 172.0;
    public const OVER_HINT_TOP = 196.0;
    public const HINT_GAP = 14.0;

    public var centerX as Number;
    public var centerY as Number;

    private var _scale as Float;

    function initialize(dc as Dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        centerX = width / 2;
        centerY = height / 2;
        _scale = (width < height ? width : height) / DESIGN_DIAMETER;
    }

    function px(designPx as Float) as Number {
        return Math.round(designPx * _scale).toNumber();
    }

    //! A stroke width that stays visible however far the design is scaled down.
    function stroke(designPx as Float) as Number {
        var scaled = px(designPx);
        return scaled > 1 ? scaled : 1;
    }

    function x(designX as Float) as Number {
        return centerX + px(designX - DESIGN_CENTER);
    }

    function y(designY as Float) as Number {
        return centerY + px(designY - DESIGN_CENTER);
    }
}
