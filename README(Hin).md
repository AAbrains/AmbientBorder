# Ambient Border

Movies / anime ke **letterbox (top+bottom)** aur **pillarbox (left+right)** black bars ko picture ke edge se nikli hui **ambient blurred light** se replace karta hai — TV ambilight / YouTube cinema mode jaisa look.

Do versions hain:

| Version | File | Kab use karo |
|---|---|---|
| **mpv (native)** | `ambient-border.glsl` | mpv me direct — ReShade ki zaroorat nahi, mpv ka OSD/UI/subtitles dikhte rehte hain. **Recommended.** |
| ReShade | `AmbientBorder.fx` | Games / kisi bhi ReShade host ke liye. |

Dono ka behaviour same hai: picture ke **edge se** light sample hoti hai (bars se nahi), falloff picture edge se screen edge tak fade hota hai, aur bars symmetric rehte hain.

---

# 1. mpv native (recommended)

## Kya chahiye

- mpv **0.38+** with `vo=gpu-next` (tested: 0.41, d3d11)
- `keepaspect=no` — iske bina shader ko black bars dikhte hi nahi (neeche "Why" dekho)

## Install

1. `ambient-border.glsl` ko mpv ke shaders folder me copy karo:

   ```
   <mpv folder>/portable_config/shaders/ambient-border.glsl
   ```

2. `mpv.conf` me ye do lines add karo:

   ```ini
   keepaspect = no
   glsl-shaders-append = ~~/shaders/ambient-border.glsl
   ```

   `glsl-shaders-append` isliye ki tumhare baaki user shaders (Aurora/Anime4K/etc.) chalte rahein — ye shader list me sabse last me chalta hai, jo sahi jagah hai.

Bas. Bar ki thickness **khud detect** hoti hai — 4:3 anime, 2.35:1 movie, 21:9 monitor, sab bina tuning.

## Ye kaam kaise karta hai

`keepaspect=no` se mpv video ko poore window me stretch kar deta hai. Tab `OUTPUT` hook **poore window** ko cover karta hai, isliye shader bars paint kar sakta hai. Shader khud:

1. `input_size` (video) vs `target_size` (window) se sahi aspect ka rectangle nikaalta hai,
2. us rectangle me picture ko wapas squeeze karke sahi aspect me dikhata hai,
3. bache hue area ko ambient light se bharta hai.

`keepaspect=yes` ke saath ye possible nahi — tab `OUTPUT` hook sirf video rectangle ko cover karta hai aur bars shader ki pahunch se bahar rehte hain.

## Tuning

Sab kuch `mpv.conf` se, file edit kiye bina:

```ini
glsl-shader-opts = ab_intensity=1.15,ab_saturation=1.2,ab_v_blur=7
```

Ya chalti hui playback me (mpv console/input.conf):

```
set glsl-shader-opts "ab_intensity=1.15"
```

> `set` poora list replace karta hai — jo values nahi likhi, woh default pe chali jaati hain.
> Sirf `vo=gpu-next` me kaam karta hai.
>
> `mpv.conf` me `=` **zaroori** hai: `glsl-shader-opts = ab_intensity=1.2`. Agar
> `glsl-shader-opts "ab_intensity=1.2"` likhoge (quotes ke saath, `=` ke bina) to mpv
> usse chup-chaap ignore kar deta hai — koi error nahi, bas value apply nahi hoti.

### Parameters

**Bars**
| Name | Default | Kaam |
|---|---|---|
| `ab_h_extra` | `0` | Top+bottom bars me **extra** thickness, window height ke %. Sirf un files ke liye jinme black bars **picture ke andar baked** hain. |
| `ab_v_extra` | `0` | Left+right bars me extra thickness, window width ke %. |
| `ab_h_intensity` | `1` | Top+bottom light ki brightness (`0` = bars kaale). |
| `ab_v_intensity` | `1` | Left+right light ki brightness (`0` = bars kaale). |
| `ab_h_falloff` | `1` | `0` = flat fill, `1` = picture edge se window edge tak fade, `2+` = light picture ke paas hi rehti hai. |
| `ab_v_falloff` | `1` | Wahi, left+right ke liye. |
| `ab_h_blur` | `5` | Light ka horizontal spread, window width ke %. |
| `ab_v_blur` | `5` | Light ka vertical spread, window height ke %. |
| `ab_h_depth` | `2.5` | Picture ke andar kitna deep sample karna, window height ke %. |
| `ab_v_depth` | `2.5` | Wahi, window width ke %. |

