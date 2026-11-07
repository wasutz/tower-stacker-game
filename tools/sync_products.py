#!/usr/bin/env python3
"""Rewrite the <iq:products> list in manifest.xml from the devices installed by the Connect IQ SDK Manager.

A device qualifies when its screen is one Tower ships fonts for, it supports watch apps, it shows at least
64 colours (the stack needs dim and lit shades), it has a BACK button (pause and quit rely on it, and
swipes are taken by the game) and it runs a Connect IQ version at or above the manifest's minApiLevel. Run it after downloading new devices, then rebuild every product (tools/build.sh --all) and test
in the simulator.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from generate_fonts import FAMILIES

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "manifest.xml"
DEVICES = Path.home() / "Library/Application Support/Garmin/ConnectIQ/Devices"
MIN_BITS_PER_PIXEL = 8


def version(text: str) -> tuple[int, ...]:
    return tuple(int(part) for part in text.split("."))


def has_back_button(device: Path) -> bool:
    keys = json.loads((device / "simulator.json").read_text(encoding="utf-8")).get("keys", [])
    return any(key.get("id") == "esc" for key in keys)


def qualifies(spec: dict, min_api: tuple[int, ...]) -> bool:
    newest = max((version(p["connectIQVersion"]) for p in spec.get("partNumbers", [])), default=(0,))
    return (
        spec.get("deviceFamily") in FAMILIES
        and spec.get("bitsPerPixel", 0) >= MIN_BITS_PER_PIXEL
        and any(app["type"] == "watchApp" for app in spec.get("appTypes", []))
        and newest >= min_api
    )


def main() -> None:
    manifest = MANIFEST.read_text(encoding="utf-8")
    min_api = version(re.search(r'minApiLevel="([\d.]+)"', manifest).group(1))
    products = sorted(
        path.parent.name
        for path in DEVICES.glob("*/compiler.json")
        if qualifies(json.loads(path.read_text(encoding="utf-8")), min_api) and has_back_button(path.parent)
    )
    entries = "\n".join(f'            <iq:product id="{p}"/>' for p in products)
    manifest = re.sub(
        r"<iq:products>.*?</iq:products>",
        f"<iq:products>\n{entries}\n        </iq:products>",
        manifest,
        flags=re.S,
    )
    MANIFEST.write_text(manifest, encoding="utf-8")
    print(f"{len(products)} products written to {MANIFEST.name}")


if __name__ == "__main__":
    main()
