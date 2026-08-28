-- Flags
local DEBUG = false

-- Debug

function log(p)
    if DEBUG then
        print(p)
    end
end

-- Main Code

if app.apiVersion < 41 then
    return app.alert("Unsupported API Version")
end

local cel = app.activeCel
if not cel then
    return app.alert("These is no active image")
end

if cel.image.colorMode == ColorMode.GRAY then
    return app.alert("Grayscale is not supported at this very moment.")
end

function userInput()
    local dlg = Dialog("Reshade")

    dlg:color{id="src", label="Source", color=app.fgColor}
    dlg:color{id="dst", label="Destination", color=app.bgColor}
    dlg:check{id="alpha", label="Include Alpha", selected=false}
    dlg:button{id="ok", text="OK"}
    dlg:button{id="cancel", text="Cancel"}
    dlg:show()

    return dlg.data
end

function pc_to_hsv(pc, c)
    local r = pc.rgbaR(c) / 255
    local g = pc.rgbaG(c) / 255
    local b = pc.rgbaB(c) / 255

    local mx = math.max(r, g, b)
    local mn = math.min(r, g, b)
    local d = mx - mn
    
    local v = mx
    local s = (mx <= 0.0) and 0.0 or d / mx
    if d <= 0.0 then return { h = 0.0, s = s, v = v } end

    local h
    if mx == r then h = ((g - b) / d) % 6.0
    elseif mx == g then h = (b - r) / d + 2.0
    else h = (r - g) / d + 4.0
    end

    h = h * 60
    if h < 0.0 then h = h + 360.0 end
    return { h = h, s = s, v = v }
end

function clampc(c)
    c = math.floor(c + 0.5)
    return c < 0 and 0 or c > 255 and 255 or c
end

function clampf(f)
    return f < 0.0 and 0.0 or f > 1.0 and 1.0 or f
end

function hsv_to_pc(pc, hsv)
    local h = hsv.h % 360.1
    if h < 0.0 then h = h + 360.0 end

    local s, v = clampf(hsv.s), clampf(hsv.v)

    local cc = v * s
    local x = cc * (1.0 - math.abs((h / 60.0) % 2.0 - 1.0))
    local m = v - cc

    local r, g, b
    if h < 60 then r, g, b = cc, x, 0
    elseif h < 120 then r, g, b = x, cc, 0
    elseif h < 180 then r, g, b = 0, cc, x
    elseif h < 240 then r, g, b = 0, x, cc
    elseif h < 300 then r, g, b = x, 0, cc
    else r, g, b = cc, 0, x
    end

    return pc.rgba(clampc((r + m) * 255), clampc((g + m) * 255), clampc((b + m) * 255), 255)
end

function create_shift(pc, src, dst)
    local hsrc = pc_to_hsv(pc, src)
    local hdst = pc_to_hsv(pc, dst)

    return {
        dh = hdst.h - hsrc.h,
        ss = (hsrc.s <= 1e-6) and 1.0 or hdst.s / hsrc.s,
        vs = (hsrc.v <= 1e-6) and 1.0 or hdst.v / hsrc.v
    }
end

function apply_shift(pc, sh, c)
    local hsv = pc_to_hsv(pc, c)

    hsv.h = (hsv.h + sh.dh + 360.0) % 360.0
    hsv.s = clampf(hsv.s * sh.ss)
    hsv.v = clampf(hsv.v * sh.vs)

    return hsv_to_pc(pc, hsv)
end

function operate(srcCol, dstCol, includeAlpha)
    local pc = app.pixelColor
    local img = cel.image:clone()

    local shift = create_shift(pc, srcCol, dstCol)

    function convert(c)
        local r = apply_shift(pc, shift, c)
        if includeAlpha then
            local cr = pc.rgbaR(r)
            local cg = pc.rgbaG(r)
            local cb = pc.rgbaB(r)

            local srca = pc.rgbaA(srcCol)
            local dsta = pc.rgbaA(dstCol)

            local ca = clampc(pc.rgbaA(c) * dsta / srca)

            r = pc.rgba(cr, cg, cb, ca)
        end

        log("input: " .. colText(c))
        log("output: " .. colText(r))

        return r
    end

    if DEBUG then
        log(convert(pc.rgba(0, 255, 0, 255)))
        return
    end

    function recEquals(a, b)
        if b == nil and a == nil then return true end
        if b == nil or a == nil then return false end
        return a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h
    end

    local bounds = app.sprite.selection.bounds
    if recEquals(app.sprite.bounds, app.sprite.selection.bounds) or bounds == nil then
        bounds = app.sprite.bounds
    end

    for it in img:pixels(bounds) do
        it(convert(it()))
    end

    cel.image = img

    app.refresh()
end

do
    local result = userInput()
    if result.ok then
        operate(result.src.rgbaPixel, result.dst.rgbaPixel, result.alpha)
    end
end