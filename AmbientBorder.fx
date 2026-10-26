#include "ReShade.fxh"

//=============================================================================
//  Ambient Border
//  Replaces letterbox / pillarbox black bars with ambient light sampled from
//  the edges of the picture (TV "ambilight" / cinema-mode look).
//
//  Requires ReShade 5.x or newer.
//  No depth buffer access needed - very cheap.
//=============================================================================

//-----------------------------------------------------------------------------
// Global
//-----------------------------------------------------------------------------

uniform float GlobalIntensity <
    ui_category = "Global";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 4.0; ui_step = 0.01;
    ui_label = "Intensity";
    ui_tooltip = "Master brightness of the ambient light.";
> = 1.0;

uniform float Saturation <
    ui_category = "Global";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 3.0; ui_step = 0.01;
    ui_label = "Saturation";
    ui_tooltip = "1.0 = keep the sampled colors, above 1.0 = more vivid light.";
> = 1.1;

uniform float ReplaceStrength <
    ui_category = "Global";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
    ui_label = "Replace Strength";
    ui_tooltip = "0 = original picture untouched, 1 = bars fully replaced by light.";
> = 1.0;

uniform int BlurSpace <
    ui_category = "Global";
    ui_type = "combo";
    ui_items = "Gamma Space (softer)\0Linear Space (physically correct)\0";
    ui_label = "Blur Space";
    ui_tooltip = "Use Linear Space unless the game already renders in linear/HDR.";
> = 0;

uniform float Dither <
    ui_category = "Global";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0; ui_step = 0.01;
    ui_label = "Dither";
    ui_tooltip = "Hides banding in the light gradient. 0 = off.";
> = 0.3;

//-----------------------------------------------------------------------------
// Horizontal bars: top + bottom (letterbox, for movies)
//-----------------------------------------------------------------------------

uniform bool HorizontalEnabled <
    ui_category = "Horizontal Bars (Top + Bottom)";
    ui_label = "Enable";
    ui_tooltip = "Fill the top and bottom letterbox bars with ambient light.";
> = true;

uniform float HorizontalThickness <
    ui_category = "Horizontal Bars (Top + Bottom)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 50.0; ui_step = 0.05;
    ui_label = "Thickness (%)";
    ui_tooltip = "Height of each bar, in percent of the screen height. Both bars use the same value.";
> = 12.0;

uniform float HorizontalIntensity <
    ui_category = "Horizontal Bars (Top + Bottom)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 3.0; ui_step = 0.01;
    ui_label = "Intensity";
> = 1.0;

uniform float HorizontalFalloff <
    ui_category = "Horizontal Bars (Top + Bottom)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 4.0; ui_step = 0.01;
    ui_label = "Falloff";
    ui_tooltip = "0 = flat fill, 1 = linear fade, higher = light hugs the picture edge.";
> = 1.0;

uniform float HorizontalBlur <
    ui_category = "Horizontal Bars (Top + Bottom)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 30.0; ui_step = 0.1;
    ui_label = "Blur (%)";
    ui_tooltip = "Horizontal spread of the sampled light, in percent of the screen width.";
> = 5.0;

uniform float HorizontalDepth <
    ui_category = "Horizontal Bars (Top + Bottom)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 20.0; ui_step = 0.05;
    ui_label = "Sample Depth (%)";
    ui_tooltip = "How far into the picture the light is read from, in percent of the screen height.";
> = 2.5;

//-----------------------------------------------------------------------------
// Vertical bars: left + right (pillarbox, for 4:3 content)
//-----------------------------------------------------------------------------

uniform bool VerticalEnabled <
    ui_category = "Vertical Bars (Left + Right)";
    ui_label = "Enable";
    ui_tooltip = "Fill the left and right pillarbox bars with ambient light.";
> = false;

