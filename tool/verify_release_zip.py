#!/usr/bin/env python3
from __future__ import annotations
import sys
import zipfile
from pathlib import Path

REQUIRED = {
    '.github/workflows/android-release.yml',
    'pubspec.yaml',
    'tool/navigation_acceptance_gate.py',
    'tool/verify_mobile.py',
}


def main() -> int:
    if len(sys.argv) != 2:
        print('usage: verify_release_zip.py <release.zip>')
        return 2
    archive = Path(sys.argv[1])
    if not archive.is_file():
        print(f'ERROR: archive not found: {archive}')
        return 2
    with zipfile.ZipFile(archive) as zf:
        names = {name.rstrip('/') for name in zf.namelist()}
    missing = sorted(REQUIRED - names)
    if missing:
        for path in missing:
            print(f'ERROR: release archive missing required path: {path}')
        return 1
    print('Release ZIP contract: PASS')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
