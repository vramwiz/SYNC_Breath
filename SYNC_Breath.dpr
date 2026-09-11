library SYNC_Breath;

{$ALIGN 8}

uses
  Winapi.Windows,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  PluginFilterTable in 'Source\Lib\PluginFilterTable.pas',
  SYNC_Breath_DebugLog in 'Source\Common\Diagnostics\SYNC_Breath_DebugLog.pas',
  SYNC_Breath_RuntimeSettings in 'Source\Common\Settings\SYNC_Breath_RuntimeSettings.pas',
  SYNC_Breath_GuideData in 'Source\Common\Settings\SYNC_Breath_GuideData.pas',
  SYNC_Breath_RuntimeDeformer in 'Source\Common\Render\SYNC_Breath_RuntimeDeformer.pas',
  SYNC_Breath_GpuDeformer in 'Source\Common\Render\SYNC_Breath_GpuDeformer.pas',
  SYNC_Breath_LastFrameCapture in 'Source\Common\Render\SYNC_Breath_LastFrameCapture.pas',
  SYNC_Breath_SettingsForm in 'Source\Plugin\Filter\SYNC_Breath_SettingsForm.pas' {FormBreathSettings},
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
