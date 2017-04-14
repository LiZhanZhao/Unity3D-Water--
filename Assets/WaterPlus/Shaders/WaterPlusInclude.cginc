#ifndef WATERPLUS_CG_INCLUDED
#define WATERPLUS_CG_INCLUDED
	
	#if !defined(WATERMAPS_ON)
		#undef BAKED_ANISOTROPY_DIR
	#endif
	
	#ifdef FLOWMAP_ANIMATION_ON
		#define FLOWMAP_ALL_ON
	#endif
	
	#define FLAT_HORIZONTAL_SURFACE

	#include "UnityCG.cginc"
	#include "Lighting.cginc"
	#include "AutoLight.cginc"
	
	sampler2D _MainTex;
	float4 _MainTex_ST;
	half _EdgeFoamStrength;
	sampler2D _HeightGlossMap;
	sampler2D _DUDVFoamMap;
	sampler2D _WaterMap;
	
	//Required anyways for proper UVs
	float4 _WaterMap_ST;
	
	sampler2D _SecondaryRefractionTex;
	float4 _SecondaryRefractionTex_ST;
	half _refractionsWetness;
	
	half _Refractivity;
		
	sampler2D _FlowMap;
	half flowMapOffset0, flowMapOffset1, halfCycle;

	half _normalStrength;
	
	sampler2D _NormalMap;
		
	samplerCUBE _Cube;

	half _Reflectivity;
	half _WaterAttenuation;
	
	fixed3 _DeepWaterTint;
	fixed3 _ShallowWaterTint;
	
	half _Shininess;
	half _Gloss;
	
	half _Fresnel0;
	
	
	sampler2D _AnisoMap;

	half _CausticsStrength;
	half _CausticsScale;
	
	sampler2D _CausticsAnimationTexture;
	half3 causticsOffsetAndScale;
	half4 causticsAnimationColorChannel;
	

	half _Opaqueness;

	//模型的反射
	sampler2D _ReflectionTex;

	// 水波
	half _GerstnerIntensity;
	float4 _GAmplitude;
	float4 _GFrequency;
	float4 _GSteepness;
	float4 _GSpeed;
	float4 _GDirectionAB;
	float4 _GDirectionCD;
	
	struct v2f {
    	float4  pos : SV_POSITION;
    	float2	uv_MainTex : TEXCOORD0;
    	
    	half2	uv_WaterMap : TEXCOORD1;
    	
    	fixed3	viewDir	: COLOR;
    	    	
    	fixed3	lightDir : TEXCOORD2;

	    float2 uv_SecondaryRefrTex : TEXCOORD5;

		float4 uv_ref : TEXCOORD4;
	};
	

	half3 GerstnerOffset4 (half2 xzVtx, half4 steepness, half4 amp, half4 freq, half4 speed, half4 dirAB, half4 dirCD) 
	{
		half3 offsets;
		
		half4 AB = steepness.xxyy * amp.xxyy * dirAB.xyzw;
		half4 CD = steepness.zzww * amp.zzww * dirCD.xyzw;
		
		half4 dotABCD = freq.xyzw * half4(dot(dirAB.xy, xzVtx), dot(dirAB.zw, xzVtx), dot(dirCD.xy, xzVtx), dot(dirCD.zw, xzVtx));
		half4 TIME = _Time.yyyy * speed;
		
		half4 COS = cos (dotABCD + TIME);
		half4 SIN = sin (dotABCD + TIME);
		
		offsets.x = dot(COS, half4(AB.xz, CD.xz));
		offsets.z = dot(COS, half4(AB.yw, CD.yw));
		offsets.y = dot(SIN, amp);

		return offsets;			
	}

	half3 GerstnerNormal4 (half2 xzVtx, half4 amp, half4 freq, half4 speed, half4 dirAB, half4 dirCD) 
	{
		half3 nrml = half3(0,2.0,0);
		
		half4 AB = freq.xxyy * amp.xxyy * dirAB.xyzw;
		half4 CD = freq.zzww * amp.zzww * dirCD.xyzw;
		
		half4 dotABCD = freq.xyzw * half4(dot(dirAB.xy, xzVtx), dot(dirAB.zw, xzVtx), dot(dirCD.xy, xzVtx), dot(dirCD.zw, xzVtx));
		half4 TIME = _Time.yyyy * speed;
		
		half4 COS = cos (dotABCD + TIME);
		
		nrml.x -= dot(COS, half4(AB.xz, CD.xz));
		nrml.z -= dot(COS, half4(AB.yw, CD.yw));
		
		nrml.xz *= _GerstnerIntensity;
		nrml = normalize (nrml);

		return nrml;			
	}

	inline void Gerstner (	out half3 offs, out half3 nrml,
					 half3 vtx, half3 tileableVtx, 
					 half4 amplitude, half4 frequency, half4 steepness, 
					 half4 speed, half4 directionAB, half4 directionCD ) 
	{
		offs = GerstnerOffset4(tileableVtx.xz, steepness, amplitude, frequency, speed, directionAB, directionCD);
		nrml = GerstnerNormal4(tileableVtx.xz + offs.xz, amplitude, frequency, speed, directionAB, directionCD);		

		/*
		#ifdef WATER_VERTEX_DISPLACEMENT_ON
			offs = GerstnerOffset4(tileableVtx.xz, steepness, amplitude, frequency, speed, directionAB, directionCD);
			nrml = GerstnerNormal4(tileableVtx.xz + offs.xz, amplitude, frequency, speed, directionAB, directionCD);		
		#else
			offs = half3(0,0,0);
			nrml = half3(0,1,0);
		#endif
		*/
	}


	v2f vert (appdata_tan v)

	{
	    v2f o;

	    o.pos = mul (UNITY_MATRIX_MVP, v.vertex);

	    o.uv_MainTex = TRANSFORM_TEX (v.texcoord, _MainTex);
	    
		o.uv_WaterMap = v.texcoord;// TRANSFORM_TEX(v.texcoord, _WaterMap);
		
	    o.viewDir = WorldSpaceViewDir(v.vertex);

	    o.lightDir = normalize(WorldSpaceLightDir( v.vertex ));
	    	
		o.uv_SecondaryRefrTex = TRANSFORM_TEX (v.texcoord, _SecondaryRefractionTex);

		o.uv_ref = ComputeScreenPos(o.pos);
	    
	    return o;
	}
	
	
	inline half CalculateCaustics(float2 uv, half waterAttenuationValue) {
		half4 causticsFrame = tex2D(_CausticsAnimationTexture, frac(uv * _CausticsScale) * causticsOffsetAndScale.zz + causticsOffsetAndScale.xy );

		return (causticsAnimationColorChannel.x * causticsFrame.r
				+ causticsAnimationColorChannel.y * causticsFrame.g
				+ causticsAnimationColorChannel.z * causticsFrame.b) * _CausticsStrength * (1.0 - waterAttenuationValue);
	}
	
	
	inline half CalculateAttenuation(half sinAlpha, fixed3 normViewDir, half4 waterMapValue) {		
		float heightValue = waterMapValue.r;
		return heightValue;
	}
	
	inline fixed3 CalculateNormalInTangentSpace(half2 uv_MainTex, out half2 _displacedUV, fixed3 normViewDir,
												half4 waterMapValue										
												,half2 flowmapValue, half flowLerp, half flowSpeed
												)
	{
		
		float2 normalmapUV = uv_MainTex;
			
		_displacedUV = normalmapUV;
	
		fixed3 normalT0 = UnpackNormal( tex2D(_NormalMap, normalmapUV + flowmapValue * flowMapOffset0 ) );
		fixed3 normalT1 = UnpackNormal( tex2D(_NormalMap, normalmapUV + flowmapValue * flowMapOffset1 ) );
									
		fixed3 pNormal = lerp( normalT0, normalT1, flowLerp );
				
		//Account for speed
		pNormal.z /= max(flowSpeed, .1);	//Account for flow map average velocity
		pNormal.z /= _normalStrength;
		pNormal = normalize(pNormal);	//Very very important to normalize!!!
			
		return pNormal;
		
	}
	
	
	inline fixed4 SampleTextureWithRespectToFlow(sampler2D _tex, float2 _uv, half2 flowmapValue, half flowLerp) 
	{
		fixed4 texT0 = tex2D(_tex, _uv + flowmapValue * flowMapOffset0 );
		fixed4 texT1 = tex2D(_tex, _uv + flowmapValue * flowMapOffset1 );
		return lerp( texT0, texT1, flowLerp );
	}
	
	
	
	inline fixed3 CalculateRefraction(
										float2 uv_Caustics,
										half refrStrength,
										float2 uv_SecondaryRefrTex,
										half waterAttenuationValue,
										fixed3 normViewDir,
										// half sinAlpha,
										float2 _dudvValue)
	{
		//Unpack and scale
		float2 dudvValue = _dudvValue * _Refractivity / 100000.0;
		fixed3 refractionColor;
		//Flat	
		refractionColor = tex2D(_SecondaryRefractionTex, uv_SecondaryRefrTex + dudvValue * _SecondaryRefractionTex_ST.x).rgb * _refractionsWetness;
		refractionColor += CalculateCaustics(uv_Caustics + dudvValue, waterAttenuationValue);
		return refractionColor;
	}
	
	
	inline fixed3 CombineEffectsWithLighting(
								fixed3 refraction, half refrStrength,
								fixed3 reflection,
								fixed3 pNormal,
								fixed3 normViewDir,
								fixed3 normLightDir,
								half2 uv_MainTex, half waterAttenuationValue
								,inout half foamAmount,
								fixed foamValue
								,fixed3 lightDir
								,fixed4 uv_ref
							)
	{
		half nDotView = dot(pNormal, normViewDir);		//Masking
		half nDotLight = dot(pNormal, normLightDir);	//Shadows (diffuse)
		fixed3 anisoDir = normalize( cross(pNormal, lightDir) );
		half lightDotT = dot(normLightDir, anisoDir);
		half viewDotT = dot(normViewDir, anisoDir);
		half spec = sqrt(1.0 - lightDotT * lightDotT) * sqrt(1.0 - viewDotT * viewDotT) - lightDotT * viewDotT;
		spec = pow(spec, _Shininess * 128.0);
		spec *= _Gloss;
		//Masking & self-shadowing
		spec *= max(.0, nDotView) * max(.0, nDotLight);
		//Prevent highlights from leaking to the wrong side of the light
		spec *= max(sign(dot(normViewDir, -normLightDir)), 0.0);
		fixed specularComponent = spec;
	    specularComponent *= _LightColor0.r / 2;

		half fresnel = _Fresnel0 + (1.0 - _Fresnel0) * pow( (1.0 - nDotView ), 5.0);
		fresnel = max(0.0, fresnel - .1);
		specularComponent *= fresnel;
	    specularComponent = specularComponent * specularComponent * 10.0;
	    
	    	    
		fixed3 finalColor;

	    finalColor = lerp(_ShallowWaterTint, _DeepWaterTint, waterAttenuationValue );

		half4 refl_col = tex2Dproj( _ReflectionTex, UNITY_PROJ_COORD(uv_ref) );

		finalColor.rgb = lerp( finalColor.rgb, refl_col.rgb, refl_col.a );
		//!!!!!!!!!!!!!!!!!!!!
		//!Magic! Don't touch!
		//!!!!!!!!!!!!!!!!!!!!
		    	
		refraction = lerp(refraction, _ShallowWaterTint, refrStrength * .5);
		    	
		finalColor = lerp(refraction, finalColor, saturate( max(waterAttenuationValue, refrStrength * .5) * .8 ) );

	    //Add reflection
  
		finalColor = lerp(finalColor, reflection, clamp(fresnel, 0.0, _Reflectivity) );

	    //Foam isn't reflective, it goes on top of everything
	    
	    foamAmount = saturate(foamAmount * foamValue);
		finalColor.rgb = lerp(finalColor, fixed3(foamValue, foamValue, foamValue), foamAmount);

		return (finalColor * _LightColor0.rgb + specularComponent) + UNITY_LIGHTMODEL_AMBIENT.rgb * .5;

	}

	fixed4 frag (v2f i) : COLOR
	{
		fixed4 outColor;
		//"Depth (R), Foam (G), Transparency(B) Refr strength(A)"
		fixed4 waterMapValue = tex2D (_WaterMap, i.uv_WaterMap);
				
		fixed3 normViewDir = normalize(i.viewDir);

	    // [0, 1] -> [-1, 1]
	    half2 flowmapValue = tex2D (_FlowMap, i.uv_WaterMap).rg * 2.0 - 1.0;
		
	    half flowSpeed = length(flowmapValue);
	    	
	    half flowLerp = ( abs( halfCycle - flowMapOffset0 ) / halfCycle );

	    half2 displacedUV;

		fixed3 pNormal = CalculateNormalInTangentSpace(i.uv_MainTex, displacedUV, normViewDir,
													//sinAlpha,
													waterMapValue												
													,flowmapValue, flowLerp, flowSpeed
													);
	    // 影响天空盒reflectCol
	    pNormal = fixed3(-pNormal.x, pNormal.z, -pNormal.y);
		//pNormal = fixed3(pNormal.x, pNormal.z, pNormal.y);

		half waterAttenuationValue = saturate( waterMapValue.r * _WaterAttenuation );
	    
	    //
	    //Sample dudv/foam texture    
		fixed3 dudvFoamValue = SampleTextureWithRespectToFlow(_DUDVFoamMap, i.uv_MainTex, flowmapValue, flowLerp).rgb;				
	    float2 dudvValue = dudvFoamValue.rg;
		dudvValue = dudvValue * 2.0 - float2(1.0, 1.0);
		
		fixed3 refrColor = CalculateRefraction(
												i.uv_MainTex,
												waterMapValue.a,
												i.uv_SecondaryRefrTex,
												waterAttenuationValue,
												normViewDir,
												dudvValue);
	    //
	    //Reflectivity	    
		fixed3 refl = reflect( -normViewDir, pNormal);
	
		fixed3 reflectCol = texCUBE( _Cube , refl ).rgb;

		fixed foamValue = dudvFoamValue.b;
		half foamAmount = waterMapValue.g * _EdgeFoamStrength;
					
		//Have foam in the undefined areas
		foamAmount = max(foamAmount, flowSpeed * foamValue * .5);
		
		outColor.rgb = CombineEffectsWithLighting(
									refrColor, waterMapValue.a,
									reflectCol,
									pNormal,
									normViewDir,
									i.lightDir,
									i.uv_MainTex, 
									waterAttenuationValue
									,foamAmount,
									foamValue		
									,i.lightDir
									,i.uv_ref
									);
		//
		//Alpha

		outColor.a = waterMapValue.b;

		outColor.a *= _Opaqueness;
		
	    return outColor;
	}
#endif