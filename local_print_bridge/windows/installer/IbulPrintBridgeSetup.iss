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
Source: "wait_for_bridge_health.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Ibul Print Bridge"; Filename: "{app}\{#ExeName}"
Name: "{group}\Kaldir"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Ibul Print Bridge"; Filename: "{app}\{#ExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "IbulLocalPrintBridge"; ValueData: """{app}\{#ExeName}"""; Flags: uninsdeletevalue

[Run]
Filename: "{app}\{#ExeName}"; WorkingDir: "{app}"; StatusMsg: "Yazici servisi baslatiliyor..."; Flags: runhidden nowait skipifsilent
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\wait_for_bridge_health.ps1"" -TimeoutSeconds 45 -BridgeExe ""{app}\{#ExeName}"""; StatusMsg: "Yazici servisi hazirlaniyor..."; Flags: waituntilterminated runhidden skipifsilent
Filename: "{app}\{#ExeName}"; Description: "Yazici servisini simdi baslat"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "taskkill.exe"; Parameters: "/IM {#ExeName} /F"; Flags: runhidden skipifdoesntexist

[Code]
procedure RepairAutostartRegistry();
var
  Value: string;
  BridgePath: string;
begin
  BridgePath := ExpandConstant('"{app}\{#ExeName}"');
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
