unit SYNC_Breath_GuideRenderer;

interface

uses
  System.Types,
  System.UITypes,
  Vcl.Graphics,
  SYNC_Breath_GuideData;

procedure DrawBreathGuide(Canvas: TCanvas; const Destination: TRect;
  const GuidePoints: TBreathGuidePoints; SelectedPoint, CurrentPPI: Integer);

implementation

uses
  System.Math,
  Winapi.Windows;

function GuidePointToCanvas(const Destination: TRect;
  const GuidePoints: TBreathGuidePoints; Kind: TBreathGuidePoint): TPoint;
begin
  Result.X := Destination.Left + Round(GuidePoints[Kind].X * Destination.Width);
  Result.Y := Destination.Top + Round(GuidePoints[Kind].Y * Destination.Height);
end;

procedure DrawBreathGuide(Canvas: TCanvas; const Destination: TRect;
  const GuidePoints: TBreathGuidePoints; SelectedPoint, CurrentPPI: Integer);
var
  AbdomenRect, ChestRect: TRect;
  ChestPoint, HeadPoint, LeftArmEnd, LeftShoulder, NeckPoint, P: TPoint;
  RightArmEnd, RightShoulder, WaistPoint: TPoint;
  Kind: TBreathGuidePoint;
  LeftBody: array[0..3] of TPoint;
  Radius, ShoulderSpan, TorsoHalfWidth: Integer;
  RightBody: array[0..3] of TPoint;
  ShoulderCurve: array[0..6] of TPoint;
begin
  HeadPoint := GuidePointToCanvas(Destination, GuidePoints, bgpHead);
  NeckPoint := GuidePointToCanvas(Destination, GuidePoints, bgpNeck);
  ChestPoint := GuidePointToCanvas(Destination, GuidePoints, bgpChest);
  WaistPoint := GuidePointToCanvas(Destination, GuidePoints, bgpWaist);
  LeftShoulder := GuidePointToCanvas(Destination, GuidePoints, bgpLeftShoulder);
  RightShoulder := GuidePointToCanvas(Destination, GuidePoints, bgpRightShoulder);
  ShoulderSpan := Max(1, RightShoulder.X - LeftShoulder.X);
  ChestRect := Rect(LeftShoulder.X + ShoulderSpan div 10,
    Min(LeftShoulder.Y, RightShoulder.Y) + 4,
    RightShoulder.X - ShoulderSpan div 10,
    ChestPoint.Y + Max(12, (WaistPoint.Y - ChestPoint.Y) div 3));
  AbdomenRect := Rect(LeftShoulder.X + ShoulderSpan div 5, ChestPoint.Y,
    RightShoulder.X - ShoulderSpan div 5, WaistPoint.Y);

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
  ShoulderCurve[1] := Point(LeftShoulder.X + ShoulderSpan div 6, LeftShoulder.Y - ShoulderSpan div 14);
  ShoulderCurve[2] := Point(NeckPoint.X - ShoulderSpan div 7, NeckPoint.Y + ShoulderSpan div 15);
  ShoulderCurve[3] := NeckPoint;
  ShoulderCurve[4] := Point(NeckPoint.X + ShoulderSpan div 7, NeckPoint.Y + ShoulderSpan div 15);
  ShoulderCurve[5] := Point(RightShoulder.X - ShoulderSpan div 6, RightShoulder.Y - ShoulderSpan div 14);
  ShoulderCurve[6] := RightShoulder;
  PolyBezier(Canvas.Handle, ShoulderCurve[0], Length(ShoulderCurve));

  TorsoHalfWidth := Max(10, ShoulderSpan div 4);
  LeftBody[0] := LeftShoulder;
  LeftBody[1] := Point(LeftShoulder.X - ShoulderSpan div 14, ChestPoint.Y);
  LeftBody[2] := Point(WaistPoint.X - TorsoHalfWidth - ShoulderSpan div 12, WaistPoint.Y - (WaistPoint.Y - ChestPoint.Y) div 3);
  LeftBody[3] := Point(WaistPoint.X - TorsoHalfWidth, WaistPoint.Y);
  RightBody[0] := RightShoulder;
  RightBody[1] := Point(RightShoulder.X + ShoulderSpan div 14, ChestPoint.Y);
  RightBody[2] := Point(WaistPoint.X + TorsoHalfWidth + ShoulderSpan div 12, WaistPoint.Y - (WaistPoint.Y - ChestPoint.Y) div 3);
  RightBody[3] := Point(WaistPoint.X + TorsoHalfWidth, WaistPoint.Y);
  PolyBezier(Canvas.Handle, LeftBody[0], Length(LeftBody));
  PolyBezier(Canvas.Handle, RightBody[0], Length(RightBody));
  Canvas.MoveTo(LeftBody[3].X, LeftBody[3].Y);
  Canvas.LineTo(RightBody[3].X, RightBody[3].Y);

  LeftArmEnd := Point(LeftShoulder.X - ShoulderSpan div 12, LeftShoulder.Y + (WaistPoint.Y - LeftShoulder.Y) div 2);
  RightArmEnd := Point(RightShoulder.X + ShoulderSpan div 12, RightShoulder.Y + (WaistPoint.Y - RightShoulder.Y) div 2);
  Canvas.MoveTo(LeftShoulder.X, LeftShoulder.Y); Canvas.LineTo(LeftArmEnd.X, LeftArmEnd.Y);
  Canvas.MoveTo(RightShoulder.X, RightShoulder.Y); Canvas.LineTo(RightArmEnd.X, RightArmEnd.Y);
  Radius := Max(12, Abs(NeckPoint.Y - HeadPoint.Y));
  Canvas.Ellipse(HeadPoint.X - Radius * 2 div 3, HeadPoint.Y - Radius,
    HeadPoint.X + Radius * 2 div 3, HeadPoint.Y + Radius);
  Canvas.MoveTo(HeadPoint.X - Radius div 3, HeadPoint.Y + Radius);
  Canvas.LineTo(NeckPoint.X - ShoulderSpan div 12, NeckPoint.Y);
  Canvas.MoveTo(HeadPoint.X + Radius div 3, HeadPoint.Y + Radius);
  Canvas.LineTo(NeckPoint.X + ShoulderSpan div 12, NeckPoint.Y);

  Radius := MulDiv(6, CurrentPPI, 96);
  for Kind := Low(TBreathGuidePoint) to High(TBreathGuidePoint) do
  begin
    P := GuidePointToCanvas(Destination, GuidePoints, Kind);
    if Ord(Kind) = SelectedPoint then Canvas.Brush.Color := TColor($000080FF)
    else Canvas.Brush.Color := TColor($00FFC060);
    Canvas.Pen.Color := clWhite;
    Canvas.Rectangle(P.X - Radius, P.Y - Radius, P.X + Radius + 1, P.Y + Radius + 1);
  end;
  Canvas.Brush.Style := bsSolid;
end;

end.
