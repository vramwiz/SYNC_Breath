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
  TWordArray = array[0..7] of Word;
  PWordArray = ^TWordArray;
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
  GOutputPixels: TBytes;
  GOutputView: ID3D11UnorderedAccessView;
  GReadback: ID3D11Texture2D;
  GShader: ID3D11ComputeShader;
  GWidth: Integer;

procedure ClearResources;
begin
  GBuffer := nil;
  GShader := nil;
  GOutputView := nil;
  GReadback := nil;
  GInputView := nil;
  GOutput := nil;
  GOutputPixels := nil;
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
  Desc.Usage := D3D11_USAGE_STAGING;
  Desc.BindFlags := 0;
  Desc.CPUAccessFlags := D3D11_CPU_ACCESS_READ;
  if Device.CreateTexture2D(Desc, nil, GReadback) < 0 then
  begin ErrorText := 'Create readback texture failed'; Exit; end;
  SetLength(GOutputPixels, NativeInt(Desc.Width) * Desc.Height * 4);
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

function HalfToSingle(Value: Word): Single;
var
  E: Integer;
  M, Bits, Sign: Cardinal;
begin
  Sign := Cardinal(Value and $8000) shl 16;
  E := (Value shr 10) and $1F;
  M := Value and $03FF;
  if E = 0 then
  begin
    if M = 0 then Bits := Sign
    else
    begin
      E := -14;
      while (M and $0400) = 0 do begin M := M shl 1; Dec(E); end;
      Bits := Sign or Cardinal(E + 127) shl 23 or (M and $03FF) shl 13;
    end;
  end
  else if E = $1F then Bits := Sign or $7F800000 or M shl 13
  else Bits := Sign or Cardinal(E + 112) shl 23 or M shl 13;
  Result := PSingle(@Bits)^;
end;

function FloatByte(Value: Single): Byte;
begin
  if IsNan(Value) or (Value <= 0) then Exit(0);
  if Value >= 1 then Exit(255);
  Result := Round(Value * 255);
end;

function ApplyBreathGpu(Video: PFILTER_PROC_VIDEO; const GuideText: string;
  const Settings: TBreathRuntimeSettings; out ErrorText: string): Boolean;
var
  CommandList: ID3D11CommandList;
  C: TConstants;
  Source: ID3D11Texture2D;
  Guide: TBreathGuidePoints;
  Immediate: ID3D11DeviceContext;
  Mapped: TD3D11_MAPPED_SUBRESOURCE;
  NoSRV: ID3D11ShaderResourceView;
  NoUAV: ID3D11UnorderedAccessView;
  Phase, Wave: Double;
  Dst, Src: PByte;
  Words: PWordArray;
  X, Y: Integer;
begin
  Result := False;
  ErrorText := '';
  if not GInitialized or (Video = nil) or
    not Assigned(Video^.GetImageTexture2D) or
    not Assigned(Video^.SetImageData) then Exit;
  EnterCriticalSection(GLock);
  try
    try
      Source := ID3D11Texture2D(Video^.GetImageTexture2D());
      if (Source = nil) or not EnsureResources(Source, ErrorText) then Exit;
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
      GContext.CopyResource(GReadback, GOutput);
      if GContext.FinishCommandList(False, CommandList) < 0 then
      begin ErrorText := 'FinishCommandList failed'; Exit; end;
      GDevice.GetImmediateContext(Immediate);
      Immediate.ExecuteCommandList(CommandList, True);
      FillChar(Mapped, SizeOf(Mapped), 0);
      if Immediate.Map(GReadback, 0, D3D11_MAP_READ, 0, Mapped) < 0 then
      begin ErrorText := 'Map readback failed'; Exit; end;
      try
        Dst := @GOutputPixels[0];
        for Y := 0 to GHeight - 1 do
        begin
          Src := PByte(NativeUInt(Mapped.pData) + NativeUInt(Y) *
            Mapped.RowPitch);
          if GFormat = DXGI_FORMAT_R8G8B8A8_UNORM then
          begin
            Move(Src^, Dst^, GWidth * 4);
            Inc(Dst, GWidth * 4);
          end
          else
          begin
            Words := PWordArray(Src);
            for X := 0 to GWidth - 1 do
            begin
              Dst[0] := FloatByte(HalfToSingle(Words[0]));
              Dst[1] := FloatByte(HalfToSingle(Words[1]));
              Dst[2] := FloatByte(HalfToSingle(Words[2]));
              Dst[3] := FloatByte(HalfToSingle(Words[3]));
              Words := PWordArray(PByte(Words) + 8);
              Inc(Dst, 4);
            end;
          end;
        end;
      finally
        Immediate.Unmap(GReadback, 0);
      end;
      Video^.SetImageData(PPIXEL_RGBA(@GOutputPixels[0]), GWidth, GHeight);
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
