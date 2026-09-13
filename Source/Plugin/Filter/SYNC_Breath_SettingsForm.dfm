object FormBreathSettings: TFormBreathSettings
  Left = 0
  Top = 0
  Caption = #21628#21560#35373#23450
  ClientHeight = 480
  ClientWidth = 720
  Color = 2894892
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWhite
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnMouseWheel = FormMouseWheel
  TextHeight = 15
  object PreviewPaintBox: TPaintBox
    Left = 0
    Top = 0
    Width = 720
    Height = 440
    Align = alClient
    OnDblClick = PreviewPaintBoxDblClick
    OnMouseDown = PreviewPaintBoxMouseDown
    OnMouseMove = PreviewPaintBoxMouseMove
    OnMouseUp = PreviewPaintBoxMouseUp
    OnPaint = PreviewPaintBoxPaint
  end
  object StatusPanel: TPanel
    Left = 0
    Top = 440
    Width = 720
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    ParentBackground = False
    Color = 2894892
    TabOrder = 0
    object StatusLabel: TLabel
      Left = 0
      Top = 0
      Width = 720
      Height = 20
      Align = alTop
      Alignment = taLeftJustify
      AutoSize = False
      Caption = #26144#20687#12399#12414#12384#21462#24471#12373#12428#12390#12356#12414#12379#12435#12290
      EllipsisPosition = epEndEllipsis
      Font.Color = clWhite
    end
  end
end
