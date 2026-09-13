unit SYNC_Breath_HalfPixels;

interface

procedure ConvertHalfRgbaRow(Source: System.PWord; Destination: PByte;
  PixelCount: Integer);

implementation

var
  HalfByteTable: array[Word] of Byte;

procedure InitializeTable;
var
  Bits, Exponent, Mantissa, Numerator, Denominator: Integer;
  Rounded, Remainder: Integer;
begin
  // Every binary16 encoding fits in 64 KiB. Match clamp and ties-to-even
  // rounding without per-channel floating-point conversion during rendering.
  for Bits := 0 to High(Word) do
  begin
    Exponent := (Bits shr 10) and $1F;
    Mantissa := Bits and $03FF;
    if ((Exponent = 31) and (Mantissa <> 0)) or
      ((Bits and $8000) <> 0) or (Exponent <= 5) then
      HalfByteTable[Bits] := 0
    else if Exponent >= 15 then
      HalfByteTable[Bits] := 255
    else
    begin
      Numerator := (1024 + Mantissa) * 255;
      Denominator := 1 shl (25 - Exponent);
      Rounded := Numerator div Denominator;
      Remainder := Numerator mod Denominator;
      if (Remainder * 2 > Denominator) or
        ((Remainder * 2 = Denominator) and Odd(Rounded)) then
        Inc(Rounded);
      HalfByteTable[Bits] := Rounded;
    end;
  end;
end;

procedure ConvertHalfRgbaRow(Source: System.PWord; Destination: PByte;
  PixelCount: Integer);
var
  X: Integer;
begin
  for X := 0 to PixelCount - 1 do
  begin
    Destination^ := HalfByteTable[Source^];
    Inc(Source); Inc(Destination);
    Destination^ := HalfByteTable[Source^];
    Inc(Source); Inc(Destination);
    Destination^ := HalfByteTable[Source^];
    Inc(Source); Inc(Destination);
    Destination^ := HalfByteTable[Source^];
    Inc(Source); Inc(Destination);
  end;
end;

initialization
  InitializeTable;

end.