**Global**
| Name | Default | Kaam |
|---|---|---|
| `ab_intensity` | `1` | Poori light ki brightness (`0`–`4`). `1` = picture edge se match, `1.2`–`1.4` = thoda punchy, `1.8` se upar bright/saturated picture ki light white me clip hone lagti hai. |
| `ab_saturation` | `1.1` | `1` = as sampled, `>1` = zyada vivid. |
| `ab_opacity` | `1` | `1` = bars light se bhare, `0` = black bars (quick A/B ke liye). |
| `ab_dither` | `0.3` | Gradient me banding chhupata hai. |
| `ab_linear_blur` | `0` | `1` = light ko linear light me average karo. **HDR content ke liye `1`** rakho. |
| `ab_source_aspect` | `0` | `0` = auto. Anamorphic/odd sources ke liye force karo, jaise `1.7778` ya `2.35`. |
| `ab_blur_samples` | `12` | Edge ke along taps (zyada = smooth, slow). |
| `ab_depth_samples` | `4` | Picture ke andar rows (zyada = smooth, slow). |

### Single-key toggle (`input.conf`)

```
Alt+b no-osd cycle-values glsl-shader-opts "ab_opacity=0" "ab_opacity=1"
```

Pehla press = bars **OFF**, dobara press = **ON**. Playback restart nahi hota, turant lagta hai.

> `cycle-values` poora `glsl-shader-opts` list replace karta hai. Agar `mpv.conf` me apne params
> set kiye hain to dono entries me repeat karo, warna woh default pe chale jayenge:
> ```
> Alt+b no-osd cycle-values glsl-shader-opts "ab_intensity=1.2,ab_opacity=0" "ab_intensity=1.2,ab_opacity=1"
> ```
> `no-osd` hata do to mpv har press pe `glsl-shader-opts: ab_opacity=0` message dikhayega.

### Ready-made presets (`input.conf`)

```
# Ambient border: off / subtle / normal / strong
Alt+1 no-osd set glsl-shader-opts "ab_opacity=0"
Alt+2 no-osd set glsl-shader-opts "ab_intensity=0.6,ab_saturation=1.0"
Alt+3 no-osd set glsl-shader-opts "ab_intensity=1.0"
Alt+4 no-osd set glsl-shader-opts "ab_intensity=1.5,ab_saturation=1.25"
```

### Baked-in bars & Universal Cropper Script

Agar file khud 16:9 hai lekin uske andar black bars baked hain (jaise kuch movies ya 4K webseries), toh shader ko asli picture pata lagane ke liye crop karna padta hai.

Iske liye ek **universal Lua script** (`crop_toggle.lua`) banaya gaya hai jo ek hi shortcut key (`Alt+2`) se sabhi popular aspect ratios ko ascending order me (chhote bars se bade bars / OFF) cycle karta hai:

1. **Script install location:** `~~/scripts/crop_toggle.lua` (ya project folder me `crop_toggle.lua`)
2. **`input.conf` binding:**
   ```
   Alt+2 script-binding crop_toggle/cycle-aspect-crops; show-text "Ambient Crop Toggle"
   ```

**Cycle order (4K 3840x2160 optimized):**
- OFF (16:9 Full)
- 1.85:1 (Flat Widescreen)
- 2.00:1 (Universal / Netflix)
- 2.20:1 (70mm Scope / GTA 6 etc.)
- 2.35:1 (CinemaScope)
- 2.39:1 / 2.40:1 (Ultrawide)
- 2.55:1 (Cinemascope wide)
- 2.76:1 (Ultra Panavision)

