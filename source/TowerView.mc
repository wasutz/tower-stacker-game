import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

class TowerView extends WatchUi.View {
    protected var _game as TowerGame;

    private var _theme as Theme = new Theme();
    private var _type as Typography = new Typography();
    private var _layout as Layout?;

    function initialize(game as TowerGame) {
        View.initialize();
        _game = game;
    }

    function onLayout(dc as Dc) as Void {
        _layout = new Layout(dc);
    }

    function onUpdate(dc as Dc) as Void {
        var layout = _layout as Layout;
        dc.setAntiAlias(true);
        dc.setColor(_theme.background, _theme.background);
        dc.clear();
        switch (_game.phase) {
            case PHASE_START:
                drawStart(dc, layout);
                break;
            case PHASE_PAUSED:
                drawPaused(dc, layout);
                break;
            case PHASE_OVER:
                drawOver(dc, layout);
                break;
            default:
                drawPlay(dc, layout);
                break;
        }
    }

    private function drawStart(dc as Dc, layout as Layout) as Void {
        for (var i = 0; i < layout.START_FLOORS.size(); i++) {
            var floor = layout.START_FLOORS[i] as Array<Float>;
            dc.setColor(_theme.startFloors[i], Graphics.COLOR_TRANSPARENT);
            fillFloor(dc, layout, floor[0], floor[1], floor[2]);
        }
        drawStartArc(dc, layout);
        drawCentered(dc, layout, layout.START_TITLE_TOP, _type.title, _theme.text, "TOWER");
        drawCentered(dc, layout, layout.START_BEST_TOP, _type.record, _theme.muted, "BEST " + _game.best + (_game.best == 1 ? " FLOOR" : " FLOORS"));
        drawCentered(dc, layout, layout.START_PROMPT_TOP, _type.prompt, _theme.accent, "Press START");
    }

    private function drawPlay(dc as Dc, layout as Layout) as Void {
        drawTower(dc, layout);
        if (_game.phase == PHASE_SLIDING) {
            drawGuides(dc, layout);
            drawTrail(dc, layout);
            drawSlider(dc, layout);
        }
        drawCentered(dc, layout, layout.PLAY_SCORE_TOP, _type.score, _theme.text, _game.floors.toString());
        drawCentered(dc, layout, layout.PLAY_CAPTION_TOP, _type.caption, _theme.muted, "FLOORS");
    }

    //! Not in the design: the frozen tower, with the two choices pointed at like the game-over screen.
    private function drawPaused(dc as Dc, layout as Layout) as Void {
        drawTower(dc, layout);
        drawGuides(dc, layout);
        drawSlider(dc, layout);
        drawEdgeArcs(dc, layout);
        drawCentered(dc, layout, layout.PLAY_SCORE_TOP, _type.score, _theme.text, _game.floors.toString());
        drawCentered(dc, layout, layout.PAUSE_VERDICT_TOP, _type.verdict, _theme.accent, "PAUSED");
        drawHints(dc, layout, layout.PAUSE_HINT_TOP, "START resume");
    }

