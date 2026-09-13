unit SYNC_Breath_RuntimeSettings;

interface

uses
  AviUtl2FilterTypes;

type
  TBreathType = (btQuiet, btStandard, btLarge);
  TBreathRhythm = (brNormal, brDeep, brPanting, brHeeHeeHoo);

  TBreathRuntimeSettings = record
    PeriodScale: Double;
    Depth: Double;
    PhaseDegrees: Double;
    BreathType: TBreathType;
    Rhythm: TBreathRhythm;
  end;

procedure AddBreathRuntimeItems;
function CurrentBreathRuntimeSettings: TBreathRuntimeSettings;
function CalculateBreathAmount(TimeSeconds: Double;
  const Settings: TBreathRuntimeSettings): Double;

implementation

uses
  System.Math,
  PluginFilterTable;

var
  BreathTypeItems: array[0..3] of TFILTER_ITEM_SELECT_ITEM;
  RhythmItems: array[0..4] of TFILTER_ITEM_SELECT_ITEM;
  BreathTypeItem: TFILTER_ITEM_SELECT;
  RhythmItem: TFILTER_ITEM_SELECT;
  PeriodItem: TFILTER_ITEM_TRACK;
  StrengthItem: TFILTER_ITEM_TRACK;
  PhaseItem: TFILTER_ITEM_TRACK;

procedure AddBreathRuntimeItems;
begin
  BreathTypeItems[0].Name := #$9759#$304B#$306A#$547C#$5438;
  BreathTypeItems[0].Value := Ord(btQuiet);
  BreathTypeItems[1].Name := #$6A19#$6E96#$547C#$5438;
  BreathTypeItems[1].Value := Ord(btStandard);
  BreathTypeItems[2].Name := #$5927#$304D#$306A#$547C#$5438;
  BreathTypeItems[2].Value := Ord(btLarge);
  BreathTypeItems[3].Name := nil;
  BreathTypeItems[3].Value := 0;
  AddSelect(BreathTypeItem, #$547C#$5438#$30BF#$30A4#$30D7,
    Ord(btStandard), @BreathTypeItems[0]);
  RhythmItems[0].Name := #$901A#$5E38;
  RhythmItems[0].Value := Ord(brNormal);
  RhythmItems[1].Name := #$6DF1#$547C#$5438;
  RhythmItems[1].Value := Ord(brDeep);
  RhythmItems[2].Name := #$606F#$4E0A#$304C#$308A;
  RhythmItems[2].Value := Ord(brPanting);
  RhythmItems[3].Name := #$30D2#$30C3#$30D2#$30C3#$30D5#$30FC;
  RhythmItems[3].Value := Ord(brHeeHeeHoo);
  RhythmItems[4].Name := nil;
  RhythmItems[4].Value := 0;
  AddSelect(RhythmItem, #$547C#$5438#$30EA#$30BA#$30E0,
    Ord(brNormal), @RhythmItems[0]);
  AddTrack(StrengthItem, #$6DF1#$3055, 100.0, 0.0, 200.0, 1.0);
  AddTrack(PeriodItem, #$5468#$671F, 100.0, 80.0, 120.0, 1.0);
  AddTrack(PhaseItem, #$4F4D#$76F8, 0.0, 0.0, 360.0, 1.0);
end;

function CurrentBreathRuntimeSettings: TBreathRuntimeSettings;
begin
  Result.PeriodScale := EnsureRange(PeriodItem.Value, 80.0, 120.0) / 100.0;
  Result.Depth := EnsureRange(StrengthItem.Value, 0.0, 200.0) / 100.0;
  Result.PhaseDegrees := EnsureRange(PhaseItem.Value, 0.0, 360.0);
  Result.BreathType := TBreathType(EnsureRange(BreathTypeItem.Value,
    Ord(Low(TBreathType)), Ord(High(TBreathType))));
  Result.Rhythm := TBreathRhythm(EnsureRange(RhythmItem.Value,
    Ord(Low(TBreathRhythm)), Ord(High(TBreathRhythm))));
end;

function SmoothTransition(StartValue, EndValue, Progress: Double): Double;
begin
  Progress := EnsureRange(Progress, 0.0, 1.0);
  Progress := Progress * Progress * (3.0 - 2.0 * Progress);
  Result := StartValue + (EndValue - StartValue) * Progress;
end;

function StandardWave(Position, InhaleEnd, HoldEnd, ExhaleEnd: Double): Double;
begin
  if Position < InhaleEnd then
    Exit(SmoothTransition(0.0, 1.0, Position / InhaleEnd));
  if Position < HoldEnd then
    Exit(1.0);
  if Position < ExhaleEnd then
    Exit(SmoothTransition(1.0, 0.0, (Position - HoldEnd) /
      (ExhaleEnd - HoldEnd)));
  Result := 0.0;
end;

function RhythmWave(Position: Double; Rhythm: TBreathRhythm): Double;
begin
  case Rhythm of
    brNormal: Result := StandardWave(Position, 0.35, 0.42, 0.90);
    brDeep: Result := StandardWave(Position, 0.42, 0.55, 0.92);
    brPanting: Result := StandardWave(Position, 0.22, 0.22, 0.80);
    brHeeHeeHoo:
      if Position < 0.18 then
        Result := SmoothTransition(0.0, 0.45, Position / 0.18)
      else if Position < 0.32 then
        Result := SmoothTransition(0.45, 0.12, (Position - 0.18) / 0.14)
      else if Position < 0.50 then
        Result := SmoothTransition(0.12, 1.0, (Position - 0.32) / 0.18)
      else
        Result := SmoothTransition(1.0, 0.0, (Position - 0.50) / 0.50);
  else
    Result := 0.0;
  end;
end;

function CalculateBreathAmount(TimeSeconds: Double;
  const Settings: TBreathRuntimeSettings): Double;
const
  BASE_PERIOD_SECONDS: array[TBreathRhythm] of Double =
    (4.0, 6.0, 1.4, 3.2);
  TYPE_AMOUNT: array[TBreathType] of Double = (0.55, 1.0, 1.45);
var
  Position: Double;
begin
  Position := Frac(TimeSeconds / (BASE_PERIOD_SECONDS[Settings.Rhythm] *
    Settings.PeriodScale) + Settings.PhaseDegrees / 360.0);
  Result := RhythmWave(Position, Settings.Rhythm) *
    TYPE_AMOUNT[Settings.BreathType] * Settings.Depth;
end;

end.
