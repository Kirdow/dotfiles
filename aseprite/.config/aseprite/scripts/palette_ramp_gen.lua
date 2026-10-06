-- Palette-Ramp-Generator.lua
--
-- Aseprite palette ramp generator.
--
-- Builds a shading ramp from a single base color. Every swatch is placed in
-- Oklab, a color space whose lightness matches what the eye actually sees, so
-- the steps of a ramp look evenly spaced instead of merely measuring evenly.
-- A Style preset decides how hue and colorfulness travel along the ramp.
--
-- Install: copy into Aseprite's script folder
--   (File > Scripts > Open Scripts Folder), then File > Scripts > Rescan.

----------------------------------------------------------------------
-- Tuning
----------------------------------------------------------------------

-- How far a ramp may travel at 100% range, as Oklab lightness. Kept inside
-- 0..1 so the extremes stop short of pure black and pure white and keep hue.
local LIGHT_FLOOR = 0.10
local LIGHT_CEIL = 0.97

-- Chroma is pulled back to this fraction of the sRGB limit, so no swatch pins
-- a channel at 0 or 255 and reads as a clipped, electric edge case.
local GAMUT_MARGIN = 0.96

-- A near-gray base has no chroma to rotate, so the ambient tint is injected
-- instead. This is what lets a stone ramp take a cool shadow rather than
-- staying dead gray all the way down.
local CHROMA_FLOOR = 0.042
local HIGHLIGHT_TINT = 0.60

-- Below this chroma a base color's own hue is unreliable, and the pole hue
-- progressively takes over instead.
local NEUTRAL_CHROMA = 0.040

-- How much of that takeover a reflective style still allows. A metal's faint
-- cast is the material talking, not noise, so it keeps most of its own hue.
local TINT_LIMITED_ADOPT = 0.35

-- Less lightness than this on one side of the base is not worth spending a
-- swatch on, which is how a base already at black or white avoids getting
-- steps it cannot use.
local USABLE_SPAN = 0.01

-- The outline continues a few degrees past where the body ramp stopped and
-- gives up chroma alongside lightness. A dark outline that keeps its full
-- chroma fringes and reads as a glow rather than a silhouette.
local OUTLINE_HUE_SHIFT = 6
local OUTLINE_CHROMA_SCALE = 0.85

-- A reflective style also produces a glint above the body: the light source
-- itself, carrying only what the material could not absorb. Near-white, and
-- deliberately not one of the evenly spaced body steps.
local SPECULAR_LIGHT = 0.965
local SPECULAR_CHROMA_SCALE = 0.35
local SPECULAR_CHROMA_MAX = 0.045

----------------------------------------------------------------------
-- Styles
----------------------------------------------------------------------

