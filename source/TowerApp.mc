import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class TowerApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    (:notour)
    function getInitialView() {
        var controller = new TowerController(new BestScore());
        return [new PlayView(controller), new TowerDelegate(controller)];
    }

    (:tour)
    function getInitialView() {
        return [new ScreenshotTour()];
    }
}
