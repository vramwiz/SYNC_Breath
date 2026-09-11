unit SYNC_Breath_FilterPlugin;


interface

uses
  Winapi.Windows,
  AviUtl2FilterTypes;

function InitializeBreathPlugin(Version: DWORD): Byte;
procedure FinalizeBreathPlugin;
function GetBreathFilterTable: PFILTER_PLUGIN_TABLE;

implementation

uses
  System.SysUtils,
  Vcl.Forms,
  PluginFilterTable,
  SYNC_Breath_LastFrameCapture,
  SYNC_Breath_SettingsForm;

var
  SettingsButton: TFILTER_ITEM_BUTTON;

function EmptyProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
begin
  CaptureLastFrame(Video);
  Result := 1;
end;

procedure SettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  Height: Integer;
  Pixels: TBytes;
  SettingsForm: TFormBreathSettings;
  Status: string;
  Width: Integer;
begin
  SettingsForm := TFormBreathSettings.Create(nil);
  try
    if CopyLastFrame(Pixels, Width, Height, Status) then
      SettingsForm.SetBackgroundRgba(Pixels, Width, Height);
    SettingsForm.SetCaptureStatus(Status);
    SettingsForm.ShowModal;
  finally
    SettingsForm.Free;
  end;
end;

function InitializeBreathPlugin(Version: DWORD): Byte;
begin
  InitializeLastFrameCapture;
  Result := 1;
end;

procedure FinalizeBreathPlugin;
begin
  FinalizeLastFrameCapture;
end;

function GetBreathFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if GTable.Name = nil then
  begin
    AddButton(SettingsButton, #$8A2D#$5B9A, SettingsButtonCallback);
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_FILTER,
      #$547C#$5438, 'SYNC',
      #$547C#$5438#$30D5#$30A3#$30EB#$30BF#$30FC#$30D7#$30E9#$30B0#$30A4#$30F3,
      EmptyProcVideo, nil);
  end;
  Result := @GTable;
end;

end.
