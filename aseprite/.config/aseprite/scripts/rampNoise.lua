if app.apiVersion < 1 then
    return app.alert("Unsupported app Version")
end

local cel = app.activeCel
if not cel then
    return app.alert("There is no active image")
end

function selectedColors()
    local pal = app.activeSprite.palettes[1]
    local idxs = app.range.colors
    local cols = {}
    for _, idx in ipairs(idxs) do
        table.insert(cols, {index=idx, color=pal:getColor(idx)})
    end
    return cols
end

-- default weight (1-100) for a range at normalized position t (0=bottom, 1=top).
-- peaks around 65%, stays high toward the top, drops to near-nothing at the bottom.
function defaultWeight(t)
    local peak = 0.65
    local sLeft = 0.22  -- steep falloff below the peak (low areas get very little)
    local sRight = 0.35 -- gentle falloff above the peak (top stays fairly high)
    local gamma = 2.5   -- >1 makes the low end drop off much more steeply (fewer dark spots)
    local d = t - peak
    local s = (d < 0) and sLeft or sRight
    local g = math.exp(-(d * d) / (2 * s * s))
    g = g ^ gamma
    local w = math.floor(g * 100 + 0.5)
    if w < 1 then w = 1 end
    if w > 100 then w = 100 end
    return w
end

function userInput(cols)
    local dlg = Dialog("Ramp Noise")

    -- one weight per range (gap) between consecutive colors
    local numRanges = #cols - 1
    for i = 1, numRanges do
        local t = (i - 0.5) / numRanges
        dlg:color{id="a" .. i, color=cols[i].color}
        dlg:color{id="b" .. i, color=cols[i + 1].color}
        dlg:number{id="w" .. i, text=tostring(defaultWeight(t)), decimals=2}
        dlg:newrow()
    end
    dlg:check{id="alpha", label="Include Alpha", selected=false}
    dlg:button{id="ok", text="OK"}
    dlg:button{id="cancel", text="Cancel"}
    dlg:show()

    return dlg.data
end

function createNoise(cols, weights, includeAlpha)
    local pc = app.pixelColor
    local img = cel.image:clone()

    if img.colorMode ~= ColorMode.RGB and img.colorMode ~= ColorMode.GRAY then
        return app.alert("Unsupported color mode")
    end

    -- build cumulative weight table over the N-1 ranges, dropping non-positive weights
    local total = 0.0
    local ranges = {}
    for i = 1, #cols - 1 do
        local w = weights[i]
        if w and w > 0 then
            total = total + w
            table.insert(ranges, {a=cols[i].color, b=cols[i + 1].color, cum=total})
        end
    end

    if #ranges == 0 then
        return app.alert("No range has a positive weight")
    end

    function pickRange()
        local r = math.random() * total
        local chosen = ranges[#ranges]
        for _, e in ipairs(ranges) do
            if r <= e.cum then
                chosen = e
                break
            end
        end
        return chosen
    end

    function nextColor()
        local e = pickRange()
        local aCol = e.a
        local bCol = e.b
        local gauss = math.random()

        if img.colorMode == ColorMode.RGB then
            local zRed = gauss * bCol.red + (1.0 - gauss) * aCol.red
            local zGreen = gauss * bCol.green + (1.0 - gauss) * aCol.green
            local zBlue = gauss * bCol.blue + (1.0 - gauss) * aCol.blue
            local zAlpha = gauss * bCol.alpha + (1.0 - gauss) * aCol.alpha

            return pc.rgba(zRed, zGreen, zBlue, (includeAlpha and {zAlpha} or {255})[1])
        elseif img.colorMode == ColorMode.GRAY then
            local zGray = gauss * bCol.gray + (1.0 - gauss) * aCol.gray
            local zAlpha = gauss * bCol.alpha + (1.0 - gauss) * aCol.alpha

            return pc.graya(zGray, (includeAlpha and {zAlpha} or {255})[1])
        end
    end

    math.randomseed(os.time())

    for it in img:pixels() do
        it(nextColor())
    end

    cel.image = img

    app.refresh()
end

do
    local cols = selectedColors()
    if #cols < 2 then
        return app.alert("Select two or more colors in the palette")
    end

    local newNoise = userInput(cols)
    if newNoise.ok then
        local weights = {}
        for i = 1, #cols - 1 do
            weights[i] = newNoise["w" .. i]
        end
        createNoise(cols, weights, newNoise.alpha)
    end
end
