# AmbientBorder v1.2

Native mpv GLSL shader port of the ReShade AmbientBorder effect + dynamic aspect ratio cropper script.

## What's New in v1.2
- **Two-Pass Dense Profile Architecture**: Replaced the sparse single-pass tap grid with a dense 4096×1 edge-colour profile (rendered via Pass 1 and sampled with linear filtering in Pass 2).
- **Zero Blocky Stripes**: Eliminates vertical/horizontal aliasing bands completely on busy or textured scenes.
- **Dynamic Resolution-Independent Cropper (`crop_toggle.lua`)**: Rewritten to automatically adapt to any window size and resolution without hardcoded scaling bugs.
- **Scene-Matching & Natural Blending**: Refined default blur and falloff behaviour so ambient light smoothly matches and blends with video scenes.

## Included Files
- `ambient-border.glsl`: Two-pass native mpv shader (requires `vo=gpu-next`).
- `crop_toggle.lua`: Aspect ratio cycle toggle script for baked-in black bars.
- `README.md` & `README(Hin).md`: Full documentation in English and Hindi.
- `AmbientBorder.fx`: Original ReShade shader (legacy).
