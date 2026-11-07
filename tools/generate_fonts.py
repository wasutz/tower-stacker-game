#!/usr/bin/env python3
"""Generate Tower's bitmap fonts (BMFont text format) for every supported screen.

Connect IQ custom fonts are pre-rasterised, so each screen size gets its own glyph atlases. Sizes are the
design's CSS pixel sizes (drawn on a 256 px display) scaled by the screen's short side, with a floor so small
MIP screens stay legible.

Every font's line box reproduces the CSS line box of the design: a font declared with `line-height: 1` gets a
line exactly one em tall, a font with `line-height: normal` gets ascent + descent. Dc.drawText places y at the
top of the line box, so drawing at a CSS box top puts the ink where the browser put it, which keeps
Layout.mc a direct transcription of the design.

Usage:
    .venv/bin/python tools/generate_fonts.py                 # all screens
    .venv/bin/python tools/generate_fonts.py round-260x260   # selected device families only
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "tools" / "font-sources"
MEDIUM = SOURCES / "SpaceGrotesk-Medium.ttf"
BOLD = SOURCES / "SpaceGrotesk-Bold.ttf"

REFERENCE_DIAMETER = 256
FAMILIES = [
    "round-218x218",
    "round-240x240",
    "round-260x260",
    "round-280x280",
    "round-360x360",
    "round-390x390",
    "round-416x416",
    "round-454x454",
    "round-466x466",
    "rectangle-240x240",
    "rectangle-320x360",
    "rectangle-448x486",
]

DIGITS = "0123456789"
LINE_HEIGHT_NORMAL = None


@dataclass
class FontSpec:
    name: str
    source: Path
    reference_px: float
    # Character sets must cover the text TowerView.mc draws in this font.
    chars: str
    line_height_em: float | None = LINE_HEIGHT_NORMAL
    tracking_em: float = 0.0
    tabular: bool = False
    min_px: int = 0


FONTS = [
    FontSpec("title", BOLD, 30, "TOWER", tracking_em=0.12),
    FontSpec("record", MEDIUM, 12, "BEST FLOR" + DIGITS, tracking_em=0.08, tabular=True, min_px=10),
    FontSpec("prompt", MEDIUM, 13, "Pres START", min_px=11),
    FontSpec("score", BOLD, 28, DIGITS, line_height_em=1.0, tabular=True),
    FontSpec("caption", MEDIUM, 10, "FLORS", tracking_em=0.16, min_px=9),
    FontSpec("best", MEDIUM, 11, "BEST NW" + DIGITS, tracking_em=0.1, tabular=True, min_px=10),
    FontSpec("verdict", MEDIUM, 12, "TOPLEDAUS", tracking_em=0.22, min_px=10),
    FontSpec("hero", BOLD, 56, DIGITS, line_height_em=1.1, tabular=True),
    FontSpec("unit", MEDIUM, 12, "floors", min_px=10),
    FontSpec("hint", MEDIUM, 11, "START retry BACK quit resume", min_px=10),
]


@dataclass
class Glyph:
    char: str
    image: Image.Image | None
    xoffset: int
    yoffset: int
    xadvance: int
    x: int = 0
    y: int = 0


@dataclass
class BitmapFont:
    name: str
    line_height: int
    base: int
    glyphs: list[Glyph] = field(default_factory=list)


def short_side(family: str) -> int:
    width, height = re.search(r"(\d+)x(\d+)", family).groups()
    return min(int(width), int(height))


def font_px(spec: FontSpec, diameter: int) -> int:
    return max(spec.min_px, round(spec.reference_px * diameter / REFERENCE_DIAMETER))


def vertical_metrics(path: Path) -> tuple[float, float]:
    """Ascent and descent in em, as browsers use them for `line-height: normal` (hhea and typo metrics agree in Space Grotesk)."""
    font = TTFont(str(path))
    upm = font["head"].unitsPerEm
    return font["hhea"].ascent / upm, -font["hhea"].descent / upm


def render_char(font: ImageFont.FreeTypeFont, char: str, features: list[str]):
    left, top, right, bottom = font.getbbox(char, anchor="ls", features=features)
    if right <= left or bottom <= top:
        return None, left, top
    image = Image.new("L", (right - left, bottom - top), 0)
    ImageDraw.Draw(image).text((-left, -top), char, font=font, fill=255, anchor="ls", features=features)
    # Pillow's box spans the advance as well as the ink; crop to the ink to keep atlases small.
    ink = image.getbbox()
    if ink is None:
        return None, left, top
    return image.crop(ink), left + ink[0], top + ink[1]


def build_font(spec: FontSpec, diameter: int) -> BitmapFont:
    size = font_px(spec, diameter)
    font = ImageFont.truetype(str(spec.source), size, layout_engine=ImageFont.Layout.RAQM)
    features = ["tnum"] if spec.tabular else []
    tracking = round(spec.tracking_em * size)
    ascent, descent = vertical_metrics(spec.source)

    content = (ascent + descent) * size
    line_height = content if spec.line_height_em is None else spec.line_height_em * size
    baseline = (line_height - content) / 2 + ascent * size

    # Equal digit advances keep counters from jittering; the max() also covers fonts left proportional.
    digit_advance = max(font.getlength(d, features=features) for d in DIGITS) if spec.tabular else None

    bitmap = BitmapFont(spec.name, line_height=round(line_height), base=round(baseline))
    for char in dict.fromkeys(spec.chars):
        image, left, top = render_char(font, char, features)
        advance = font.getlength(char, features=features)
        if digit_advance is not None and char in DIGITS:
            left += round((digit_advance - advance) / 2)
            advance = digit_advance
        bitmap.glyphs.append(Glyph(char, image, left, round(baseline) + top, round(advance) + tracking))
    return bitmap


def pack(bitmap: BitmapFont) -> Image.Image:
    padding = 2
    images = [g for g in bitmap.glyphs if g.image is not None]
    total_area = sum((g.image.width + padding) * (g.image.height + padding) for g in images)
    atlas_w = 32
    while atlas_w * atlas_w < total_area * 1.3 or atlas_w < max(g.image.width for g in images) + padding:
        atlas_w *= 2
    x = y = shelf = 0
    for glyph in sorted(images, key=lambda g: -g.image.height):
        if x + glyph.image.width + padding > atlas_w:
            x, y, shelf = 0, y + shelf, 0
        glyph.x, glyph.y = x, y
        x += glyph.image.width + padding
        shelf = max(shelf, glyph.image.height + padding)
    atlas = Image.new("RGBA", (atlas_w, max(8, y + shelf)), (255, 255, 255, 0))
    for glyph in images:
        white = Image.new("RGBA", glyph.image.size, (255, 255, 255, 255))
        white.putalpha(glyph.image)
        atlas.paste(white, (glyph.x, glyph.y))
    return atlas


def write_font(bitmap: BitmapFont, directory: Path) -> None:
    atlas = pack(bitmap)
    png_name = f"{bitmap.name}.png"
    atlas.save(directory / png_name, optimize=True)
    lines = [
        f'info face="Tower-{bitmap.name}" size={bitmap.line_height} bold=0 italic=0 charset="" unicode=1 '
        f"stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=2,2",
        f"common lineHeight={bitmap.line_height} base={bitmap.base} scaleW={atlas.width} scaleH={atlas.height} pages=1 packed=0",
        f'page id=0 file="{png_name}"',
        f"chars count={len(bitmap.glyphs)}",
    ]
    for g in bitmap.glyphs:
        w, h = (g.image.width, g.image.height) if g.image else (0, 0)
        lines.append(
            f"char id={ord(g.char)} x={g.x} y={g.y} width={w} height={h} "
            f"xoffset={g.xoffset} yoffset={g.yoffset} xadvance={g.xadvance} page=0 chnl=15"
        )
    (directory / f"{bitmap.name}.fnt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def fonts_xml() -> str:
    rows = "\n".join(
        f'    <font id="{spec.name.capitalize()}" filename="{spec.name}.fnt" antialias="true"/>' for spec in FONTS
    )
    return f"<fonts>\n{rows}\n</fonts>\n"


def generate(family: str) -> Path:
    directory = ROOT / f"resources-{family}" / "fonts"
    directory.mkdir(parents=True, exist_ok=True)
    diameter = short_side(family)
    for spec in FONTS:
        write_font(build_font(spec, diameter), directory)
    (directory / "fonts.xml").write_text(fonts_xml(), encoding="utf-8")
    return directory


def main(argv: list[str]) -> None:
    for family in argv or FAMILIES:
        print(f"{family} -> {generate(family).relative_to(ROOT)}")


if __name__ == "__main__":
    main(sys.argv[1:])
