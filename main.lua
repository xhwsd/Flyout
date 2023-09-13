local _G = getfenv(0)

local ref = nil
local bars = {
   'Action',
   'BonusAction',
   'MultiBarBottomLeft',
   'MultiBarBottomRight',
   'MultiBarRight',
   'MultiBarLeft'
}

-- upvalues
local ActionButton_GetPagedID = ActionButton_GetPagedID
local GameTooltip_SetDefaultAnchor = GameTooltip_SetDefaultAnchor
local GetActionText = GetActionText
local GetNumSpellTabs = GetNumSpellTabs
local GetSpellName = GetSpellName
local GetSpellTabInfo = GetSpellTabInfo
local GetScreenHeight = GetScreenHeight
local GetScreenWidth = GetScreenWidth
local HasAction = HasAction
local GetMacroIndexByName = GetMacroIndexByName
local GetMacroInfo = GetMacroInfo

local insert = table.insert

local strfind = string.find
local strgfind = string.gfind
local strgsub = string.gsub
local strlower = string.lower
local strsub = string.sub

-- helper functions
local function strtrim(str)
   local _, e = strfind(str, "^%s*")
   local s, _ = strfind(str, "%s*$", e + 1)
   return strsub(str, e + 1, s - 1)
end

local function strsplit(str, delimiter)
   local t = {}
   strgsub(str, '([^' .. delimiter .. ']+)',
      function(value)
         insert(t, strtrim(value))
      end
   )
   return t
end

function Flyout_Init()
   if not Flyout_Config then
      Flyout_Config = {
         ['button_size'] = 24,
         ['border_color'] = {
            ['r'] = 1.0,
            ['g'] = 1.0,
            ['b'] = 1.0
         },
      }
   end

   local size = Flyout_Config['button_size']
   for i = 1, 12 do
      local button = CreateFrame('CheckButton', 'FlyoutButton' .. i, UIParent, 'ActionButtonTemplate')
      button:SetHeight(size)
      button:SetWidth(size)
      button:SetFrameStrata('DIALOG')
      button:Hide()

      button.border = button:CreateTexture('FlyoutButton' .. i .. 'BorderTexture', 'BACKGROUND')
      button.border:SetTexture('Interface\\AddOns\\Flyout\\assets\\FlyoutButton')
      button.border:SetTexCoord(0, 0.515625, 0, 1)
      button.border:SetPoint('TOPLEFT', button, -1, 1)
      button.border:SetPoint('BOTTOMRIGHT', button, 1, -1)
      button.border:SetVertexColor(Flyout_Config['border_color']['r'], Flyout_Config['border_color']['g'], Flyout_Config['border_color']['b'])
   end

   ref = _G['FlyoutButton1']
   ref.elapsed = 0
   ref.active = nil
   ref.sticky = false
   ref:SetScript('OnUpdate',
      function()
         this.elapsed = this.elapsed + arg1
         if not this.sticky and this.elapsed >= 3 then
		      this.elapsed = 0

            Flyout_HideFlyout()
         end
      end
   )
end

-- credit: https://github.com/DanielAdolfsson/CleverMacro
function Flyout_GetSpellSlotByName(name)
   name = strlower(name)
   local b, _, rank = strfind(name, "%(%s*rank%s+(%d+)%s*%)")
   if b then name = (b > 1) and strtrim(strsub(name, 1, b - 1)) or "" end

   for tabIndex = GetNumSpellTabs(), 1, -1 do
      local _, _, offset, count = GetSpellTabInfo(tabIndex)
      for index = offset + count, offset + 1, -1 do
         local spell, subSpell = GetSpellName(index, "spell")
         spell = strlower(spell)
         if name == spell and (not rank or subSpell == "Rank " .. rank) then
            return index
         end
      end
   end
end

function Flyout_GetActionButton(action)
   for _, bar in pairs(bars) do
      for i = 1, 12 do
         local button = _G[bar .. "Button" .. i]
         local slot = ActionButton_GetPagedID(button)
         if slot == action and button:IsVisible() then
            return button
         end
      end
   end
end

