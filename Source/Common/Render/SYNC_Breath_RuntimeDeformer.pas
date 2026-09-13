unit SYNC_Breath_RuntimeDeformer;

interface

uses
  AviUtl2FilterTypes,
  SYNC_Breath_RuntimeSettings;

procedure InitializeRuntimeDeformer;
procedure FinalizeRuntimeDeformer;
function ApplyBreathToVideo(Video: PFILTER_PROC_VIDEO; const GuideText: string;
  const Settings: TBreathRuntimeSettings): Boolean;

implementation

uses
  System.Classes,
  System.Math,
  System.SysUtils,
  System.Types,
  Winapi.Windows,
  SYNC_Breath_DebugLog;

type
  TGuidePoints = array[0..5] of TPointF;

var
  BufferLock: TRTLCriticalSection;
  BuffersInitialized: Boolean;
  SourcePixels: TBytes;
  OutputPixels: TBytes;
  CachedGuideText: string;
  CachedGuide: TGuidePoints;

procedure DefaultGuide(out Guide: TGuidePoints);
begin
  Guide[0] := PointF(0.50, 0.74);
  Guide[1] := PointF(0.50, 0.49);
  Guide[2] := PointF(0.50, 0.30);
  Guide[3] := PointF(0.50, 0.14);
  Guide[4] := PointF(0.28, 0.37);
  Guide[5] := PointF(0.72, 0.37);
end;

function ParseGuide(const Text: string; out Guide: TGuidePoints): Boolean;
var
  FS: TFormatSettings;
  I: Integer;
  Parts: TStringList;
begin
  DefaultGuide(Guide);
  if Text = '' then
    Exit(True);
  Result := False;
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ';';
    Parts.DelimitedText := Text;
    if (Parts.Count <> 13) or (Parts[0] <> 'SBR1') then
      Exit;
    FS := TFormatSettings.Create('en-US');
    for I := 0 to 5 do
      if not TryStrToFloat(Parts[I * 2 + 1], Guide[I].X, FS) or
        not TryStrToFloat(Parts[I * 2 + 2], Guide[I].Y, FS) then
        Exit;
    Result := True;
  finally
    Parts.Free;
  end;
end;

procedure InitializeRuntimeDeformer;
begin
  if BuffersInitialized then
    Exit;
  InitializeCriticalSection(BufferLock);
  BuffersInitialized := True;
  DefaultGuide(CachedGuide);
end;

procedure FinalizeRuntimeDeformer;
begin
  if not BuffersInitialized then
    Exit;
  EnterCriticalSection(BufferLock);
  try
    SourcePixels := nil;
    OutputPixels := nil;
    CachedGuideText := '';
  finally
    LeaveCriticalSection(BufferLock);
  end;
  DeleteCriticalSection(BufferLock);
  BuffersInitialized := False;
end;

function ApplyBreathToVideo(Video: PFILTER_PROC_VIDEO; const GuideText: string;
  const Settings: TBreathRuntimeSettings): Boolean;
const
  BASE_LIFT = 0.026;
var
  AbdomenInfluence: Double;
  Breath: Double;
  CenterX: Double;
  ChestInfluence: Double;
  ChestWidth: Double;
  Height: Integer;
  HorizontalInfluence: Double;
  I: NativeInt;
  ImageX: Double;
  ImageY: Double;
  Influence: Double;
  PixelCount: NativeInt;
  SourceIndex: NativeInt;
  SourceY: Integer;
  TimeSeconds: Double;
  UpperInfluence: Double;
  Width: Integer;
  X: Integer;
  Y: Integer;
