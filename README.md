# Tower

A one-button stacking game for Garmin watches. A floor slides back and forth above the tower; drop it on the
stack. Any overhang is cut off, so the tower narrows until a floor misses it.

Watch app, Connect IQ API 3.2+, 108 products: round screens from 218 to 466 px plus Venu Sq, Venu Sq 2 and Venu X1.
Monochrome and 8-colour screens (Instinct, Descent G1, Forerunner 55), watches without a BACK button (vívoactive 3
Music) and bike or handheld units are not targeted.

## Controls

| Input | In a game | Paused | Start and game over |
| --- | --- | --- | --- |
| START | Drop the floor | Resume | Start or retry |
| BACK | Pause | Quit | Quit |
| Tap | Drop the floor | Resume | Start or retry |

The score is the number of floors placed on the base. A drop within 3 px of the floor below is perfect: it lands
aligned, wins back 4 px of width (up to the base's width) and ticks twice instead of once. The floor's centre
swings 64 px either side of the screen's centre, so a full-width floor cannot miss: the game only ends once cuts
have narrowed the tower. Speed starts at 80 px/s and rises by 3 px/s per floor up to 190 px/s (design pixels on a
256 px screen).

The best score is saved when a game ends or pauses. If the app loses the screen mid-game, the game waits paused.

## Project layout

```
manifest.xml
monkey.jungle
source/
  TowerApp.mc               app entry
  TowerController.mc        frame timer while the floor slides or the tower topples; redraws, haptics, saved best
  BestScore.mc              best score in app storage
  TowerDelegate.mc          buttons and touch
  TowerView.mc              all drawing
  PlayView.mc               TowerView plus pause on hide
  Haptics.mc                floor, perfect and topple vibrations
  ScreenshotTour.mc         scripted games for tools/screenshots.py (tour builds only)
  game/TowerGame.mc         the rules in fixed 10 ms steps, free of timers and drawing
  design/Theme.mc           AMOLED and 64-colour palettes
  design/Layout.mc          the design's 256 px geometry, scaled to any screen
  design/Typography.mc      bitmap fonts
  test/                     unit tests for the rules and the key event handling
resources/                  app name, 65 px launcher icon
resources-<family>/         bitmap fonts per screen, 40 px launcher icon on small screens (generated)
tools/
  build.sh                  build one device, all devices, the unit tests, or the store package
  generate_fonts.py         Space Grotesk to BMFont atlases per screen
  generate_launcher_icon.py launcher icons and the 500 px store icon
  sync_products.py          manifest product list from the installed SDK devices
  screenshots.py            captures every screen from the simulator
docs/store/                 store listing text and icon
screenshots/                simulator captures per device, for the store listing
LICENSES/                   font licence
```

## Tuning

Slide, cut and camera constants live in `source/game/TowerGame.mc`; debris physics in its `Debris` class. Run
`tools/build.sh --test fr965` after any change.

## Build

Requirements: Connect IQ SDK (built and tested with 9.3.0) with the devices downloaded in the SDK Manager, a JDK,
and a developer key. Keep `developer_key.der` safe: store updates must be signed with the same key.

```sh
tools/build.sh venu3            # bin/Tower-venu3.prg
tools/build.sh --run fenix7     # build and load into the simulator
tools/build.sh --test fr965     # run the unit tests in the simulator
tools/build.sh --all            # build every product in manifest.xml
tools/build.sh --package        # bin/Tower.iq for the store
```

`build.sh` uses `$CIQ_SDK` and `$CIQ_DEVELOPER_KEY` when set, otherwise the SDK Manager's current SDK and
`./developer_key.der`. If `/usr/bin/java` has no registered JDK it falls back to Homebrew's OpenJDK.

Regenerating assets needs Python with `tools/requirements.txt`:

```sh
python3 -m venv .venv && .venv/bin/pip install -r tools/requirements.txt
.venv/bin/python tools/generate_fonts.py
.venv/bin/python tools/generate_launcher_icon.py
.venv/bin/python tools/sync_products.py
.venv/bin/python tools/screenshots.py
```

## Licences

Space Grotesk is licensed under the SIL Open Font License, see `LICENSES/SpaceGrotesk-OFL.txt`.
