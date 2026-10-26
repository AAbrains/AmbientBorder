-- Universal Aspect Ratio & Baked Bar Cropper for mpv
-- Cycles through common movie/webseries aspect ratios (ascending: smallest bars to biggest bars)
-- Designed for 4K (3840x2160) sources. Scales automatically or applies exact pixel crops.

local crops = {
    { name = "OFF (16:9 Full)",          vf = "" },
    { name = "1.85:1 (Flat Widescreen)", vf = "crop=3840:2076:0:52" },
    { name = "2.00:1 (Univ. / Netflix)", vf = "crop=3840:1920:0:120" },
    { name = "2.20:1 (70mm Scope)",      vf = "crop=3840:1740:0:210" },
    { name = "2.35:1 (CinemaScope)",     vf = "crop=3840:1634:0:273" },
    { name = "2.39:1 / 2.40:1 (Ultrawide)", vf = "crop=3840:1606:0:287" },
    { name = "2.55:1 (Cinemascope)",     vf = "crop=3840:1506:0:337" },
    { name = "2.76:1 (Ultra Panavision)",vf = "crop=3840:1392:0:384" },
}

local current_index = 1

mp.add_key_binding("Alt+2", "cycle-aspect-crops", function()
    current_index = current_index + 1
    if current_index > #crops then
        current_index = 1
    end
    
    local item = crops[current_index]
    mp.commandv("set", "vf", item.vf)
    mp.osd_message("Ambient Crop: " .. item.name, 2)
end)
