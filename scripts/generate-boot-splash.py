#!/usr/bin/env python3
"""Generate a minimal dark boot splash BMP for systemd-boot UKI embedding.

Matches the host monitor resolution for a clean native-resolution boot screen.
Designed for OLED/4K displays: pure black background with subtle geometric accents.
"""

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.pretty import pretty
from PIL import Image, ImageDraw


def parse_display(display: str) -> tuple[int, int]:
    m = re.match(r"(\d+)x(\d+)", display)
    if not m:
        raise ValueError(f"Cannot parse display resolution from: {display}")
    return int(m.group(1)), int(m.group(2))


def generate_splash(width: int, height: int, output: str) -> None:
    img = Image.new("RGB", (width, height), color=(0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx, cy = width // 2, height // 2
    scale = min(width, height) // 600  # proportional to display size

    r_outer = 24 * scale
    r_inner = 8 * scale
    r_circle = 3 * scale
    dark = (28, 28, 32)   # near-black, visible only on close inspection
    dim = (18, 18, 22)    # even subtler

    # outer diamond
    pts_outer = [
        (cx, cy - r_outer),
        (cx + r_outer, cy),
        (cx, cy + r_outer),
        (cx - r_outer, cy),
    ]
    draw.polygon(pts_outer, outline=dark, width=max(1, scale // 2))

    # inner diamond (offset 45° — creates an 8-point star silhouette)
    pts_inner = [
        (cx, cy - r_inner),
        (cx + r_inner, cy),
        (cx, cy + r_inner),
        (cx - r_inner, cy),
    ]
    draw.polygon(pts_inner, outline=dim, width=max(1, scale // 3))

    # centered circle
    draw.ellipse(
        [cx - r_circle, cy - r_circle, cx + r_circle, cy + r_circle],
        outline=dark,
        width=max(1, scale // 4),
    )

    img.save(output, "BMP")
    pretty.ok(f"Generated {width}x{height} splash → {pretty.filepath(output)}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate a minimal dark boot splash BMP for systemd-boot UKI"
    )
    parser.add_argument("--display", type=str, default=None,
                        help="Display resolution (e.g. 3840x2160@240). Overrides --width/--height.")
    parser.add_argument("--width", type=int, default=3840, help="Splash width (default: 3840)")
    parser.add_argument("--height", type=int, default=2160, help="Splash height (default: 2160)")
    parser.add_argument(
        "--output", type=str,
        default="/usr/share/systemd/bootctl/splash-custom.bmp",
        help="Output BMP path",
    )
    args = parser.parse_args()
    if args.display:
        width, height = parse_display(args.display)
    else:
        width, height = args.width, args.height
    generate_splash(width, height, args.output)


if __name__ == "__main__":
    main()
