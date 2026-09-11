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
  PluginFilterTable;

function EmptyProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
begin
  Result := 1;
end;

function InitializeBreathPlugin(Version: DWORD): Byte;
begin
  Result := 1;
end;

procedure FinalizeBreathPlugin;
begin
end;

function GetBreathFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if GTable.Name = nil then
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_FILTER,
      '呼吸', 'SYNC', '呼吸フィルタープラグイン', EmptyProcVideo, nil);
  Result := @GTable;
end;

end.
