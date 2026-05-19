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
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "IbulLocalPrintBridge"; ValueData: """{app}\bridge\{#BridgeExeName}"""; Flags: uninsdeletevalue

[Run]
Filename: "{app}\bridge\{#BridgeExeName}"; WorkingDir: "{app}\bridge"; StatusMsg: "Yazici servisi baslatiliyor..."; Flags: runhidden nowait skipifsilent
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\bridge\wait_for_bridge_health.ps1"" -TimeoutSeconds 45"; StatusMsg: "Yazici servisi hazirlaniyor..."; Flags: waituntilterminated runhidden skipifsilent
Filename: "{app}\{#SellerExeName}"; Description: "Ibul Satıcı uygulamasini simdi baslat"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "taskkill.exe"; Parameters: "/IM {#BridgeExeName} /F"; Flags: runhidden skipifdoesntexist
Filename: "taskkill.exe"; Parameters: "/IM {#SellerExeName} /F"; Flags: runhidden skipifdoesntexist

[Code]
procedure RepairAutostartRegistry();
var
  Value: string;
  BridgePath: string;
begin
  BridgePath := ExpandConstant('"{app}\bridge\{#BridgeExeName}"');
  if RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run',
    'IbulLocalPrintBridge', Value) then
  begin
    if (Pos('powershell.exe', LowerCase(Value)) > 0) or
       (Pos('.ps1', LowerCase(Value)) > 0) or
       (Value <> BridgePath) then
    begin
      RegWriteStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run',
        'IbulLocalPrintBridge', BridgePath);
    end;
  end
  else
  begin
    RegWriteStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run',
      'IbulLocalPrintBridge', BridgePath);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    RepairAutostartRegistry();
end;
