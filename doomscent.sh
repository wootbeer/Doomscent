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

# Other mods (mods/mods.txt, or -file on the command line) load before
# Doomscent so its ship, HUD and replacements win.
set -- "$@" --end--
CLI_MODS=""
IWAD=""
INFILE=0
PREV=""
for a in "$@"; do
	shift
	if [ "$a" = "--end--" ]; then break; fi
	[ "$PREV" = "-iwad" ] && IWAD="$a"
	PREV="$a"
	case "$a" in
		-file) INFILE=1; continue ;;
		-*|+*) INFILE=0 ;;
		*) if [ $INFILE = 1 ]; then CLI_MODS="$CLI_MODS
$(cd "$(dirname "$a")" && pwd)/$(basename "$a")"; continue; fi ;;
	esac
	set -- "$@" "$a"
done

# mods/mods.txt: load order; # in front switches a mod off; [doom],
# [heretic], [hexen], [chex] (or several, [doom,chex]) limits it to those
# games.  New mods are added for Doom: gameplay mods are usually Doom-only.
gameof() {
	case "$(basename "$1" | tr 'A-Z' 'a-z')" in
		heretic*) echo heretic ;; hex*) echo hexen ;; chex*) echo chex ;; *) echo doom ;;
	esac
}
LIST="$ROOT/mods/mods.txt"
ENTRIES=""
if [ -f "$LIST" ]; then
	while IFS= read -r line || [ -n "$line" ]; do
		on=1
		case "$line" in '#'*) on=0; line=${line#\#} ;; esac
		games=""
		case "$line" in '['*']'*) games=${line%%]*}; games=${games#[}; line=${line#*]} ;; esac
		line=$(printf '%s' "$line" | sed 's/^ *//; s/ *$//')
		[ -n "$line" ] && [ -e "$ROOT/mods/$line" ] && ENTRIES="$ENTRIES
$on|$games|$line"
	done < "$LIST"
fi
for f in "$ROOT"/mods/*; do
	name=$(basename "$f")
	case "$name" in mods.txt|README.txt) continue ;; esac
	[ -e "$f" ] || continue
	printf '%s\n' "$ENTRIES" | grep -qF "|$name" && continue
	ENTRIES="$ENTRIES
1|doom|$name"
	[ -f "$LIST" ] || printf '# Doomscent mods, loaded top to bottom.\n# # in front switches a mod off; [doom], [heretic], [hexen], [chex]\n# (or several, [doom,chex]) limits it to those games.\n' > "$LIST"
	printf '[doom] %s\n' "$name" >> "$LIST"
done

# Mods for only some games need to know which game this is: from -iwad,
# the only IWAD, or by asking (instead of GZDoom's own picker).
GAME=""
if [ -n "$IWAD" ]; then
	GAME=$(gameof "$IWAD")
elif printf '%s\n' "$ENTRIES" | grep -q '^1|[^|]'; then
	IWADS=$(ls "$ROOT/data" | grep -iE '\.(wad|ipk3|pk3)$')
	if [ "$(printf '%s\n' "$IWADS" | grep -c .)" -eq 1 ]; then
		IWAD=$IWADS
	elif [ -n "$IWADS" ]; then
		echo "Which game?"
		printf '%s\n' "$IWADS" | awk '{ printf "  %2d. %s\n", NR, $0 }'
		n=""
		while [ -z "$n" ] || ! printf '%s\n' "$IWADS" | sed -n "${n}p" | grep -q .; do
			printf 'Number: '
			read -r n < /dev/tty || exit 1
			case "$n" in ''|*[!0-9]*|0) n="" ;; esac
		done
		IWAD=$(printf '%s\n' "$IWADS" | sed -n "${n}p")
		set -- -iwad "$IWAD" "$@"
	fi
	[ -n "$IWAD" ] && GAME=$(gameof "$IWAD")
fi
MODS=""
while IFS='|' read -r on games name; do
	[ "$on" = 1 ] || continue
	if [ -n "$games" ] && ! printf ',%s,' "$games" | tr -d ' ' | grep -q ",$GAME,"; then
		echo "Not loading $name (only for: $games)."
		continue
	fi
	MODS="$MODS
$ROOT/mods/$name"
done <<EOF
$ENTRIES
EOF
MODS="$MODS$CLI_MODS"
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
