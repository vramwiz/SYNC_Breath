unit SYNC_Breath_SettingsForm;


interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  System.UITypes,
  Vcl.Controls,
  Vcl.Buttons,
  Vcl.ComCtrls,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.Menus,
  Vcl.StdCtrls,
  SYNC_Breath_GuideData,
  SYNC_Breath_RuntimeSettings;

type
  TFormBreathSettings = class(TForm)
    PreviewPaintBox: TPaintBox;
    StatusPanel: TPanel;
    StatusLabel: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
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
    FGuidePoints: TBreathGuidePoints;
    FSelectedPoint: Integer;
    FGuideDragging: Boolean;
    FContextMenu: TPopupMenu;
    FFitMenuItem: TMenuItem;
    FResetMenuItem: TMenuItem;
    FPreviewMenuItem: TMenuItem;
    FSelectionLabel: TLabel;
    FPreviewBitmap: TBitmap;
    FPreviewEnabled: Boolean;
    FPreviewStartedTick: UInt64;
    FPreviewTimer: TTimer;
    FPreviewFrameCount: Integer;
    FPreviewLastLogTick: UInt64;
    FPreviewPaintLogged: Boolean;
    FRuntimeSettings: TBreathRuntimeSettings;
    function DestinationRect: TRect;
    function CanvasToNormalized(X, Y: Integer;
      out Position: TPointF): Boolean;
    function GuidePointToCanvas(Kind: TBreathGuidePoint): TPoint;
    function HitTestGuidePoint(X, Y: Integer): Integer;
    procedure DrawGuide(Canvas: TCanvas);
    procedure SetGuidePoint(Kind: TBreathGuidePoint;
      const Position: TPointF);
    procedure ResetGuide;
    procedure CreateEditorControls;
    procedure FitButtonClick(Sender: TObject);
    procedure ResetButtonClick(Sender: TObject);
    procedure PreviewButtonClick(Sender: TObject);
    procedure PreviewTimerTick(Sender: TObject);
    procedure UpdateBreathPreview;
    procedure UpdateEditorControls;
    procedure AddContextMenuItem(const Caption: string; OnClick: TNotifyEvent;
      out MenuItem: TMenuItem);
    procedure FitImage;
    procedure UpdateStatus;
  public
    procedure SetBackgroundRgba(const Pixels: TBytes; Width, Height: Integer);
    procedure SetCaptureStatus(const Value: string);
    procedure SetRuntimeSettings(const Value: TBreathRuntimeSettings);
    function TryLoadGuideDataText(const Text: string;
      out ErrorText: string): Boolean;
    function TrySaveGuideDataText(out Text, ErrorText: string): Boolean;
  end;

implementation

uses
  System.Math,
  Winapi.Windows,
  SYNC_Breath_DebugLog,
  SYNC_Breath_GuideRenderer;

{$R *.dfm}

type
  TControlAccess = class(TControl);

function GuidePointName(Kind: TBreathGuidePoint): string;
begin
  case Kind of
    bgpWaist: Result := #$8170;
    bgpChest: Result := #$80F8;
    bgpNeck: Result := #$9996;
    bgpHead: Result := #$982D;
    bgpLeftShoulder: Result := #$5DE6#$80A9;
    bgpRightShoulder: Result := #$53F3#$80A9;
  else
    Result := '';
  end;
end;

procedure TFormBreathSettings.CreateEditorControls;
var
  GuideStateItem: TMenuItem;
  Separator: TMenuItem;
