program HalfPixelsTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Math,
  Winapi.Windows,
  SYNC_Breath_HalfPixels in '..\Source\Common\Render\SYNC_Breath_HalfPixels.pas';

function ReferenceHalfToSingle(Value: Word): Single;
var
  E: Integer;
  M, Bits, Sign: Cardinal;
begin
  Sign := Cardinal(Value and $8000) shl 16;
  E := (Value shr 10) and $1F;
  M := Value and $03FF;
  if E = 0 then
  begin
    if M = 0 then Bits := Sign
    else
    begin
      E := -14;
      while (M and $0400) = 0 do begin M := M shl 1; Dec(E); end;
      Bits := Sign or Cardinal(E + 127) shl 23 or (M and $03FF) shl 13;
    end;
  end
  else if E = $1F then Bits := Sign or $7F800000 or M shl 13
  else Bits := Sign or Cardinal(E + 112) shl 23 or M shl 13;
  Result := PSingle(@Bits)^;
end;

function ReferenceByte(Value: Single): Byte;
begin
  if IsNan(Value) or (Value <= 0) then Exit(0);
  if Value >= 1 then Exit(255);
  Result := Round(Value * 255);
end;

procedure ReferenceRow(Source: Pointer; Destination: PByte; PixelCount: Integer);
type
  TWords = array[0..7] of Word;
  PWords = ^TWords;
var
  Words: PWords;
  X: Integer;
begin
  Words := Source;
  for X := 0 to PixelCount - 1 do
  begin
    Destination[0] := ReferenceByte(ReferenceHalfToSingle(Words[0]));
    Destination[1] := ReferenceByte(ReferenceHalfToSingle(Words[1]));
    Destination[2] := ReferenceByte(ReferenceHalfToSingle(Words[2]));
    Destination[3] := ReferenceByte(ReferenceHalfToSingle(Words[3]));
    Words := PWords(PByte(Words) + 8);
    Inc(Destination, 4);
  end;
end;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

procedure CheckValues;
var
  Source: array of Word;
  Output: TBytes;
  I, Row, Channel: Integer;
begin
  SetLength(Source, 65536);
  SetLength(Output, 65536);
  for I := 0 to 65535 do Source[I] := I;
  ConvertHalfRgbaRow(@Source[0], @Output[0], 16384);
  for I := 0 to 65535 do
    Check(Output[I] = ReferenceByte(ReferenceHalfToSingle(I)),
      Format('Mismatch at binary16 0x%.4x', [I]));

  // Odd row widths, input padding, output guards and RGBA channel order.
  SetLength(Source, 3 * 16);
  SetLength(Output, 3 * 12 + 2);
  FillChar(Output[0], Length(Output), $A5);
  for I := 0 to High(Source) do Source[I] := $3000 + I * 37;
  for Row := 0 to 2 do
    ConvertHalfRgbaRow(@Source[Row * 16], @Output[1 + Row * 12], 3);
  for Row := 0 to 2 do
    for Channel := 0 to 11 do
      Check(Output[1 + Row * 12 + Channel] =
        ReferenceByte(ReferenceHalfToSingle(Source[Row * 16 + Channel])),
        'Row pitch or channel order mismatch');
  Check((Output[0] = $A5) and (Output[High(Output)] = $A5), 'Guard overwritten');
  ConvertHalfRgbaRow(nil, nil, 0);
  Writeln('PASS: all 65536 binary16 values, RGBA order, padded rows, guards, empty row');
end;

procedure Benchmark;
const
  Width = 1125;
  Height = 1500;
  Repeats = 10;
var
  Source: array of Word;
  OldOutput, NewOutput: TBytes;
  I, Pass, Y: Integer;
  Started, Finished, Frequency: Int64;
  OldMs, NewMs: Double;
begin
  SetLength(Source, Width * Height * 4);
  SetLength(OldOutput, Length(Source));
  SetLength(NewOutput, Length(Source));
  // Synthetic [0,1] RGBA values, including transparent and opaque components.
  for I := 0 to High(Source) do Source[I] := I mod ($3C00 + 1);
  QueryPerformanceFrequency(Frequency);
  OldMs := 0;
  NewMs := 0;
  for Pass := 0 to Repeats do
  begin
    QueryPerformanceCounter(Started);
    for Y := 0 to Height - 1 do
      ReferenceRow(@Source[Y * Width * 4], @OldOutput[Y * Width * 4], Width);
    QueryPerformanceCounter(Finished);
    if Pass = 0 then OldMs := 0
    else OldMs := OldMs + (Finished - Started) * 1000.0 / Frequency;
    QueryPerformanceCounter(Started);
    for Y := 0 to Height - 1 do
      ConvertHalfRgbaRow(@Source[Y * Width * 4], @NewOutput[Y * Width * 4], Width);
    QueryPerformanceCounter(Finished);
    if Pass = 0 then NewMs := 0
    else NewMs := NewMs + (Finished - Started) * 1000.0 / Frequency;
  end;
  Check(CompareMem(@OldOutput[0], @NewOutput[0], Length(OldOutput)), 'Frame mismatch');
  Writeln(Format('Synthetic 1125x1500, %d iterations: old=%.3f ms new=%.3f ms speedup=%.2fx',
    [Repeats, OldMs / Repeats, NewMs / Repeats, OldMs / NewMs]));
end;

begin
  try
    CheckValues;
    Benchmark;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
