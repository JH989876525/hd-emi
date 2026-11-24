#!/usr/bin/env bash
# Play an EMI H pattern with GStreamer. Patterns come from generate.py
# (auto-generated for the requested resolution if missing).
#
# Usage: ./play.sh [-r WxH] [-p white-on-black|black-on-white] [-s small|large]
#                  [-m static|scroll] [-f FPS] [-k SINK] [-l RUNS] [-t SEC] [-n]
#   -r  resolution, must match the HDMI mode under test   (default 1920x1080)
#   -p  polarity                                          (default white-on-black)
#   -s  H size                                            (default small)
#   -m  static | scroll                                   (default static)
#   -f  frame rate                                        (default 60)
#   -k  video sink: autovideosink | ximagesink | glimagesink | kmssink | fakesink
#                                                         (default autovideosink)
#   -l  number of runs; prints PASS/FAIL (gst-launch exit status) after each run
#       and a summary at the end                          (default 1)
#   -t  seconds per run; 0 = run until Ctrl-C             (default 5 if -l is
#                                                          given, else 0)
#   -n  print the gst-launch command only, don't run it
#
# Note: autovideosink opens a normal window (fine for a quick check). For a real
# EMI run the image must be shown 1:1 and fullscreen on the HDMI output, e.g.
# kmssink from a TTY, or fullscreen the window on the HDMI monitor.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RES=1920x1080 POL=white-on-black SIZE=small MODE=static FPS=60 SINK=autovideosink DRY=0 RUNS=1 SECS=

while getopts "r:p:s:m:f:k:l:t:nh" o; do
  case $o in
    r) RES=$OPTARG ;;  p) POL=$OPTARG ;;  s) SIZE=$OPTARG ;;
    m) MODE=$OPTARG ;; f) FPS=$OPTARG ;;  k) SINK=$OPTARG ;;
    l) RUNS=$OPTARG ;; t) SECS=$OPTARG ;;
    n) DRY=1 ;;        h|*) sed -n '2,24p' "$0"; exit 0 ;;
  esac
done

[[ $RUNS =~ ^[1-9][0-9]*$ ]] || { echo "-l must be a positive integer" >&2; exit 1; }
if [ -z "$SECS" ]; then [ "$RUNS" -gt 1 ] && SECS=5 || SECS=0; fi
[[ $SECS =~ ^[0-9]+$ ]] || { echo "-t must be a non-negative integer" >&2; exit 1; }
# a run ends by itself after FPS*SECS frames (EOS), so each run is short
NBUF=-1; [ "$SECS" -gt 0 ] && NBUF=$((FPS * SECS))

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
  PIPE=(filesrc location="$TARGET" ! pngdec ! videoconvert ! imagefreeze num-buffers=$NBUF
        ! "video/x-raw,framerate=$FPS/1" ! videoconvert ! "$SINK" sync=true)
else
  # numbered frames = one seamless scroll period, looped forever
  PIPE=(multifilesrc location="$(dirname "$TARGET")/%03d.png" loop=true num-buffers=$NBUF
        caps="image/png,framerate=$FPS/1" ! pngdec ! videoconvert ! "$SINK" sync=true)
fi

echo "+ gst-launch-1.0 ${PIPE[*]}" >&2
[ "$DRY" = 1 ] && exit 0

# Run RUNS times; each run's result is gst-launch's exit status (0 = PASS).
# Ctrl-C stops the whole loop instead of counting as a failure.
# colors only when stdout is a terminal (and NO_COLOR is unset)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then GRN=$'\033[32m' RED=$'\033[31m' RST=$'\033[0m'; else GRN= RED= RST=; fi
trap 'echo; echo "interrupted"; exit 130' INT
pass=0 fail=0
for ((i = 1; i <= RUNS; i++)); do
  rc=0
  gst-launch-1.0 -e "${PIPE[@]}" >/dev/null || rc=$?
  if [ "$rc" -eq 0 ]; then
    pass=$((pass + 1)); echo "run $i/$RUNS: ${GRN}PASS${RST}"
  else
    fail=$((fail + 1)); echo "run $i/$RUNS: ${RED}FAIL${RST} (gst-launch exit $rc)"
  fi
done
[ "$RUNS" -gt 1 ] && echo "summary: ${GRN}$pass PASS${RST}, ${RED}$fail FAIL${RST} out of $RUNS runs"
[ "$fail" -eq 0 ]
