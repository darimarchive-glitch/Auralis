# Building Auralis 3.1.1

## Preparar runners

```bash
python tool/bootstrap.py
```

## Testar

```bash
flutter test
flutter analyze --no-fatal-infos
```

## Android

```bash
flutter build apk --release
```

## Windows

```powershell
flutter build windows --release
```

O instalador final é produzido com Inno Setup pelo workflow oficial.

## Linux / Flatpak

```bash
flutter build linux --release
```

O workflow copia o bundle para o manifesto Flatpak e gera o `.flatpak`.
