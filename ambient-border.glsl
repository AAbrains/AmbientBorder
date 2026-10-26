//=============================================================================
//  AmbientBorder - native mpv port of the ReShade AmbientBorder shader
//
//  Replaces letterbox / pillarbox black bars with ambient light sampled from
//  the edges of the picture (TV ambilight / cinema-mode look).
//
//  mpv config:
//      keepaspect=no
//      glsl-shaders-append=~~/shaders/ambient-border.glsl
//
//  Why keepaspect=no: with keepaspect=yes the OUTPUT hook only covers the
//  video rectangle, so the black bars live outside the shader's reach. With
//  keepaspect=no the hook covers the whole window, and this shader restores
//  the correct aspect ratio itself, then fills the leftover area with light.
//
//  Bar thickness is detected automatically from the video aspect ratio, so
//  4:3 anime and 2.35:1 movies both work with zero tuning.
//
//  Tuning (no file editing needed):
//      mpv.conf:   glsl-shader-opts=ab_intensity=1.2,ab_v_blur=8
//      runtime:    set glsl-shader-opts "ab_intensity=1.2"
//
//  NOTE: do not put comments between the parameter blocks below, the parser
//  expects a single value line right after each block's directives.
//=============================================================================

//!PARAM ab_h_extra
//!DESC Top + bottom bars: extra thickness, % of window height (for baked-in bars)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 30.0
0.0
//!PARAM ab_v_extra
//!DESC Left + right bars: extra thickness, % of window width (for baked-in bars)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 30.0
0.0
//!PARAM ab_h_intensity
//!DESC Top + bottom bars: light brightness (0 turns them black)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 3.0
1.0
//!PARAM ab_v_intensity
//!DESC Left + right bars: light brightness (0 turns them black)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 3.0
1.0
//!PARAM ab_intensity
//!DESC Global light brightness
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 4.0
1.0
//!PARAM ab_saturation
//!DESC 1 = colors as sampled, above 1 = more vivid light
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 3.0
1.1
//!PARAM ab_h_falloff
//!DESC Top + bottom bars: 0 flat fill, 1 fade, 2+ hugs the picture
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 4.0
1.0
//!PARAM ab_v_falloff
//!DESC Left + right bars: 0 flat fill, 1 fade, 2+ hugs the picture
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 4.0
1.0
//!PARAM ab_h_blur
//!DESC Top + bottom bars: light spread, % of window width
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 30.0
5.0
//!PARAM ab_v_blur
//!DESC Left + right bars: light spread, % of window height
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 30.0
5.0
//!PARAM ab_h_depth
//!DESC Top + bottom bars: read depth into the picture, % of window height
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 20.0
2.5
//!PARAM ab_v_depth
//!DESC Left + right bars: read depth into the picture, % of window width
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 20.0
2.5
//!PARAM ab_opacity
//!DESC 1 = fill the bars with light, 0 = keep them black
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
1.0
//!PARAM ab_dither
//!DESC Gradient dithering, hides banding
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.3
//!PARAM ab_linear_blur
//!DESC 1 = average the light in linear light, 0 = as stored
//!TYPE DEFINE
//!MINIMUM 0
//!MAXIMUM 1
0
//!PARAM ab_source_aspect
//!DESC 0 = auto, else forced picture aspect ratio (e.g. 2.35)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 4.0
0.0
//!PARAM ab_blur_samples
//!DESC Taps along the picture edge, higher = smoother but slower
//!TYPE DEFINE
//!MINIMUM 4
//!MAXIMUM 24
12
//!PARAM ab_depth_samples
//!DESC Rows read into the picture, higher = smoother but slower
//!TYPE DEFINE
//!MINIMUM 1
//!MAXIMUM 8
4

//!HOOK OUTPUT
//!BIND HOOKED
//!DESC AmbientBorder (ambient light in the letterbox / pillarbox bars)

const vec3 AB_LUMA = vec3(0.2126, 0.7152, 0.0722);

// 0 at the picture edge, 1 at the window edge.
float abFalloff(float distPx, float barPx, float power)
{
    float t = clamp(distPx / max(barPx, 1.0), 0.0, 1.0);
    return pow(max(1.0 - t, 0.0), max(power, 0.0));
}

vec3 abSample(vec2 uv)
{
#if ab_linear_blur
    return linearize(HOOKED_tex(uv)).rgb;
#else
    return HOOKED_tex(uv).rgb;
#endif
}

// Averages a blurred band lying just inside the picture edge.
//   edgePix  : edge point, sharing the blur-axis coordinate of this pixel
//   blurAxis : axis the band is smeared along  ((1,0) horizontal, (0,1) vertical)
//   depthAxis: axis the band reaches into the picture
//   dir      : +1 / -1, direction into the picture along depthAxis
//   fitMin/invFit: map window pixels -> picture uv. The hooked texture holds
//                  the stretched video, so every sample has to go through it.
vec3 abBand(vec2 edgePix, vec2 blurAxis, vec2 depthAxis, float dir,
            float blurPx, float depthPx, vec2 lo, vec2 hi,
            vec2 fitMin, vec2 invFit)
{
    vec3 sum = vec3(0.0);

    for (int j = 0; j < ab_depth_samples; ++j)
    {
        float d = (float(j) + 0.5) / float(ab_depth_samples) * depthPx;
        vec2 base = edgePix + depthAxis * (dir * d);

        for (int i = 0; i < ab_blur_samples; ++i)
        {
            float b = ((float(i) + 0.5) / float(ab_blur_samples) - 0.5) * 2.0 * blurPx;
            vec2 p = clamp(base + blurAxis * b, lo, hi);
            sum += abSample(clamp((p - fitMin) * invFit, 0.0, 1.0));
        }
    }

    sum /= float(ab_depth_samples * ab_blur_samples);

#if ab_linear_blur
    sum = delinearize(vec4(sum, 1.0)).rgb;
#endif
    return sum;
}

