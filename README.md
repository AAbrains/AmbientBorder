# Ambient Border

Replaces movie letterbox (top+bottom) and pillarbox (left+right) black bars with ambient blurred light sampled from the picture edge—similar to TV ambilight or YouTube cinema mode.

Available in two versions:

| Version | File | When to use |
|---|---|---|
| **mpv (native)** | `ambient-border.glsl` | Direct in mpv—no ReShade needed. mpv OSD, UI, and subtitles stay fully visible. **Recommended.** |
| ReShade | `AmbientBorder.fx` | Games or any ReShade-compatible video player host. |

Both versions share the same behavior: light is sampled from the **picture edge** (never from the black bars), falloff fades smoothly from picture edge to screen edge, and bars remain symmetric.

---

# 1. mpv Native (Recommended)

## Requirements

- mpv **0.38+** with `vo=gpu-next` (tested: 0.41, d3d11)
- `keepaspect=no` — without this, the shader cannot detect black bars (see "How it works" below)

## Installation

1. Copy `ambient-border.glsl` to your mpv shaders folder:
   ```
   <mpv folder>/portable_config/shaders/ambient-border.glsl
   ```

2. Add these two lines to your `mpv.conf`:
   ```ini
   keepaspect = no
   glsl-shaders-append = ~~/shaders/ambient-border.glsl
   ```
   *(`glsl-shaders-append` ensures your other user shaders like Aurora/Anime4K keep running; this shader runs last in the chain).*

Bar thickness is **auto-detected**—4:3 anime, 2.35:1 movies, ultrawide monitors, all without manual tuning.

## How it works

With `keepaspect=no`, mpv stretches the video across the entire window. The `OUTPUT` hook then covers the **entire window**, allowing the shader to paint the bars. The shader itself:
1. Computes the correct aspect rectangle from `input_size` (video) vs `target_size` (window).
2. Re-fits the picture inside that rectangle to restore correct geometry.
3. Fills the remaining empty areas with ambient light.

*Note: This is not possible with `keepaspect=yes`, as the `OUTPUT` hook only covers the video rectangle, keeping bars out of reach.*

## Tuning

Adjust everything directly from `mpv.conf` without editing any shader files:

```ini
glsl-shader-opts = ab_intensity=1.15,ab_saturation=1.2,ab_v_blur=7
```

Or during live playback (mpv console / `input.conf`):
```
set glsl-shader-opts "ab_intensity=1.15"
```

> `set` replaces the entire option list—omitted parameters revert to their defaults.
> Works only with `vo=gpu-next`.
> 
> `=` is **mandatory** in `mpv.conf`: `glsl-shader-opts = ab_intensity=1.2`. If you write `glsl-shader-opts "ab_intensity=1.2"` (with quotes, missing `=`), mpv silently ignores it with no error.

### Parameters

**Bars**
| Name | Default | Description |
|---|---|---|
| `ab_h_extra` | `0` | Extra thickness for top+bottom bars (% of window height). Only for files with **baked-in** black bars. |
| `ab_v_extra` | `0` | Extra thickness for left+right bars (% of window width). |
| `ab_h_intensity` | `1` | Top+bottom light brightness (`0` = black bars). |
| `ab_v_intensity` | `1` | Left+right light brightness (`0` = black bars). |
| `ab_h_falloff` | `1` | `0` = flat fill, `1` = fade to window edge, `2+` = hugs the picture closely. |
| `ab_v_falloff` | `1` | Same, for left+right. |
| `ab_h_blur` | `5` | Horizontal light spread (% of window width). |
| `ab_v_blur` | `5` | Vertical light spread (% of window height). |
| `ab_h_depth` | `2.5` | Sample depth inside the picture (% of window height). |
| `ab_v_depth` | `2.5` | Same, (% of window width). |

**Global**
| Name | Default | Description |
|---|---|---|
| `ab_intensity` | `1` | Overall light brightness (`0`–`4`). `1` = matches picture edge, `1.2`–`1.4` = punchy, above `1.8` bright content may clip to white. |
| `ab_saturation` | `1.1` | `1` = sampled colors, `>1` = more vivid light. |
| `ab_opacity` | `1` | `1` = fill bars with light, `0` = keep black (quick A/B testing). |
| `ab_dither` | `0.3` | Gradient dithering to eliminate banding. |
| `ab_linear_blur` | `0` | `1` = average light in linear color space. **Recommended `1` for HDR content**. |
| `ab_source_aspect` | `0` | `0` = auto. Force a specific picture aspect ratio if needed (e.g., `1.7778` or `2.35`). |
| `ab_blur_samples` | `12` | Taps along the edge (higher = smoother, slower). |
| `ab_depth_samples` | `4` | Rows inside the picture (higher = smoother, slower). |

