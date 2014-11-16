float4x4 g_World : World;
float4x4		g_WorldViewProjection	: WorldViewProjection;

float g_Time;
float3 g_ImpactPosition;
float g_ShieldPercent;

texture g_TextureNoise3D;
texture	g_TextureEnvironmentCube : Environment;
texture g_TextureDiffuse0;

float g_InternalHitRadius;
float g_ExternalHitRadius;

float4 g_GlowColor;

samplerCUBE TextureEnvironmentCubeSampler = sampler_state{
    Texture = <g_TextureEnvironmentCube>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
};

sampler NoiseSampler 
= sampler_state 
{
    texture = < g_TextureNoise3D >;
    AddressU  = WRAP;        
    AddressV  = WRAP;
	AddressW  = WRAP;
    MIPFILTER = LINEAR;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

void
RenderSceneVS_WithoutPixelShader( 
	float3 iPosition					: POSITION, 
	float2 iTexCoord0					: TEXCOORD0,
	float3 iNormal						: NORMAL,
	float4 iColor						: COLOR0,
	out float4 oPosition				: POSITION,
    out float4 oColor0					: COLOR0,
    out float2 oTexCoord0				: TEXCOORD0 )
{
	float dist = distance( iPosition, g_ImpactPosition );
	
	oColor0 = g_GlowColor;
	oColor0.a = lerp( 0.1f, 0.f, dist/g_ExternalHitRadius);

	oColor0.a *= g_ShieldPercent;

	oPosition = mul( float4( iPosition, 1.f ), g_WorldViewProjection );
   
    oTexCoord0 = iTexCoord0; 
}

void
RenderSceneVS_WithPixelShader( 
	float3 iPosition					: POSITION, 
	float2 iTexCoord0					: TEXCOORD0,
	float3 iNormal						: NORMAL,
	float3 iTangent						: TANGENT,
	float4 iColor						: COLOR0,
	out float4 oPosition				: POSITION,
    out float4 oColor0					: COLOR0,
    out float2 oTexCoord0				: TEXCOORD0,
	out float oDist						: TEXCOORD1,
	out float3 oPos						: TEXCOORD2,
	out float3 oView					: TEXCOORD3 )
{
	oColor0 = g_GlowColor;

	oDist = distance( iPosition, g_ImpactPosition );
	oPos = iPosition;
	
	//Vertex Position
	float3 position = iPosition;
	
	oPosition = mul( float4( position, 1.f ), g_WorldViewProjection );
   
    oTexCoord0 = iTexCoord0; 
    
	float3 tangentInWorldSpace = normalize(mul(iTangent, (float3x3)g_World));
	float3 normalInWorldSpace = normalize(mul(iNormal, (float3x3)g_World));
	float3 biTangentInWorldSpace = cross(normalInWorldSpace, tangentInWorldSpace);
    float3x3 tangentMatrix = transpose(float3x3(tangentInWorldSpace, biTangentInWorldSpace, normalInWorldSpace));
    
	float3 positionInWorldSpace = mul(float4(position, 1.f), g_World).xyz;
	float3 positionInTangentSpace = mul(positionInWorldSpace, tangentMatrix);
	oView = normalize(-positionInTangentSpace);
}

float4
GetPixelColor( float4 iColor, float2 iTexCoord, float iDist, float3 iPos, float3 iView)
{
	float4 environmentColor = texCUBE(TextureEnvironmentCubeSampler, iView);	
	float4 color = g_GlowColor;
	
	//Standard Shield Frame alpha
	float notHitArea = 0.05f;
	float distVertex = iDist; //uses inter-vertex interpolation - less accurate but good over longer range
	color.a = lerp( notHitArea, 0.f, distVertex/g_InternalHitRadius);
	
	//Impact point animtion stuff
	float distPixel = distance( iPos, g_ImpactPosition ); //uses texcoord to encode so limited range, but more accurate	
	float noiseScale = g_ExternalHitRadius;
	float timeScale = 10.f;	
	float noiseTime = ( g_Time * timeScale );
	float3 index = float3( iTexCoord.x, iTexCoord.y, noiseTime ) * 2.f;
	
	float domainPhaseShift = tex3D( NoiseSampler, noiseScale * index ) * 2 - 1; //range -1 to 1
	
	float inversePercent = max(1.f - distVertex/g_InternalHitRadius,0.f);//don't want negative values
	float newAlpha = color.a + domainPhaseShift * inversePercent;
	color.a = max( newAlpha, color.a);
	
	//Weaker shields are fainter
	color.a *= g_ShieldPercent;

	return color;
}

void
RenderScenePS( 
	float4 iColor					: COLOR0,
	float2 iTexCoord0				: TEXCOORD0,
	float iDist						: TEXCOORD1,
	float3 iPos						: TEXCOORD2,
	float3 iView					: TEXCOORD3,
	out float4 oColor0				: COLOR0 )
{ 
	oColor0 = GetPixelColor( iColor, iTexCoord0, iDist, iPos, iView);
}

technique RenderWithoutVertexShader
{
    pass Pass0
    {   	        
        VertexShader		= NULL;
		PixelShader			= NULL;
		
		AlphaBlendEnable	= true;
		SrcBlend			= srcalpha;
		DestBlend			= invsrcalpha;
		
		ZEnable				= true;
		ZWriteEnable		= false;		
    }
}

technique RenderWithoutPixelShader
{
    pass Pass0
    {   	        
        VertexShader		= compile vs_1_1 RenderSceneVS_WithoutPixelShader();
		PixelShader			= NULL;
		
		AlphaTestEnable		= false;
		
		ZEnable				= true;
		ZWriteEnable		= false;		
    }
}

technique RenderWithPixelShader
{
    pass Pass0
    {          
        VertexShader		= compile vs_1_1 RenderSceneVS_WithPixelShader();
        PixelShader			= compile ps_2_0 RenderScenePS();
        
        AlphaTestEnable		= false;
	
		ZEnable				= true;
		ZWriteEnable		= false;
     }
}