## mpv notes / tradeoffs

- **Subtitles / OSD / menu sab dikhte hain** — ye ReShade wale version ka main problem tha, native me nahi hota. OSD shader ke **baad** draw hota hai.
- `keepaspect=no` se subtitles window ke bottom pe aate hain, matlab letterbox movie me bottom bar ke andar. Padhne me dikkat ho to `sub-pos=86` kar do (ya `ab_opacity` thoda kam).
- `keepaspect=no` **global** hai — agar kabhi shader hatao to woh line bhi comment kar dena, warna video stretched dikhega.
- Picture ek baar resample hoti hai (mpv stretch karta hai → shader wapas squeeze karta hai). 16:9 video 16:9 window me **1:1 untouched** rehti hai; sirf bars wale cases me halka sa softness aata hai.
- Bars hamesha symmetric hote hain (top = bottom, left = right).
- Screenshots (`s`) me bars bhi aa jaate hain, kyunki woh render ka hissa hain.

---

# 2. ReShade version

## Install

1. Ye folder ReShade ke `Shaders` folder me copy karo:
   `.../reshade-shaders/Shaders/AmbientBorder/AmbientBorder.fx`
2. Game me `Home` dabao → shader list me **Ambient Border** tick karo.
3. Effect ko list me **sabse neeche** rakho.

> ReShade version me mpv ka OSD/UI hide ho jata hai — isliye mpv ke liye native version better hai.

## Setup (2 minute)

1. Sirf wahi group on karo jo chahiye — movie ke liye **Horizontal**, 4:3 anime ke liye **Vertical**.
2. **Thickness (%)** set karo (upar wali table).
3. **Blur (%)** badhao jab tak light smooth na lage (5–8% achha start hai).
4. **Sample Depth (%)** = picture ke andar kitna dekhna hai. 2–4% accha hai.
5. **Falloff**: `0` = flat, `1` = fade, `2+` = picture ke paas.
6. **Intensity** se brightness.

### Sliders

| Slider | Kaam |
|---|---|
| Intensity (global) | Poori ambient light ki brightness (0–4). |
| Saturation | `1` = as-is, `>1` = zyada vivid. |
| Replace Strength | `1` = bars fully replaced, `0` = original untouched. |
| Blur Space | `Gamma` = softer, `Linear` = physically correct. |
| Dither | Banding chhupata hai. |
| Enable | Us group ka light on/off. |
| Thickness (%) | Bar ki size. Dono bars same value use karte hain. |
| Intensity | Us group ki brightness. |
| Falloff | `0` flat, `1` fade, `2+` concentrated. |
| Blur (%) | Light ka spread. |
| Sample Depth (%) | Picture ke andar kitna deep sample. |

## Notes

- Corners pe dono groups ka light smoothly mix hota hai — koi hard seam nahi.
- Sampling hamesha **picture ke andar** rehti hai, kabhi black bars se light nahi uthati.

---

# Developer notes

**ReShade:** pixel shader ka pehla parameter `float4 vpos : SV_Position` **hataana mat**. Uske bina ReShade `TEXCOORD` input galat bind karta hai aur poori screen kaali ho jaati hai (compile phir bhi pass ho jata hai, log me error nahi aata).

**mpv:** `keepaspect=yes` ke saath `OUTPUT` hook sirf video rectangle cover karta hai, isliye bars paint nahi ho sakte — `keepaspect=no` zaroori hai.

**mpv:** hooked texture me **stretched** video hoti hai, isliye ambient band ke samples ko bhi fit-rect mapping se guzaarna padta hai (`(p - fitMin) / fitSize`), warna light galat jagah se aati hai.

**mpv:** `//!PARAM` blocks ke beech me `//` comment lines mat daalo — parser value line ko comment ke saath parse karta hai aur poora shader load fail ho jata hai (error: "Failed parsing variable data").
