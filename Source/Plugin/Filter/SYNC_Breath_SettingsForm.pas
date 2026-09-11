unit SYNC_Breath_SettingsForm;


interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls;

type
  TFormBreathSettings = class(TForm)
    PreviewPaintBox: TPaintBox;
    StatusPanel: TPanel;
    StatusLabel: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure PreviewPaintBoxDblClick(Sender: TObject);
    procedure PreviewPaintBoxMouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PreviewPaintBoxMouseMove(Sender: TObject;
      Shift: TShiftState; X, Y: Integer);
    procedure PreviewPaintBoxMouseUp(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PreviewPaintBoxPaint(Sender: TObject);
  private
    FBackground: TBitmap;
    FDragging: Boolean;
    FDragOrigin: TPoint;
    FFitToWindow: Boolean;
    FOffset: TPoint;
    FOffsetOrigin: TPoint;
    FZoomPercent: Integer;
    function DestinationRect: TRect;
    procedure FitImage;
    procedure UpdateStatus;
  public
    procedure SetBackgroundRgba(const Pixels: TBytes; Width, Height: Integer);
    procedure SetCaptureStatus(const Value: string);
  end;

implementation

uses
  System.Math,
  Winapi.Windows;

{$R *.dfm}

type
  TControlAccess = class(TControl);

function TFormBreathSettings.DestinationRect: TRect;
var
  DrawHeight: Integer;
  DrawWidth: Integer;
  Scale: Double;
begin
  Result := PreviewPaintBox.ClientRect;
  if (FBackground.Width <= 0) or (FBackground.Height <= 0) then
    Exit;
  if FFitToWindow then
    Scale := Min(PreviewPaintBox.ClientWidth / FBackground.Width,
      PreviewPaintBox.ClientHeight / FBackground.Height)
  else
    Scale := FZoomPercent / 100.0;
  DrawWidth := Max(1, Round(FBackground.Width * Scale));
  DrawHeight := Max(1, Round(FBackground.Height * Scale));
  Result.Left := (PreviewPaintBox.ClientWidth - DrawWidth) div 2 + FOffset.X;
  Result.Top := (PreviewPaintBox.ClientHeight - DrawHeight) div 2 + FOffset.Y;
  Result.Right := Result.Left + DrawWidth;
  Result.Bottom := Result.Top + DrawHeight;
end;

procedure TFormBreathSettings.FitImage;
begin
  FFitToWindow := True;
  FOffset := Point(0, 0);
  UpdateStatus;
  PreviewPaintBox.Invalidate;
end;

procedure TFormBreathSettings.FormCreate(Sender: TObject);
begin
  FBackground := Vcl.Graphics.TBitmap.Create;
  FBackground.PixelFormat := pf32bit;
  FZoomPercent := 100;
  FFitToWindow := True;
  FOffset := Point(0, 0);
  DoubleBuffered := True;
  TControlAccess(PreviewPaintBox).ControlStyle :=
    TControlAccess(PreviewPaintBox).ControlStyle + [csOpaque];
end;

procedure TFormBreathSettings.FormDestroy(Sender: TObject);
begin
  FBackground.Free;
end;

procedure TFormBreathSettings.FormMouseWheel(Sender: TObject;
  Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
begin
  if WheelDelta > 0 then
    Inc(FZoomPercent, 25)
  else
    Dec(FZoomPercent, 25);
  FZoomPercent := EnsureRange(FZoomPercent, 25, 400);
  FFitToWindow := False;
  UpdateStatus;
  PreviewPaintBox.Invalidate;
  Handled := True;
end;

procedure TFormBreathSettings.PreviewPaintBoxDblClick(Sender: TObject);
begin
  FitImage;
end;

procedure TFormBreathSettings.PreviewPaintBoxMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then
    Exit;
  FDragging := True;
  FDragOrigin := Point(X, Y);
  FOffsetOrigin := FOffset;
  TControlAccess(PreviewPaintBox).MouseCapture := True;
  PreviewPaintBox.Cursor := crSizeAll;
end;

procedure TFormBreathSettings.PreviewPaintBoxMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
  if not FDragging then
    Exit;
  FOffset.X := FOffsetOrigin.X + X - FDragOrigin.X;
  FOffset.Y := FOffsetOrigin.Y + Y - FDragOrigin.Y;
  PreviewPaintBox.Invalidate;
end;

procedure TFormBreathSettings.PreviewPaintBoxMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then
    Exit;
  FDragging := False;
  TControlAccess(PreviewPaintBox).MouseCapture := False;
  PreviewPaintBox.Cursor := crDefault;
end;

procedure TFormBreathSettings.PreviewPaintBoxPaint(Sender: TObject);
var
  Destination: TRect;
begin
  PreviewPaintBox.Canvas.Brush.Color := clBlack;
  PreviewPaintBox.Canvas.FillRect(PreviewPaintBox.ClientRect);
  if (FBackground.Width <= 0) or (FBackground.Height <= 0) then
    Exit;
  Destination := DestinationRect;
  SetStretchBltMode(PreviewPaintBox.Canvas.Handle, HALFTONE);
  PreviewPaintBox.Canvas.StretchDraw(Destination, FBackground);
end;

procedure TFormBreathSettings.SetBackgroundRgba(const Pixels: TBytes;
  Width, Height: Integer);
var
  Destination: PByte;
  Source: PByte;
  X: Integer;
  Y: Integer;
begin
  if (Width <= 0) or (Height <= 0) or
    (Length(Pixels) <> NativeInt(Width) * Height * 4) then
    Exit;
  FBackground.SetSize(Width, Height);
  Source := @Pixels[0];
  for Y := 0 to Height - 1 do
  begin
    Destination := FBackground.ScanLine[Y];
    for X := 0 to Width - 1 do
    begin
      Destination[0] := Source[2];
      Destination[1] := Source[1];
      Destination[2] := Source[0];
      Destination[3] := Source[3];
      Inc(Destination, 4);
      Inc(Source, 4);
    end;
  end;
  FitImage;
end;

procedure TFormBreathSettings.SetCaptureStatus(const Value: string);
begin
  StatusLabel.Hint := Value;
  UpdateStatus;
end;

procedure TFormBreathSettings.UpdateStatus;
var
  ViewText: string;
begin
  if FFitToWindow then
    ViewText := #$5168#$4F53#$8868#$793A
  else
    ViewText := Format('%d%%', [FZoomPercent]);
  if StatusLabel.Hint <> '' then
    StatusLabel.Caption := StatusLabel.Hint + '  |  ' + ViewText +
      '  |  ' + #$30DB#$30A4#$30FC#$30EB + ': ' +
      #$62E1#$5927#$7E2E#$5C0F + ' / ' +
      #$5DE6#$30C9#$30E9#$30C3#$30B0 + ': ' + #$79FB#$52D5 + ' / ' +
      #$30C0#$30D6#$30EB#$30AF#$30EA#$30C3#$30AF + ': ' +
      #$5168#$4F53#$8868#$793A
  else
    StatusLabel.Caption := ViewText;
end;

end.
