if app.apiVersion < 1 then
    return app.alert("Unsupported app Version")
end

local cel = app.activeCel
if not cel then
    return app.alert("There is no active image")
end

function userInput()
    local dlg = Dialog("Tex Noise")
    
    dlg:color{id="fg", label="Foreground", color=app.fgColor}
    dlg:color{id="bg", label="Background", color=app.fgColor}
    dlg:check{id="alpha", label="Include Alpha", selected=false}
    dlg:button{id="ok", text="OK"}
    dlg:button{id="cancel", text="Cancel"}
    dlg:show()

    return dlg.data
end

function createNoise(fgCol, bgCol, includeAlpha)
    local pc = app.pixelColor
    local img = cel.image:clone()
    function nextColor(gauss)
        if img.colorMode == ColorMode.RGB then
            local aRed = pc.rgbaR(bgCol)
            local aGreen = pc.rgbaG(bgCol)
            local aBlue = pc.rgbaB(bgCol)

            local bRed = pc.rgbaR(fgCol)
            local bGreen = pc.rgbaG(fgCol)
            local bBlue = pc.rgbaB(fgCol)

            local zRed = gauss * bRed + (1.0 - gauss) * aRed 
            local zGreen = gauss * bGreen + (1.0 - gauss) * aGreen 
            local zBlue = gauss * bBlue + (1.0 - gauss) * aBlue 

            return pc.rgba(zRed, zGreen, zBlue, (includeAlpha and {pc.rgbaA(bgCol)} or {255})[1])
        elseif img.colorMode == ColorMode.GRAY then
            local aRed = pc.rgbaR(bgCol)
            local bRed = pc.rgbaR(fgCol)
            local zRed = gauss * bRed + (1.0 - gauss) * aRed

            return pc.graya(zRed, (includeAlpha and {pc.rgbaG(bgCol)} or {255})[1])
        end
    end

    if img.colorMode ~= ColorMode.RGB and img.colorMode ~= ColorMode.GRAY then
        return app.alert("Unsupported color mode")
    end

    math.randomseed(os.time())


    for it in img:pixels() do
        it(nextColor(math.random()))

    end

    cel.image = img

    app.refresh()
end

do
    local newNoise = userInput()
    if newNoise.ok then
        createNoise(newNoise.fg.rgbaPixel, newNoise.bg.rgbaPixel, newNoise.alpha)
    end
end
