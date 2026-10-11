#!/usr/bin/env python3
"""Zip the mod/ folder into doomscent.pk3, stamping in the version."""
import os
import sys
import zipfile

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, '..')
src = os.path.join(root, 'mod')
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, 'doomscent.pk3')

try:
    with open(os.path.join(root, 'VERSION')) as f:
        version = f.read().strip()
except OSError:
    version = 'dev'

with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for path, dirs, files in os.walk(src):
        dirs.sort()
        for f in sorted(files):
            full = os.path.join(path, f)
            z.write(full, os.path.relpath(full, src).replace(os.sep, '/'))
    # A second LANGUAGE lump just for the version shown in the menu.
    z.writestr('language.version', '[enu default]\nDD_VERSION = "Doomscent %s";\n' % version)
print('wrote %s (version %s)' % (os.path.abspath(out), version))
