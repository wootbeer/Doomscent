#!/bin/sh
# Doomscent launcher for Linux / macOS.
# Needs gzdoom on PATH (or GZDOOM=/path/to/gzdoom) and Python 3, plus your
# Doom IWAD and DESCENT.HOG / DESCENT.PIG in ./data/.
set -e
ROOT=$(cd "$(dirname "$0")" && pwd)
GZ=${GZDOOM:-$(command -v gzdoom || true)}
[ -x "$ROOT/gzdoom/gzdoom" ] && GZ="$ROOT/gzdoom/gzdoom"
if [ -z "$GZ" ]; then
	echo "Could not find GZDoom; install it or set GZDOOM." >&2
	exit 1
fi

# From a source checkout, rebuild the mod when mod/ has changed.
if [ -d "$ROOT/mod" ]; then
	if [ ! -f "$ROOT/doomscent.pk3" ] || [ -n "$(find "$ROOT/mod" -newer "$ROOT/doomscent.pk3" -type f | head -n 1)" ]; then
		python3 "$ROOT/tools/build_pk3.py" "$ROOT/doomscent.pk3"
	fi
fi

if [ ! -f "$ROOT/dd_descent_assets.pk3" ] || [ "$ROOT/tools/ddconvert.py" -nt "$ROOT/dd_descent_assets.pk3" ]; then
	if [ ! -f "$ROOT/data/DESCENT.PIG" ] && [ ! -f "$ROOT/data/descent.pig" ]; then
		echo "Copy DESCENT.HOG and DESCENT.PIG from Descent 1 into $ROOT/data/." >&2
		exit 1
	fi
	python3 "$ROOT/tools/ddconvert.py" "$ROOT/data" -o "$ROOT/dd_descent_assets.pk3"
fi

# Run from data/ so GZDoom finds the IWADs there and offers a choice.
cd "$ROOT/data"
exec "$GZ" -file "$ROOT/dd_descent_assets.pk3" "$ROOT/doomscent.pk3" "$@"
