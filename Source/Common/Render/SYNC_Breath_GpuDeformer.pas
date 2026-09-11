unit SYNC_Breath_GpuDeformer;

interface

uses
  AviUtl2FilterTypes,
  SYNC_Breath_RuntimeSettings;

procedure InitializeGpuDeformer;
procedure FinalizeGpuDeformer;
function ApplyBreathGpu(Video: PFILTER_PROC_VIDEO; const GuideText: string;
  const Settings: TBreathRuntimeSettings; out ErrorText: string): Boolean;

implementation

uses
  System.Classes,
  System.Math,
  System.SysUtils,
  Winapi.D3D11,
  Winapi.DXGIFormat,
  Winapi.Windows,
  SYNC_Breath_DebugLog,
  SYNC_Breath_GuideData;

{$R 'Shader\SYNC_Breath_Compute.res'}

type
  TConstants = packed record
    Width, Height: Cardinal;
    Breath, Padding: Single;
    CenterX, WaistY, ChestY, NeckY: Single;
    HeadY, LeftShoulderX, RightShoulderX, Padding2: Single;
  end;

var
  GBuffer: ID3D11Buffer;
  GContext: ID3D11DeviceContext;
  GDevice: ID3D11Device;
  GFormat: DXGI_FORMAT;
  GHeight: Integer;
  GInput: ID3D11Texture2D;
  GInputView: ID3D11ShaderResourceView;
  GLock: TRTLCriticalSection;
  GInitialized: Boolean;
  GLoggedGpu: Boolean;
  GOutput: ID3D11Texture2D;
  GOutputView: ID3D11UnorderedAccessView;
  GShader: ID3D11ComputeShader;
  GWidth: Integer;

procedure ClearResources;
begin
  GBuffer := nil;
  GShader := nil;
  GOutputView := nil;
  GInputView := nil;
  GOutput := nil;
  GInput := nil;
  GContext := nil;
  GDevice := nil;
  GWidth := 0;
  GHeight := 0;
  GFormat := DXGI_FORMAT_UNKNOWN;
end;

procedure InitializeGpuDeformer;
begin
  if GInitialized then Exit;
  InitializeCriticalSection(GLock);
  GInitialized := True;
end;

procedure FinalizeGpuDeformer;
begin
  if not GInitialized then Exit;
  EnterCriticalSection(GLock);
  try ClearResources; finally LeaveCriticalSection(GLock); end;
  DeleteCriticalSection(GLock);
  GInitialized := False;
end;

function EnsureResources(Source: ID3D11Texture2D;
  out ErrorText: string): Boolean;
var
  BD: TD3D11_BUFFER_DESC;
  Desc: TD3D11_TEXTURE2D_DESC;
  Device: ID3D11Device;
  Stream: TResourceStream;
begin
  Result := False;
  Source.GetDesc(Desc);
  Source.GetDevice(Device);
  if (Device = nil) or (Desc.SampleDesc.Count <> 1) or
    not (Desc.Format in [DXGI_FORMAT_R8G8B8A8_UNORM,
      DXGI_FORMAT_R16G16B16A16_FLOAT]) then
  begin
    ErrorText := Format('unsupported texture format: %d', [Ord(Desc.Format)]);
    Exit;
  end;
  if (GDevice <> nil) and (Pointer(GDevice) = Pointer(Device)) and
    (GWidth = Integer(Desc.Width)) and (GHeight = Integer(Desc.Height)) and
    (GFormat = Desc.Format) then Exit(True);
  ClearResources;
  if Device.CreateDeferredContext(0, GContext) < 0 then
  begin ErrorText := 'CreateDeferredContext failed'; Exit; end;
  Stream := TResourceStream.Create(HInstance, 'BREATH_COMPUTE', RT_RCDATA);
  try
    if Device.CreateComputeShader(Stream.Memory, Stream.Size, nil, GShader) < 0 then
    begin ErrorText := 'CreateComputeShader failed'; Exit; end;
  finally Stream.Free; end;
  Desc.Usage := D3D11_USAGE_DEFAULT;
  Desc.CPUAccessFlags := 0;
  Desc.MiscFlags := 0;
  Desc.BindFlags := D3D11_BIND_SHADER_RESOURCE;
  if Device.CreateTexture2D(Desc, nil, GInput) < 0 then
  begin ErrorText := 'Create input texture failed'; Exit; end;
  if Device.CreateShaderResourceView(GInput, nil, GInputView) < 0 then
  begin ErrorText := 'Create SRV failed'; Exit; end;
  Desc.BindFlags := D3D11_BIND_UNORDERED_ACCESS;
  if Device.CreateTexture2D(Desc, nil, GOutput) < 0 then
  begin ErrorText := 'Create output texture failed'; Exit; end;
  if Device.CreateUnorderedAccessView(GOutput, nil, GOutputView) < 0 then
  begin ErrorText := 'Create UAV failed'; Exit; end;
  FillChar(BD, SizeOf(BD), 0);
  BD.ByteWidth := SizeOf(TConstants);
  BD.Usage := D3D11_USAGE_DEFAULT;
  BD.BindFlags := D3D11_BIND_CONSTANT_BUFFER;
  if Device.CreateBuffer(BD, nil, GBuffer) < 0 then
  begin ErrorText := 'Create constant buffer failed'; Exit; end;
  GDevice := Device;
  GWidth := Desc.Width;
  GHeight := Desc.Height;
  GFormat := Desc.Format;
  Result := True;