uniform float VerticalThickness <
    ui_category = "Vertical Bars (Left + Right)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 50.0; ui_step = 0.05;
    ui_label = "Thickness (%)";
    ui_tooltip = "Width of each bar, in percent of the screen width. Both bars use the same value.";
> = 12.5;

uniform float VerticalIntensity <
    ui_category = "Vertical Bars (Left + Right)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 3.0; ui_step = 0.01;
    ui_label = "Intensity";
> = 1.0;

uniform float VerticalFalloff <
    ui_category = "Vertical Bars (Left + Right)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 4.0; ui_step = 0.01;
    ui_label = "Falloff";
    ui_tooltip = "0 = flat fill, 1 = linear fade, higher = light hugs the picture edge.";
> = 1.0;

uniform float VerticalBlur <
    ui_category = "Vertical Bars (Left + Right)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 30.0; ui_step = 0.1;
    ui_label = "Blur (%)";
    ui_tooltip = "Vertical spread of the sampled light, in percent of the screen height.";
> = 5.0;

uniform float VerticalDepth <
    ui_category = "Vertical Bars (Left + Right)";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 20.0; ui_step = 0.05;
    ui_label = "Sample Depth (%)";
    ui_tooltip = "How far into the picture the light is read from, in percent of the screen width.";
> = 2.5;

//-----------------------------------------------------------------------------
// Helpers
//-----------------------------------------------------------------------------

static const float3 LUMA = float3(0.2126, 0.7152, 0.0722);

float3 ToLinear(float3 c)
{
    return pow(max(c, 0.0), 2.2);
}

float3 ToGamma(float3 c)
{
    return pow(max(c, 0.0), 1.0 / 2.2);
}

// 0 at the picture edge, 1 at the screen edge.
float EdgeFalloff(float distPx, float barPx, float power)
{
    float t = saturate(distPx / max(barPx, 1.0));
    return pow(saturate(1.0 - t), max(power, 0.0));
}

// Averages a blurred band lying just inside the picture edge.
//   edgePix  : edge point, sharing the blur-axis coordinate of the current pixel
//   blurMask : axis the band is smeared along  ((1,0) horizontal, (0,1) vertical)
//   depthMask: axis the band reaches into the picture
//   dir      : +1 / -1, direction into the picture along depthMask
float3 SampleBand(float2 edgePix, float2 blurMask, float2 depthMask, float dir,
                  float blurPx, float depthPx,
                  float2 frameMin, float2 frameMax, float2 invRes)
{
    float3 sum = 0.0;
    for (int j = 0; j < 4; j++)
    {
        float2 dpos = edgePix + depthMask * (dir * (j + 0.5) / 4.0 * depthPx);
        for (int i = 0; i < 12; i++)
        {
            float b = ((i + 0.5) / 12.0 - 0.5) * 2.0 * blurPx;
            float2 p = clamp(dpos + blurMask * b, frameMin, frameMax);
            float3 c = tex2Dlod(ReShade::BackBuffer, float4(p * invRes, 0.0, 0.0)).rgb;
            sum += (BlurSpace == 1) ? ToLinear(c) : c;
        }
    }

    sum /= 48.0;
    return (BlurSpace == 1) ? ToGamma(sum) : sum;
}

float InterleavedGradientNoise(float2 p)
{
    return frac(52.9829189 * frac(dot(p, float2(0.06711056, 0.00583715))));
}

//-----------------------------------------------------------------------------
// Pixel shader
//-----------------------------------------------------------------------------

