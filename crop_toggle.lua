-- Universal Aspect Ratio & Baked Bar Cropper for mpv (Dynamic & Resolution-Independent)
-- Cycles through common movie/webseries aspect ratios.
-- Works universally across any video resolution (YouTube, 1080p, 1440p, 4K, etc.)
-- using dynamic mathematical cropping based on active video dimensions.

local crops = {
    { name = "OFF (16:9 Full)",          aspect = 0 },
    { name = "1.85:1 (Flat Widescreen)", aspect = 1.85 },
    { name = "2.00:1 (Univ. / Netflix)", aspect = 2.00 },
    { name = "2.20:1 (70mm Scope)",      aspect = 2.20 },
    { name = "2.35:1 (CinemaScope)",     aspect = 2.35 },
    { name = "2.39:1 / 2.40:1 (Ultrawide)", aspect = 2.40 },
    { name = "2.55:1 (Cinemascope)",     aspect = 2.55 },
    { name = "2.76:1 (Ultra Panavision)",aspect = 2.76 },
}

local current_index = 1

mp.add_key_binding("Alt+2", "cycle-aspect-crops", function()
    current_index = current_index + 1
    if current_index > #crops then
        current_index = 1
    end
    
    local item = crops[current_index]
    
    if item.aspect == 0 then
        mp.commandv("set", "vf", "")
        mp.osd_message("Ambient Crop: " .. item.name, 2)
    else
        -- Get current video width and height using mpv properties
        local w = mp.get_property_number("width")
        local h = mp.get_property_number("height")
        
        if not w or not h then
            mp.osd_message("Ambient Crop: No video loaded", 2)
            return
        end
        
        -- Calculate crop height based on target aspect ratio
        -- target_h = w / aspect
        local target_h = math.floor(w / item.aspect + 0.5)
        
        -- Ensure target height doesn't exceed source height
        if target_h > h then
            target_h = h
        end
        
        -- Calculate vertical offset (y) to center the crop
        local y = math.floor((h - target_h) / 2 + 0.5)
        
        -- Build dynamic crop string: crop=w:h:x:y
        local vf_string = string.format("crop=%d:%d:0:%d", w, target_h, y)
        
        mp.commandv("set", "vf", vf_string)
        mp.osd_message(string.format("Ambient Crop: %s (%dx%d offset %d)", item.name, w, target_h, y), 2)
    end
end)
