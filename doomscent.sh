#!/bin/sh
# Doomscent launcher for Linux / macOS.
# Needs gzdoom on PATH (or GZDOOM=/path/to/gzdoom) and Python 3, plus your
# Doom IWAD and DESCENT.HOG / DESCENT.PIG in ./data/ (--descent2: Descent
# II's DESCENT2.HOG, DESCENT2.HAM, GROUPA.PIG and DESCENT2.S22).
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

# Descent 1 by default; --descent2 plays in Descent II mode (its own asset
# pack), as does having only Descent II's files.
D2=0
if [ "$1" = "--descent2" ] || [ "$1" = "-descent2" ]; then
	D2=1
	shift
fi

# Other mods (the mods folder, or -file on the command line) load before
# Doomscent so its ship, HUD and replacements win.
set -- "$@" --end--
MODS=""
for f in "$ROOT"/mods/*; do
	[ -e "$f" ] && MODS="$MODS
$f"
done
INFILE=0
for a in "$@"; do
	shift
	if [ "$a" = "--end--" ]; then break; fi
	case "$a" in
		-file) INFILE=1; continue ;;
		-*|+*) INFILE=0 ;;
		*) if [ $INFILE = 1 ]; then MODS="$MODS
$(cd "$(dirname "$a")" && pwd)/$(basename "$a")"; continue; fi ;;
	esac
	set -- "$@" "$a"
done
has() { ls "$ROOT/data" 2>/dev/null | grep -qix "$1"; }
if [ $D2 = 0 ] && ! has descent.pig && has descent2.hog; then
	D2=1
fi
if [ $D2 = 1 ]; then
	ASSETS="$ROOT/dd_descent2_assets.pk3"
	CONV="--descent2"
else
	ASSETS="$ROOT/dd_descent_assets.pk3"
	CONV=""
fi

# (Ick Mode's optional data/ickface.png also triggers a reconvert.)
if [ ! -f "$ASSETS" ] || [ "$ROOT/tools/ddconvert.py" -nt "$ASSETS" ] ||
	[ "$ROOT/data/ickface.png" -nt "$ASSETS" ]; then
	if [ $D2 = 1 ]; then
		if ! has descent2.hog || ! has descent2.ham || ! has groupa.pig; then
			echo "Copy DESCENT2.HOG, DESCENT2.HAM, GROUPA.PIG and DESCENT2.S22 from Descent II into $ROOT/data/." >&2
			exit 1
		fi
	elif ! has descent.pig || ! has descent.hog; then
		echo "Copy DESCENT.HOG and DESCENT.PIG from Descent 1 into $ROOT/data/." >&2
		exit 1
	fi
	python3 "$ROOT/tools/ddconvert.py" $CONV "$ROOT/data" -o "$ASSETS"
fi

# Run from data/ so GZDoom finds the IWADs there and offers a choice.
cd "$ROOT/data"
# Mod paths are newline-separated so they may contain spaces.
OLDIFS=$IFS
IFS='
'
# shellcheck disable=SC2086
set -- -file $MODS "$ASSETS" "$ROOT/doomscent.pk3" "$@"
IFS=$OLDIFS
exec "$GZ" "$@"
