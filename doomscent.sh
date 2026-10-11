#!/bin/sh
# Doomscent launcher for Linux / macOS.
# Needs gzdoom on PATH (or GZDOOM=/path/to/gzdoom), and your DOOM/DOOM2
# WADs plus DESCENT.HOG and DESCENT.PIG in ./data/.
set -e
ROOT=$(cd "$(dirname "$0")" && pwd)
GZ=${GZDOOM:-$(command -v gzdoom || true)}
[ -x "$ROOT/gzdoom/gzdoom" ] && GZ="$ROOT/gzdoom/gzdoom"
if [ -z "$GZ" ]; then
	echo "Could not find GZDoom; install it or set GZDOOM." >&2
	exit 1
fi
[ -f "$ROOT/doomscent.pk3" ] || python3 "$ROOT/tools/build_pk3.py" "$ROOT/doomscent.pk3"
if [ ! -f "$ROOT/dd_descent_assets.pk3" ]; then
	python3 "$ROOT/tools/ddconvert.py" "$ROOT/data" -o "$ROOT/dd_descent_assets.pk3"
fi
cd "$ROOT/data"
exec "$GZ" -file "$ROOT/dd_descent_assets.pk3" "$ROOT/doomscent.pk3" "$@"
