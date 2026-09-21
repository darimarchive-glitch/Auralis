#!/usr/bin/env python3
from pathlib import Path
import platform
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
flutter = shutil.which('flutter')
if not flutter:
    raise SystemExit('Flutter não encontrado no PATH.')


def run(*args):
    print('+', ' '.join(args))
    subprocess.run(args, cwd=ROOT, check=True)

if not (ROOT / 'android').exists():
    subprocess.run([str(ROOT / 'tool/bootstrap.py')], cwd=ROOT, check=True)

run(flutter, 'test')
run(flutter, 'analyze')
run(flutter, 'build', 'apk', '--release')

system = platform.system().lower()
if system == 'linux':
    run(flutter, 'build', 'linux', '--release')
elif system == 'windows':
    run(flutter, 'build', 'windows', '--release')
else:
    print('Build desktop ignorado: use Linux para o binário Linux e Windows para o .exe.')
