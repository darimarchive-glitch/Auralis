#define MyAppName "Auralis Reader"
#define MyAppVersion "2.0.0"
#define MyAppExeName "auralis_reader.exe"

[Setup]
AppId={{A77E131E-7D71-4F52-B6AC-1CBF9755EA16}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Auralis
DefaultDirName={autopf}\Auralis Reader
DefaultGroupName=Auralis Reader
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename=Auralis-Reader-2.0.0-Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Auralis Reader"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\Auralis Reader"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Atalhos adicionais:"; Flags: unchecked

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Abrir Auralis Reader"; Flags: nowait postinstall skipifsilent
