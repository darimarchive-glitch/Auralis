from __future__ import annotations

import os
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")


def test_main_qml_loads():
    from PySide6.QtCore import QUrl
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine
    from auralis.controller import AppController  # noqa: F401

    app = QGuiApplication.instance() or QGuiApplication([])
    engine = QQmlApplicationEngine()
    qml = Path(__file__).parents[1] / "src" / "auralis" / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml)))
    assert engine.rootObjects(), "Main.qml failed to create a root object"
    engine.deleteLater()
    app.processEvents()
