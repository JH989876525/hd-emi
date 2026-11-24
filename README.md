# HDMI EMI H Pattern (GStreamer)

EMI "H pattern" (Quantum Data / LeCroy style): the whole screen is tiled edge to edge
with a bitmap letter "H" (5x7 glyph in an 8x8 cell, no gaps between characters).

| Item | Option |
|---|---|
| White H on black / Black H on white | `-p white-on-black` / `-p black-on-white` |
| Small H (8x8 cell) / Large H (32x32 cell) | `-s small` / `-s large` |
| Static / Scrolling (horizontal, seamless loop) | `-m static` / `-m scroll` |

## Files

- `generate.py` – generates the pattern images for any resolution into `patterns/<WxH>/`
- `play.sh` – plays a pattern with `gst-launch-1.0` (default sink: `autovideosink`)
- `h.py`, `h_pattern.png` – original simple "H grid" image (not the EMI pattern)

## Requirements

GStreamer 1.x (`gst-launch-1.0`, base plugins), Python 3 with `numpy` and `Pillow`.

## Usage

```bash
./generate.py                          # 1920x1080 (default)
./generate.py -r 720p 1080p 4k         # presets: 720p 1080p 1440p 4k, or any WxH
./generate.py --speed 2                # scroll speed, px/frame (default 1)

./play.sh                              # white-on-black, small, static, 1920x1080 @60
./play.sh -p black-on-white -s large   # black H on white, large H
./play.sh -m scroll                    # scrolling
./play.sh -r 3840x2160 -f 30           # other resolution / frame rate
./play.sh -k kmssink                   # other sink
./play.sh -n                           # print the gst-launch command only
```

`play.sh` runs `generate.py` automatically if the requested resolution has not been generated yet.

## Why generate per resolution?

The image must be shown **1:1** (one image pixel per display pixel) at the HDMI mode under
test. If the sink rescales it, the 1-pixel strokes blur and the EMI stress is lost. So pick
`-r` to match the actual HDMI output mode.

`autovideosink` opens a normal window, which is fine for a quick check. For a real EMI run,
show it fullscreen on the HDMI output (e.g. fullscreen the window on that monitor, or use
`kmssink` from a TTY) and confirm the mode matches (`xrandr`, or `modetest` on the target).

## Layout of `patterns/<WxH>/`

```
<polarity>_<size>_static.png          static frame
<polarity>_<size>_scroll/000.png ...  one seamless scroll period (8 frames small, 32 large @ 1px/frame),
                                      looped by multifilesrc
```

## Notes

- Glyph/cell sizes are my choice; Quantum Data / LeCroy exact sizes weren't verified. Edit
  `H_GLYPH`, `CELL_W/H` or `--large-scale` in `generate.py` to match your test spec.
- Scrolling is horizontal only (`--direction left|right` when generating).