-- hue         how hue travels. "poles" rotates toward a shadow pole and a
--             highlight pole, "comp" swaps the shadow pole for the base's
--             opposite, "sweep" slides one direction across the whole ramp,
--             "none" holds the base hue.
-- shadow      shadow pole, in Oklab hue degrees.
-- highlight   highlight pole, in Oklab hue degrees.
-- shift       degrees of rotation per side at 100% range.
-- shiftDark   overrides shift on the shadow side. A light source is not lit by
--             the world, so its dim end takes no ambient rotation at all.
-- sweep       degrees per step, for the "sweep" mode only.
-- rise        chroma gained heading into shadow.
-- fall        chroma handed back at the deepest shadow, so darks do not
--             go muddy.
-- lightFall   chroma lost heading into the highlight.
-- lightPower  shapes when that loss happens. Above 1 it holds off until near
--             the top, which is how a light source stays colored on its way up
--             and only blows out at the very end.
-- lightFloor  overrides LIGHT_FLOOR, for styles that must not reach near-black.
-- darkCurve   eases where the shadow swatches sit. Below 1 they bunch toward
--             the dark end, which is how a reflective surface crushes its darks.
-- lightCurve  the same for the highlight side. Above 1 the top step becomes a
--             leap rather than a stride.
-- tintLimited scales hue rotation by how neutral the base is. A metal tints
--             whatever it reflects, so chrome takes the sky's hue almost whole
--             while gold reflects a gold-tinted sky and barely moves at all.
-- specular    generates a glint swatch above the body.
local STYLES = {
  {
    name = "Natural Light",
    help1 = "Cool shadows, warm highlights, the way daylight falls.",
    help2 = "The safe default. Right for almost anything.",
    hue = "poles", shadow = 291, highlight = 90, shift = 60,
    rise = 1.30, fall = 1.45, lightFall = 0.45
  },
  {
    name = "Muted",
    help1 = "Natural Light dialled down. Quiet, low contrast.",
    help2 = "For wide surfaces that repeat: ground, walls, backgrounds.",
    hue = "poles", shadow = 291, highlight = 90, shift = 32,
    rise = 0.70, fall = 0.85, lightFall = 0.30
  },
  {
    name = "Vivid",
    help1 = "Natural Light pushed hard. Strong, colorful shading.",
    help2 = "For things that must stand out: pickups, gems, icons.",
    hue = "poles", shadow = 291, highlight = 90, shift = 95,
    rise = 1.95, fall = 1.85, lightFall = 0.55
  },
  {
    name = "Moonlight",
    help1 = "Reversed: cool light, warm shadow.",
    help2 = "For night scenes, moonlight, snow, ice, screens.",
    hue = "poles", shadow = 71, highlight = 271, shift = 60,
    rise = 1.30, fall = 1.45, lightFall = 0.45
  },
  {
    name = "Sweep",
    help1 = "Color slides steadily one way from dark to light.",
    help2 = "A classic pixel-art look. Good for whole palette sets.",
    hue = "sweep", sweep = 18, shift = 0,
    rise = 1.10, fall = 1.30, lightFall = 0.40
  },
  {
    name = "Complementary",
    help1 = "Shadows fall toward the opposite color on the wheel.",
    help2 = "Deliberately unnatural. For gems, magic, energy.",
    hue = "comp", highlight = 90, shift = 85,
    rise = 1.70, fall = 1.60, lightFall = 0.45
  },
  {
    name = "Glow",
    help1 = "Climbs toward white-hot and takes no ambient tint.",
    help2 = "For things that give off light: fire, lamps, crystals.",
    hue = "poles", shadow = 291, highlight = 90, shift = 55, shiftDark = 0,
    rise = 1.15, fall = 0.00, lightFall = 2.20, lightPower = 2.00,
    lightFloor = 0.22
  },
  {
    name = "Metal",
    help1 = "Reflective: crushed darks, a fast climb, a hard glint.",
    help2 = "For ingots, machinery, armour, anything polished.",
    hue = "poles", shadow = 65, highlight = 252, shift = 60, tintLimited = true,
    rise = 0.30, fall = 1.60, lightFall = 0.90, lightPower = 1.40,
    darkCurve = 0.55, lightCurve = 1.50, specular = true
  },
  {
    name = "Flat",
    help1 = "Lightness only. Hue and colorfulness hold still.",
    help2 = "For UI, icons, silhouettes and readability checks.",
    hue = "none", shift = 0,
    rise = 0.00, fall = 0.00, lightFall = 0.00
  }
}

local STYLE_NAMES = {}
for i, style in ipairs(STYLES) do STYLE_NAMES[i] = style.name end

local function styleByName(name)
  for _, style in ipairs(STYLES) do
    if style.name == name then return style end
  end
  return STYLES[1]
end

----------------------------------------------------------------------
-- Color math
----------------------------------------------------------------------

local function clamp(x, low, high)
  if x < low then return low end
  if x > high then return high end
  return x
end

local function round(x)
  return math.floor(x + 0.5)
end

local function toLinear(c)
  if c <= 0.04045 then return c / 12.92 end
  return ((c + 0.055) / 1.055) ^ 2.4
end

local function toGamma(c)
  if c <= 0.0031308 then return 12.92 * c end
  return 1.055 * (c ^ (1 / 2.4)) - 0.055
end

local function cbrt(x)
  if x < 0 then return -((-x) ^ (1 / 3)) end
  return x ^ (1 / 3)
end

-- sRGB 0..1 to Oklab lightness, chroma, and hue in degrees.
local function toOklch(red, green, blue)
  local r, g, b = toLinear(red), toLinear(green), toLinear(blue)
  local l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
  local m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
  local s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)

  local lightness = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
  local a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
  local b2 = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s

  return lightness, math.sqrt(a * a + b2 * b2), math.deg(math.atan(b2, a)) % 360
end

