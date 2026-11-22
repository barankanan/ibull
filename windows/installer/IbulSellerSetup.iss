#define AppName "Ibul Satıcı"
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define Publisher "Ibul"
#define SellerExeName "IbulSellerDesktop.exe"
#define BridgeExeName "IbulPrintBridge.exe"
#define SellerDistDir "..\\..\\build\\windows\\x64\\runner\\Release"
#define BridgeDistDir "..\\..\\local_print_bridge\\windows\\dist\\bridge"
#define BridgeFontsDir "..\\..\\local_print_bridge\\fonts"
#define BridgeInstallerDir "..\\..\\local_print_bridge\\windows\\installer"

[Setup]
AppId={{A91F6C3E-5B2D-4E8A-9F1C-2D7E6B4A9031}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#Publisher}
DefaultDirName={autopf}\IbulSeller
DefaultGroupName=Ibul Satıcı
UninstallDisplayIcon={app}\{#SellerExeName}
OutputDir=..\..\build\windows\installer
OutputBaseFilename=IbulSellerSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
CloseApplications=yes
CloseApplicationsFilter={#SellerExeName},{#BridgeExeName}
RestartApplications=no

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaustu kisayolu olustur"; GroupDescription: "Ek kisayollar:"; Flags: unchecked

[Files]
Source: "{#SellerDistDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BridgeDistDir}\*"; DestDir: "{app}\bridge"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#BridgeFontsDir}\*.ttf"; DestDir: "{app}\bridge\fonts"; Flags: ignoreversion
Source: "{#BridgeInstallerDir}\wait_for_bridge_health.ps1"; DestDir: "{app}\bridge"; Flags: ignoreversion

[Icons]
Name: "{group}\Ibul Satıcı"; Filename: "{app}\{#SellerExeName}"
Name: "{group}\Kaldir"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Ibul Satıcı"; Filename: "{app}\{#SellerExeName}"; Tasks: desktopicon

[Registry]
; Nothing starts at Windows sign-in. The seller app starts the printer service
; when it opens. An autostart value left by an older setup is removed.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "IbulLocalPrintBridge"; Flags: deletevalue

[Run]
; Waiter phones reach the local center over the private (home/work) network
; only. The rule is bound to the seller program, not to a fixed port.
Filename: "netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Ibul Satici Yerel Merkez"""; Flags: runhidden
Filename: "netsh.exe"; Parameters: "advfirewall firewall add rule name=""Ibul Satici Yerel Merkez"" dir=in action=allow program=""{app}\{#SellerExeName}"" protocol=TCP profile=private"; StatusMsg: "Yerel ag izni ekleniyor..."; Flags: runhidden
Filename: "{app}\{#SellerExeName}"; Description: "Ibul Satıcı uygulamasini simdi baslat"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "taskkill.exe"; Parameters: "/IM {#BridgeExeName} /F"; Flags: runhidden skipifdoesntexist
Filename: "taskkill.exe"; Parameters: "/IM {#SellerExeName} /F"; Flags: runhidden skipifdoesntexist
Filename: "netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Ibul Satici Yerel Merkez"""; Flags: runhidden

[Code]
procedure RemoveAutostartLeftovers();
begin
  RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run',
    'IbulLocalPrintBridge');
  DeleteFile(ExpandConstant('{userstartup}\ibul-local-print.cmd'));
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    RemoveAutostartLeftovers();
end;
