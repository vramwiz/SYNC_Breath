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
  System.UITypes,
  Vcl.Dialogs,
  Vcl.Forms,
  PluginFilterTable,
  SYNC_Breath_LastFrameCapture,
  SYNC_Breath_SettingsForm;

var
  SettingsButton: TFILTER_ITEM_BUTTON;
  InternalDataGroup: TFILTER_ITEM_GROUP;
  GuideDataItem: TFILTER_ITEM_STRING;

function EmptyProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
begin
  CaptureLastFrame(Video);
  Result := 1;
end;

procedure SettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  CurrentDataText: string;
  DataError: string;
  FocusObject: OBJECT_HANDLE;
  Height: Integer;
  Pixels: TBytes;
  SavedDataText: string;
  SettingsForm: TFormBreathSettings;
  Status: string;
  Utf8DataText: UTF8String;
  Width: Integer;
begin
  try
    SettingsForm := TFormBreathSettings.Create(nil);
    try
      if CopyLastFrame(Pixels, Width, Height, Status) then
        SettingsForm.SetBackgroundRgba(Pixels, Width, Height);
      SettingsForm.SetCaptureStatus(Status);
      CurrentDataText := '';
      if Assigned(GuideDataItem.Value) then
        CurrentDataText := string(GuideDataItem.Value);
      if not SettingsForm.TryLoadGuideDataText(CurrentDataText,
        DataError) then
      begin
        MessageDlg(#$4FDD#$5B58#$6E08#$307F#$30AC#$30A4#$30C9#$30C7#$30FC#$30BF +
          #$3092#$8AAD#$307F#$8FBC#$3081#$307E#$305B#$3093#$3067#$3057#$305F#$3002 +
          sLineBreak + DataError, mtWarning, [mbOK], 0);
        SettingsForm.TryLoadGuideDataText('', DataError);
      end;
      SettingsForm.ShowModal;
      if not SettingsForm.TrySaveGuideDataText(SavedDataText,
        DataError) then
      begin
        MessageDlg(#$30AC#$30A4#$30C9#$30C7#$30FC#$30BF#$3092 +
          #$4FDD#$5B58#$3067#$304D#$307E#$305B#$3093#$3067#$3057#$305F#$3002 +
          sLineBreak + DataError, mtError, [mbOK], 0);
        Exit;
      end;
      if SavedDataText = CurrentDataText then
        Exit;
      FocusObject := nil;
      if (Edit <> nil) and Assigned(Edit^.GetFocusObject) then
        FocusObject := Edit^.GetFocusObject();
      if (Edit = nil) or not Assigned(Edit^.SetObjectItemValue) or
        (FocusObject = nil) then
      begin
        MessageDlg(#$4FDD#$5B58#$5BFE#$8C61#$3092#$53D6#$5F97 +
          #$3067#$304D#$307E#$305B#$3093#$3067#$3057#$305F#$3002,
          mtError, [mbOK], 0);
        Exit;
      end;
      Utf8DataText := UTF8String(SavedDataText);
      if not Edit^.SetObjectItemValue(FocusObject, #$547C#$5438,
        #$30AC#$30A4#$30C9#$30C7#$30FC#$30BF,
        PAnsiChar(Utf8DataText)) then
        MessageDlg(#$30AC#$30A4#$30C9#$30C7#$30FC#$30BF#$3092 +
          #$66F8#$304D#$8FBC#$3081#$307E#$305B#$3093#$3067#$3057#$305F#$3002,
          mtError, [mbOK], 0);
    finally
      SettingsForm.Free;
    end;
  except
    on E: Exception do
      MessageDlg(#$8A2D#$5B9A#$753B#$9762#$3067#$30A8#$30E9#$30FC +
        #$304C#$767A#$751F#$3057#$307E#$3057#$305F#$3002 + sLineBreak +
        E.Message, mtError, [mbOK], 0);
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
    AddGroup(InternalDataGroup,
      #$5185#$90E8#$30C7#$30FC#$30BF, 0);
    AddString(GuideDataItem,
      #$30AC#$30A4#$30C9#$30C7#$30FC#$30BF, '');
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_FILTER,
      #$547C#$5438, 'SYNC',
      #$547C#$5438#$30D5#$30A3#$30EB#$30BF#$30FC#$30D7#$30E9#$30B0#$30A4#$30F3,
      EmptyProcVideo, nil);
  end;
  Result := @GTable;
end;

end.
