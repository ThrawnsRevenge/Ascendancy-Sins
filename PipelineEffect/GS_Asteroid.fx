float4x4 g_World : World;
float4x4 g_WorldViewProjection : WorldViewProjection;
float4x4 g_View;
float4x4 g_ShadowUVTransforms[ShadowMapCount];

texture	g_TextureDiffuse0 : Diffuse;
texture	g_TextureNormal;
texture g_TextureTeamColor;
texture	g_TextureSelfIllumination;
texture	g_TextureEnvironmentCube : Environment;
texture g_EnvironmentIllumination : Environment;
texture g_TextureShadowMap;

float4 g_Light_AmbientLite : Ambient;
float4 g_Light_AmbientDark : Ambient;

float3 g_Light0_Position: Position = float3( 0.f, 0.f, 0.f );
float4 g_Light0_DiffuseLite: Diffuse = float4( 1.f, 1.f, 1.f, 1.f );
float4 g_Light0_Specular;

float g_MaterialGlossiness;
float g_ShadowTextureSize;
float4 g_TeamColor;
float minShadow = .0f;
float cascadeBias[4] = {0,0,0,0};
float cascadeBlurLowerBound = .99f;

sampler TextureColorSampler = sampler_state{
    Texture = <g_TextureDiffuse0>;
#ifndef Anisotropy
    Filter = LINEAR;
#else
	Filter = ANISOTROPIC;
	MaxAnisotropy = AnisotropyLevel;
#endif
};

sampler TextureNormalSampler = sampler_state{
    Texture = <g_TextureNormal>;
#ifndef Anisotropy
    Filter = LINEAR;
#else
	Filter = ANISOTROPIC;
	MaxAnisotropy = AnisotropyLevel;
#endif
};

sampler TextureDataSampler = sampler_state{
    Texture = <g_TextureSelfIllumination>;    
#ifndef Anisotropy
    Filter = LINEAR;
#else
	Filter = ANISOTROPIC;
	MaxAnisotropy = AnisotropyLevel;
#endif
};

samplerCUBE TextureEnvironmentCubeSampler = sampler_state{
    Texture = <g_TextureEnvironmentCube>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
	 
};

samplerCUBE EnvironmentIlluminationCubeSampler = sampler_state{
    Texture = <g_EnvironmentIllumination>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;

};

sampler TextureShadowSampler = sampler_state{
	Texture = <g_TextureShadowMap>;
	MipFilter = NONE;
	MinFilter = POINT;
    MagFilter = POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;	
};

struct VsOutput
{
	float4 Position	: POSITION;
	float2 TexCoord : TEXCOORD0;
	float3 LightTangent : TEXCOORD1;
	float3 ViewTangent : TEXCOORD2;
	float3 ShadowUV[ShadowMapCount]: TEXCOORD3;
};

float3 GetShadowUV(float4 position, int level)
{
	float4 fullShadowUV = mul(position, g_ShadowUVTransforms[level]);
	float3 shadowUV = fullShadowUV.xyz / fullShadowUV.w;
	return shadowUV;
}

VsOutput RenderSceneVS( 
	float3 position : POSITION, 
	float3 normal : NORMAL,
	float3 tangent : TANGENT,
	float2 texCoord : TEXCOORD0)
{
	VsOutput output;
	
	output.Position = mul(float4(position, 1.0f), g_WorldViewProjection);
	output.TexCoord = texCoord;	

	float3 tangentInWorldSpace = normalize(mul(tangent, (float3x3)g_World));
	float3 normalInWorldSpace = normalize(mul(normal, (float3x3)g_World));
	float3 biTangentInWorldSpace = cross(normalInWorldSpace, tangentInWorldSpace);
    float3x3 tangentMatrix = transpose(float3x3(tangentInWorldSpace, biTangentInWorldSpace, normalInWorldSpace));
    
	float3 positionInWorldSpace = mul(float4(position, 1.f), g_World).xyz;
	float3 positionInTangentSpace = mul(positionInWorldSpace, tangentMatrix);
	output.ViewTangent = normalize(-positionInTangentSpace);
         
	float3 lightInTangentSpace = mul(g_Light0_Position, tangentMatrix);
	output.LightTangent = normalize(lightInTangentSpace - positionInTangentSpace);

	for(int i = 0; i < ShadowMapCount; ++i)
	{
		output.ShadowUV[i] = GetShadowUV(float4(position, 1.f), i);
	}
    
    return output;
}