begin
  Result := False;
  if not BuffersInitialized or (Video = nil) or (Video^.Object_ = nil) or
    not Assigned(Video^.GetImageData) or not Assigned(Video^.SetImageData) then
    Exit;
  Width := Video^.Object_^.Width;
  Height := Video^.Object_^.Height;
  if (Width <= 0) or (Height <= 0) then
    Exit;
  EnterCriticalSection(BufferLock);
  try
    if GuideText <> CachedGuideText then
    begin
      if not ParseGuide(GuideText, CachedGuide) then
        DefaultGuide(CachedGuide);
      CachedGuideText := GuideText;
    end;
    PixelCount := NativeInt(Width) * Height;
    SetLength(SourcePixels, PixelCount * SizeOf(PIXEL_RGBA));
    SetLength(OutputPixels, Length(SourcePixels));
    Video^.GetImageData(PPIXEL_RGBA(@SourcePixels[0]));
    Move(SourcePixels[0], OutputPixels[0], Length(SourcePixels));

    TimeSeconds := Video^.Object_^.Time;
    Breath := CalculateBreathAmount(TimeSeconds, Settings);
    CenterX := CachedGuide[1].X;
    ChestWidth := Max(0.08, (CachedGuide[5].X - CachedGuide[4].X) * 0.52);

    for Y := 0 to Height - 1 do
    begin
      ImageY := Y / Max(1, Height - 1);
      if ImageY <= CachedGuide[1].Y then
        ChestInfluence := 1 - Abs(ImageY - CachedGuide[1].Y) /
          Max(0.001, CachedGuide[1].Y - CachedGuide[2].Y)
      else
        ChestInfluence := 1 - (ImageY - CachedGuide[1].Y) /
          Max(0.001, (CachedGuide[0].Y - CachedGuide[1].Y) * 0.55);
      ChestInfluence := EnsureRange(ChestInfluence, 0.0, 1.0);
      if ImageY < CachedGuide[3].Y then
        UpperInfluence := 0.18 * EnsureRange(1 -
          (CachedGuide[3].Y - ImageY) /
          Max(0.001, CachedGuide[2].Y - CachedGuide[3].Y), 0.0, 1.0)
      else if ImageY < CachedGuide[2].Y then
        UpperInfluence := 0.18 + 0.22 * (ImageY - CachedGuide[3].Y) /
          Max(0.001, CachedGuide[2].Y - CachedGuide[3].Y)
      else if ImageY < CachedGuide[1].Y then
        UpperInfluence := 0.40 + 0.60 * (ImageY - CachedGuide[2].Y) /
          Max(0.001, CachedGuide[1].Y - CachedGuide[2].Y)
      else
        UpperInfluence := 0;
      if ImageY < CachedGuide[1].Y then
        AbdomenInfluence := 0
      else
        AbdomenInfluence := EnsureRange(1 - Abs(
          ((ImageY - CachedGuide[1].Y) /
          Max(0.001, CachedGuide[0].Y - CachedGuide[1].Y)) * 2 - 1),
          0.0, 1.0);
      for X := 0 to Width - 1 do
      begin
        ImageX := X / Max(1, Width - 1);
        HorizontalInfluence := EnsureRange(1 - Abs(ImageX - CenterX) /
          ChestWidth, 0.0, 1.0);
        Influence := Max(ChestInfluence, UpperInfluence) *
          HorizontalInfluence + AbdomenInfluence *
          HorizontalInfluence * 0.46;
        if Influence <= 0 then
          Continue;
        SourceY := EnsureRange(Round(Y + BASE_LIFT * Breath * Influence *
          Height), 0, Height - 1);
        SourceIndex := (NativeInt(SourceY) * Width + X) * 4;
        I := (NativeInt(Y) * Width + X) * 4;
        Move(SourcePixels[SourceIndex], OutputPixels[I], 4);
      end;
    end;
    Video^.SetImageData(PPIXEL_RGBA(@OutputPixels[0]), Width, Height);
    Result := True;
  except
    on E: Exception do
      DebugLog('Runtime deformation exception: ' + E.ClassName + ': ' +
        E.Message);
  end;
  LeaveCriticalSection(BufferLock);
end;

end.