local function oklabToRgb(lightness, a, b)
  local l = (lightness + 0.3963377774 * a + 0.2158037573 * b) ^ 3
  local m = (lightness - 0.1055613458 * a - 0.0638541728 * b) ^ 3
  local s = (lightness - 0.0894841775 * a - 1.2914855480 * b) ^ 3
  return  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
         -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
         -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
end

local function inGamut(lightness, a, b)
  local r, g, b2 = oklabToRgb(lightness, a, b)
  local low, high = -0.0001, 1.0001
  return r >= low and r <= high and g >= low and g <= high
     and b2 >= low and b2 <= high
end

-- Holds lightness and hue and gives up chroma until the color fits sRGB. That
-- is the one direction of compromise which leaves a ramp's spacing intact.
local function toColor(lightness, chroma, hue, alpha)
  local radians = math.rad(hue)
  local a, b = chroma * math.cos(radians), chroma * math.sin(radians)

  if not inGamut(lightness, a, b) then
    local low, high = 0.0, 1.0
    for _ = 1, 24 do
      local mid = (low + high) / 2
      if inGamut(lightness, a * mid, b * mid) then low = mid else high = mid end
    end
    low = low * GAMUT_MARGIN
    a, b = a * low, b * low
  end

  local r, g, b2 = oklabToRgb(lightness, a, b)
  return Color{
    red = round(clamp(toGamma(r), 0, 1) * 255),
    green = round(clamp(toGamma(g), 0, 1) * 255),
    blue = round(clamp(toGamma(b2), 0, 1) * 255),
    alpha = alpha
  }
end

local function readColor(color)
  return toOklch(color.red / 255, color.green / 255, color.blue / 255)
end

-- The two poles cut the hue wheel into two arcs. Whichever arc the base sits
-- in, the poles are reached by opposite rotations, so shadow and highlight can
-- never travel the same way and fold the ramp back onto itself.
local function poleRooms(baseHue, shadowPole, highlightPole)
  local arc = (shadowPole - highlightPole) % 360
  if ((baseHue - highlightPole) % 360) < arc then
    return (shadowPole - baseHue) % 360, -((baseHue - highlightPole) % 360)
  end
  return -((baseHue - shadowPole) % 360), (highlightPole - baseHue) % 360
end

-- Rotates by at most amount degrees along room's direction, never overshooting.
local function rotateWithin(hue, room, amount)
  local magnitude = math.min(amount, math.abs(room))
  if room < 0 then magnitude = -magnitude end
  return hue + magnitude
end

----------------------------------------------------------------------
-- Ramp
----------------------------------------------------------------------

-- Splits the body steps between the two sides in proportion to how much
-- *perceptual* distance each side covers, rather than how much range it was
-- given. A base already sitting near white has little room above it, so its
-- steps get spent below instead, where they are actually visible.
local function splitSteps(steps, darkSpan, lightSpan, darkPercent, lightPercent)
  if darkPercent <= 0 then return 0, steps - 1 end
  if lightPercent <= 0 then return steps - 1, 0 end

  local span = darkSpan + lightSpan
  if span <= 0.0001 then return 0, steps - 1 end

  -- Each side keeps at least one step, but only where it has somewhere to go.
  -- A base already at black or white has no room on one side and spends every
  -- step on the other.
  local dark = round((steps - 1) * darkSpan / span)
  if darkSpan > USABLE_SPAN then dark = math.max(dark, 1) end
  if lightSpan > USABLE_SPAN then dark = math.min(dark, steps - 2) end
  dark = clamp(dark, 0, steps - 1)
  return dark, (steps - 1) - dark
end