// vpos must stay: ReShade mis-binds TEXCOORD when SV_Position is missing.
float3 PS_AmbientBorder(float4 vpos : SV_Position, float2 uv : TEXCOORD) : SV_Target
{
    float3 src = tex2Dlod(ReShade::BackBuffer, float4(uv, 0.0, 0.0)).rgb;

    float2 res    = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
    float2 invRes = BUFFER_PIXEL_SIZE;
    float2 pix    = uv * res;

    float hBarPx = HorizontalEnabled ? max(HorizontalThickness, 0.0) * 0.01 * res.y : 0.0;
    float vBarPx = VerticalEnabled   ? max(VerticalThickness,   0.0) * 0.01 * res.x : 0.0;

    bool inTop    = pix.y <  hBarPx;
    bool inBottom = pix.y >= res.y - hBarPx;
    bool inLeft   = pix.x <  vBarPx;
    bool inRight  = pix.x >= res.x - vBarPx;

    if (!inTop && !inBottom && !inLeft && !inRight)
        return src;

    // Bars never feed back into the light: sampling stays inside the picture.
    float2 frameMin = float2(vBarPx, hBarPx);
    float2 frameMax = max(float2(res.x - vBarPx, res.y - hBarPx), frameMin + 1.0);

    float3 colorSum = 0.0;
    float  wSum     = 0.0;
    float  bright   = 0.0;

    if (inTop)
    {
        float  w = EdgeFalloff(hBarPx - pix.y, hBarPx, HorizontalFalloff) * HorizontalIntensity;
        colorSum += SampleBand(float2(pix.x, hBarPx), float2(1.0, 0.0), float2(0.0, 1.0), 1.0,
                               HorizontalBlur * 0.01 * res.x, HorizontalDepth * 0.01 * res.y,
                               frameMin, frameMax, invRes) * w;
        wSum   += w;
        bright  = max(bright, w);
    }

    if (inBottom)
    {
        float  w = EdgeFalloff(pix.y - (res.y - hBarPx), hBarPx, HorizontalFalloff) * HorizontalIntensity;
        colorSum += SampleBand(float2(pix.x, res.y - hBarPx), float2(1.0, 0.0), float2(0.0, 1.0), -1.0,
                               HorizontalBlur * 0.01 * res.x, HorizontalDepth * 0.01 * res.y,
                               frameMin, frameMax, invRes) * w;
        wSum   += w;
        bright  = max(bright, w);
    }

    if (inLeft)
    {
        float  w = EdgeFalloff(vBarPx - pix.x, vBarPx, VerticalFalloff) * VerticalIntensity;
        colorSum += SampleBand(float2(vBarPx, pix.y), float2(0.0, 1.0), float2(1.0, 0.0), 1.0,
                               VerticalBlur * 0.01 * res.y, VerticalDepth * 0.01 * res.x,
                               frameMin, frameMax, invRes) * w;
        wSum   += w;
        bright  = max(bright, w);
    }

    if (inRight)
    {
        float  w = EdgeFalloff(pix.x - (res.x - vBarPx), vBarPx, VerticalFalloff) * VerticalIntensity;
        colorSum += SampleBand(float2(res.x - vBarPx, pix.y), float2(0.0, 1.0), float2(1.0, 0.0), -1.0,
                               VerticalBlur * 0.01 * res.y, VerticalDepth * 0.01 * res.x,
                               frameMin, frameMax, invRes) * w;
        wSum   += w;
        bright  = max(bright, w);
    }

    if (wSum < 1e-5)
        return src;

    // wSum carries the intensity, bright the falloff envelope, so the light
    // fades out towards the screen edge instead of filling the bar flat.
    float3 ambient = colorSum / wSum * bright;

    float lum = dot(ambient, LUMA);
    ambient = lerp(float3(lum, lum, lum), ambient, Saturation);
    ambient *= GlobalIntensity;
    ambient += (InterleavedGradientNoise(pix) - 0.5) * Dither * 0.02;

    return lerp(src, max(ambient, 0.0), ReplaceStrength);
}

//-----------------------------------------------------------------------------
// Technique
//-----------------------------------------------------------------------------

technique AmbientBorder <
    ui_label = "Ambient Border";
    ui_tooltip = "Replaces letterbox / pillarbox bars with ambient light taken from the picture edge.";
>
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader  = PS_AmbientBorder;
    }
}
