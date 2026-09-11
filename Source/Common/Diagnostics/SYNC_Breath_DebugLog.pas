unit SYNC_Breath_DebugLog;

interface

procedure ResetDebugLog;
procedure DebugLog(const MessageText: string);

implementation

uses
  System.IOUtils,
  System.SysUtils,
  System.SyncObjs;

const
  DEBUG_LOG_PATH =
    'C:\ProgramData\aviutl2\Plugin\SYNC_Breath\SYNC_Breath_debug.log';

var
  LogLock: TCriticalSection;

procedure ResetDebugLog;
begin
{$IFDEF DEBUG}
  LogLock.Acquire;
  try
    TFile.WriteAllText(DEBUG_LOG_PATH,
      FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
      ' Debug log started.' + sLineBreak, TEncoding.UTF8);
  finally
    LogLock.Release;
  end;
{$ENDIF}
end;

procedure DebugLog(const MessageText: string);
begin
{$IFDEF DEBUG}
  LogLock.Acquire;
  try
    TFile.AppendAllText(DEBUG_LOG_PATH,
      FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' +
      MessageText + sLineBreak, TEncoding.UTF8);
  finally
    LogLock.Release;
  end;
{$ENDIF}
end;

initialization
  LogLock := TCriticalSection.Create;

finalization
  LogLock.Free;

end.