-- Returns the ramp darkest-first, plus how many swatches sit below the base. A
-- side with a range of 0 gets no steps, so the base ends up as the lightest or
-- darkest swatch rather than the middle one.
local function buildRamp(base, style, darkPercent, lightPercent, steps,
                         anchor, anchorStrength)
  local baseLight, baseChroma, baseHue = readColor(base)
  local darkRange, lightRange = darkPercent / 100, lightPercent / 100
  local floor = style.lightFloor or LIGHT_FLOOR

  -- A base outside the ramp's own limits would otherwise travel backwards, so
  -- each end is held on its own side of the base.
  local darkLight = math.min(baseLight - (baseLight - floor) * darkRange, baseLight)
  local lightLight = math.max(baseLight + (LIGHT_CEIL - baseLight) * lightRange,
                              baseLight)

  -- Anchoring drags the dark end onto the shared color, so at full strength
  -- the darkest swatch is the anchor itself whatever the range is.
  local anchorLight, anchorChroma, anchorHue
  if anchor then
    anchorLight, anchorChroma, anchorHue = readColor(anchor)
    darkLight = darkLight + (anchorLight - darkLight) * anchorStrength
  end

  local darkSteps, lightSteps = splitSteps(steps,
                                           baseLight - darkLight,
                                           lightLight - baseLight,
                                           darkPercent, lightPercent)

  local shadowPole = style.shadow or 291
  local highlightPole = style.highlight or 90
  if style.hue == "comp" then shadowPole = (baseHue + 180) % 360 end
  local shadowRoom, highlightRoom = poleRooms(baseHue, shadowPole, highlightPole)

  -- How far the base is from having a usable hue of its own.
  local neutral = 1 - math.min(baseChroma / NEUTRAL_CHROMA, 1)

  -- distance runs 0 at the base to 1 at that side's far end.
  local function shade(step, side, stepIndex)
    local range, pole, room, target = darkRange, shadowPole, shadowRoom, darkLight
    local shift = style.shiftDark or style.shift
    local curve = style.darkCurve or 1
    if side > 0 then
      range, pole, room, target = lightRange, highlightPole, highlightRoom, lightLight
      shift = style.shift
      curve = style.lightCurve or 1
    end

    -- Easing decides where a swatch sits between the base and that side's end.
    -- Everything else follows from that position, so hue and chroma stay in
    -- step with lightness however unevenly the swatches are spaced.
    local distance = step ^ curve

    -- A metal tints what it reflects, so the more color the base already has,
    -- the less of the environment's hue reaches the ramp. The floor keeps a
    -- strongly colored metal from going completely flat.
    --
    -- A reflective base also keeps its own hue even when that hue is faint: the
    -- difference between silver and platinum is exactly such a tint, so it must
    -- not be discarded as unreliable the way a gray stone's hue is.
    local adopt = neutral
    if style.tintLimited then
      shift = shift * (0.20 + 0.80 * neutral)
      adopt = neutral * TINT_LIMITED_ADOPT
    end

    local lightness = baseLight + (target - baseLight) * distance

    local chroma
    if side < 0 then
      chroma = baseChroma + math.max(baseChroma, CHROMA_FLOOR) * range *
               (style.rise * distance - style.fall * distance * distance)
    else
      chroma = baseChroma - math.max(baseChroma, CHROMA_FLOOR) * range *
               style.lightFall * (distance ^ (style.lightPower or 1))
    end
    chroma = math.max(chroma, 0)

    if style.hue ~= "none" then
      local tint = CHROMA_FLOOR * math.sqrt(range) * distance
      if side > 0 then tint = tint * HIGHLIGHT_TINT end
      -- A reflective material gets its color from the reflection itself, so it
      -- needs far less injected ambient tint than a diffuse one.
      if style.tintLimited then tint = tint * 0.5 end
      chroma = math.max(chroma, tint)
    end

    local hue = baseHue
    if style.hue == "sweep" then
      hue = baseHue + style.sweep * stepIndex

    elseif style.tintLimited then
      -- A reflective surface hands its own color back and takes up the
      -- environment's. Mixing the two directly means the swap passes through
      -- neutral, the way a steel edge greys out before it picks up the sky.
      -- Rotating instead would drag it the long way round the wheel and give
      -- iron pink highlights.
      local reach = adopt
      if room ~= 0 then
        reach = adopt + (1 - adopt)
                * math.min(shift * range * distance / math.abs(room), 1)
      end
      local baseRadians, poleRadians = math.rad(baseHue), math.rad(pole)
      local a = chroma * (math.cos(baseRadians) * (1 - reach)
                        + math.cos(poleRadians) * reach)
      local b = chroma * (math.sin(baseRadians) * (1 - reach)
                        + math.sin(poleRadians) * reach)
      chroma = math.sqrt(a * a + b * b)
      hue = math.deg(math.atan(b, a)) % 360

    elseif style.hue ~= "none" then
      -- A side that does not rotate must not borrow the pole's hue either.
      -- The borrowed part travels the same way the rotation will, so the two
      -- never pull a near-gray base in opposite directions around the wheel.
      local start = baseHue
      if shift > 0 then
        start = baseHue + room * adopt
      end
      hue = rotateWithin(start, room * (1 - adopt), shift * range * distance)
    end

    -- Anchoring steers hue and chroma only; lightness is already placed.
    if anchor and side < 0 then
      local weight = anchorStrength * distance
      local radians, anchorRadians = math.rad(hue), math.rad(anchorHue)
      local a = chroma * math.cos(radians) * (1 - weight)
              + anchorChroma * math.cos(anchorRadians) * weight
      local b = chroma * math.sin(radians) * (1 - weight)
              + anchorChroma * math.sin(anchorRadians) * weight
      chroma = math.sqrt(a * a + b * b)
      hue = math.deg(math.atan(b, a)) % 360
    end

    return toColor(lightness, chroma, hue, base.alpha)
  end

  local ramp = {}
  for j = darkSteps, 1, -1 do
    ramp[#ramp + 1] = shade(j / darkSteps, -1, -j)
  end
  ramp[#ramp + 1] = base
  for j = 1, lightSteps do
    ramp[#ramp + 1] = shade(j / lightSteps, 1, j)
  end
  return ramp
end

-- The outline is a silhouette color, not the body's deepest shadow, so it is
-- always derived from the darkest body swatch rather than taken from the ramp.
-- A shared dark color reaches the outline only through that swatch, which is
-- what lets outlines converge across a sheet while still sitting below their
-- own ramp.
local function buildOutline(darkest, style, depthPercent)
  local lightness, chroma, hue = readColor(darkest)
  local depth = 1 - depthPercent / 100
  lightness = lightness * depth

  if style.hue ~= "none" then
    local shadowPole = style.shadow or 291
    if style.hue == "comp" then shadowPole = (hue + 180) % 360 end
    local shadowRoom = poleRooms(hue, shadowPole, style.highlight or 90)
    hue = rotateWithin(hue, shadowRoom, OUTLINE_HUE_SHIFT)
  end
  -- Chroma follows lightness down. Holding it while the swatch darkens is what
  -- turns an outline into a saturated fringe.
  chroma = chroma * OUTLINE_CHROMA_SCALE * depth

  return toColor(lightness, chroma, hue, darkest.alpha)
end

-- The glint a reflective surface throws back is the light source, not the
-- material, so it is built from the base's own tint rather than from the top of
-- the ramp and is capped near white. Styles that are not reflective get none.
local function buildSpecular(base, style)
  if not style.specular then return nil end

  local _, chroma, hue = readColor(base)
  chroma = math.min(chroma * SPECULAR_CHROMA_SCALE, SPECULAR_CHROMA_MAX)
  return toColor(SPECULAR_LIGHT, chroma, hue, base.alpha)
end

-- The direction splits one range into the distance each side travels.
local function resolveRanges(data)
  if data.direction == "Darker" then
    return data.range, 0
  end
  if data.direction == "Brighter" then
    return 0, data.range
  end
  return data.range, data.range
end

-- Returns the body ramp darkest-first, plus the outline or nil when disabled.
local function generate(data)
  local darkPercent, lightPercent = resolveRanges(data)
  local style = styleByName(data.style)
  local anchor = nil
  if data.useAnchor then anchor = data.anchor end

  local body = buildRamp(data.base, style, darkPercent, lightPercent, data.steps,
                         anchor, data.anchorStrength / 100)

  return body,
         buildOutline(body[1], style, data.outlineDepth),
         buildSpecular(data.base, style)
end

-- Saved palettes run outline, body, then any glint, so the file stays ordered
-- darkest-first.
local function combine(body, outline, specular)
  local all = { outline }
  for _, color in ipairs(body) do
    all[#all + 1] = color
  end
  if specular then all[#all + 1] = specular end
  return all
end

----------------------------------------------------------------------
-- Output
----------------------------------------------------------------------

local function sanitizeName(name)
  local cleaned = name:gsub("[^%w%-%_%. ]", "")
  cleaned = cleaned:gsub("^%s+", "")
  cleaned = cleaned:gsub("%s+$", "")
  if cleaned == "" then cleaned = "Ramp" end
  return cleaned
end

local function toPalette(ramp)
  local palette = Palette(#ramp)
  for i, color in ipairs(ramp) do
    palette:setColor(i - 1, color)
  end
  return palette
end

-- Registers the ramp as a palette preset so it shows up under the palette
-- menu's preset list. Uses a throwaway sprite so the user's open sprites keep
-- their own palettes untouched.
local function saveAsPreset(palette, name)
  local previous = app.activeSprite
  local scratch = Sprite(1, 1, ColorMode.INDEXED)
  scratch:setPalette(palette)
  app.command.SavePalette{ preset = name }
  scratch:close()
  if previous then
    pcall(function() app.activeSprite = previous end)
  end
end

-- Defaults into Aseprite's own palettes folder, which it scans for presets on
-- startup, so the out-of-the-box save still lands in the user's palette list.
local function defaultSavePath()
  return app.fs.joinPath(app.fs.joinPath(app.fs.userConfigPath, "palettes"), "Ramp.gpl")
end

local function colorKey(color)
  return color.red .. "," .. color.green .. "," .. color.blue .. "," .. color.alpha
end

-- Appends the ramp to the end of the active sprite's palette, keeping the
-- colors already there and skipping any that are already present. Skipping is
-- what keeps a shared outline from being added once per material. Wrapped in a
-- transaction so it lands as one undo step.
local function appendToActivePalette(ramp)
  local sprite = app.activeSprite
  if sprite == nil then
    return false, "No sprite open"
  end

  local current = sprite.palettes[1]
  local used = #current

  local seen = {}
  for i = 0, used - 1 do
    seen[colorKey(current:getColor(i))] = true
  end

  local fresh = {}
  for _, color in ipairs(ramp) do
    local key = colorKey(color)
    if not seen[key] then
      seen[key] = true
      fresh[#fresh + 1] = color
    end
  end

  local skipped = #ramp - #fresh
  if #fresh == 0 then
    return true, "Every color was already in the palette"
  end

  if sprite.colorMode == ColorMode.INDEXED and used + #fresh > 256 then
    return false, "Indexed palette has no room for " .. #fresh .. " more colors"
  end

  local merged = Palette(used + #fresh)
  for i = 0, used - 1 do
    merged:setColor(i, current:getColor(i))
  end
  for i, color in ipairs(fresh) do
    merged:setColor(used + i - 1, color)
  end

  app.transaction(function() sprite:setPalette(merged) end)

  local message = "Added " .. #fresh .. " colors to the sprite palette"
  if skipped > 0 then
    message = message .. " (" .. skipped .. " already there)"
  end
  return true, message
end

-- Writes the ramp to an arbitrary path, creating the folder if needed and
-- defaulting to .gpl when the entered path carries no extension.
local function saveToPath(palette, path)
  if app.fs.fileExtension(path) == "" then
    path = path .. ".gpl"
  end
  local folder = app.fs.filePath(path)
  if folder ~= "" then
    app.fs.makeAllDirectories(folder)
  end
  palette:saveAs(path)
  return path
end

----------------------------------------------------------------------
-- Dialog
----------------------------------------------------------------------

local refresh

local dlg = Dialog("Palette Ramp Generator")

dlg:tab{ id = "tabRamp", text = "Ramp" }

dlg:color{
  id = "base",
  label = "Base Color",
  color = app.fgColor,
  onchange = function() refresh() end
}

dlg:combobox{
  id = "style",
  label = "Style",
  option = STYLES[1].name,
  options = STYLE_NAMES,
  onchange = function() refresh() end
}

dlg:label{ id = "styleHelp1", label = "", text = STYLES[1].help1 }
dlg:label{ id = "styleHelp2", label = "", text = STYLES[1].help2 }

dlg:combobox{
  id = "direction",
  label = "Direction",
  option = "Center",
  options = { "Darker", "Center", "Brighter" },
  onchange = function() refresh() end
}

dlg:slider{
  id = "range",
  label = "Range (%)",
  min = 1,
  max = 100,
  value = 45,
  onchange = function() refresh() end
}

dlg:slider{
  id = "steps",
  label = "Steps",
  min = 2,
  max = 16,
  value = 5,
  onchange = function() refresh() end
}

dlg:label{ label = "", text = "Direction picks which side of the base to spend" }
dlg:label{ label = "", text = "swatches on. Range is how far the ramp travels." }

dlg:tab{ id = "tabShading", text = "Shading" }

dlg:check{
  id = "useAnchor",
  text = "Sink the dark end into a shared color",
  selected = false,
  onclick = function() refresh() end
}

dlg:color{
  id = "anchor",
  label = "Shared Dark",
  color = Color{ red = 20, green = 18, blue = 32 },
  onchange = function() refresh() end
}

dlg:slider{
  id = "anchorStrength",
  label = "Strength (%)",
  min = 0,
  max = 100,
  value = 60,
  onchange = function() refresh() end
}

dlg:label{ label = "", text = "Every ramp bends into this as it darkens, so a" }
dlg:label{ label = "", text = "sheet looks lit by one world. Use a tinted dark," }
dlg:label{ label = "", text = "never gray or black." }

dlg:slider{
  id = "outlineDepth",
  label = "Outline (%)",
  min = 10,
  max = 80,
  value = 40,
  onchange = function() refresh() end
}

dlg:label{ label = "", text = "How far the silhouette sits below the body ramp." }

dlg:tab{ id = "tabExport", text = "Export" }

dlg:file{
  id = "path",
  label = "Save To",
  save = true,
  filename = defaultSavePath(),
  filetypes = { "gpl", "pal", "act", "aco", "css", "hex", "png" }
}

dlg:check{
  id = "addPreset",
  text = "Also add to palette presets",
  selected = true
}

dlg:label{ label = "", text = "Presets show up in Aseprite's own palette list." }
dlg:label{ label = "", text = "Leave it on for house palettes, off for one-offs." }

dlg:endtabs{ id = "tabs", selected = "tabRamp" }

dlg:separator{ text = "Preview (darkest first)" }

dlg:shades{
  id = "outlinePreview",
  label = "Outline",
  colors = {},
  mode = "pick",
  onclick = function(ev) app.fgColor = ev.color end
}

dlg:shades{
  id = "preview",
  label = "Body",
  colors = {},
  mode = "pick",
  onclick = function(ev) app.fgColor = ev.color end
}

dlg:shades{
  id = "specularPreview",
  label = "Specular",
  colors = {},
  mode = "pick",
  onclick = function(ev) app.fgColor = ev.color end
}

dlg:label{ id = "status", label = "", text = "Click a swatch to set the foreground color." }

dlg:button{
  id = "append",
  text = "Add to Current Palette",
  onclick = function()
    local body, outline, specular = generate(dlg.data)
    local added, message = appendToActivePalette(combine(body, outline, specular))
    dlg:modify{ id = "status", text = message }
  end
}

dlg:button{
  id = "save",
  text = "Save Palette",
  onclick = function()
    local data = dlg.data
    if data.path == nil or data.path == "" then
      dlg:modify{ id = "status", text = "Pick a save location on the Export tab" }
      return
    end

    local body, outline, specular = generate(data)
    local palette = toPalette(combine(body, outline, specular))

    local written, result = pcall(saveToPath, palette, data.path)
    if not written then
      dlg:modify{ id = "status", text = "Save failed: " .. tostring(result) }
      return
    end

    local status = app.fs.fileName(result) .. " saved"

    -- Writing into the presets folder is enough for Aseprite to list the
    -- palette on its next scan; SavePalette registers it in this session too.
    if data.addPreset then
      local name = sanitizeName(app.fs.fileTitle(result))
      if not pcall(saveAsPreset, palette, name) then
        status = status .. ", preset needs a restart"
      end
    end

    dlg:modify{ id = "status", text = status }
  end
}

dlg:newrow()

dlg:button{ id = "close", text = "Close", onclick = function() dlg:close() end }

refresh = function()
  local data = dlg.data

  local style = styleByName(data.style)
  dlg:modify{ id = "styleHelp1", text = style.help1 }
  dlg:modify{ id = "styleHelp2", text = style.help2 }

  dlg:modify{ id = "anchor", visible = data.useAnchor }
  dlg:modify{ id = "anchorStrength", visible = data.useAnchor }

  local body, outline, specular = generate(data)
  dlg:modify{ id = "outlinePreview", colors = { outline } }
  dlg:modify{ id = "preview", colors = body }

  -- Only a reflective style throws a glint, so the row is hidden otherwise.
  dlg:modify{ id = "specularPreview", visible = specular ~= nil }
  if specular then
    dlg:modify{ id = "specularPreview", colors = { specular } }
  end
end

refresh()

-- Scrollbars guarantee the buttons stay reachable on a short screen whatever
-- the tab contents add up to.
dlg:show{ wait = false, autoscrollbars = true }
