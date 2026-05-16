#define AppName "Ibul Seller Desktop"
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define Publisher "Ibul"
#define ExeName "IbulSellerDesktop.exe"
#define DistDir "..\\..\\build\\windows\\x64\\runner\\Release"

[Setup]
AppId={{6C0E4A62-34AC-4DCE-8E7E-0D72B4A13592}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#Publisher}
DefaultDirName={autopf}\IbulSellerDesktop
DefaultGroupName=Ibul Seller Desktop
UninstallDisplayIcon={app}\{#ExeName}
OutputDir=..\..\build\windows\installer
OutputBaseFilename=IbulSellerDesktopSetup
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
Name: "{group}\Ibul Seller Desktop"; Filename: "{app}\{#ExeName}"
Name: "{group}\Kaldir"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Ibul Seller Desktop"; Filename: "{app}\{#ExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#ExeName}"; Description: "Seller Desktop uygulamasini simdi baslat"; Flags: nowait postinstall skipifsilent
