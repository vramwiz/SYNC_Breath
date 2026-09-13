unit SYNC_Breath_DebugLog;

interface

procedure ResetDebugLog;
procedure DebugLog(const MessageText: string);

{$IFDEF DEBUG}
type
  TPerfStage = (psCapture, psGpuSetup, psGpuSubmit, psReadbackWait,
    psPixelConvert, psSetImage, psGpuTotal, psCpuFallback, psTotal);
function PerfNow: Int64;
procedure PerfRecord(Stage: TPerfStage; Started: Int64);
procedure FlushPerformance;
{$ENDIF}

implementation

uses
  Winapi.Windows,
  System.IOUtils,
  System.SysUtils,
  System.SyncObjs;

const
  DEBUG_LOG_PATH =
    'C:\ProgramData\aviutl2\Plugin\SYNC_Breath\SYNC_Breath_debug.log';

var
  LogLock: TCriticalSection;

{$IFDEF DEBUG}
const
  STAGE_NAMES: array[TPerfStage] of string = ('capture', 'gpu_setup',
    'gpu_submit', 'readback_wait', 'pixel_convert', 'set_image',
    'gpu_total', 'cpu_fallback', 'callback_total');
type
  TPerfStats = record
    Count, Batch: Integer;
    Sum, Maximum: Int64;
  end;
var
  PerfFrequency: Int64;
  PerfStats: array[TPerfStage] of TPerfStats;

function PerfNow: Int64;
begin
  QueryPerformanceCounter(Result);
end;

procedure FlushPerformance;
var
  Stage: TPerfStage;
  S: TPerfStats;
begin
  LogLock.Acquire;
  try
    for Stage := Low(TPerfStage) to High(TPerfStage) do
    begin
      S := PerfStats[Stage];
      if (S.Count = 0) or (PerfFrequency = 0) then Continue;
      try
        TFile.AppendAllText(DEBUG_LOG_PATH,
          FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
          Format(' PERF stage=%s batch=%d n=%d mean_ms=%.4f max_ms=%.4f',
            [STAGE_NAMES[Stage], S.Batch, S.Count,
             S.Sum * 1000.0 / PerfFrequency / S.Count,
             S.Maximum * 1000.0 / PerfFrequency]) + sLineBreak, TEncoding.UTF8);
      except
        // Diagnostics must not interrupt rendering when the log is unavailable.
      end;
      Inc(PerfStats[Stage].Batch);
      PerfStats[Stage].Count := 0;
      PerfStats[Stage].Sum := 0;
      PerfStats[Stage].Maximum := 0;
    end;
  finally
    LogLock.Release;
  end;
end;

procedure PerfRecord(Stage: TPerfStage; Started: Int64);
var
  Elapsed: Int64;
begin
  Elapsed := PerfNow - Started;
  LogLock.Acquire;
  try
    Inc(PerfStats[Stage].Count);
    Inc(PerfStats[Stage].Sum, Elapsed);
    if Elapsed > PerfStats[Stage].Maximum then
      PerfStats[Stage].Maximum := Elapsed;
    // All file writes happen after the outer callback timer has stopped.
    if (Stage = psTotal) and (PerfStats[psTotal].Count >= 120) then
      FlushPerformance;
  finally
    LogLock.Release;
  end;
end;
{$ENDIF}

procedure ResetDebugLog;
begin
{$IFDEF DEBUG}
  LogLock.Acquire;
  try
    TFile.WriteAllText(DEBUG_LOG_PATH,
      FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
      ' Debug log started. PERF v1: 120 callbacks/batch; batch 0 includes warmup; host elapsed ms; Debug only.' + sLineBreak, TEncoding.UTF8);
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
{$IFDEF DEBUG}
  QueryPerformanceFrequency(PerfFrequency);
{$ENDIF}

finalization
  LogLock.Free;

end.
