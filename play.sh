#!/usr/bin/env bash
# Play an EMI H pattern with GStreamer. Patterns come from generate.py
# (auto-generated for the requested resolution if missing).
#
# Usage: ./play.sh [-r WxH] [-p white-on-black|black-on-white] [-s small|large]
#                  [-m static|scroll] [-f FPS] [-k SINK] [-n]
#   -r  resolution, must match the HDMI mode under test   (default 1920x1080)
#   -p  polarity                                          (default white-on-black)
#   -s  H size                                            (default small)
#   -m  static | scroll                                   (default static)
#   -f  frame rate                                        (default 60)
#   -k  video sink: autovideosink | ximagesink | glimagesink | kmssink | fakesink
#                                                         (default autovideosink)
#   -n  print the gst-launch command only, don't run it
#
# Note: autovideosink opens a normal window (fine for a quick check). For a real
# EMI run the image must be shown 1:1 and fullscreen on the HDMI output, e.g.
# kmssink from a TTY, or fullscreen the window on the HDMI monitor.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RES=1920x1080 POL=white-on-black SIZE=small MODE=static FPS=60 SINK=autovideosink DRY=0

while getopts "r:p:s:m:f:k:nh" o; do
  case $o in
    r) RES=$OPTARG ;;  p) POL=$OPTARG ;;  s) SIZE=$OPTARG ;;
    m) MODE=$OPTARG ;; f) FPS=$OPTARG ;;  k) SINK=$OPTARG ;;
    n) DRY=1 ;;        h|*) sed -n '2,19p' "$0"; exit 0 ;;
  esac
done

NAME="${POL}_${SIZE}"
case $MODE in
  static) TARGET="$DIR/patterns/$RES/${NAME}_static.png" ;;
  scroll) TARGET="$DIR/patterns/$RES/${NAME}_scroll/000.png" ;;
  *) echo "mode must be static or scroll" >&2; exit 1 ;;
esac

if [ ! -f "$TARGET" ]; then
  echo "pattern for $RES not found, generating..." >&2
  "$DIR/generate.py" -r "$RES" >&2
fi

if [ "$MODE" = static ]; then
  # one decoded frame, repeated forever at FPS so the link keeps a constant stream
  PIPE=(filesrc location="$TARGET" ! pngdec ! videoconvert ! imagefreeze
        ! "video/x-raw,framerate=$FPS/1" ! videoconvert ! "$SINK" sync=true)
else
  # numbered frames = one seamless scroll period, looped forever
  PIPE=(multifilesrc location="$(dirname "$TARGET")/%03d.png" loop=true
        caps="image/png,framerate=$FPS/1" ! pngdec ! videoconvert ! "$SINK" sync=true)
fi

echo "+ gst-launch-1.0 ${PIPE[*]}" >&2
[ "$DRY" = 1 ] && exit 0
exec gst-launch-1.0 -e "${PIPE[@]}"
