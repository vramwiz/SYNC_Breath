unit SYNC_Breath_RuntimeSettings;

interface

uses
  AviUtl2FilterTypes;

type
  TBreathType = (btNormal, btHeavy);

  TBreathRuntimeSettings = record
    PeriodSeconds: Double;
    Strength: Double;
    PhaseDegrees: Double;
    BreathType: TBreathType;
  end;

procedure AddBreathRuntimeItems;
function CurrentBreathRuntimeSettings: TBreathRuntimeSettings;

implementation

uses
  System.Math,
  PluginFilterTable;

var
  BreathTypeItems: array[0..2] of TFILTER_ITEM_SELECT_ITEM;
  BreathTypeItem: TFILTER_ITEM_SELECT;
  PeriodItem: TFILTER_ITEM_TRACK;
  StrengthItem: TFILTER_ITEM_TRACK;
  PhaseItem: TFILTER_ITEM_TRACK;

procedure AddBreathRuntimeItems;
begin
  BreathTypeItems[0].Name := #$901A#$5E38#$547C#$5438;
  BreathTypeItems[0].Value := Ord(btNormal);
  BreathTypeItems[1].Name := #$8352#$3044#$547C#$5438;
  BreathTypeItems[1].Value := Ord(btHeavy);
  BreathTypeItems[2].Name := nil;
  BreathTypeItems[2].Value := 0;
  AddSelect(BreathTypeItem, #$547C#$5438#$30BF#$30A4#$30D7,
    Ord(btNormal), @BreathTypeItems[0]);
  AddTrack(PeriodItem, #$5468#$671F, 4.0, 0.5, 10.0, 0.1);
  AddTrack(StrengthItem, #$5F37#$5EA6, 100.0, 0.0, 300.0, 1.0);
  AddTrack(PhaseItem, #$4F4D#$76F8, 0.0, 0.0, 360.0, 1.0);
end;

function CurrentBreathRuntimeSettings: TBreathRuntimeSettings;
begin
  Result.PeriodSeconds := EnsureRange(PeriodItem.Value, 0.5, 10.0);
  Result.Strength := EnsureRange(StrengthItem.Value, 0.0, 300.0) / 100.0;
  Result.PhaseDegrees := EnsureRange(PhaseItem.Value, 0.0, 360.0);
  Result.BreathType := TBreathType(EnsureRange(BreathTypeItem.Value,
    Ord(Low(TBreathType)), Ord(High(TBreathType))));
end;

end.
