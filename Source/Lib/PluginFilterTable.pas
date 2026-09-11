unit PluginFilterTable;

interface

uses
  AviUtl2FilterTypes;

procedure SetupPluginTable(Flag: Integer; Name, Label_, Information: PWideChar;
  VideoProc: TFuncProcVideo; AudioProc: TFuncProcAudio);
procedure AddButton(var Item: TFILTER_ITEM_BUTTON; Name: PWideChar;
  Callback: TFILTER_ITEM_BUTTON_CALLBACK);
procedure AddGroup(var Item: TFILTER_ITEM_GROUP; Name: PWideChar;
  DefaultVisible: Integer);
procedure AddString(var Item: TFILTER_ITEM_STRING; Name, Value: PWideChar);
procedure AddTrack(var Item: TFILTER_ITEM_TRACK; Name: PWideChar;
  Value, S, E, Step: Double);
procedure AddSelect(var Item: TFILTER_ITEM_SELECT; Name: PWideChar;
  Value: Integer; List: PFILTER_ITEM_SELECT_ITEM);

var
  GTable: TFILTER_PLUGIN_TABLE;

implementation

const
  MAX_GUI_ITEMS = 100;

var
  ItemIndex: Integer;
  Items: array[0..MAX_GUI_ITEMS - 1] of Pointer;

procedure SetupPluginTable(Flag: Integer; Name, Label_, Information: PWideChar;
  VideoProc: TFuncProcVideo; AudioProc: TFuncProcAudio);
begin
  GTable.Flag := Flag;
  GTable.Name := Name;
  GTable.Label_ := Label_;
  GTable.Information := Information;
  GTable.Items := @Items[0];
  GTable.Func_Proc_Video := VideoProc;
  GTable.Func_Proc_Audio := AudioProc;
end;

procedure AddButton(var Item: TFILTER_ITEM_BUTTON; Name: PWideChar;
  Callback: TFILTER_ITEM_BUTTON_CALLBACK);
begin
  if ItemIndex >= MAX_GUI_ITEMS - 1 then
    Exit;
  Items[ItemIndex] := @Item;
  Item.ItemType := 'button';
  Item.Name := Name;
  Item.Callback := Callback;
  Inc(ItemIndex);
  Items[ItemIndex] := nil;
end;

procedure AddGroup(var Item: TFILTER_ITEM_GROUP; Name: PWideChar;
  DefaultVisible: Integer);
begin
  if ItemIndex >= MAX_GUI_ITEMS - 1 then
    Exit;
  Items[ItemIndex] := @Item;
  Item.ItemType := 'group';
  Item.Name := Name;
  Item.DefaultVisible := Ord(DefaultVisible <> 0);
  Inc(ItemIndex);
  Items[ItemIndex] := nil;
end;

procedure AddString(var Item: TFILTER_ITEM_STRING; Name, Value: PWideChar);
begin
  if ItemIndex >= MAX_GUI_ITEMS - 1 then
    Exit;
  Items[ItemIndex] := @Item;
  Item.ItemType := 'string';
  Item.Name := Name;
  Item.Value := Value;
  Inc(ItemIndex);
  Items[ItemIndex] := nil;
end;

procedure AddTrack(var Item: TFILTER_ITEM_TRACK; Name: PWideChar;
  Value, S, E, Step: Double);
begin
  if ItemIndex >= MAX_GUI_ITEMS - 1 then
    Exit;
  Items[ItemIndex] := @Item;
  Item.ItemType := 'track';
  Item.Name := Name;
  Item.Value := Value;
  Item.S := S;
  Item.E := E;
  Item.Step := Step;
  Inc(ItemIndex);
  Items[ItemIndex] := nil;
end;

procedure AddSelect(var Item: TFILTER_ITEM_SELECT; Name: PWideChar;
  Value: Integer; List: PFILTER_ITEM_SELECT_ITEM);
begin
  if ItemIndex >= MAX_GUI_ITEMS - 1 then
    Exit;
  Items[ItemIndex] := @Item;
  Item.ItemType := 'select';
  Item.Name := Name;
  Item.Value := Value;
  Item.List := List;
  Inc(ItemIndex);
  Items[ItemIndex] := nil;
end;

end.
