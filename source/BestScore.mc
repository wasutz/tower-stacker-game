import Toybox.Application;
import Toybox.Lang;

class BestScore {
    private const KEY = "best";

    function initialize() {
    }

    function load() as Number {
        var stored = Storage.getValue(KEY);
        return stored instanceof Number ? stored : 0;
    }

    function save(best as Number) as Void {
        Storage.setValue(KEY, best);
    }
}
