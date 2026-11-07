import Toybox.Lang;

//! The game screen as the player sees it: the game pauses whenever the app loses the screen, and waits paused
//! for START when it comes back.
(:notour)
class PlayView extends TowerView {
    private var _controller as TowerController;

    function initialize(controller as TowerController) {
        TowerView.initialize(controller.game);
        _controller = controller;
    }

    function onHide() as Void {
        _controller.suspend();
    }
}
