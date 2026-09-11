object FormBreathSettings: TFormBreathSettings
  Left = 0
  Top = 0
  Caption = #21628#21560#35373#23450
  ClientHeight = 640
  ClientWidth = 960
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnMouseWheel = FormMouseWheel
  TextHeight = 15
  object PreviewPaintBox: TPaintBox
    Left = 0
    Top = 0
    Width = 960
    Height = 600
    Align = alClient
    OnDblClick = PreviewPaintBoxDblClick
    OnMouseDown = PreviewPaintBoxMouseDown
    OnMouseMove = PreviewPaintBoxMouseMove
    OnMouseUp = PreviewPaintBoxMouseUp
    OnPaint = PreviewPaintBoxPaint
  end
  object StatusPanel: TPanel
    Left = 0
    Top = 600
    Width = 960
    Height = 40
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object StatusLabel: TLabel
      Left = 12
      Top = 11
      Width = 936
      Height = 17
      AutoSize = False
      Caption = #26144#20687#12399#12414#12384#21462#24471#12373#12428#12390#12356#12414#12379#12435#12290
      EllipsisPosition = epEndEllipsis
    end
  end
end
