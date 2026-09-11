unit SYNC_Breath_GuideData;

interface

uses
  System.Types;

type
  TBreathGuidePoint = (bgpWaist, bgpChest, bgpNeck, bgpHead,
    bgpLeftShoulder, bgpRightShoulder);
  TBreathGuidePoints = array[TBreathGuidePoint] of TPointF;

procedure ResetBreathGuide(out Guide: TBreathGuidePoints);
function TryDecodeBreathGuide(const Text: string; out Guide: TBreathGuidePoints;
  out ErrorText: string): Boolean;
function TryEncodeBreathGuide(const Guide: TBreathGuidePoints;
  out Text, ErrorText: string): Boolean;

implementation

uses
  System.Classes,
  System.SysUtils;

procedure ResetBreathGuide(out Guide: TBreathGuidePoints);
begin
  Guide[bgpWaist] := PointF(0.50, 0.74);
  Guide[bgpChest] := PointF(0.50, 0.49);
  Guide[bgpNeck] := PointF(0.50, 0.30);
  Guide[bgpHead] := PointF(0.50, 0.14);
  Guide[bgpLeftShoulder] := PointF(0.28, 0.37);
  Guide[bgpRightShoulder] := PointF(0.72, 0.37);
end;

function TryDecodeBreathGuide(const Text: string; out Guide: TBreathGuidePoints;
  out ErrorText: string): Boolean;
var
  FS: TFormatSettings;
  Kind: TBreathGuidePoint;
  Parts: TStringList;
  ValueIndex: Integer;
begin
  ResetBreathGuide(Guide);
  ErrorText := '';
  if Text = '' then
    Exit(True);
  Result := False;
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ';';
    Parts.DelimitedText := Text;
    // SBR1 is persisted in AviUtl2 projects, so field order must remain stable.
    if (Parts.Count <> 13) or (Parts[0] <> 'SBR1') then
    begin
      ErrorText := 'Invalid guide data format.';
      Exit;
    end;
    FS := TFormatSettings.Create('en-US');
    ValueIndex := 1;
    for Kind := Low(TBreathGuidePoint) to High(TBreathGuidePoint) do
    begin
      if not TryStrToFloat(Parts[ValueIndex], Guide[Kind].X, FS) or
        not TryStrToFloat(Parts[ValueIndex + 1], Guide[Kind].Y, FS) or
        (Guide[Kind].X < 0) or (Guide[Kind].X > 1) or
        (Guide[Kind].Y < 0) or (Guide[Kind].Y > 1) then
      begin
        ErrorText := 'Invalid guide coordinate.';
        Exit;
      end;
      Inc(ValueIndex, 2);
    end;
    if (Guide[bgpHead].Y >= Guide[bgpNeck].Y) or
      (Guide[bgpNeck].Y >= Guide[bgpChest].Y) or
      (Guide[bgpChest].Y >= Guide[bgpWaist].Y) or
      (Guide[bgpLeftShoulder].X >= Guide[bgpChest].X) or
      (Guide[bgpRightShoulder].X <= Guide[bgpChest].X) then
    begin
      ErrorText := 'Invalid guide point order.';
      Exit;
    end;
    Result := True;
  finally
    Parts.Free;
  end;
end;

function TryEncodeBreathGuide(const Guide: TBreathGuidePoints;
  out Text, ErrorText: string): Boolean;
var
  FS: TFormatSettings;
  Kind: TBreathGuidePoint;
begin
  FS := TFormatSettings.Create('en-US');
  Text := 'SBR1';
  for Kind := Low(TBreathGuidePoint) to High(TBreathGuidePoint) do
    Text := Text + ';' + FormatFloat('0.000000', Guide[Kind].X, FS) +
      ';' + FormatFloat('0.000000', Guide[Kind].Y, FS);
  Result := Length(Text) <= 32767;
  if Result then
    ErrorText := ''
  else
  begin
    Text := '';
    ErrorText := 'Guide data is too long.';
  end;
end;

end.
