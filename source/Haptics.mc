import Toybox.Attention;
import Toybox.Lang;

//! A tick for every floor placed, so the rhythm of the stack can be felt; a perfect drop ticks twice.
module Haptics {
    const FULL_STRENGTH = 100;
    const OFF = 0;
    const TICK_MS = 40;
    const TICK_GAP_MS = 50;
    const TOPPLE_MS = 400;

    function playFloor() as Void {
        play([TICK_MS]);
    }

    function playPerfect() as Void {
        play([TICK_MS, TICK_GAP_MS, TICK_MS]);
    }

    function playTopple() as Void {
        play([TOPPLE_MS]);
    }

    //! Alternating on and off durations in milliseconds.
    function play(rhythm as Array<Number>) as Void {
        if (!(Attention has :vibrate)) {
            return;
        }
        var profiles = [] as Array<Attention.VibeProfile>;
        for (var i = 0; i < rhythm.size(); i++) {
            var strength = i % 2 == 0 ? FULL_STRENGTH : OFF;
            profiles.add(new Attention.VibeProfile(strength, rhythm[i]));
        }
        Attention.vibrate(profiles);
    }
}