end;

function ApplyBreathGpu(Video: PFILTER_PROC_VIDEO; const GuideText: string;
  const Settings: TBreathRuntimeSettings; out ErrorText: string): Boolean;
var
  CommandList: ID3D11CommandList;
  C: TConstants;
  Framebuffer, Source: ID3D11Texture2D;
  Guide: TBreathGuidePoints;
  Immediate: ID3D11DeviceContext;
  NoSRV: ID3D11ShaderResourceView;
  NoUAV: ID3D11UnorderedAccessView;
  Phase, Wave: Double;
begin
  Result := False;
  ErrorText := '';
  if not GInitialized or (Video = nil) or
    not Assigned(Video^.GetImageTexture2D) or
    not Assigned(Video^.GetFramebufferTexture2D) then Exit;
  EnterCriticalSection(GLock);
  try
    try
      Source := ID3D11Texture2D(Video^.GetImageTexture2D());
      Framebuffer := ID3D11Texture2D(Video^.GetFramebufferTexture2D());
      if (Source = nil) or (Framebuffer = nil) or
        not EnsureResources(Source, ErrorText) then Exit;
      if not TryDecodeBreathGuide(GuideText, Guide, ErrorText) then Exit;
      Phase := Frac(Video^.Object_^.Time / Settings.PeriodSeconds +
        Settings.PhaseDegrees / 360) * 2 * Pi;
      Wave := 0.5 - 0.5 * Cos(Phase);
      if Settings.BreathType = btHeavy then Wave := Power(Wave, 0.55);
      FillChar(C, SizeOf(C), 0);
      C.Width := GWidth; C.Height := GHeight;
      C.Breath := Wave * Settings.Strength;
      C.CenterX := Guide[bgpChest].X; C.WaistY := Guide[bgpWaist].Y;
      C.ChestY := Guide[bgpChest].Y; C.NeckY := Guide[bgpNeck].Y;
      C.HeadY := Guide[bgpHead].Y;
      C.LeftShoulderX := Guide[bgpLeftShoulder].X;
      C.RightShoulderX := Guide[bgpRightShoulder].X;
      GContext.ClearState;
      GContext.CopyResource(GInput, Source);
      GContext.UpdateSubresource(GBuffer, 0, nil, @C, 0, 0);
      GContext.CSSetShader(GShader, nil, 0);
      GContext.CSSetShaderResources(0, 1, GInputView);
      GContext.CSSetUnorderedAccessViews(0, 1, GOutputView, nil);
      GContext.CSSetConstantBuffers(0, 1, GBuffer);
      GContext.Dispatch((GWidth + 15) div 16, (GHeight + 15) div 16, 1);
      GContext.CSSetShaderResources(0, 1, NoSRV);
      GContext.CSSetUnorderedAccessViews(0, 1, NoUAV, nil);
      GContext.CopyResource(Framebuffer, GOutput);
      if GContext.FinishCommandList(False, CommandList) < 0 then
      begin ErrorText := 'FinishCommandList failed'; Exit; end;
      GDevice.GetImmediateContext(Immediate);
      Immediate.ExecuteCommandList(CommandList, True);
      if not GLoggedGpu then
      begin DebugLog('Runtime deformation path: D3D11 GPU.'); GLoggedGpu := True; end;
      Result := True;
    except
      on E: Exception do ErrorText := E.ClassName + ': ' + E.Message;
    end;
  finally
    LeaveCriticalSection(GLock);
  end;
end;

end.
