local function ShowColorPicker(r, g, b, callback)
   ColorPickerFrame:SetColorRGB(r, g, b)
   ColorPickerFrame.previousValues = {r, g, b}
   ColorPickerFrame.func, ColorPickerFrame.cancelFunc = callback, callback
   ColorPickerFrame:Hide()
   ColorPickerFrame:Show()
end

local function ColorPickerCallback(restore)
   local r, g, b
   if restore then
      r, g, b = unpack(restore)
   else
      r, g, b = ColorPickerFrame:GetColorRGB()
   end

   Flyout_Config["BORDER_COLOR"][1] = r
   Flyout_Config["BORDER_COLOR"][2] = g
   Flyout_Config["BORDER_COLOR"][3] = b
end

local function IsValidDirection(direction)
   local validDirections = { "top", "bottom", "left", "right" }
   for i = 1, table.getn(validDirections) do
      if validDirections[i] == direction then
         return true
      end
   end
   return false
end

SLASH_FLYOUT1 = "/flyout"
SlashCmdList["FLYOUT"] = function(msg)
   local args = {}
   local i = 1
   for arg in string.find(string.lower(msg), "%S+") do
      args[i] = arg
      i = i + 1
   end

   if not args[1] then
      DEFAULT_CHAT_FRAME:AddMessage("/flyout size [number||reset] - set flyout button size")
      DEFAULT_CHAT_FRAME:AddMessage("/flyout color [reset] - adjust the color of the flyout border")
      DEFAULT_CHAT_FRAME:AddMessage("/flyout arrow [number||reset] - adjust the relative size of the flyout arrow")
      DEFAULT_CHAT_FRAME:AddMessage("/flyout direction [top|bottom|left|right|reset] - override flyout direction")
      DEFAULT_CHAT_FRAME:AddMessage(" ")
   elseif args[1] == "size" then
      if args[2] then
         if type(tonumber(args[2])) == "number" then
            Flyout_Config["BUTTON_SIZE"] = tonumber(args[2])
         elseif args[2] == "reset" then
            Flyout_Config["BUTTON_SIZE"] = FLYOUT_DEFAULT_CONFIG["BUTTON_SIZE"]
         end
         DEFAULT_CHAT_FRAME:AddMessage("Flyout button size has been set to " .. Flyout_Config["BUTTON_SIZE"] .. ".")
      end
   elseif args[1] == "color" then
      if args[2] == "reset" then
         Flyout_Config["BORDER_COLOR"][1] = FLYOUT_DEFAULT_CONFIG["BORDER_COLOR"][1]
         Flyout_Config["BORDER_COLOR"][2] = FLYOUT_DEFAULT_CONFIG["BORDER_COLOR"][2]
         Flyout_Config["BORDER_COLOR"][3] = FLYOUT_DEFAULT_CONFIG["BORDER_COLOR"][3]
         DEFAULT_CHAT_FRAME:AddMessage("Flyout border color has been reset.")
      else
         ShowColorPicker(Flyout_Config["BORDER_COLOR"][1], Flyout_Config["BORDER_COLOR"][2], Flyout_Config["BORDER_COLOR"][3], ColorPickerCallback)
         DEFAULT_CHAT_FRAME:AddMessage('Use the color picker to pick a border color. Click "Okay" once you"re done or "Cancel" to keep the current color.')
      end
   elseif args[1] == "arrow" then
      if args[2] then
         if type(tonumber(args[2])) == "number" then
            Flyout_Config["ARROW_SCALE"] = tonumber(args[2])
         elseif args[2] == "reset" then
            Flyout_Config["ARROW_SCALE"] = FLYOUT_DEFAULT_CONFIG["ARROW_SCALE"]
         end
         DEFAULT_CHAT_FRAME:AddMessage("Flyout arrow scale has been set to " .. Flyout_Config["ARROW_SCALE"] .. ".")
         Flyout_UpdateBars()
      end
   elseif args[1] == "direction" then
      if args[2] then
         if args[2] == "reset" then
            Flyout_Config["DIRECTION_OVERRIDE"] = nil
            DEFAULT_CHAT_FRAME:AddMessage("Flyout direction override has been reset. Using dynamic direction calculation.")
         elseif IsValidDirection(args[2]) then
            Flyout_Config["DIRECTION_OVERRIDE"] = strupper(args[2])
            DEFAULT_CHAT_FRAME:AddMessage("Flyout direction has been set to " .. Flyout_Config["DIRECTION_OVERRIDE"] .. ".")
         else
            DEFAULT_CHAT_FRAME:AddMessage("Invalid direction. Valid options are: top, bottom, left, right, reset")
         end
         Flyout_UpdateBars() -- Update arrows after direction change
      else
         if Flyout_Config["DIRECTION_OVERRIDE"] then
            DEFAULT_CHAT_FRAME:AddMessage("Current direction override: " .. Flyout_Config["DIRECTION_OVERRIDE"])
         else
            DEFAULT_CHAT_FRAME:AddMessage("No direction override set. Using dynamic calculation.")
         end
      end
   end
end
