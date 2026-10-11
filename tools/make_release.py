#!/usr/bin/env python3
"""Assemble the end-user release zip.

    python tools/make_release.py [--exe path/to/ddconvert.exe] [-o dist]

The zip contains the launchers, the built mod, the converter, README,
LICENSE and an empty data/ folder.  It never contains game data or GZDoom.
"""
import argparse
import os
import subprocess
import sys
import zipfile

root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--exe', help='standalone ddconvert.exe to include')
    ap.add_argument('-o', '--outdir', default=os.path.join(root, 'dist'))
    args = ap.parse_args()

    version = open(os.path.join(root, 'VERSION')).read().strip()
    os.makedirs(args.outdir, exist_ok=True)
    pk3 = os.path.join(args.outdir, 'doomscent.pk3')
    subprocess.check_call([sys.executable, os.path.join(root, 'tools', 'build_pk3.py'), pk3])

    name = 'Doomscent-%s' % version
    out = os.path.join(args.outdir, name + '.zip')
    files = {
        'Doomscent.bat': 'Doomscent.bat',
        'doomscent.sh': 'doomscent.sh',
        'README.md': 'README.md',
        'LICENSE': 'LICENSE',
        'CHANGELOG.md': 'CHANGELOG.md',
        'data/README.txt': 'data/README.txt',
        'tools/launcher.ps1': 'tools/launcher.ps1',
        'tools/ddconvert.py': 'tools/ddconvert.py',
    }
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for arc, rel in files.items():
            info = zipfile.ZipInfo.from_file(os.path.join(root, rel), name + '/' + arc)
            if arc.endswith('.sh'):
                info.external_attr = 0o100755 << 16
            with open(os.path.join(root, rel), 'rb') as f:
                z.writestr(info, f.read(), zipfile.ZIP_DEFLATED)
        z.write(pk3, name + '/doomscent.pk3')
        if args.exe:
            z.write(args.exe, name + '/tools/ddconvert.exe')
    print('wrote', out)


if __name__ == '__main__':
    main()
