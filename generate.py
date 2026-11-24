#!/usr/bin/env python3
"""Generate EMI "H pattern" images (Quantum Data / LeCroy style) at any resolution.

The screen is tiled edge-to-edge with a bitmap "H" (no gaps between characters).
Output is pixel-exact, so generate it at the SAME resolution as the HDMI mode
under test -- if a sink rescales it, the 1px strokes blur and the EMI stress is lost.

Output layout (per resolution WxH, under --out, default ./patterns):

  patterns/1920x1080/
      white-on-black_small_static.png
      white-on-black_large_static.png
      black-on-white_small_static.png
      black-on-white_large_static.png
      white-on-black_small_scroll/000.png 001.png ...   (one seamless scroll period)
      ... (same for each polarity/size)

Examples
  ./generate.py                          # 1920x1080
  ./generate.py -r 1280x720 1920x1080 3840x2160
  ./generate.py -r 1080p 4k --speed 2    # presets: 720p 1080p 1440p 4k
  ./generate.py --large-scale 3
"""
import argparse
import math
import os
import shutil
import sys

import numpy as np
from PIL import Image

# 5x7 bitmap "H" in an 8x8 cell (glyph at col 1..5, row 0..6; rest is spacing).
H_GLYPH = [
    "X...X",
    "X...X",
    "X...X",
    "XXXXX",
    "X...X",
    "X...X",
    "X...X",
]
CELL_W, CELL_H = 8, 8
GLYPH_X, GLYPH_Y = 1, 0

PRESETS = {"720p": (1280, 720), "1080p": (1920, 1080), "1440p": (2560, 1440), "4k": (3840, 2160)}


def parse_res(s: str):
    s = s.lower()
    if s in PRESETS:
        return PRESETS[s]
    try:
        w, h = s.split("x")
        return int(w), int(h)
    except ValueError:
        raise argparse.ArgumentTypeError(f"bad resolution '{s}' (use WxH or {'/'.join(PRESETS)})")


def make_cell(scale: int) -> np.ndarray:
    cell = np.zeros((CELL_H, CELL_W), dtype=bool)
    for r, row in enumerate(H_GLYPH):
        for c, ch in enumerate(row):
            if ch == "X":
                cell[GLYPH_Y + r, GLYPH_X + c] = True
    return np.kron(cell, np.ones((scale, scale), dtype=bool)) if scale > 1 else cell


def make_wide(w, h, cell, black_on_white) -> np.ndarray:
    """GRAY8 image, h x (>= w + one cell), so scroll frames are plain crops."""
    ch, cw = cell.shape
    tiled = np.tile(cell, (math.ceil(h / ch), math.ceil(w / cw) + 1))[:h]
    ink, bg = (0, 255) if black_on_white else (255, 0)
    return np.where(tiled, ink, bg).astype(np.uint8)


def save(arr, path):
    Image.fromarray(np.ascontiguousarray(arr), mode="L").save(path, optimize=False, compress_level=1)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("-r", "--res", nargs="+", type=parse_res, default=[(1920, 1080)],
                    help="one or more resolutions: WxH or 720p/1080p/1440p/4k (default 1920x1080)")
    ap.add_argument("-o", "--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "patterns"))
    ap.add_argument("--large-scale", type=int, default=4, help="glyph scale for 'large' (default 4 -> 32x32 cell)")
    ap.add_argument("--speed", type=int, default=1, help="scroll speed in px/frame baked into the frame set (default 1)")
    ap.add_argument("--direction", choices=["left", "right"], default="left")
    ap.add_argument("--no-scroll", action="store_true", help="only write the static PNGs")
    a = ap.parse_args()

    sizes = {"small": 1, "large": a.large_scale}
    for (w, h) in a.res:
        d = os.path.join(a.out, f"{w}x{h}")
        os.makedirs(d, exist_ok=True)
        for pol, bow in (("white-on-black", False), ("black-on-white", True)):
            for sz, sc in sizes.items():
                cell = make_cell(sc)
                cw = cell.shape[1]
                wide = make_wide(w, h, cell, bow)
                name = f"{pol}_{sz}"
                save(wide[:, :w], os.path.join(d, f"{name}_static.png"))

                if not a.no_scroll:
                    sd = os.path.join(d, f"{name}_scroll")
                    shutil.rmtree(sd, ignore_errors=True)
                    os.makedirs(sd)
                    step = a.speed % cw or cw
                    n = cw // math.gcd(step, cw)          # frames in one seamless period
                    for i in range(n):
                        off = (i * step) % cw
                        if a.direction == "right":
                            off = (cw - off) % cw
                        save(wide[:, off:off + w], os.path.join(sd, f"{i:03d}.png"))
                print(f"{w}x{h}  {name:28s} cell {cw}x{cell.shape[0]}"
                      + ("" if a.no_scroll else f"  scroll: {n} frames @ {a.speed}px/frame"))
    print("output:", a.out)


if __name__ == "__main__":
    sys.exit(main())