    private function drawOver(dc as Dc, layout as Layout) as Void {
        drawEdgeArcs(dc, layout);
        dc.setColor(_theme.divider, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(layout.stroke(1.0));
        var dividerY = layout.y(layout.OVER_DIVIDER_Y);
        var halfWidth = layout.px(layout.OVER_DIVIDER_HALF_WIDTH);
        dc.drawLine(layout.centerX - halfWidth, dividerY, layout.centerX + halfWidth, dividerY);

        var floors = _game.floors;
        drawCentered(dc, layout, layout.OVER_VERDICT_TOP, _type.verdict, _theme.accent, "TOPPLED");
        drawCentered(dc, layout, layout.OVER_SCORE_TOP, _type.hero, _theme.text, floors.toString());
        drawCentered(dc, layout, layout.OVER_UNIT_TOP, _type.unit, _theme.muted, floors == 1 ? "floor" : "floors");
        if (_game.isNewBest()) {
            drawCentered(dc, layout, layout.OVER_BEST_TOP, _type.best, _theme.accent, "NEW BEST");
        } else {
            drawCentered(dc, layout, layout.OVER_BEST_TOP, _type.best, _theme.muted, "BEST " + _game.best);
        }
        drawHints(dc, layout, layout.OVER_HINT_TOP, "START retry");
    }

    private function drawTower(dc as Dc, layout as Layout) as Void {
        var stack = _game.stack;
        var topIndex = stack.size() - 1;
        for (var i = topIndex; i >= 0; i--) {
            var depth = topIndex - i;
            var floorTop = levelTop(layout, _game.floors - depth);
            if (floorTop > 256) {
                break;
            }
            dc.setColor(_theme.floorShade(depth), Graphics.COLOR_TRANSPARENT);
            fillFloor(dc, layout, stack[i].left, floorTop, stack[i].width);
        }
        drawDebris(dc, layout);
    }

    //! Ticks marking the top floor's edges, so the player can line the sliding floor up with them.
    private function drawGuides(dc as Dc, layout as Layout) as Void {
        var top = _game.top();
        var topEdge = levelTop(layout, _game.floors);
        var far = layout.y(topEdge - layout.GUIDE_FAR);
        var near = layout.y(topEdge - layout.GUIDE_NEAR);
        dc.setColor(_theme.guide, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(layout.stroke(layout.GUIDE_STROKE));
        dc.drawLine(layout.x(top.left), far, layout.x(top.left), near);
        dc.drawLine(layout.x(top.right()), far, layout.x(top.right()), near);
    }

    private function drawTrail(dc as Dc, layout as Layout) as Void {
        var floorTop = levelTop(layout, _game.sliderLevel());
        for (var i = _theme.trail.size() - 1; i >= 0; i--) {
            dc.setColor(_theme.trail[i], Graphics.COLOR_TRANSPARENT);
            fillFloor(dc, layout, _game.sliderLeftBehind(layout.TRAIL_SPACING * (i + 1)), floorTop, _game.slider.width);
        }
    }

    private function drawSlider(dc as Dc, layout as Layout) as Void {
        dc.setColor(_theme.accent, Graphics.COLOR_TRANSPARENT);
        fillFloor(dc, layout, _game.slider.left, levelTop(layout, _game.sliderLevel()), _game.slider.width);
    }

    private function drawDebris(dc as Dc, layout as Layout) as Void {
        var halfHeight = layout.FLOOR_HEIGHT / 2;
        for (var i = 0; i < _game.debris.size(); i++) {
            var piece = _game.debris[i];
            var halfWidth = piece.width / 2;
            var centerX = piece.left + halfWidth + piece.drift();
            var centerY = levelTop(layout, piece.level) + halfHeight + piece.fallen();
            var radians = Math.toRadians(piece.degrees()).toFloat();
            var cos = Math.cos(radians).toFloat();
            var sin = Math.sin(radians).toFloat();
            var corners = [[-halfWidth, -halfHeight], [halfWidth, -halfHeight], [halfWidth, halfHeight], [-halfWidth, halfHeight]];
            var points = [] as Array<Graphics.Point2D>;
            for (var c = 0; c < corners.size(); c++) {
                var dx = corners[c][0];
                var dy = corners[c][1];
                points.add([layout.x(centerX + dx * cos - dy * sin), layout.y(centerY + dx * sin + dy * cos)]);
            }
            dc.setColor(piece.isWholeFloor ? _theme.accent : _theme.debris, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(points);
        }
    }

    //! The design's y of a level's top edge at the camera's current height.
    private function levelTop(layout as Layout, level as Number) as Float {
        return layout.BASE_TOP - _game.FLOOR_PITCH * level + _game.lift;
    }

    private function fillFloor(dc as Dc, layout as Layout, left as Float, top as Float, width as Float) as Void {
        var x = layout.x(left);
        var y = layout.y(top);
        var w = layout.x(left + width) - x;
        var h = layout.y(top + layout.FLOOR_HEIGHT) - y;
        var radius = layout.px(layout.FLOOR_RADIUS);
        if (w > 2 * radius && radius > 0) {
            dc.fillRoundedRectangle(x, y, w, h, radius);
        } else {
            dc.fillRectangle(x, y, w > 1 ? w : 1, h);
        }
    }

    //! The arc beside the START button, pointing at the button that starts a game.
    private function drawStartArc(dc as Dc, layout as Layout) as Void {
        dc.setPenWidth(layout.stroke(layout.EDGE_WIDTH));
        dc.setColor(_theme.accent, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(layout.centerX, layout.centerY, layout.px(layout.EDGE_RADIUS), Graphics.ARC_COUNTER_CLOCKWISE, layout.EDGE_NEAR_DEGREES, layout.EDGE_FAR_DEGREES);
    }

    //! The arcs sit beside the START and BACK buttons, pointing at the two choices.
    private function drawEdgeArcs(dc as Dc, layout as Layout) as Void {
        drawStartArc(dc, layout);
        dc.setColor(_theme.edgeMuted, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(layout.centerX, layout.centerY, layout.px(layout.EDGE_RADIUS), Graphics.ARC_COUNTER_CLOCKWISE, 360 - layout.EDGE_FAR_DEGREES, 360 - layout.EDGE_NEAR_DEGREES);
    }

    private function drawHints(dc as Dc, layout as Layout, designTop as Float, startHint as String) as Void {
        var quitHint = "BACK quit";
        var startWidth = dc.getTextWidthInPixels(startHint, _type.hint);
        var quitWidth = dc.getTextWidthInPixels(quitHint, _type.hint);
        var gap = layout.px(layout.HINT_GAP);
        var left = layout.centerX - (startWidth + gap + quitWidth) / 2;
        var top = layout.y(designTop);
        dc.setColor(_theme.accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, top, _type.hint, startHint, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(_theme.muted, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + startWidth + gap, top, _type.hint, quitHint, Graphics.TEXT_JUSTIFY_LEFT);
    }

    private function drawCentered(dc as Dc, layout as Layout, designTop as Float, font as FontResource, color as Number, text as String) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(layout.centerX, layout.y(designTop), font, text, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
