from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_all_distribution_formats_are_declared():
    android = (ROOT / ".github/workflows/android.yml").read_text(encoding="utf-8")
    windows = (ROOT / ".github/workflows/windows.yml").read_text(encoding="utf-8")
    linux = (ROOT / ".github/workflows/linux.yml").read_text(encoding="utf-8")

    assert ".apk" in android
    assert "Inno Setup" in windows or "innosetup" in windows.lower()
    assert ".exe" in windows
    assert "flatpak-builder" in linux
    assert ".flatpak" in linux


def test_packaging_sources_exist():
    required = [
        "packaging/windows/Auralis.iss",
        "packaging/flatpak/io.github.darimarchive_glitch.Auralis.yml",
        "packaging/flatpak/io.github.darimarchive_glitch.Auralis.desktop",
        "packaging/flatpak/io.github.darimarchive_glitch.Auralis.metainfo.xml",
        "packaging/flatpak/io.github.darimarchive_glitch.Auralis.svg",
    ]
    for relative in required:
        assert (ROOT / relative).is_file(), relative