float4 SRGBToLinear(float4 color)
{
	return color;

	//When external colors and the data texture are redone this can be reenabled.
	//return float4(color.rgb * (color.rgb * (color.rgb * 0.305306011f + 0.682171111f) + 0.012522878f), color.a);
}

float4 LinearToSRGB(float4 color)
{
	return color;

	//When external colors and the data texture are redone this can be reenabled.
	//float3 S1 = sqrt(color.rgb);
	//float3 S2 = sqrt(S1);
	//float3 S3 = sqrt(S2);
	//return float4(0.662002687 * S1 + 0.684122060 * S2 - 0.323583601 * S3 - 0.225411470 * color.rgb, color.a);
}

float4 GetColorWithTeamColorSample(float4 colorSample)
{
	float4 linearTeamColor = SRGBToLinear(g_TeamColor);
	float teamColorScalar = (colorSample.a * linearTeamColor.a); 
	
	float4 colorWithTeamColor = colorSample * (1.f - teamColorScalar);
	colorWithTeamColor += (linearTeamColor * teamColorScalar);
	colorWithTeamColor.a = colorSample.a;

	return colorWithTeamColor;
}

float3 GetNormalInTangentSpace(float2 texCoord)
{
	//using nvidia's DXT5_NM format:
	//http://discuss.microsoft.com/SCRIPTS/WA-MSD.EXE?A2=ind0507D&L=DIRECTXDEV&P=R1929&I=-3
	float4 sample = 2.f * tex2D(TextureNormalSampler, texCoord) - 1.f;
	float x = sample.a;
	float y = sample.g;
	float z = sqrt(1 - x * x - y * y);

	//NOTE: have to renormalize tangent vectors as linear interpolation screws them up.
	return normalize(float3(x,y,z));
}

float4 GetAmbientLightColor(float3 normal)
{
    float4 ambSample = SRGBToLinear(texCUBE(EnvironmentIlluminationCubeSampler, normal));
	ambSample.a = 1.f;	
    return ambSample;
}

float4 GetDiffuseLightColor(float3 incidence, float3 normal, float4 lightColor, float shadowScalar)
{
	float diffuseScalar = clamp(dot(incidence, normal), minShadow, 1.f);
	bool hasDiffuse = diffuseScalar < 1;
	if(hasDiffuse)
	{
		diffuseScalar = max(minShadow, min(shadowScalar, diffuseScalar));
	}	
	return diffuseScalar * lightColor;
}

float4 GetSpecularColor(float3 light, float3 normal, float3 view, float glossScalar)
{
	float3 h = normalize(light + view); //half angle

    float NDotH = dot(normal, h);
    float HDotV = dot(h, view);
    float NDotV = dot(normal, view);
    float NDotL = dot(normal, light);
	
	//Geometretic attenuation (self masking)
    float selfMask = clamp(min(1, min(2 * (NDotH * NDotV) / HDotV, 2 * (NDotH * NDotL) / HDotV)), .001f, 1.f);

	float i = pow(clamp(NDotH, 0.0001f, 1.f), g_MaterialGlossiness) * glossScalar; //pow(0, x) is bugged so keep it at a small non-zero value.
	
	float4 linearSpecular = SRGBToLinear(g_Light0_Specular);
	return i * selfMask * linearSpecular;
}

float4 GetEnvironmentColor(float3 view, float envScalar)
{
    float4 envSample = SRGBToLinear(texCUBE(TextureEnvironmentCubeSampler, view));    
	envSample.a = 1.f;
    return (envSample * envScalar);
}

float GetShadowTermFromSampleWithPCF(float3 texCoord, float dotLightNormal, int cascadeIndex)
{
	float shadowTexelOffset = 1.f / g_ShadowTextureSize;
	
	// Sample each of them checking whether the pixel under test is shadowed or not
	float fShadowTerm = 0.f;

	for(int i = -2; i <= 2; ++i)
	{
		for(int j = -2; j <= 2; ++j)
		{			
			float2 offsetTexCoord = texCoord.xy + float2(i * shadowTexelOffset, j * shadowTexelOffset);
			float smDepth = tex2D(TextureShadowSampler, offsetTexCoord.xy).r;
			fShadowTerm += (texCoord.z - cascadeBias[cascadeIndex] <= smDepth) ? 1.f : minShadow;
		}
	}		

	fShadowTerm /= 25.0f;

	fShadowTerm = lerp(minShadow, fShadowTerm, (dotLightNormal + 1.f) / 2.f);

	return fShadowTerm;
}

