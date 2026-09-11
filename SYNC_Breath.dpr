library SYNC_Breath;

{$ALIGN 8}

uses
  Winapi.Windows,
  AviUtl2FilterTypes in '..\Syncroh2\AviUtl\Filter\AviUtl2FilterTypes.pas',
  PluginFilterTable in '..\Syncroh2\Plugin_Filter\PluginFilterTable.pas',
  SYNC_Breath_FilterPlugin in 'Source\Plugin\Filter\SYNC_Breath_FilterPlugin.pas';

function InitializePlugin(Version: DWORD): Byte; cdecl;
begin
  Result := InitializeBreathPlugin(Version);
end;

procedure UninitializePlugin; cdecl;
begin
  FinalizeBreathPlugin;
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := GetBreathFilterTable;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.