### Single-Key Toggle (`input.conf`)

```
Alt+b no-osd cycle-values glsl-shader-opts "ab_opacity=0" "ab_opacity=1"
```
First press turns bars **OFF**, second press turns them **ON**. Instant apply with no playback restart.

> `cycle-values` replaces the entire `glsl-shader-opts` list. If you have custom parameters in `mpv.conf`, repeat them in both values to avoid resetting them:
> ```
> Alt+b no-osd cycle-values glsl-shader-opts "ab_intensity=1.2,ab_opacity=0" "ab_intensity=1.2,ab_opacity=1"
> ```

### Ready-Made Presets (`input.conf`)

```
# Ambient border: off / subtle / normal / strong
Alt+1 no-osd set glsl-shader-opts "ab_opacity=0"
Alt+3 no-osd set glsl-shader-opts "ab_intensity=1.0"
Alt+4 no-osd set glsl-shader-opts "ab_intensity=1.5,ab_saturation=1.25"
```

### Baked-in Bars & Universal Cropper Script

If a video file is natively 16:9 but contains permanent black bars baked into the video frame (common in certain movies and 4K webseries), auto-detection cannot find the active picture area. 

To solve this universally, a Lua script (`crop_toggle.lua`) is included that cycles through popular aspect ratios in ascending order (smallest bars to biggest bars / OFF) using a single shortcut key (`Alt+2`):

1. **Script installation:** Copy `crop_toggle.lua` to `~~/scripts/crop_toggle.lua`
2. **`input.conf` binding:**
   ```
   Alt+2 script-binding crop_toggle/cycle-aspect-crops; show-text "Ambient Crop Toggle"
   ```

**Cycle Order (Optimized for 4K 3840x2160):**
- OFF (16:9 Full)
- 1.85:1 (Flat Widescreen)
- 2.00:1 (Universal / Netflix)
- 2.20:1 (70mm Scope)
- 2.35:1 (CinemaScope)
- 2.39:1 / 2.40:1 (Ultrawide)
- 2.55:1 (Cinemascope wide)
- 2.76:1 (Ultra Panavision)

## mpv Notes / Tradeoffs

- **Subtitles, OSD, and menus stay fully visible**—unlike the ReShade version. OSD renders **after** user shaders.
- `keepaspect=no` places subtitles at the absolute bottom of the window (inside the bottom letterbox bar). If difficult to read, adjust `sub-pos=86` (or lower `ab_opacity`).
- `keepaspect=no` is **global**—if you ever remove the shader, comment out that line too, otherwise videos will look stretched.
- The picture is resampled once (mpv stretches → shader squeezes back). 16:9 video in a 16:9 window remains **1:1 untouched**; slight softness occurs only when letterbox bars are active.
- Bars are always symmetric (top = bottom, left = right).
- Screenshots (`s`) capture the ambient bars because they are part of the rendered frame.

---

# 2. ReShade Version

## Installation

1. Copy the folder to your ReShade Shaders directory:
   `.../reshade-shaders/Shaders/AmbientBorder/AmbientBorder.fx`
2. In-game, press `Home` → check **Ambient Border** in the effect list.
3. Move the effect to the **very bottom** of the render list.

*(Note: The ReShade version hides mpv's OSD/UI, which is why the native mpv GLSL version is recommended for media players).*

## Setup

1. Enable only the required group—**Horizontal** for movies, **Vertical** for 4:3 anime.
2. Set **Thickness (%)** according to your aspect ratio.
3. Increase **Blur (%)** until the light looks smooth (5–8% is a good start).
4. Set **Sample Depth (%)** (how deep to read into the picture, 2–4% is ideal).
5. Choose **Falloff**: `0` = flat, `1` = fade, `2+` = hugs picture.
6. Adjust **Intensity** for brightness.

### Sliders

| Slider | Description |
|---|---|
| Intensity (global) | Overall ambient light brightness (0–4). |
| Saturation | `1` = as-is, `>1` = more vivid. |
| Replace Strength | `1` = bars fully replaced, `0` = original untouched. |
| Blur Space | `Gamma` = softer, `Linear` = physically correct. |
| Dither | Eliminates color banding. |
| Enable | Toggle light group on/off. |
| Thickness (%) | Bar size. Both bars share this value. |
| Intensity | Group brightness. |
| Falloff | `0` flat, `1` fade, `2+` concentrated. |
| Blur (%) | Light spread. |
| Sample Depth (%) | Depth inside picture to sample. |

## ReShade Notes

- Corners blend smoothly between horizontal and vertical groups—no hard seams.
- Sampling always stays **inside the picture**, never sampling from the black bars themselves.