float GetShadowScalar(float3 shadowUV[ShadowMapCount], float3 lightDir, float3 normalDir)
{	
	float columnInc = 1.f / ShadowMapColumnCount;
	float rowInc = 1.f / ShadowMapRowCount;
	bool foundValidCascade = false;
	int cascadeIndex = -1;
	float3 texCoord;
	float distToEdge = -1.f;
	for(int row = 0; row < ShadowMapRowCount; row++)
	{
		for(int column = 0; column < ShadowMapColumnCount; column++)
		{	
			//check if close to the left or right and blend with sample on either side.
			
			float left = column * columnInc;
			float right = left + columnInc;
			float bottom = row * rowInc;
			float top = bottom + rowInc;
			cascadeIndex = column + row * ShadowMapColumnCount;
			texCoord = shadowUV[cascadeIndex];
			if(texCoord.x >= left && 
				texCoord.x <= right && 
				texCoord.y >= bottom && 
				texCoord.y <= top)
			{
				foundValidCascade = true;
				distToEdge = min(right - texCoord.x, top - texCoord.y);
				break;
			}
		}
		if(foundValidCascade)
		{
			break;
		}
	}
		
	float shadowScalar;	
	float dotLightNormal = dot(lightDir, normalDir);
	if(foundValidCascade)
	{
		shadowScalar = GetShadowTermFromSampleWithPCF(texCoord, dotLightNormal, cascadeIndex);
		if(cascadeIndex != ShadowMapCount - 1)
		{
			float nextShadowScalar = GetShadowTermFromSampleWithPCF(shadowUV[cascadeIndex + 1], dotLightNormal, cascadeIndex + 1);			
			float tValue = max(1.f - distToEdge - cascadeBlurLowerBound, 0.f) / (1.f - cascadeBlurLowerBound);
			shadowScalar = lerp(shadowScalar, nextShadowScalar, tValue);
		}
	}
	else
	{		
		shadowScalar = max((dotLightNormal + 1.f) / 2.f, minShadow);
	}
	return shadowScalar;
}

float4 GetFinalPixelColor(float2 texCoord, float3 lightTangent, float3 viewTangent, float3 shadowUV[ShadowMapCount])
{   
	float4 colorSample = SRGBToLinear(tex2D(TextureColorSampler, texCoord));
	colorSample = GetColorWithTeamColorSample(colorSample);	
	float4 dataSample = tex2D(TextureDataSampler, texCoord);	
		
	float3 normalTangent = GetNormalInTangentSpace(texCoord);
	
	float shadowScalar = GetShadowScalar(shadowUV, lightTangent, normalTangent);		

	float specScalar = dataSample.r;
	float4 spec = GetSpecularColor(lightTangent, normalTangent, viewTangent, specScalar) * shadowScalar;	

	float4 amb = GetAmbientLightColor(normalTangent) * colorSample;

	float4 linearDiffuseLite = SRGBToLinear(g_Light0_DiffuseLite);
	float4 diff = GetDiffuseLightColor(lightTangent, normalTangent, linearDiffuseLite, shadowScalar) * colorSample;
	
	float envScalar = dataSample.b;
	float4 env = GetEnvironmentColor(viewTangent, envScalar);
	
	float4 finalColor = amb + diff + env + spec;
	
	float selfIllumLightScalar = dataSample.g;
	finalColor = selfIllumLightScalar * colorSample + (1.f - selfIllumLightScalar) * finalColor;
		
	return LinearToSRGB(finalColor);
}

float4 RenderScenePS(VsOutput input) : COLOR0
{ 
	return GetFinalPixelColor(input.TexCoord, input.LightTangent, input.ViewTangent, input.ShadowUV);
}

technique RenderWithPixelShader
{
    pass Pass0
    {          
        VertexShader = compile vs_3_0 RenderSceneVS();
        PixelShader = compile ps_3_0 RenderScenePS();
		AlphaTestEnable = FALSE;
        AlphaBlendEnable = TRUE;
		SrcBlend = ONE;
		DestBlend = ZERO;
		ZEnable = TRUE;
		ZWriteEnable = TRUE;			   
    }
}
