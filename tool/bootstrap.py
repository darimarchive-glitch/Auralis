#!/usr/bin/env python3
"""Generate/refresh Flutter platform runners without adding secrets."""
from __future__ import annotations

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
    android_ns = 'http://schemas.android.com/apk/res/android'
    android = '{' + android_ns + '}'
    ET.register_namespace('android', android_ns)
    tree = ET.parse(manifest)
    root = tree.getroot()
    app = root.find('application')
    if app is not None:
        app.set(android + 'label', 'Auralis Reader')

    def permission(name: str) -> None:
        if any(node.get(android + 'name') == name for node in root.findall('uses-permission')):
            return
        node = ET.Element('uses-permission')
        node.set(android + 'name', name)
        root.insert(0, node)

    permission('android.permission.INTERNET')
    permission('android.permission.ACCESS_NETWORK_STATE')

    queries = root.find('queries')
    if queries is None:
        queries = ET.Element('queries')
        root.insert(0, queries)
    has_tts = any(
        action.get(android + 'name') == 'android.intent.action.TTS_SERVICE'
        for intent in queries.findall('intent')
        for action in intent.findall('action')
    )
    if not has_tts:
        intent = ET.SubElement(queries, 'intent')
        action = ET.SubElement(intent, 'action')
        action.set(android + 'name', 'android.intent.action.TTS_SERVICE')

    tree.write(manifest, encoding='utf-8', xml_declaration=True)


def main() -> None:
    flutter = shutil.which('flutter')
    if not flutter:
        raise SystemExit('Flutter not found in PATH.')

    with tempfile.TemporaryDirectory(prefix='auralis_flutter_') as td:
        target = Path(td) / 'auralis_reader'
        run(
            flutter,
            'create',
            '--platforms=android,linux,windows',
            '--org',
            'io.auralis',
            '--project-name',
            'auralis_reader',
            str(target),
            cwd=Path(td),
        )
        for platform in ('android', 'linux', 'windows'):
            dst = ROOT / platform
            # Preserve checked-in runners when they exist. This makes the repo
            # complete while still allowing a clean regeneration in CI.
            if not dst.exists():
                shutil.copytree(target / platform, dst)

    patch_android()
    run(flutter, 'pub', 'get')
    print('Auralis platform runners are ready.')


if __name__ == '__main__':
    main()
