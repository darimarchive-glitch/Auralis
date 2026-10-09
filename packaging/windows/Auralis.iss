#define MyAppName "Auralis"
#ifndef MyAppVersion
#define MyAppVersion "3.1.1"
#endif

[Setup]
AppId={{2EB75C52-CABE-4FC5-B445-84C36F5D85CF}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher=Auralis
DefaultDirName={autopf}\Auralis
DefaultGroupName=Auralis
DisableProgramGroupPage=yes
OutputDir=..\..\artifacts
OutputBaseFilename=Auralis-Reader-{#MyAppVersion}-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\Auralis.exe

[Files]
Source: "app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Auralis"; Filename: "{app}\Auralis.exe"
Name: "{autodesktop}\Auralis"; Filename: "{app}\Auralis.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Atalhos adicionais:"

[Run]
Filename: "{app}\Auralis.exe"; Description: "Abrir Auralis"; Flags: nowait postinstall skipifsilent
