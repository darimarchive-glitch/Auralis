[app]
title = Auralis
project_dir = .
input_file = main.py
exec_directory = dist
project_file = pyproject.toml

[python]
python_path = python

[qt]
modules = Core,Gui,Qml,Quick,QuickControls2,Network,Pdf,TextToSpeech

[buildozer]
mode = debug

[android]
arch = aarch64
plugins = texttospeech,platforms,imageformats,tls

[nuitka]
mode = standalone
extra_args =
