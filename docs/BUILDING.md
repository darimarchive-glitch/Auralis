# Building Auralis

## Core

```bash
python -m pip install -e '.[dev]'
pytest -q
python main.py
```

## Windows

CI builds the Qt/Python standalone distribution with `pyside6-deploy` and Nuitka, then generates `Auralis-Reader-<version>-Setup.exe` with Inno Setup.

## Linux

CI builds the standalone application, stages it under `packaging/flatpak/app/Auralis.dist`, and builds `Auralis-Reader-<version>.flatpak`.

## Android

CI uses official PySide6/Shiboken Android wheels, Qt for Python's Android deployment helper, Android SDK/NDK and python-for-android. The output is an arm64 installable APK.

## Release

Changing `VERSION` triggers the three platform workflows and the release workflow. Successful platform jobs attach their artifacts to `v<VERSION>`.

Do not place private signing keys or API credentials in this repository.