float abNoise(vec2 p)
{
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

vec4 hook()
{
    vec2 res = target_size;
    vec2 pix = gl_FragCoord.xy;          // y = 0 at the top

    // --- picture rectangle: contain fit of the source into the window ------
    float srcAR = ab_source_aspect > 0.0
                ? ab_source_aspect
                : (input_size.x > 1.0 && input_size.y > 1.0
                   ? input_size.x / input_size.y
                   : res.x / res.y);
    float dstAR = res.x / res.y;

    vec2 fitSize = (srcAR > dstAR) ? vec2(res.x, res.x / srcAR)
                                   : vec2(res.y * srcAR, res.y);
    fitSize = clamp(floor(fitSize + 0.5), vec2(2.0), res);
    vec2 fitMin = floor((res - fitSize) * 0.5 + 0.5);

    // Auto bar size, plus the optional manual extra for baked-in bars.
    float hBar = clamp(fitMin.y + ab_h_extra * 0.01 * res.y, 0.0, res.y * 0.5 - 1.0);
    float vBar = clamp(fitMin.x + ab_v_extra * 0.01 * res.x, 0.0, res.x * 0.5 - 1.0);

    // mpv stretched the video to the whole window; squeeze it back.
    if (pix.x >= fitMin.x && pix.x < fitMin.x + fitSize.x &&
        pix.y >= fitMin.y && pix.y < fitMin.y + fitSize.y)
    {
        return vec4(HOOKED_tex((pix - fitMin) / fitSize).rgb, 1.0);
    }

    bool inTop    = pix.y <  hBar;
    bool inBottom = pix.y >= res.y - hBar;
    bool inLeft   = pix.x <  vBar;
    bool inRight  = pix.x >= res.x - vBar;

    if (!inTop && !inBottom && !inLeft && !inRight)
        return vec4(0.0, 0.0, 0.0, 1.0);

    // Bars never feed back into the light: sampling stays inside the picture.
    vec2 lo = vec2(vBar, hBar) + 0.5;
    vec2 hi = max(res - vec2(vBar, hBar) - 0.5, lo + 1.0);

    vec2 invFit    = 1.0 / fitSize;

    float hBlurPx  = ab_h_blur  * 0.01 * res.x;
    float hDepthPx = ab_h_depth * 0.01 * res.y;
    float vBlurPx  = ab_v_blur  * 0.01 * res.y;
    float vDepthPx = ab_v_depth * 0.01 * res.x;

    vec3  colorSum = vec3(0.0);
    float wSum     = 0.0;
    float bright   = 0.0;

    if (inTop)
    {
        float w = abFalloff(hBar - pix.y, hBar, ab_h_falloff) * ab_h_intensity;
        colorSum += abBand(vec2(pix.x, hBar), vec2(1.0, 0.0), vec2(0.0, 1.0),  1.0,
                           hBlurPx, hDepthPx, lo, hi, fitMin, invFit) * w;
        wSum   += w;
        bright  = max(bright, w);
    }

    if (inBottom)
    {
        float w = abFalloff(pix.y - (res.y - hBar), hBar, ab_h_falloff) * ab_h_intensity;
        colorSum += abBand(vec2(pix.x, res.y - hBar), vec2(1.0, 0.0), vec2(0.0, 1.0), -1.0,
                           hBlurPx, hDepthPx, lo, hi, fitMin, invFit) * w;
        wSum   += w;
        bright  = max(bright, w);
    }

    if (inLeft)
    {
        float w = abFalloff(vBar - pix.x, vBar, ab_v_falloff) * ab_v_intensity;
        colorSum += abBand(vec2(vBar, pix.y), vec2(0.0, 1.0), vec2(1.0, 0.0),  1.0,
                           vBlurPx, vDepthPx, lo, hi, fitMin, invFit) * w;
        wSum   += w;
        bright  = max(bright, w);
    }

    if (inRight)
    {
        float w = abFalloff(pix.x - (res.x - vBar), vBar, ab_v_falloff) * ab_v_intensity;
        colorSum += abBand(vec2(res.x - vBar, pix.y), vec2(0.0, 1.0), vec2(1.0, 0.0), -1.0,
                           vBlurPx, vDepthPx, lo, hi, fitMin, invFit) * w;
        wSum   += w;
        bright  = max(bright, w);
    }

    if (wSum < 1e-5)
        return vec4(0.0, 0.0, 0.0, 1.0);

    // wSum carries the intensity, bright the falloff envelope, so the light
    // fades towards the window edge instead of filling the bar flat.
    vec3 ambient = colorSum / wSum * bright;

    float lum = dot(ambient, AB_LUMA);
    ambient = mix(vec3(lum), ambient, ab_saturation);
    ambient *= ab_intensity * ab_opacity;
    ambient += (abNoise(pix) - 0.5) * ab_dither * 0.02;

    return vec4(max(ambient, 0.0), 1.0);
}
