import Toybox.Lang;
import Toybox.System;

//! Colours from the design, on black, with its opacities flattened onto black. Non-AMOLED targets get the nearest
//! legible 64-colour match, where the design's faint shades would round down to invisible (channels step
//! 0x00/0x55/0xAA/0xFF).
class Theme {
    public var background as Number = 0x000000;
    public var text as Number = 0xFFFFFF;
    public var muted as Number;
    public var accent as Number;
    //! Placed floors from the top of the tower down; floors deeper than the list take its last colour.
    public var floorShades as Array<Number>;
    //! The start screen's floors, top first.
    public var startFloors as Array<Number>;
    //! Ghosts behind the sliding floor, nearest first.
    public var trail as Array<Number>;
    public var guide as Number;
    public var debris as Number;
    public var edgeMuted as Number;
    public var divider as Number;

    function initialize() {
        if (System.getDeviceSettings().requiresBurnInProtection) {
            muted = 0x9AA0AA;
            accent = 0xFFC23D;
            floorShades = [0xCC9B31, 0x8C6B22, 0x4D3A12, 0x373A42, 0x30333A, 0x2A2D33];
            startFloors = [0xFFC23D, 0x997425, 0x4D3A12];
            trail = [0x40310F, 0x1A1306];
            guide = 0x3A3D44;
            debris = 0x6B707A;
            edgeMuted = 0x6B707A;
            divider = 0x2E3138;
        } else {
            muted = 0xAAAAAA;
            accent = 0xFFAA00;
            floorShades = [0xAA5500, 0x555500, 0x555555];
            startFloors = [0xFFAA00, 0xAA5500, 0x555500];
            trail = [0x555500];
            guide = 0x555555;
            debris = 0xAAAAAA;
            edgeMuted = 0xAAAAAA;
            divider = 0x555555;
        }
    }

    function floorShade(depth as Number) as Number {
        var last = floorShades.size() - 1;
        return floorShades[depth < last ? depth : last];
    }
}
