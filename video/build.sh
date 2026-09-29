#!/bin/sh
# Renders the WebGL scene frame by frame, synthesizes the soundtrack,
# and muxes both into docs/intro.mp4.
set -eu
cd "$(dirname "$0")"

[ -d node_modules ] || npm install
[ -d .venv ] || { python3 -m venv .venv && .venv/bin/pip install -q numpy; }
mkdir -p out

node render.mjs
.venv/bin/python music.py out/soundtrack.wav

ffmpeg -y -loglevel error \
  -framerate 30 -i frames/frame-%05d.jpg \
  -i out/soundtrack.wav \
  -c:v libx264 -preset slow -crf 22 -pix_fmt yuv420p -movflags +faststart \
  -af "loudnorm=I=-14:TP=-1.5:LRA=11" -c:a aac -b:a 192k \
  -shortest ../docs/intro.mp4

echo "wrote docs/intro.mp4"