begin
  FContextMenu := TPopupMenu.Create(Self);
  FContextMenu.AutoPopup := True;
  FContextMenu.Images := nil;
  GuideStateItem := TMenuItem.Create(FContextMenu);
  GuideStateItem.Caption := #$30AC#$30A4#$30C9#$7DE8#$96C6;
  GuideStateItem.Checked := True;
  GuideStateItem.Enabled := False;
  FContextMenu.Items.Add(GuideStateItem);
  Separator := TMenuItem.Create(FContextMenu);
  Separator.Caption := '-';
  FContextMenu.Items.Add(Separator);
  AddContextMenuItem(#$5168#$4F53#$8868#$793A, FitButtonClick, FFitMenuItem);
  AddContextMenuItem(#$521D#$671F#$914D#$7F6E, ResetButtonClick, FResetMenuItem);
  Separator := TMenuItem.Create(FContextMenu);
  Separator.Caption := '-';
  FContextMenu.Items.Add(Separator);
  AddContextMenuItem(#$547C#$5438#$30D7#$30EC#$30D3#$30E5#$30FC,
    PreviewButtonClick, FPreviewMenuItem);
  FPreviewMenuItem.ShortCut := ShortCut(VK_SPACE, []);
  PreviewPaintBox.PopupMenu := FContextMenu;

  FSelectionLabel := TLabel.Create(Self);
  FSelectionLabel.Parent := StatusPanel;
  FSelectionLabel.Align := alBottom;
  FSelectionLabel.Height := 20;
  FSelectionLabel.Font.Color := clWhite;
  FSelectionLabel.Font.Color := TColor($00D0D0D0);
end;

procedure TFormBreathSettings.AddContextMenuItem(const Caption: string;
  OnClick: TNotifyEvent; out MenuItem: TMenuItem);
begin
  MenuItem := TMenuItem.Create(FContextMenu);
  MenuItem.Caption := Caption;
  MenuItem.OnClick := OnClick;
  FContextMenu.Items.Add(MenuItem);
end;

procedure TFormBreathSettings.ResetGuide;
begin
  FGuidePoints[bgpHead] := PointF(0.50, 0.14);
  FGuidePoints[bgpNeck] := PointF(0.50, 0.30);
  FGuidePoints[bgpLeftShoulder] := PointF(0.28, 0.37);
  FGuidePoints[bgpRightShoulder] := PointF(0.72, 0.37);
  FGuidePoints[bgpChest] := PointF(0.50, 0.49);
  FGuidePoints[bgpWaist] := PointF(0.50, 0.74);
  FSelectedPoint := Ord(bgpChest);
  UpdateEditorControls;
  PreviewPaintBox.Invalidate;
end;

function TFormBreathSettings.CanvasToNormalized(X, Y: Integer;
  out Position: TPointF): Boolean;
var
  Destination: TRect;
begin
  Destination := DestinationRect;
  Result := (Destination.Width > 0) and (Destination.Height > 0) and
    PtInRect(Destination, Point(X, Y));
  if not Result then
    Exit;
  Position.X := EnsureRange((X - Destination.Left) / Destination.Width,
    0.0, 1.0);
  Position.Y := EnsureRange((Y - Destination.Top) / Destination.Height,
    0.0, 1.0);
end;

function TFormBreathSettings.GuidePointToCanvas(
  Kind: TBreathGuidePoint): TPoint;
var
  Destination: TRect;
begin
  Destination := DestinationRect;
  Result.X := Destination.Left + Round(FGuidePoints[Kind].X *
    Destination.Width);
  Result.Y := Destination.Top + Round(FGuidePoints[Kind].Y *
    Destination.Height);
end;

function TFormBreathSettings.HitTestGuidePoint(X, Y: Integer): Integer;
var
  Kind: TBreathGuidePoint;
  P: TPoint;
  Radius: Integer;
begin
  Result := -1;
  Radius := MulDiv(10, CurrentPPI, 96);
  for Kind := Low(TBreathGuidePoint) to High(TBreathGuidePoint) do
  begin
    P := GuidePointToCanvas(Kind);
    if (Abs(P.X - X) <= Radius) and (Abs(P.Y - Y) <= Radius) then
      Exit(Ord(Kind));
  end;
end;

procedure TFormBreathSettings.SetGuidePoint(Kind: TBreathGuidePoint;
  const Position: TPointF);
const
  MIN_GAP = 0.03;
var
  P: TPointF;
  CenterX: Single;
begin
  P.X := EnsureRange(Position.X, 0.0, 1.0);
  P.Y := EnsureRange(Position.Y, 0.0, 1.0);
  CenterX := FGuidePoints[bgpChest].X;
  case Kind of
    bgpHead:
      P.Y := Min(P.Y, FGuidePoints[bgpNeck].Y - MIN_GAP);
    bgpNeck:
      P.Y := EnsureRange(P.Y, FGuidePoints[bgpHead].Y + MIN_GAP,
        FGuidePoints[bgpChest].Y - MIN_GAP);
    bgpChest:
      P.Y := EnsureRange(P.Y, FGuidePoints[bgpNeck].Y + MIN_GAP,
        FGuidePoints[bgpWaist].Y - MIN_GAP);
    bgpWaist:
      P.Y := Max(P.Y, FGuidePoints[bgpChest].Y + MIN_GAP);
    bgpLeftShoulder:
      P.X := Min(P.X, CenterX - MIN_GAP);
    bgpRightShoulder:
      P.X := Max(P.X, CenterX + MIN_GAP);
  end;
  FGuidePoints[Kind] := P;
  if Kind = bgpChest then
  begin
    FGuidePoints[bgpLeftShoulder].X := Min(
      FGuidePoints[bgpLeftShoulder].X, P.X - MIN_GAP);
    FGuidePoints[bgpRightShoulder].X := Max(
      FGuidePoints[bgpRightShoulder].X, P.X + MIN_GAP);
  end;
end;

procedure TFormBreathSettings.DrawGuide(Canvas: TCanvas);
var
  ChestPoint: TPoint;
  HeadPoint: TPoint;
  Kind: TBreathGuidePoint;
  LeftShoulder: TPoint;
  NeckPoint: TPoint;
  P: TPoint;
  Radius: Integer;
  RightShoulder: TPoint;
  ShoulderSpan: Integer;
  WaistPoint: TPoint;
  AbdomenRect: TRect;
  ChestRect: TRect;
  LeftArmEnd: TPoint;
  LeftBody: array[0..3] of TPoint;
  RightArmEnd: TPoint;
  RightBody: array[0..3] of TPoint;
  ShoulderCurve: array[0..6] of TPoint;
  TorsoHalfWidth: Integer;
begin
  if (FBackground.Width <= 0) or (FBackground.Height <= 0) then
    Exit;
  DrawBreathGuide(Canvas, DestinationRect, FGuidePoints, FSelectedPoint,
    CurrentPPI);
  Exit;
  HeadPoint := GuidePointToCanvas(bgpHead);
  NeckPoint := GuidePointToCanvas(bgpNeck);
  ChestPoint := GuidePointToCanvas(bgpChest);
  WaistPoint := GuidePointToCanvas(bgpWaist);
  LeftShoulder := GuidePointToCanvas(bgpLeftShoulder);
  RightShoulder := GuidePointToCanvas(bgpRightShoulder);

  ShoulderSpan := Max(1, RightShoulder.X - LeftShoulder.X);
  ChestRect := Rect(LeftShoulder.X + ShoulderSpan div 10,
    Min(LeftShoulder.Y, RightShoulder.Y) + 4,
    RightShoulder.X - ShoulderSpan div 10,
    ChestPoint.Y + Max(12, (WaistPoint.Y - ChestPoint.Y) div 3));
  AbdomenRect := Rect(LeftShoulder.X + ShoulderSpan div 5,
    ChestPoint.Y,
    RightShoulder.X - ShoulderSpan div 5,
    WaistPoint.Y);

  Canvas.Pen.Color := TColor($000080FF);
  Canvas.Pen.Width := Max(1, MulDiv(2, CurrentPPI, 96));
  Canvas.Pen.Style := psDash;
  Canvas.Brush.Style := bsClear;
  Canvas.Ellipse(ChestRect);
  Canvas.Font.Color := Canvas.Pen.Color;
  Canvas.TextOut(ChestRect.Left + 6, ChestRect.Top + 5, #$80F8#$90E8);
  Canvas.Pen.Color := TColor($0040C080);
  Canvas.Ellipse(AbdomenRect);
  Canvas.Font.Color := Canvas.Pen.Color;
  Canvas.TextOut(AbdomenRect.Left + 6, AbdomenRect.Top + 5, #$8179#$90E8);

  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Color := TColor($00E8C080);
  Canvas.MoveTo(HeadPoint.X, HeadPoint.Y);
  Canvas.LineTo(NeckPoint.X, NeckPoint.Y);
  Canvas.LineTo(ChestPoint.X, ChestPoint.Y);
  Canvas.LineTo(WaistPoint.X, WaistPoint.Y);
  ShoulderCurve[0] := LeftShoulder;
  ShoulderCurve[1] := Point(LeftShoulder.X + ShoulderSpan div 6,
    LeftShoulder.Y - ShoulderSpan div 14);
  ShoulderCurve[2] := Point(NeckPoint.X - ShoulderSpan div 7,
    NeckPoint.Y + ShoulderSpan div 15);
  ShoulderCurve[3] := NeckPoint;
  ShoulderCurve[4] := Point(NeckPoint.X + ShoulderSpan div 7,
    NeckPoint.Y + ShoulderSpan div 15);
  ShoulderCurve[5] := Point(RightShoulder.X - ShoulderSpan div 6,
    RightShoulder.Y - ShoulderSpan div 14);
  ShoulderCurve[6] := RightShoulder;
  PolyBezier(Canvas.Handle, ShoulderCurve[0], Length(ShoulderCurve));

  TorsoHalfWidth := Max(10, ShoulderSpan div 4);
  LeftBody[0] := LeftShoulder;
  LeftBody[1] := Point(LeftShoulder.X - ShoulderSpan div 14,
    ChestPoint.Y);
  LeftBody[2] := Point(WaistPoint.X - TorsoHalfWidth - ShoulderSpan div 12,
    WaistPoint.Y - (WaistPoint.Y - ChestPoint.Y) div 3);
  LeftBody[3] := Point(WaistPoint.X - TorsoHalfWidth, WaistPoint.Y);
  RightBody[0] := RightShoulder;
  RightBody[1] := Point(RightShoulder.X + ShoulderSpan div 14,
    ChestPoint.Y);
  RightBody[2] := Point(WaistPoint.X + TorsoHalfWidth + ShoulderSpan div 12,
    WaistPoint.Y - (WaistPoint.Y - ChestPoint.Y) div 3);
  RightBody[3] := Point(WaistPoint.X + TorsoHalfWidth, WaistPoint.Y);
  PolyBezier(Canvas.Handle, LeftBody[0], Length(LeftBody));
  PolyBezier(Canvas.Handle, RightBody[0], Length(RightBody));
  Canvas.MoveTo(LeftBody[3].X, LeftBody[3].Y);
  Canvas.LineTo(RightBody[3].X, RightBody[3].Y);

  LeftArmEnd := Point(LeftShoulder.X - ShoulderSpan div 12,
    LeftShoulder.Y + (WaistPoint.Y - LeftShoulder.Y) div 2);
  RightArmEnd := Point(RightShoulder.X + ShoulderSpan div 12,
    RightShoulder.Y + (WaistPoint.Y - RightShoulder.Y) div 2);
  Canvas.MoveTo(LeftShoulder.X, LeftShoulder.Y);
  Canvas.LineTo(LeftArmEnd.X, LeftArmEnd.Y);
  Canvas.MoveTo(RightShoulder.X, RightShoulder.Y);
  Canvas.LineTo(RightArmEnd.X, RightArmEnd.Y);
  Radius := Max(12, Abs(NeckPoint.Y - HeadPoint.Y));
  Canvas.Ellipse(HeadPoint.X - Radius * 2 div 3,
    HeadPoint.Y - Radius,
    HeadPoint.X + Radius * 2 div 3, HeadPoint.Y + Radius);
  Canvas.MoveTo(HeadPoint.X - Radius div 3, HeadPoint.Y + Radius);
  Canvas.LineTo(NeckPoint.X - ShoulderSpan div 12, NeckPoint.Y);
  Canvas.MoveTo(HeadPoint.X + Radius div 3, HeadPoint.Y + Radius);
  Canvas.LineTo(NeckPoint.X + ShoulderSpan div 12, NeckPoint.Y);

  Radius := MulDiv(6, CurrentPPI, 96);
  for Kind := Low(TBreathGuidePoint) to High(TBreathGuidePoint) do
  begin
    P := GuidePointToCanvas(Kind);
    if Ord(Kind) = FSelectedPoint then
      Canvas.Brush.Color := TColor($000080FF)
    else
      Canvas.Brush.Color := TColor($00FFC060);
    Canvas.Pen.Color := clWhite;
    Canvas.Rectangle(P.X - Radius, P.Y - Radius,
      P.X + Radius + 1, P.Y + Radius + 1);
  end;
  Canvas.Brush.Style := bsSolid;
end;

procedure TFormBreathSettings.FitButtonClick(Sender: TObject);
begin
  FitImage;
end;

procedure TFormBreathSettings.ResetButtonClick(Sender: TObject);
begin
  ResetGuide;
end;

procedure TFormBreathSettings.PreviewButtonClick(Sender: TObject);
begin
  DebugLog(Format('Preview button clicked: enabled=%s, background=%dx%d.',
    [BoolToStr(FPreviewEnabled, True), FBackground.Width,
    FBackground.Height]));
  FPreviewEnabled := not FPreviewEnabled;
  if FPreviewEnabled then
  begin
    FPreviewStartedTick := GetTickCount64 - 750;
    FPreviewTimer.Enabled := True;
    FPreviewFrameCount := 0;
    FPreviewLastLogTick := 0;
    FPreviewPaintLogged := False;
    FPreviewMenuItem.Caption := #$30D7#$30EC#$30D3#$30E5#$30FC#$505C#$6B62;
    UpdateBreathPreview;
    DebugLog(Format('Preview started: timer enabled=%s, interval=%d ms.',
      [BoolToStr(FPreviewTimer.Enabled, True), FPreviewTimer.Interval]));
  end
  else
  begin
    FPreviewTimer.Enabled := False;
    FPreviewMenuItem.Caption := #$547C#$5438#$30D7#$30EC#$30D3#$30E5#$30FC;
    PreviewPaintBox.Invalidate;
    DebugLog('Preview stopped.');
  end;
end;

procedure TFormBreathSettings.PreviewTimerTick(Sender: TObject);
begin
  if FPreviewFrameCount = 1 then
    DebugLog('First preview timer tick received.');
  UpdateBreathPreview;
end;

procedure TFormBreathSettings.UpdateBreathPreview;
const
  PREVIEW_MAX_WIDTH = 672;
  PREVIEW_MAX_HEIGHT = 480;
  CHEST_LIFT = 0.026;
  ABDOMEN_LIFT = 0.012;
var
  AbdomenInfluence: Double;
  AbdomenWidth: Double;
  BreathAmount: Double;
  CenterX: Double;
  ChestInfluence: Double;
  ChestWidth: Double;
  DestinationPixel: PByte;
  DestinationRow: PByte;
  VerticalDisplacement: Double;
  HorizontalInfluence: Double;
  UpperHorizontalInfluence: Double;
  UpperInfluence: Double;
  UpperWidth: Double;
  ImageX: Double;
  ImageY: Double;
  Influence: Double;
  LeftX: Double;
  LogicalY: Integer;
  PreviewHeight: Integer;
  PreviewScale: Double;
  PreviewWidth: Integer;
  RightX: Double;
  SourcePixel: PByte;
  SourceRow: PByte;
  SourceBitmapY: Integer;
  SourceImageY: Double;
  SourceX: Integer;
  ChangedPixelCount: Integer;
  FrameStartedTick: UInt64;
  MaximumDisplacementPixels: Double;
  NowTick: UInt64;
  X: Integer;
begin
  if not FPreviewEnabled or (FBackground.Width <= 0) or
    (FBackground.Height <= 0) then
  begin
    DebugLog(Format('Preview update skipped: enabled=%s, background=%dx%d.',
      [BoolToStr(FPreviewEnabled, True), FBackground.Width,
      FBackground.Height]));
    Exit;
  end;
  FrameStartedTick := GetTickCount64;
  Inc(FPreviewFrameCount);
  ChangedPixelCount := 0;
  MaximumDisplacementPixels := 0;
  PreviewScale := Min(1.0, Min(PREVIEW_MAX_WIDTH / FBackground.Width,
    PREVIEW_MAX_HEIGHT / FBackground.Height));
  PreviewWidth := Max(1, Round(FBackground.Width * PreviewScale));
  PreviewHeight := Max(1, Round(FBackground.Height * PreviewScale));
  if (FPreviewBitmap.Width <> PreviewWidth) or
    (FPreviewBitmap.Height <> PreviewHeight) then
    FPreviewBitmap.SetSize(PreviewWidth, PreviewHeight);

  BreathAmount := CalculateBreathAmount(
    (GetTickCount64 - FPreviewStartedTick) / 1000.0, FRuntimeSettings);
  CenterX := FGuidePoints[bgpChest].X;
  LeftX := FGuidePoints[bgpLeftShoulder].X;
  RightX := FGuidePoints[bgpRightShoulder].X;
  ChestWidth := Max(0.08, (RightX - LeftX) * 0.52);
  AbdomenWidth := ChestWidth * 0.82;

  for LogicalY := 0 to PreviewHeight - 1 do
  begin
    // AviUtl2 capture rows and VCL bitmap scanlines use the opposite Y origin.
    // Convert the processed bitmap row back to the guide's top-origin Y value.
    ImageY := 1.0 - LogicalY / Max(1, PreviewHeight - 1);
    if ImageY <= FGuidePoints[bgpChest].Y then
      ChestInfluence := 1 - Abs(ImageY - FGuidePoints[bgpChest].Y) /
        Max(0.001, FGuidePoints[bgpChest].Y -
        FGuidePoints[bgpNeck].Y)
    else
      ChestInfluence := 1 - (ImageY - FGuidePoints[bgpChest].Y) /
        Max(0.001, (FGuidePoints[bgpWaist].Y -
        FGuidePoints[bgpChest].Y) * 0.55);
    ChestInfluence := EnsureRange(ChestInfluence, 0.0, 1.0);

    if ImageY < FGuidePoints[bgpHead].Y then
      UpperInfluence := 0.18 * EnsureRange(1 -
        (FGuidePoints[bgpHead].Y - ImageY) /
        Max(0.001, FGuidePoints[bgpNeck].Y -
        FGuidePoints[bgpHead].Y), 0.0, 1.0)
    else if ImageY < FGuidePoints[bgpNeck].Y then
      UpperInfluence := 0.18 + 0.22 *
        (ImageY - FGuidePoints[bgpHead].Y) /
        Max(0.001, FGuidePoints[bgpNeck].Y -
        FGuidePoints[bgpHead].Y)
    else if ImageY < FGuidePoints[bgpChest].Y then
      UpperInfluence := 0.40 + 0.60 *
        (ImageY - FGuidePoints[bgpNeck].Y) /
        Max(0.001, FGuidePoints[bgpChest].Y -
        FGuidePoints[bgpNeck].Y)
    else
      UpperInfluence := 0;
    UpperInfluence := EnsureRange(UpperInfluence, 0.0, 1.0);

    if ImageY < FGuidePoints[bgpChest].Y then
      AbdomenInfluence := 0
    else
    begin
      AbdomenInfluence := (ImageY - FGuidePoints[bgpChest].Y) /
        Max(0.001, FGuidePoints[bgpWaist].Y -
        FGuidePoints[bgpChest].Y);
      AbdomenInfluence := 1 - Abs(AbdomenInfluence * 2 - 1);
      AbdomenInfluence := EnsureRange(AbdomenInfluence, 0.0, 1.0);
    end;

    DestinationRow := FPreviewBitmap.ScanLine[
      PreviewHeight - 1 - LogicalY];
    for X := 0 to PreviewWidth - 1 do
    begin
      ImageX := X / Max(1, PreviewWidth - 1);
      HorizontalInfluence := 1 - Abs(ImageX - CenterX) /
        Max(0.001, ChestWidth);
      HorizontalInfluence := EnsureRange(HorizontalInfluence, 0.0, 1.0);
      Influence := CHEST_LIFT * ChestInfluence * HorizontalInfluence;
      UpperWidth := ChestWidth * (0.48 + 0.52 * EnsureRange(
        (ImageY - FGuidePoints[bgpHead].Y) /
        Max(0.001, FGuidePoints[bgpChest].Y -
        FGuidePoints[bgpHead].Y), 0.0, 1.0));
      UpperHorizontalInfluence := 1 - Abs(ImageX - CenterX) /
        Max(0.001, UpperWidth);
      UpperHorizontalInfluence := EnsureRange(UpperHorizontalInfluence,
        0.0, 1.0);
      Influence := Max(Influence, CHEST_LIFT * UpperInfluence *
        UpperHorizontalInfluence);
      HorizontalInfluence := 1 - Abs(ImageX - CenterX) /
        Max(0.001, AbdomenWidth);
      HorizontalInfluence := EnsureRange(HorizontalInfluence, 0.0, 1.0);
      Influence := Influence + ABDOMEN_LIFT * AbdomenInfluence *
        HorizontalInfluence;
      VerticalDisplacement := Influence * BreathAmount;
      SourceImageY := EnsureRange(ImageY + VerticalDisplacement,
        0.0, 1.0);
      SourceBitmapY := EnsureRange(Round(SourceImageY *
        (FBackground.Height - 1)), 0, FBackground.Height - 1);
      SourceRow := FBackground.ScanLine[SourceBitmapY];
      if SourceBitmapY <> Round(ImageY * (FBackground.Height - 1)) then
        Inc(ChangedPixelCount);
      MaximumDisplacementPixels := Max(MaximumDisplacementPixels,
        Abs(SourceBitmapY - Round(ImageY * (FBackground.Height - 1))));
      SourceX := EnsureRange(Round(ImageX * (FBackground.Width - 1)),
        0, FBackground.Width - 1);
      SourcePixel := SourceRow + SourceX * 4;
      DestinationPixel := DestinationRow + X * 4;
      DestinationPixel[0] := SourcePixel[0];
      DestinationPixel[1] := SourcePixel[1];
      DestinationPixel[2] := SourcePixel[2];
      DestinationPixel[3] := SourcePixel[3];
    end;
  end;
  NowTick := GetTickCount64;
  if (FPreviewFrameCount = 1) or (NowTick - FPreviewLastLogTick >= 1000) then
  begin
    DebugLog(Format('Preview frame=%d breath=%.3f changed=%d '+
      'max-vertical-displacement=%.1f px processing=%d ms bitmap=%dx%d.',
      [FPreviewFrameCount, BreathAmount, ChangedPixelCount,
      MaximumDisplacementPixels, NowTick - FrameStartedTick,
      FPreviewBitmap.Width, FPreviewBitmap.Height]));
    FPreviewLastLogTick := NowTick;
  end;
  PreviewPaintBox.Invalidate;
end;

procedure TFormBreathSettings.UpdateEditorControls;
var
  Kind: TBreathGuidePoint;
begin
  if FSelectedPoint >= 0 then
  begin
    Kind := TBreathGuidePoint(FSelectedPoint);
    FSelectionLabel.Caption := #$9078#$629E + ': ' + GuidePointName(Kind) +
      Format('  (X: %.1f%% / Y: %.1f%%)', [FGuidePoints[Kind].X * 100,
      FGuidePoints[Kind].Y * 100]);
  end
  else
  begin
    FSelectionLabel.Caption := #$672A#$9078#$629E;
  end;
  UpdateStatus;
end;

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
  DebugLog('Settings form FormCreate entered.');
  FBackground := Vcl.Graphics.TBitmap.Create;
  FBackground.PixelFormat := pf32bit;
  FPreviewBitmap := Vcl.Graphics.TBitmap.Create;
  FPreviewBitmap.PixelFormat := pf32bit;
  FPreviewTimer := TTimer.Create(Self);
  FPreviewTimer.Enabled := False;
  FPreviewTimer.Interval := 80;
  FPreviewTimer.OnTimer := PreviewTimerTick;
  FZoomPercent := 100;
  FFitToWindow := True;
  FOffset := Point(0, 0);
  FSelectedPoint := -1;
  DoubleBuffered := True;
  TControlAccess(PreviewPaintBox).ControlStyle :=
    TControlAccess(PreviewPaintBox).ControlStyle + [csOpaque];
  CreateEditorControls;
  ResetGuide;
  DebugLog('Settings form initialized.');
end;

procedure TFormBreathSettings.FormDestroy(Sender: TObject);
begin
  DebugLog('Settings form FormDestroy entered.');
  FPreviewTimer.Enabled := False;
  FPreviewTimer.Free;
  FPreviewBitmap.Free;
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

procedure TFormBreathSettings.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_SPACE) and (Shift = []) then
  begin
    PreviewButtonClick(Self);
    Key := 0;
  end;
end;

procedure TFormBreathSettings.PreviewPaintBoxDblClick(Sender: TObject);
begin
  FitImage;
end;

procedure TFormBreathSettings.PreviewPaintBoxMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  HitIndex: Integer;
begin
  if (Button = mbLeft) and not FPreviewEnabled then
  begin
    HitIndex := HitTestGuidePoint(X, Y);
    if HitIndex >= 0 then
    begin
      FSelectedPoint := HitIndex;
      FGuideDragging := True;
      TControlAccess(PreviewPaintBox).MouseCapture := True;
      PreviewPaintBox.Cursor := crSizeAll;
      UpdateEditorControls;
      PreviewPaintBox.Invalidate;
      Exit;
    end;
  end;
  if not ((Button = mbMiddle) or
    (Button = mbLeft)) then
    Exit;
  FDragging := True;
  FDragOrigin := Point(X, Y);
  FOffsetOrigin := FOffset;
  TControlAccess(PreviewPaintBox).MouseCapture := True;
  PreviewPaintBox.Cursor := crSizeAll;
end;

procedure TFormBreathSettings.PreviewPaintBoxMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
var
  Position: TPointF;
begin
  if FGuideDragging and (FSelectedPoint >= 0) then
  begin
    if CanvasToNormalized(X, Y, Position) then
    begin
      SetGuidePoint(TBreathGuidePoint(FSelectedPoint), Position);
      UpdateEditorControls;
      PreviewPaintBox.Invalidate;
    end;
    Exit;
  end;
  if not FDragging then
    Exit;
  FOffset.X := FOffsetOrigin.X + X - FDragOrigin.X;
  FOffset.Y := FOffsetOrigin.Y + Y - FDragOrigin.Y;
  PreviewPaintBox.Invalidate;
end;

procedure TFormBreathSettings.PreviewPaintBoxMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if FGuideDragging then
  begin
    FGuideDragging := False;
    TControlAccess(PreviewPaintBox).MouseCapture := False;
    PreviewPaintBox.Cursor := crDefault;
    Exit;
  end;
  if not (Button in [mbLeft, mbMiddle]) then
    Exit;
  FDragging := False;
  TControlAccess(PreviewPaintBox).MouseCapture := False;
  PreviewPaintBox.Cursor := crDefault;
end;

procedure TFormBreathSettings.PreviewPaintBoxPaint(Sender: TObject);
var
  Destination: TRect;
begin
  if not FPreviewPaintLogged then
  begin
    DebugLog(Format('Preview paint: enabled=%s, preview=%dx%d, background=%dx%d.',
      [BoolToStr(FPreviewEnabled, True), FPreviewBitmap.Width,
      FPreviewBitmap.Height, FBackground.Width, FBackground.Height]));
    FPreviewPaintLogged := True;
  end;
  PreviewPaintBox.Canvas.Brush.Color := clBlack;
  PreviewPaintBox.Canvas.FillRect(PreviewPaintBox.ClientRect);
  if (FBackground.Width <= 0) or (FBackground.Height <= 0) then
    Exit;
  Destination := DestinationRect;
  SetStretchBltMode(PreviewPaintBox.Canvas.Handle, HALFTONE);
  if FPreviewEnabled and (FPreviewBitmap.Width > 0) then
    PreviewPaintBox.Canvas.StretchDraw(Destination, FPreviewBitmap)
  else
    PreviewPaintBox.Canvas.StretchDraw(Destination, FBackground);
  if not FPreviewEnabled then
    DrawGuide(PreviewPaintBox.Canvas);
end;

procedure TFormBreathSettings.SetBackgroundRgba(const Pixels: TBytes;
  Width, Height: Integer);
var
  Destination: PByte;
  Source: PByte;
  X: Integer;
  Y: Integer;
begin
  DebugLog(Format('SetBackgroundRgba called: %dx%d, %d bytes.',
    [Width, Height, Length(Pixels)]));
  if (Width <= 0) or (Height <= 0) or
    (Length(Pixels) <> NativeInt(Width) * Height * 4) then
  begin
    DebugLog('SetBackgroundRgba rejected invalid dimensions or byte count.');
    Exit;
  end;
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
  if FPreviewEnabled then
    UpdateBreathPreview;
  FitImage;
  DebugLog('Background bitmap created successfully.');
end;

procedure TFormBreathSettings.SetCaptureStatus(const Value: string);
begin
  StatusLabel.Hint := Value;
  UpdateStatus;
end;

procedure TFormBreathSettings.SetRuntimeSettings(
  const Value: TBreathRuntimeSettings);
begin
  FRuntimeSettings := Value;
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
    StatusLabel.Caption := StatusLabel.Hint + '  |  ' + ViewText + '  |  ' +
      #$30DB#$30A4#$30FC#$30EB + ': ' + #$62E1#$5927#$7E2E#$5C0F +
      ' / ' + #$5DE6#$30C9#$30E9#$30C3#$30B0 + ': ' +
      #$70B9#$306F#$30AC#$30A4#$30C9 + #$79FB#$52D5 +
      #$3001#$7A7A#$6240#$306F#$8868#$793A#$79FB#$52D5 + ' / ' +
      #$4E2D#$30C9#$30E9#$30C3#$30B0 + ': ' + #$8868#$793A#$79FB#$52D5 +
      ' / ' + #$30C0#$30D6#$30EB#$30AF#$30EA#$30C3#$30AF + ': ' +
      #$5168#$4F53#$8868#$793A
  else
    StatusLabel.Caption := ViewText;
end;

function TFormBreathSettings.TryLoadGuideDataText(const Text: string;
  out ErrorText: string): Boolean;
begin
  Result := TryDecodeBreathGuide(Text, FGuidePoints, ErrorText);
  if Result then
  begin
    FSelectedPoint := Ord(bgpChest);
    UpdateEditorControls;
    PreviewPaintBox.Invalidate;
  end;
end;

function TFormBreathSettings.TrySaveGuideDataText(out Text,
  ErrorText: string): Boolean;
begin
  Result := TryEncodeBreathGuide(FGuidePoints, Text, ErrorText);
end;

end.