function Flyout_GetFlyoutDirection(button)
   local horizontal = false
   local bar = button:GetParent()
   if bar:GetWidth() > bar:GetHeight() then
      horizontal = true
   end

   local direction = horizontal and 'TOP' or 'LEFT'

   local centerX, centerY = button:GetCenter()
   if centerX and centerY then
      if horizontal then
         local halfScreen = GetScreenHeight() / 2
         direction = centerY < halfScreen and 'TOP' or 'BOTTOM'
      else
         local halfScreen = GetScreenWidth() / 2
         direction = centerX > halfScreen and 'LEFT' or 'RIGHT'
      end
   end
   return direction
end

function Flyout_UpdateFlyoutArrow(button)
   if not button then return end

   local direction = Flyout_GetFlyoutDirection(button)

   button.arrow = _G[button:GetName() .. 'FlyoutArrow'] or button:CreateTexture(button:GetName() .. 'FlyoutArrow', 'OVERLAY')
   button.arrow:ClearAllPoints()
   button.arrow:SetTexture('Interface\\AddOns\\Flyout\\assets\\FlyoutButton')
   button.arrow:Show()

   if direction == 'BOTTOM' then
      button.arrow:SetHeight(12)
      button.arrow:SetWidth(20)
      button.arrow:SetTexCoord(0.5312, 0.8125, 0.3750, 0)
      button.arrow:SetPoint('BOTTOM', button, 0, -5)

   elseif direction == 'LEFT' then
      button.arrow:SetHeight(20)
      button.arrow:SetWidth(12)
      button.arrow:SetTexCoord(0.5312, 0.7031, 0.3750, 1)
      button.arrow:SetPoint('LEFT', button, -5, 0)

   elseif direction == 'RIGHT' then
      button.arrow:SetHeight(20)
      button.arrow:SetWidth(12)
      button.arrow:SetTexCoord(0.7031, 0.5312, 0.3750, 1)
      button.arrow:SetPoint('RIGHT', button, 5, 0)

   else
      button.arrow:SetHeight(12)
      button.arrow:SetWidth(20)
      button.arrow:SetTexCoord(0.5315, 0.8125, 0, 0.3750)
      button.arrow:SetPoint('TOP', button, 0, 5)
   end
end

function Flyout_UpdateBars()
   for _, bar in ipairs(bars) do
      for i = 1, 12 do
         local button = _G[bar .. "Button" .. i]
         local arrow = _G[button:GetName() .. 'FlyoutArrow']
         if arrow then arrow:Hide() end

         local slot = ActionButton_GetPagedID(button)
         if HasAction(slot) then
            local macro = GetActionText(slot)
            if macro then
               local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
               local s = strfind(body, "/flyout")
               if s and s == 1 then
                  Flyout_UpdateFlyoutArrow(button)
               end
            end
         end
      end
   end
end

function Flyout_UpdateBarButton(slot)
   local button = Flyout_GetActionButton(slot)
   if button then
      local arrow = _G[button:GetName() .. 'FlyoutArrow']
      if arrow then
         if arrow:IsVisible() then
            arrow:Hide()
         end
      end

      local macro = GetActionText(slot)
      if macro then
         local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
         local s = strfind(body, "/flyout")
         if s and s == 1 then
            Flyout_UpdateFlyoutArrow(button)
         end
      end
   end
end

function Flyout_HideFlyout()
   for i = 1, 12 do
      local button = _G['FlyoutButton' .. i]
      if button then
         button:SetChecked(false)
         button:Hide()
         _G[button:GetName() .. 'NormalTexture']:SetTexture(nil)
      end
   end

   ref.active = nil
end

function Flyout_OnEvent()
   if event == 'VARIABLES_LOADED' then
      Flyout_Init()

   elseif event == 'PLAYER_ENTERING_WORLD' then
      Flyout_UpdateBars()

   elseif event == 'ACTIONBAR_SLOT_CHANGED' then
      Flyout_HideFlyout()
      Flyout_UpdateBarButton(arg1)

   elseif event == 'ACTIONBAR_PAGE_CHANGED' or event == 'UPDATE_MACROS' then
      Flyout_HideFlyout()
      Flyout_UpdateBars()
   end
end

