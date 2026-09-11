Texture2D<float4> InputTexture : register(t0);
RWTexture2D<float4> OutputTexture : register(u0);
cbuffer Constants : register(b0) {
 uint Width; uint Height; float Breath; float Pad;
 float4 CenterLevels; // center X, waist Y, chest Y, neck Y
 float4 HeadShoulders; // head Y, left shoulder X, right shoulder X, unused
};
[numthreads(16,16,1)]
void Main(uint3 id : SV_DispatchThreadID) {
 if (id.x >= Width || id.y >= Height) return;
 float2 p=float2(id.xy)/float2(max(Width-1,1),max(Height-1,1));
 float cx=CenterLevels.x, waist=CenterLevels.y, chestY=CenterLevels.z;
 float neck=CenterLevels.w, head=HeadShoulders.x;
 float width=max(.08,(HeadShoulders.z-HeadShoulders.y)*.52);
 float horizontal=saturate(1-abs(p.x-cx)/width);
 float chest=p.y<=chestY ? 1-abs(p.y-chestY)/max(.001,chestY-neck)
   : 1-(p.y-chestY)/max(.001,(waist-chestY)*.55);
 chest=saturate(chest);
 float upper=0;
 if(p.y<head) upper=.18*saturate(1-(head-p.y)/max(.001,neck-head));
 else if(p.y<neck) upper=lerp(.18,.40,(p.y-head)/max(.001,neck-head));
 else if(p.y<chestY) upper=lerp(.40,1,(p.y-neck)/max(.001,chestY-neck));
 float abdomen=p.y<chestY ? 0 : saturate(1-abs(((p.y-chestY)/max(.001,waist-chestY))*2-1));
 float influence=(max(chest,upper)+abdomen*.46)*horizontal;
 int sy=clamp(int(round(id.y+.026*Breath*influence*Height)),0,int(Height)-1);
 OutputTexture[id.xy]=InputTexture.Load(int3(id.x,sy,0));
}
