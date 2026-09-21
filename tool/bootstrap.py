#!/usr/bin/env python3
"""Gera os runners nativos usando a versão de Flutter instalada na máquina."""
from __future__ import annotations
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def run(*args: str, cwd: Path | None = None) -> None:
    print('+', ' '.join(args))
    subprocess.run(args, cwd=cwd or ROOT, check=True)


def patch_android() -> None:
    manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
    if not manifest.exists():
        return
    ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')
    tree = ET.parse(manifest)
    root = tree.getroot()
    android = '{http://schemas.android.com/apk/res/android}'
    app = root.find('application')
    if app is not None:
        app.set(android + 'label', 'Auralis Reader')

    has_internet = any(
        permission.get(android + 'name') == 'android.permission.INTERNET'
        for permission in root.findall('uses-permission')
    )
    if not has_internet:
        permission = ET.Element('uses-permission')
        permission.set(android + 'name', 'android.permission.INTERNET')
        root.insert(0, permission)
    has_query = any(
        intent.find('action') is not None
        and intent.find('action').get(android + 'name') == 'android.intent.action.TTS_SERVICE'
        for queries in root.findall('queries')
        for intent in queries.findall('intent')
    )
    if not has_query:
        queries = root.find('queries')
        if queries is None:
            queries = ET.Element('queries')
            root.insert(0, queries)
        intent = ET.SubElement(queries, 'intent')
        action = ET.SubElement(intent, 'action')
        action.set(android + 'name', 'android.intent.action.TTS_SERVICE')
    tree.write(manifest, encoding='utf-8', xml_declaration=True)


def main() -> None:
    flutter = shutil.which('flutter')
    if not flutter:
        raise SystemExit('Flutter não encontrado no PATH. Instale Flutter 3.47+ e execute novamente.')
    with tempfile.TemporaryDirectory(prefix='auralis_flutter_') as td:
        target = Path(td) / 'auralis_reader'
        run(flutter, 'create', '--platforms=android,linux,windows', '--org', 'io.auralis', '--project-name', 'auralis_reader', str(target), cwd=Path(td))
        for platform in ('android', 'linux', 'windows'):
            dst = ROOT / platform
            if dst.exists():
                shutil.rmtree(dst)
            shutil.copytree(target / platform, dst)
    patch_android()
    run(flutter, 'pub', 'get')
    print('\nAuralis preparado. Rode: flutter run -d <dispositivo>')


if __name__ == '__main__':
    main()