local _UseAction = UseAction
function UseAction(slot, checkCursor)
   _UseAction(slot, checkCursor)

   if ref.active then
      if ref.active == slot then
         Flyout_HideFlyout()
         return
      end

      Flyout_HideFlyout()
   end

   ref.active = slot

   local macro = GetActionText(slot)
   if macro then
      local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
      local s, e = strfind(body, "/flyout")
      if s and s == 1 then
         local button = Flyout_GetActionButton(slot)
         if button then
            local direction = Flyout_GetFlyoutDirection(button)
            local size = Flyout_Config['button_size']
            local offset = size

            ref.sticky = false
            ref.elapsed = 0

            button:SetFrameStrata('DIALOG')

            if strfind(body, "%[sticky%]") then
               s, e = strfind(body, "%[sticky%]")
               ref.sticky = true
            end

            body = strsub(body, e + 1)
            for i, n in (strsplit(body, ';')) do
               local spell = Flyout_GetSpellSlotByName(n)
               if spell then
                  local b = _G['FlyoutButton' .. i]
                  b:Show()
                  b:ClearAllPoints()

                  if direction == 'BOTTOM' then
                     b:SetPoint('BOTTOM', button, 0, -offset)
                  elseif direction == 'LEFT' then
                     b:SetPoint('LEFT', button, -offset, 0)
                  elseif direction == 'RIGHT' then
                     b:SetPoint('RIGHT', button, offset, 0)
                  else
                     b:SetPoint('TOP', button, 0, offset)
                  end

                  b:SetScript('OnClick',
                     function()
                        CastSpell(spell, 'spell')

                        ref.elapsed = 0

                        if ref.sticky then
                           b:SetChecked(0)
                        else
                           Flyout_HideFlyout()
                        end
                     end
                  )
                  b:SetScript('OnEnter',
                     function()
                        GameTooltip_SetDefaultAnchor(GameTooltip, this)
                        GameTooltip:SetSpell(spell, 'spell')
                        GameTooltip:Show()
                     end
                  )
                  b:SetScript('OnLeave',
                     function()
                        GameTooltip:Hide()
                     end
                  )

                  b.texture = _G[b:GetName() .. 'NormalTexture']
                  b.texture:SetTexture(GetSpellTexture(spell, 'spell'))
                  b.texture:SetAllPoints()
                  b.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

                  offset = offset + size
               end
            end
         end
      end
   end
end

local handler = CreateFrame('Frame')
handler:RegisterEvent('VARIABLES_LOADED')
handler:RegisterEvent('PLAYER_ENTERING_WORLD')
handler:RegisterEvent('ACTIONBAR_SLOT_CHANGED')
handler:RegisterEvent('ACTIONBAR_PAGE_CHANGED')
handler:RegisterEvent('UPDATE_MACROS')
handler:SetScript('OnEvent', Flyout_OnEvent)

-- customization stuff
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

   Flyout_Config['border_color']['r'] = r
   Flyout_Config['border_color']['g'] = g
   Flyout_Config['border_color']['b'] = b
end

SLASH_FLYOUT1 = "/flyout"
SlashCmdList['FLYOUT'] = function(msg)
   local args = {}
   local i = 1
   for arg in strgfind(strlower(msg), "%S+") do
      args[i] = arg
      i = i + 1
   end

   if not args[1] then
      DEFAULT_CHAT_FRAME:AddMessage("/flyout size [number] - set flyout button size")
      DEFAULT_CHAT_FRAME:AddMessage("/flyout color - adjust the color of the flyout border")
      DEFAULT_CHAT_FRAME:AddMessage("")
      DEFAULT_CHAT_FRAME:AddMessage("Any changes will be applied after you reload your interface.")

   elseif args[1] == 'size' then
      if args[2] and type(tonumber(args[2])) == 'number' then
         Flyout_Config['button_size'] = tonumber(args[2])

         DEFAULT_CHAT_FRAME:AddMessage("Flyout button size has been set to " .. args[2] .. ".")
      end

   elseif args[1] == 'color' then
      ShowColorPicker(Flyout_Config['border_color']['r'], Flyout_Config['border_color']['g'], Flyout_Config['border_color']['b'], ColorPickerCallback)

      DEFAULT_CHAT_FRAME:AddMessage("Use the color picker to pick a border color. Click 'Okay' once you're done or 'Cancel' to keep the default color.")
   end
end