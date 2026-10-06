-- outline.lua
-- Turns the active cel into a white-on-black edge map.
-- A pixel becomes white when any neighbour differs from it by more than
-- the tolerance, measured in a perceptual color space (Oklab / CIELAB).

if app.apiVersion < 41 then
    return app.alert("Requires Aseprite API version 41 or newer")
end

local sprite = app.activeSprite
local cel = app.activeCel
if not sprite or not cel then
    return app.alert("There is no active image")
end

local img = cel.image
if img.colorMode ~= ColorMode.RGB
    and img.colorMode ~= ColorMode.GRAY
    and img.colorMode ~= ColorMode.INDEXED then
    return app.alert("Unsupported color mode")
end

---------------------------------------------------------------------------
-- Color space conversion
---------------------------------------------------------------------------

local function srgbToLinear(c)
    c = c / 255
    if c <= 0.04045 then
        return c / 12.92
    end
    return ((c + 0.055) / 1.055) ^ 2.4
end

local function cbrt(x)
    if x < 0 then return -((-x) ^ (1 / 3)) end
    return x ^ (1 / 3)
end

-- Oklab (Björn Ottosson). L in [0,1], a/b roughly [-0.4,0.4].
local function rgbToOklab(r, g, b)
    r, g, b = srgbToLinear(r), srgbToLinear(g), srgbToLinear(b)

    local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

    l, m, s = cbrt(l), cbrt(m), cbrt(s)

    return
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
end

-- CIELAB, D65 white. L in [0,100], a/b roughly [-128,128].
local function rgbToCielab(r, g, b)
    r, g, b = srgbToLinear(r), srgbToLinear(g), srgbToLinear(b)

    local x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
    local y = (0.2126729 * r + 0.7151522 * g + 0.0721750 * b) / 1.00000
    local z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883

    local function f(t)
        if t > 0.008856 then return cbrt(t) end
        return 7.787 * t + 16 / 116
    end

    local fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)
end

local function rgbToSrgb(r, g, b)
    return r, g, b
end

-- name -> { convert, maxDist } where maxDist is the black<->white distance
-- used to normalise the tolerance slider.
local spaces = {
    ["Oklab"]  = { fn = rgbToOklab,  max = 1.0 },
    ["CIELAB"] = { fn = rgbToCielab, max = 100.0 },
    ["sRGB"]   = { fn = rgbToSrgb,   max = math.sqrt(3 * 255 * 255) },
}

---------------------------------------------------------------------------
-- Pixel decoding
---------------------------------------------------------------------------

local pc = app.pixelColor
local palette = sprite.palettes[1]

-- Returns r, g, b, a for a raw pixel value in the image's color mode.
local function decode(v)
    local mode = img.colorMode
    if mode == ColorMode.RGB then
        return pc.rgbaR(v), pc.rgbaG(v), pc.rgbaB(v), pc.rgbaA(v)
    elseif mode == ColorMode.GRAY then
        local g = pc.grayaV(v)
        return g, g, g, pc.grayaA(v)
    else
        if v == sprite.transparentColor and sprite.spec.colorMode == ColorMode.INDEXED
            and cel.layer.isTransparent then
            return 0, 0, 0, 0
        end
        local c = palette:getColor(v)
        return c.red, c.green, c.blue, c.alpha
    end
end

-- Find palette index closest to given rgb (indexed output only).
local function nearestIndex(r, g, b)
    local best, bestD = 0, math.huge
    for i = 0, #palette - 1 do
        local c = palette:getColor(i)
        local d = (c.red - r) ^ 2 + (c.green - g) ^ 2 + (c.blue - b) ^ 2
        if d < bestD then best, bestD = i, d end
    end
    return best
end

local function encodeOut(white)
    local mode = img.colorMode
    if mode == ColorMode.RGB then
        return white and pc.rgba(255, 255, 255, 255) or pc.rgba(0, 0, 0, 255)
    elseif mode == ColorMode.GRAY then
        return white and pc.graya(255, 255) or pc.graya(0, 255)
    else
        return white and nearestIndex(255, 255, 255) or nearestIndex(0, 0, 0)
    end
end

---------------------------------------------------------------------------
-- Dialog
---------------------------------------------------------------------------

local function userInput()
    local dlg = Dialog("Outline")

    dlg:slider{ id = "tolerance", label = "Tolerance", min = 0, max = 100, value = 10 }
    dlg:combobox{ id = "space", label = "Color space",
        option = "Oklab", options = { "Oklab", "CIELAB", "sRGB" } }
    dlg:combobox{ id = "neighbors", label = "Neighbors",
        option = "4", options = { "4", "8" } }
    dlg:combobox{ id = "thickness", label = "Thickness",
        option = "1px", options = { "1px", "2px" } }
    dlg:check{ id = "alphaEdge", label = "Alpha edges", selected = true }
    dlg:check{ id = "invert", label = "Invert", selected = false }
    dlg:button{ id = "ok", text = "OK" }
    dlg:button{ id = "cancel", text = "Cancel" }
    dlg:show()

    return dlg.data
end

---------------------------------------------------------------------------
-- Outline
---------------------------------------------------------------------------

local function outline(opts)
    local space = spaces[opts.space]
    local threshold = (opts.tolerance / 100) * space.max
    local threshSq = threshold * threshold
    local w, h = img.width, img.height

    -- Cache raw pixel -> {L, a, b, transparent}
    local cache = {}
    local function lab(v)
        local e = cache[v]
        if e then return e end
        local r, g, b, a = decode(v)
        local L, A, B = space.fn(r, g, b)
        e = { L, A, B, a == 0 }
        cache[v] = e
        return e
    end

    -- Read whole image into a flat array once (faster than repeated getPixel)
    local px = {}
    for it in img:pixels() do
        px[it.y * w + it.x + 1] = lab(it())
    end

    local function differs(a, b)
        if a[4] or b[4] then
            if a[4] and b[4] then return false end
            return opts.alphaEdge
        end
        local dl, da, db = a[1] - b[1], a[2] - b[2], a[3] - b[3]
        return dl * dl + da * da + db * db > threshSq
    end

    -- 1px: only compare forward (right/down) so each edge is drawn once.
    -- 2px: compare in all directions so both sides get marked.
    local offsets
    if opts.thickness == "1px" then
        offsets = { { 1, 0 }, { 0, 1 } }
        if opts.neighbors == "8" then
            offsets[#offsets + 1] = { 1, 1 }
            offsets[#offsets + 1] = { -1, 1 }
        end
    else
        offsets = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }
        if opts.neighbors == "8" then
            offsets[#offsets + 1] = { 1, 1 }
            offsets[#offsets + 1] = { -1, 1 }
            offsets[#offsets + 1] = { 1, -1 }
            offsets[#offsets + 1] = { -1, -1 }
        end
    end

    local whitePx = encodeOut(not opts.invert)
    local blackPx = encodeOut(opts.invert)

    local out = Image(img.spec)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local cur = px[y * w + x + 1]
            local edge = false
            for _, o in ipairs(offsets) do
                local nx, ny = x + o[1], y + o[2]
                if nx >= 0 and nx < w and ny >= 0 and ny < h then
                    if differs(cur, px[ny * w + nx + 1]) then
                        edge = true
                        break
                    end
                end
            end
            out:drawPixel(x, y, edge and whitePx or blackPx)
        end
    end

    app.transaction("Outline", function()
        cel.image = out
    end)
    app.refresh()
end

do
    local data = userInput()
    if data.ok then
        outline(data)
    end
end
