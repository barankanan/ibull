#define AppName "Ibul Print Bridge"
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define Publisher "Ibul"
#define ExeName "IbulPrintBridge.exe"
#define DistDir "..\\dist\\bridge"

[Setup]
AppId={{C0EFD72A-6A45-4D75-BB74-AFE63C62D0E8}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#Publisher}
DefaultDirName={autopf}\IbulPrintBridge
DefaultGroupName=Ibul Print Bridge
UninstallDisplayIcon={app}\{#ExeName}
OutputDir=..\dist\installer
OutputBaseFilename=IbulPrintBridgeSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
CloseApplications=yes
CloseApplicationsFilter={#ExeName}
RestartApplications=no

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaustu kisayolu olustur"; GroupDescription: "Ek kisayollar:"; Flags: unchecked

[Files]
Source: "{#DistDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Ibul Print Bridge"; Filename: "{app}\{#ExeName}"
Name: "{group}\Kaldir"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Ibul Print Bridge"; Filename: "{app}\{#ExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "IbulLocalPrintBridge"; ValueData: """{app}\{#ExeName}"""; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#ExeName}"; Description: "Yazici servisini simdi baslat"; Flags: nowait postinstall skipifsilent
