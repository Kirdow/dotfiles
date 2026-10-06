-- Flags
local DEBUG = true

-- Variables

local GEN_VERSION = "0.0.1"

-- Debug

local function var_dump(value, depth)
    depth = depth or 4

    local function dump(v, d, indent)
        if type(v) ~= "table" then
            if type(v) == "string" then
                return string.format("%q", v)
            end
            return tostring(v)
        end

        if d <= 0 then
            return "{...}"
        end

        local parts = {}
        local pad = string.rep("  ", indent + 1)
        for k, val in pairs(v) do
            local key
            if type(k) == "string" then
                key = k
            else
                key = "[" .. tostring(k) .. "]"
            end
            parts[#parts + 1] = pad .. key .. " = " .. dump(val, d - 1, indent + 1)
        end

        if #parts == 0 then
            return "{}"
        end

        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. string.rep("  ", indent) .. "}"
    end

    return dump(value, depth, 0)
end

function log(...)
    if DEBUG then
        print(...)
    end
end

-- Main Code

if app.apiVersion < 41 then
    return app.alert("Unsupported API Version")
end

local try = function(fn)
    local success, err = pcall(fn)
    if not success then
        log("Catch:", err)
        return false
    end

    return true
end
local function clamp01(x)
    if x < 0.0 then return 0.0 end
    if x > 1.0 then return 1.0 end
    return x
end
local function clampC(c)
    if c < 0.0 then return 0.0 end
    if c > 0.5 then return 0.5 end   -- Oklab chroma rarely exceeds ~0.4 in sRGB gamut
    return c
end

-- Colours are shaped in Oklab / OkLCh (Bjorn Ottosson) rather than HSV, so equal
-- lightness (L) steps look equally spaced to the eye and hue stays stable while
-- lightening. HSV "value" is not perceptual: yellow at v=1 reads far brighter
-- than blue at v=1, and value ramps clamp/band near the extremes -- which is what
-- collapsed steps 4 and 5 of a bright base together.
local function cbrt(x)
    if x < 0.0 then return -((-x) ^ (1.0 / 3.0)) end
    return x ^ (1.0 / 3.0)
end
local function srgb_to_linear(c)
    if c <= 0.04045 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
end
local function linear_to_srgb(c)
    if c <= 0.0031308 then return 12.92 * c end
    return 1.055 * (c ^ (1.0 / 2.4)) - 0.055
end
local function rgb_to_oklab(r, g, b)
    r = srgb_to_linear(r); g = srgb_to_linear(g); b = srgb_to_linear(b)
    local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l = cbrt(l); m = cbrt(m); s = cbrt(s)
    return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
           1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
           0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
end
local function oklab_to_rgb(L, A, B)
    local l = L + 0.3963377774 * A + 0.2158037573 * B
    local m = L - 0.1055613458 * A - 0.0638541728 * B
    local s = L - 0.0894841775 * A - 1.2914855480 * B
    l = l * l * l; m = m * m * m; s = s * s * s
    local r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    local g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    local b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return clamp01(linear_to_srgb(clamp01(r))),
           clamp01(linear_to_srgb(clamp01(g))),
           clamp01(linear_to_srgb(clamp01(b)))
end
local function oklab_to_lch(L, A, B)
    local C = math.sqrt(A * A + B * B)
    local h = math.deg(math.atan(B, A))
    if h < 0.0 then h = h + 360.0 end
    return L, C, h
end
local function lch_to_oklab(L, C, h)
    local r = math.rad(h)
    return L, C * math.cos(r), C * math.sin(r)
end
-- Rotate `h0` toward `target` by at most `amtDeg`, along the shortest path.
local function hueShift(h0, target, amtDeg)
    local d = ((target - h0 + 540.0) % 360.0) - 180.0
    local amt = math.min(amtDeg, math.abs(d))
    if d < 0.0 then amt = -amt end
    return (h0 + amt) % 360.0
end

-- Oklab hue poles (deg) that the modes shift toward. Oklab hue angles differ from
-- HSV: warm sits low, blue high. These are the anchor directions, not the output.
local H_AMBER  = 50.0    -- warm sunlight / sodium & window light
local H_YELLOW = 105.0   -- sunlit leaf (yellow-green)
local H_GREEN  = 150.0   -- mid foliage green
local H_TEAL   = 200.0   -- cool leaf shadow (blue-green)
local H_ICE    = 240.0   -- cold blue-white
local H_BLUE   = 255.0   -- moonlit / ambient shadow blue
local H_VIOLET = 285.0   -- deep indigo shadow

-- Shading modes keyed to real subjects. Each returns shaped hue + chroma for a
-- step at position t (-1 darkest .. 0 base .. +1 brightest), range r (0..1).
-- `contrast` widens the lightness window; `bias` shifts the whole ramp darker (-)
-- or brighter (+) in perceptual L. Hue shifts stay subtle per the pixel-art
-- convention (warm highlights / cool shadows), tuned per subject from the sources.
local GRADIENT_MODES = { "Foliage", "Vegetation", "Rocks", "Winter", "Nighttime", "Cityscape", "Metal", "Glow", "Flat" }
local MODES = {
    -- Trees / leaves, often backlit: yellow-green sunlit highlights, blue-green
    -- shadows, colours stay vivid. Medium-high contrast.
    Foliage = { contrast = 1.15, bias = 0.0, shape = function(t, r, C0, h0)
        local target = (t >= 0.0) and H_YELLOW or H_TEAL
        local h = hueShift(h0, target, math.abs(t) * r * 35.0)
        return h, clampC(C0 * (1.0 - t * r * 0.15))   -- shadows slightly richer
    end },
    -- Grass / groundcover / bushes: like foliage but flatter and softer, less
    -- backlight drama, shadows lean plain green rather than teal.
    Vegetation = { contrast = 1.0, bias = 0.0, shape = function(t, r, C0, h0)
        local target = (t >= 0.0) and H_YELLOW or H_GREEN
        local h = hueShift(h0, target, math.abs(t) * r * 25.0)
        return h, clampC(C0 * (1.0 - t * r * 0.2))
    end },
    -- Stone / cliffs / boulders: earthy and desaturated, strong value contrast,
    -- warm-amber sunlit face vs cool-blue shade. Chroma fades toward the light.
    Rocks = { contrast = 1.25, bias = 0.0, shape = function(t, r, C0, h0)
        local target = (t >= 0.0) and H_AMBER or H_BLUE
        local h = hueShift(h0, target, math.abs(t) * r * 18.0)
        return h, clampC(C0 * (1.0 - 0.35 * r) * (1.0 - 0.3 * math.max(t, 0.0)))
    end },
    -- Snow / ice: cold throughout. Highlights bloom to blue-white, shadows take a
    -- blue-violet tint. Kept fairly bright.
    Winter = { contrast = 1.1, bias = 0.03, shape = function(t, r, C0, h0)
        local target = (t >= 0.0) and H_ICE or H_VIOLET
        local h = hueShift(h0, target, math.abs(t) * r * 30.0)
        local C
        if t > 0.0 then C = clampC(C0 * (1.0 - t * r * 0.8))       -- highlights toward white
        else C = clampC(C0 * (1.0 - t * r * 0.15) + 0.02 * r) end  -- cold shadow tint
        return h, C
    end },
    -- Moonlit night: overall darker (bias), blue-dominant, deep indigo shadows.
    Nighttime = { contrast = 1.0, bias = -0.08, shape = function(t, r, C0, h0)
        local target = (t >= 0.0) and H_BLUE or H_VIOLET
        local h = hueShift(h0, target, math.abs(t) * r * 30.0)
        return h, clampC(C0 * (1.0 - t * r * 0.1))
    end },
    -- Urban night/dusk: cool desaturated ambient shadows with warm artificial-light
    -- highlights (windows / sodium / neon) that pop in chroma. Split lighting.
    Cityscape = { contrast = 1.2, bias = -0.03, shape = function(t, r, C0, h0)
        local target = (t >= 0.0) and H_AMBER or H_BLUE
        local h = hueShift(h0, target, math.abs(t) * r * 38.0)
        local C
        if t > 0.0 then C = clampC(C0 * (1.0 + t * r * 0.25))  -- warm highlight pops
        else C = clampC(C0 * (1.0 - 0.25 * r)) end             -- cool shadows desaturate
        return h, C
    end },
    -- Metallic: high lightness contrast, desaturated, chroma fades to both ends.
    Metal = { contrast = 1.35, bias = 0.0, shape = function(t, r, C0, h0)
        local target = (t >= 0.0) and H_AMBER or H_BLUE
        local h = hueShift(h0, target, math.abs(t) * r * 20.0)
        return h, clampC(C0 * (1.0 - 0.5 * r) * (1.0 - 0.5 * math.abs(t)))
    end },
    -- Emissive: highlights bloom toward warm white, shadows keep their colour.
    Glow = { contrast = 1.15, bias = 0.0, shape = function(t, r, C0, h0)
        if t > 0.0 then
            return hueShift(h0, H_AMBER, t * r * 35.0), clampC(C0 * (1.0 - t * r))
        end
        return h0, C0
    end },
    -- Pure tint/shade: lightness ramp only, no hue or chroma drift.
    Flat = { contrast = 1.0, bias = 0.0, shape = function(t, r, C0, h0)
        return h0, C0
    end },
}

local function calculateGradient(mode, useHue, useSaturation, useVibrance, baseColor, range, steps)
    local colors = {}
    local r = range / 100.0
    local m = MODES[mode] or MODES.Foliage

    local L0, A0, B0 = rgb_to_oklab(baseColor.red / 255.0, baseColor.green / 255.0, baseColor.blue / 255.0)
    local _, C0, h0 = oklab_to_lch(L0, A0, B0)
    local a255 = baseColor.alpha

    -- Perceptual lightness window around the base (shifted by the mode's bias),
    -- widened by mode contrast and moved to fit [Lmin, Lmax] so the requested number
    -- of steps stays distinct even when the base sits near black or white
    -- (fixes collapsed top/bottom steps).
    local center = L0 + (m.bias or 0.0)
    local half = r * 0.45 * m.contrast
    local Lmin, Lmax = 0.02, 0.98
    local loL, hiL = center - half, center + half
    if hiL > Lmax then loL = loL - (hiL - Lmax); hiL = Lmax end
    if loL < Lmin then hiL = hiL + (Lmin - loL); loL = Lmin end
    if hiL > Lmax then hiL = Lmax end
    if loL < Lmin then loL = Lmin end

    for i = 1, steps do
        local u = 0.5
        if steps > 1 then u = (i - 1) / (steps - 1) end   -- 0 dark .. 1 bright
        local t = u * 2.0 - 1.0

        local L = loL + (hiL - loL) * u
        local h, C = m.shape(t, r, C0, h0)

        -- Per-channel toggles: revert whichever Oklab axis the user disabled.
        if not useVibrance then L = L0 end    -- Vibrance drives the lightness ramp
        if not useSaturation then C = C0 end  -- Saturation drives chroma
        if not useHue then h = h0 end         -- Hue drives the hue shift

        local rr, gg, bb = oklab_to_rgb(lch_to_oklab(L, C, h))
        colors[i] = Color{
            r = math.floor(rr * 255.0 + 0.5),
            g = math.floor(gg * 255.0 + 0.5),
            b = math.floor(bb * 255.0 + 0.5),
            a = a255,
        }
    end

    return colors
end

function show()
    local dlg = Dialog("Palette Gradient Generator v" .. GEN_VERSION)

    local function reload()
        local d = dlg.data
        local result = calculateGradient(d.mode, d.hue, d.saturation, d.vibrance, d.base, d.range, d.steps)
        if result and type(result) == "table" then
            dlg:modify{ id="shades", colors=result }

            app.refresh()
        end
    end

    dlg:color{ id="base", label="Base Color", color=app.fgColor, onchange=function()reload()end}
    dlg:slider{ id="range", label="Range", min=0, max=100, value=50, onchange=function()reload()end}
    dlg:slider{ id="steps", label="Steps", min=1, max=21, value=5, onchange=function()reload()end}

    dlg:separator{ id="shifts", label="Shifts" }

    dlg:combobox{ id="mode", label="Mode", option=GRADIENT_MODES[1], options=GRADIENT_MODES, onchange=function()reload()end}

    dlg:check{ id="hue", text="Hue", selected=true, onclick=function()reload()end}
    dlg:check{ id="saturation", text="Saturation", selected=true, onclick=function()reload()end}
    dlg:check{ id="vibrance", text="Vibrance", selected=true, onclick=function()reload()end}

    dlg:separator{ label="Preview (dark to bright)"}

    dlg:shades{ id="shades", mode="pick", colors={}, onclick=function(a, b, c)
        log("shades")
        try(function()
            log("a", var_dump(a))
            log("b", b)
            log("c", c)
        end)
    end}

    dlg:separator{}
    local _path = nil
    local setPath = function(path)
        _path = path
        if _path ~= nil then
            dlg:modify{ id="result", text="Will save as " .. path }
        end
    end

    dlg:file{ id="target", title="Save To", filename="gradient.gpl", filetypes=".gpl", save=true, onchange=function(a, b, c)
        log("target")
        try(function()
            log("a", a)
            log("b", b)
            log("c", c)
        end)
    end}

    dlg:check{ id="presets", label="Add to palette presets", selected=true }
    label = dlg:label{ id="result", text="" }
    
    dlg:button{ id="save", text="Save Palette", onclick=function(a, b, c)
        log("save")
        try(function()
            log("a", a)
            log("b", b)
            log("c", c)
        end)
    end}

    dlg:button{ id="cancel", text="Close", onclick=function()
        local confirm = Dialog("Are you sure?")

        confirm:button{ id="ok", text="Yes"}
        confirm:button{ id="cancel", text="No"}
        confirm:show()

        if confirm.data.ok then
            dlg:close()
        end
    end}

    reload()

    dlg:show()

    return dlg.data
end

do
    show()
end