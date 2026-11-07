#!/usr/bin/env python3
"""Render the launcher icon and the store icon: the start screen's three floors, narrowing upwards, drawn at 8x
and downsampled.

Small screens use 40 px icons and the rest 65 px (compiler.json "launcherIcon"); the compiler rescales to each
product's exact size, so one icon per class keeps the edges crisp.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SMALL_FAMILIES = [
    "round-218x218",
    "round-240x240",
    "round-260x260",
    "round-280x280",
    "rectangle-240x240",
    "rectangle-320x360",
]
TARGETS = {
    ROOT / "resources" / "drawables": 65,
    **{ROOT / f"resources-{family}" / "drawables": 40 for family in SMALL_FAMILIES},
}
STORE_ICON = ROOT / "docs" / "store" / "icon-500.png"
DRAWABLES_XML = '<drawables>\n    <bitmap id="LauncherIcon" filename="launcher_icon.png"/>\n</drawables>\n'
SUPERSAMPLE = 8

# The design's accent at 100 %, 60 % and 30 % opacity on black, top floor first.
FLOOR_COLORS = [(0xFF, 0xC2, 0x3D, 255), (0x99, 0x74, 0x25, 255), (0x4D, 0x3A, 0x12, 255)]
# The icon is a 100-unit square; floors are taller than the design's so they read at 40 px.
FLOOR_WIDTHS = [44, 54, 64]
FLOOR_HEIGHT = 14
FLOOR_GAP = 4
FLOOR_RADIUS = 2.5


def render(size: int) -> Image.Image:
    s = size * SUPERSAMPLE
    unit = s / 100
    image = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse([0, 0, s - 1, s - 1], fill=(0, 0, 0, 255))

    stack_height = len(FLOOR_WIDTHS) * FLOOR_HEIGHT + (len(FLOOR_WIDTHS) - 1) * FLOOR_GAP
    top = 50 - stack_height / 2
    for width, color in zip(FLOOR_WIDTHS, FLOOR_COLORS):
        left = 50 - width / 2
        box = [left * unit, top * unit, (left + width) * unit, (top + FLOOR_HEIGHT) * unit]
        draw.rounded_rectangle(box, radius=FLOOR_RADIUS * unit, fill=color)
        top += FLOOR_HEIGHT + FLOOR_GAP
    return image.resize((size, size), Image.LANCZOS)


def main() -> None:
    for directory, size in TARGETS.items():
        directory.mkdir(parents=True, exist_ok=True)
        render(size).save(directory / "launcher_icon.png", optimize=True)
        (directory / "drawables.xml").write_text(DRAWABLES_XML, encoding="utf-8")
        print(f"{size}px -> {directory.relative_to(ROOT)}")
    STORE_ICON.parent.mkdir(parents=True, exist_ok=True)
    render(500).save(STORE_ICON, optimize=True)
    print(f"500px -> {STORE_ICON.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
