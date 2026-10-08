[app]
title = Auralis
project_dir = .
input_file = main.py
exec_directory = ./dist
project_file =
icon =

[python]
python_path = python
packages = nuitka,ordered_set,zstandard
android_packages = buildozer,cython

[qt]
qml_files = auralis/qml/Main.qml
excluded_qml_plugins = QtQuick3D,QtCharts,QtWebEngine,QtSensors
modules = Quick,QuickControls2,Multimedia,TextToSpeech,Pdf,Network
plugins =

[android]
wheel_pyside =
wheel_shiboken =
plugins = platforms_qtforandroid

[nuitka]
mode = standalone
extra_args = --quiet --assume-yes-for-downloads --noinclude-qt-translations --include-data-dir=auralis/qml=auralis/qml

[buildozer]
mode = debug
recipe_dir =
jars_dir =
ndk_path =
sdk_path =
modules = Quick,QuickControls2,Multimedia,TextToSpeech,Pdf,Network
local_libs = plugins_platforms_qtforandroid
arch = aarch64
