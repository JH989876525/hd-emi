- [Overview](#overview)
- [Requirements](#requirements)
- [Files](#files)
- [Usage](#usage)
- [H Pattern](#h-pattern)

# Overview

`hd-emi` generates pixel-exact EMI "H pattern" images for any resolution.

And also provide GStreamer examples.

# Requirements

- `gst-launch-1.0`
- `Python3` : `numpy`, `Pillow`

# Files

- `generate.py` – generates the pattern images for any resolution into `patterns/<WxH>/`
- `play.sh` – plays a pattern with `gst-launch-1.0` (default sink: `autovideosink`)
- `patterns/` – pre-generated images for 1280x720, 1920x1080 and 3840x2160

# Usage

```bash
git clone https://github.com/JH989876525/hd-emi.git
cd hd-emi

./generate.py                          # 1920x1080 (default)
./generate.py -r 720p 1080p 4k         # presets: 720p 1080p 1440p 4k, or any WxH
./generate.py --speed 2                # scroll speed, px/frame (default 1)

./play.sh                              # white-on-black, small, static, 1920x1080 @60
./play.sh -p black-on-white -s large   # black H on white, large H
./play.sh -m scroll                    # scrolling
./play.sh -r 3840x2160 -f 30           # other resolution / frame rate
./play.sh -k kmssink                   # other sink
./play.sh -l 10                        # 10 runs of 5 s each, prints PASS/FAIL per run
./play.sh -l 100 -t 10                 # 100 runs of 10 s each
./play.sh -n                           # print the gst-launch command only
```

- With `-l RUNS`, each run lasts `-t` seconds (default 5) and ends with `PASS` or `FAIL`
  (the `gst-launch-1.0` exit status), followed by a summary; the script exits non-zero if any
  run failed. Without `-l`/`-t` it plays until Ctrl-C, as before.
- `play.sh` runs `generate.py` automatically if the requested resolution has not been generated yet.

# H Pattern

Reference: Quantum Data / LeCroy EMI H pattern. Required patterns:

1. White H on black background
2. Black H on white background
3. Small H / Large H
4. Static H pattern
5. Scrolling H pattern

<details>
<summary><b>Implementation details</b></summary>
<br>

- **Fill:** the full screen is tiled edge to edge with the character "H", with no gaps
  between characters and no margins. Partial characters are cut off at the right and
  bottom edges.
- **Glyph:** a 5x7 bitmap H (two vertical strokes plus a middle bar) in an 8x8 cell,
  with 1-pixel-wide strokes (no anti-aliasing, so only pure black and white pixels exist):

  ```
  X...X
  X...X
  X...X
  XXXXX      cell = 8x8: glyph at column 1..5, row 0..6,
  X...X      remaining columns/row are inter-character spacing
  X...X
  X...X
  ```
- **Colors:** pure white (255) and pure black (0) only. Polarity is inverted for
  black-on-white.
- **Small H:** the glyph at 1x (8x8 cell).
- **Large H:** the glyph scaled by an integer factor (default 4x, 32x32 cell,
  `--large-scale N` to change). Scaling is nearest-neighbor, so edges stay sharp.
- **Static:** one frame, repeated at the chosen frame rate.
- **Scrolling:** the pattern moves horizontally by a fixed number of pixels per frame
  (default 1 px/frame, `--speed N`, `--direction left|right`). One scroll period equals one
  cell width (8 frames small, 32 frames large at 1 px/frame), so the loop is seamless.
- **Resolution:** the image is generated at exactly the HDMI output resolution (1:1 pixel
  mapping, no scaling).

> The reference name and the five required patterns come from the test spec. The exact
> glyph and cell sizes above are my own choice; I did not verify the actual Quantum Data /
> LeCroy character dimensions. Adjust `H_GLYPH`, `CELL_W/H` or `--large-scale` in
> `generate.py` if your spec defines them.
</details>