-- Flags
local DEBUG = false

-- Debug

function log(p)
    if DEBUG then
        print(p)
    end
end

-- Main Code

function ptoc(p)
    return p * 255
end


local DARKEN_TOP = 1.1
local DARKEN_NORMAL = 0.84
local DARKEN_EDGE = 0.9
local DARKEN_BOTTOM = 0.8

log("API Version: " .. app.apiVersion)
if app.apiVersion < 41 then
    return app.alert("Unsupported app Version")
end

local cel = app.activeCel
if not cel then
    return app.alert("There is no active image")
end

function userInput()
    local dlg = Dialog("Tex Void Creator")
    
    dlg:check{id="solid", text="Solid Alpha", selected=false}
    dlg:check{id="alpha", text="Include Alpha", selected=true}
    dlg:button{id="ok", text="OK"}
    dlg:button{id="cancel", text="Cancel"}
    dlg:show()

    return dlg.data
end

function createVoid(solidAlpha, includeAlpha)
    local pc = app.pixelColor
    local img = cel.image:clone()

    function nextVoid()
        if img.colorMode == ColorMode.RGB then
            return pc.rgba(0, 0, 0, (solidAlpha and {255} or {0})[1])
        elseif img.colorMode == ColorMode.GRAY then
            return pc.graya(0, (solidAlpha and {255} or {0})[1])
        end
    end

    function clampC(c)
        if c < 0 then return 0 end
        if c > 255 then return 255 end
        return c
    end

    function nextColor(c, num)
        num = ptoc(num)
        local den = 255
        if img.colorMode == ColorMode.RGB then
            local red = pc.rgbaR(c)
            local green = pc.rgbaG(c)
            local blue = pc.rgbaB(c)
            
            local rRed = clampC(math.floor(red * num / den))
            local rGreen = clampC(math.floor(green * num / den))
            local rBlue = clampC(math.floor(blue * num / den))

            return pc.rgba(rRed, rGreen, rBlue, (includeAlpha and {pc.rgbaA(c)} or {255})[1])
        elseif img.colorMode == ColorMode.GRAY then
            local red = pc.rgbaR(c)

            local rRed = clampC(math.floor(red * num / den))

            return pc.graya(rRed, (includeAlpha and {pc.rgbaG(c)} or {255})[1])
        end
    end

    function nextBottom(c)
        return nextColor(c, DARKEN_BOTTOM)
    end

    function nextTop(c)
        return nextColor(c, DARKEN_TOP)
    end

    function nextEdge(c, isTop, isBottom)
        if isBottom then c = nextBottom(c) end
        c = nextColor(c, DARKEN_EDGE)
        if isTop then c = nextTop(c) end

        return c
    end

    function nextNormal(c)
        return nextColor(c, DARKEN_NORMAL)
    end

    if img.colorMode ~= ColorMode.RGB and img.colorMode ~= ColorMode.GRAY then
        return app.alert("Unsupported color mode")
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

    log("Bounds: (x" .. bounds.x .. " y" .. bounds.y .. " w" .. bounds.w .. " h" .. bounds.h .. ")")
    log("Image (x" .. img.bounds.x .. " y" .. img.bounds.y .. " w" .. img.bounds.width .. " h" .. img.bounds.height .. ")")

    local pos = function(it)
        return {
            x = it.x - bounds.x,
            y = it.y - bounds.y
        }
    end

    local w = bounds.w
    local h = math.floor(bounds.h / 4)

    log("(w" .. w .. " h" .. h .. ")")

    local lastY = -1
    for it in img:pixels(bounds) do
        local p = pos(it)
        if p.y ~= lastY then
            lastY = p.y
            log("Y: " .. p.y)
        end
        if p.y == 0 then
            log("X: " .. p.x)
        end
        local c = it()
        if p.y > h then
            it(nextVoid())
        elseif p.x == 0 or p.x == w - 1 then
            local isTop = (p.y == 0)
            local isBottom = (p.y == h)
            it(nextEdge(c, isTop, isBottom))
        elseif p.y == h then
            it(nextBottom(c))
        elseif p.y == 0 then
            it(nextTop(c))
        else
            it(nextNormal(c))
        end
    end

    cel.image = img

    app.refresh()
end

do
    local dialogResult = userInput()
    if dialogResult.ok then
        createVoid(dialogResult.solid, dialogResult.alpha)
    end
end