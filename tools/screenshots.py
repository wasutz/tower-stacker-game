#!/usr/bin/env python3
"""Capture every game screen from the Connect IQ simulator and build a contact sheet per device.

The app is built with the screenshot tour (source/ScreenshotTour.mc, tools/tour.jungle), which plays a scripted
game and prints "SHOT <name>" after each redraw; this script captures the simulator window on each line and
crops the watch screen using the device's simulator.json.

macOS only: needs Screen Recording permission for the terminal, and swiftc (Xcode command line tools) to look
up the simulator window.

Usage:
    .venv/bin/python tools/screenshots.py                 # one device per screen class (DEVICES)
    .venv/bin/python tools/screenshots.py fr965 fenix7

Output: screenshots/<device>/<name>.png at native resolution and screenshots/contact-<device>.png.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "screenshots"
DEVICES = ["fr965", "fenix7", "fr245", "fenix5plus", "venu3", "venusq2", "venusq", "fenix9pro51mm", "vivoactive4s"]
CIQ_HOME = Path.home() / "Library" / "Application Support" / "Garmin" / "ConnectIQ"
WINDOW_TOOL = ROOT / "bin" / "simulator-window"
# Height of the simulator window's title bar, in points, above the device image.
TITLE_BAR_PT = 28
TOUR_TIMEOUT_S = 90
CAPTURE_ATTEMPTS = 3
THUMB = 227

WINDOW_TOOL_SOURCE = """
import CoreGraphics
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in windows where (w[kCGWindowOwnerName as String] as? String ?? "").contains("Simulator") {
    let b = w[kCGWindowBounds as String] as! [String: Any]
    print(w[kCGWindowNumber as String]!, b["Width"]!, b["Height"]!)
}
"""


def sdk_home() -> Path:
    return Path((CIQ_HOME / "current-sdk.cfg").read_text().strip().rstrip("/"))


def java_env() -> dict[str, str]:
    env = dict(os.environ)
    env["PATH"] = "/opt/homebrew/opt/openjdk/bin:" + env["PATH"]
    return env


def simulator_window() -> tuple[int, float, float] | None:
    if not WINDOW_TOOL.exists():
        source = WINDOW_TOOL.with_suffix(".swift")
        source.write_text(WINDOW_TOOL_SOURCE)
        subprocess.run(["swiftc", "-O", str(source), "-o", str(WINDOW_TOOL)], check=True)
    lines = subprocess.run([str(WINDOW_TOOL)], capture_output=True, text=True).stdout.split("\n")
    windows = [(int(w), float(width), float(height)) for w, width, height in (l.split() for l in lines if l)]
    # The device window is the simulator's largest; dialogs and menus come and go beside it.
    return max(windows, key=lambda w: w[1] * w[2], default=None)


def restart_simulator() -> None:
    subprocess.run(["pkill", "-f", "ConnectIQ.app"])
    subprocess.run(["pkill", "-f", "monkeydo"])
    time.sleep(3)
    subprocess.run(["open", str(sdk_home() / "bin" / "ConnectIQ.app")], check=True)
    for _ in range(60):
        if simulator_window():
            time.sleep(5)
            return
        time.sleep(1)
    raise SystemExit("simulator window did not appear")


def build(device: str) -> Path:
    prg = ROOT / "bin" / f"Tower-tour-{device}.prg"
    subprocess.run([str(sdk_home() / "bin" / "monkeyc"), "-f", f"{ROOT / 'monkey.jungle'};{ROOT / 'tools' / 'tour.jungle'}",
                    "-y", str(ROOT / "developer_key.der"), "-l", "2", "-d", device, "-o", str(prg)],
                   check=True, env=java_env(), stdout=subprocess.DEVNULL)
    return prg


def device_is_round(device: str) -> bool:
    return json.loads((CIQ_HOME / "Devices" / device / "compiler.json").read_text())["deviceFamily"].startswith("round")


def screen_rect(device: str) -> tuple[int, int, int, int]:
    location = json.loads((CIQ_HOME / "Devices" / device / "simulator.json").read_text())["display"]["location"]
    return location["x"], location["y"], location["width"], location["height"]


def capture(device: str, path: Path) -> None:
    raw = path.with_suffix(".raw.png")
    for _ in range(CAPTURE_ATTEMPTS):
        window, width_pt, _ = simulator_window()
        if subprocess.run(["screencapture", "-x", "-o", "-l", str(window), str(raw)]).returncode == 0:
            break
        time.sleep(0.2)
    else:
        raise SystemExit(f"could not capture {path.name}")
    image = Image.open(raw)
    scale = image.width / width_pt
    x, y, w, h = screen_rect(device)
    box = tuple(round(v * scale) for v in (x, y + TITLE_BAR_PT, x + w, y + TITLE_BAR_PT + h))
    screen = image.crop(box).convert("RGB").resize((w, h), Image.LANCZOS)
    if device_is_round(device):
        mask = Image.new("L", (w, h))
        ImageDraw.Draw(mask).ellipse((0, 0, w - 1, h - 1), fill=255)
        screen = Image.composite(screen, Image.new("RGB", (w, h)), mask)
    screen.save(path)
    raw.unlink()


def tour(device: str) -> list[Path]:
    restart_simulator()
    prg = build(device)
    folder = OUT / device
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("*.png"):
        old.unlink()
    run = subprocess.Popen([str(sdk_home() / "bin" / "monkeydo"), str(prg), device], stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, text=True, env=java_env())
    shots = []
    deadline = time.time() + TOUR_TIMEOUT_S
    try:
        for line in run.stdout:
            if line.startswith("SHOT "):
                path = folder / f"{line.split()[1]}.png"
                # The simulator repaints just after the print; let the frame land.
                time.sleep(0.4)
                capture(device, path)
                shots.append(path)
            if line.startswith("TOUR DONE") or time.time() > deadline:
                break
    finally:
        run.terminate()
    return shots


def contact_sheet(device: str, shots: list[Path]) -> None:
    sheet = Image.new("RGB", (THUMB * len(shots), THUMB), (24, 24, 24))
    for i, shot in enumerate(shots):
        image = Image.open(shot)
        image.thumbnail((THUMB, THUMB), Image.LANCZOS)
        sheet.paste(image, (i * THUMB, 0))
    sheet.save(OUT / f"contact-{device}.png")


def main(argv: list[str]) -> None:
    for device in argv or DEVICES:
        shots = tour(device)
        contact_sheet(device, shots)
        print(f"{device}: {len(shots)} shots")


if __name__ == "__main__":
    main(sys.argv[1:])
