#define AppName "skeleton"
#define AppDisplayName "skeleton (ARM64)"
#ifndef AppVersion
#define AppVersion "0.3.2"
#endif
#ifndef AppPublisher
#define AppPublisher "fosterbarnes"
#endif
#ifndef AppURL
#define AppURL "https://github.com/fosterbarnes/skeleton"
#endif
#ifndef SetupIconFile
#define SetupIconFile "..\.resources\icon\skeleton.ico"
#endif
#ifndef AppCopyright
#define AppCopyright "Copyright © 2026 Foster Barnes"
#endif
#define ExeName "skeleton.exe"

[Setup]
AppId={{7F3E2A91-4D58-4B6C-9E1F-2A8D5C4B7E90}
AppName={#AppName}
UninstallDisplayName={#AppDisplayName}
AppVersion={#AppVersion}
VersionInfoVersion={#AppVersion}.0
VersionInfoProductVersion={#AppVersion}
VersionInfoCopyright={#AppCopyright}
DisableDirPage=auto
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={localappdata}\{#AppName}
UninstallDisplayIcon={app}\{#ExeName}
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
OutputDir=Output
OutputBaseFilename=skeleton-arm64-installer
SetupIconFile={#SetupIconFile}
SolidCompression=yes
WizardStyle=classic dark

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
SetupWindowTitle=skeleton v{#AppVersion} installer (ARM64)

[CustomMessages]
CreateStartMenuIcon=Create Start Menu shortcut

[Tasks]
Name: "desktopicon"; Description: "Create Desktop shortcut"; GroupDescription: "{cm:AdditionalIcons}"
Name: "startmenuicon"; Description: "{cm:CreateStartMenuIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\publish\arm64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#ExeName}"; Tasks: startmenuicon
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#ExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#ExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

#include "skeleton.uninstall.iss"
