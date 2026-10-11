#!/usr/bin/env python3
"""Zip the mod/ folder into doomdescent.pk3."""
import os
import sys
import zipfile

here = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(here, '..', 'mod')
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', 'doomscent.pk3')

with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(src):
        dirs.sort()
        for f in sorted(files):
            full = os.path.join(root, f)
            z.write(full, os.path.relpath(full, src).replace(os.sep, '/'))
print('wrote', os.path.abspath(out))
