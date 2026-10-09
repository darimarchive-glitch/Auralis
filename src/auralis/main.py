from __future__ import annotations

import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from .controller import AppController  # noqa: F401 - registers QML type


def main() -> int:
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Auralis")
    app.setOrganizationName("Auralis")
    engine = QQmlApplicationEngine()
    qml = Path(__file__).parent / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml)))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
