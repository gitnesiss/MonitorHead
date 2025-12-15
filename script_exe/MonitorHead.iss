; MonitorHead Setup Script
; Created with Inno Setup 6

#define MyAppName "MonitorHead"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Trofimov RV"
#define MyAppExeName "MonitorHead.exe"
#define MyIconPath "C:\Users\pomai\programming\code\projects\qt_qml\MonitorHead\images\logo.ico"

[Setup]
AppId={{90DBD8C4-7E9F-44C1-8DFF-28ED15470F1B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=C:\Users\pomai\programming\code\projects\qt_qml\MonitorHead\executable_files
OutputBaseFilename=MonitorHead_Setup
SetupIconFile={#MyIconPath}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
VersionInfoVersion={#MyAppVersion}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription={#MyAppName} Setup
VersionInfoCopyright=Copyright © {#MyAppPublisher}

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "C:\Users\pomai\programming\code\projects\qt_qml\MonitorHead\Release_For_Installer\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\Users\pomai\programming\code\projects\qt_qml\MonitorHead\Release_For_Installer\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyIconPath}"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\logo.ico"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\logo.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
procedure InitializeWizard();
begin
  // Инициализация мастера установки
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResearchPath: String;
begin
  if CurStep = ssPostInstall then
  begin
    ResearchPath := ExpandConstant('{userdocs}') + '\MonitorHead\research';
    if not DirExists(ResearchPath) then
      ForceDirectories(ResearchPath);
      
    SaveStringToFile(
      ResearchPath + '\README.txt',
      'Папка для сохранения исследований MonitorHead' + #13#10 +
      'Файлы: Research_номер_дата_время.txt',
      False
    );
  end;
end;