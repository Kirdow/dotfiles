------------------------------------------------------------------------
-- Create random noise on a new layer, with the current foreground color
--
-- * Noise spread: determines the density of the noise.
--      Example: if density = 10, then this will create one speck of 
--               noise in every 10x10 grid across the entire layer
--
-- * Use current brush: if true, will use the paint brush instead of 
--               drawing a single pixel of noise. If bigger specks of 
--               noise are required, just set a larger brush before
--               running the script
-- 
-- by Willow Willis
-- MIT license: free for all uses, commercial or otherwise
------------------------------------------------------------------------
local sprite = app.activeSprite
if not sprite then
  return app.alert("There is no active sprite")
end

-- Ensures the noise will be different every time the script is run
math.randomseed(os.time())

-- Opens dialog, asks for input
function userInput()
   local dlg = Dialog("Add Noise")

   dlg:number{ id="cellsize", label="Noise spread:", decimals=4, text="10"}
   dlg:check { id="usebrush", label="Use current brush", selected=false }
   dlg:button{ id="ok", text="OK" } 
   dlg:button{ id="cancel", text="Cancel" }
   dlg:show()

   return dlg.data
end

-- Creates the noise
function createNoise(density, useBrush)

   if density > sprite.width or density > sprite.height then
      return app.alert("Value entered for density was greater than the image dimensions. Hint: smaller numbers yield greater density, larger numbers yield lower density.")
   end

   -- useBrush, but no active brush? kill the script
   local brush = app.activeBrush
   if useBrush and not brush then
      return app.alert("Script called with no active brush set")
   end

   local layer = sprite:newLayer()
   local cel   = sprite:newCel(layer,1)
   local image = cel.image

   layer.name = "Noise"

   local totWidth  = sprite.width
   local totHeight = sprite.height
   local w = 0
   local h = 0

   -- Walk the canvas. For each square (density x density size), make one piece of noise
   while(w < totWidth ) do
      while( h < totHeight ) do

         local y = h + math.random(density) - 1
         local x = w + math.random(density) - 1

	 if useBrush then
            local pt = Point(x,y)
            app.useTool {
               tool = "pencil",
               color = app.fgColor,
               brush = brush,
	       points = { pt },
               cel = cel,
               layer = layer
            }
	 else
            image:drawPixel(x,y,app.fgColor)
         end

         h = h + density
      end
      h = 0
      w = w + density
   end
end

-- Run the script
do
   local newNoise = userInput()
   if newNoise.ok then
      createNoise(newNoise.cellsize, newNoise.usebrush)
   end
end