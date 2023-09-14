local _G = getfenv(0)

local active = nil
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
local sizeof = table.getn

local strfind = string.find
local strgsub = string.gsub
local strlower = string.lower
local strsub = string.sub

-- helper functions
local function strtrim(str)
   local _, e = strfind(str, '^%s*')
   local s, _ = strfind(str, '%s*$', e + 1)
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

-- credit: https://github.com/DanielAdolfsson/CleverMacro
local function GetSpellSlotByName(name)
   name = strlower(name)
   local b, _, rank = strfind(name, '%(%s*rank%s+(%d+)%s*%)')
   if b then name = (b > 1) and strtrim(strsub(name, 1, b - 1)) or '' end

   for tabIndex = GetNumSpellTabs(), 1, -1 do
      local _, _, offset, count = GetSpellTabInfo(tabIndex)
      for index = offset + count, offset + 1, -1 do
         local spell, subSpell = GetSpellName(index, 'spell')
         spell = strlower(spell)
         if name == spell and (not rank or subSpell == 'Rank ' .. rank) then
            return index
         end
      end
   end
end

local function HideFlyout()
   local i = 0
   while true do
      i = i + 1

      local button = _G['FlyoutButton' .. i]
      if button then
         button:SetChecked(false)
         button:Hide()

         _G[button:GetName() .. 'NormalTexture']:SetTexture(nil)
      else
         break
      end
   end

   active = nil
end

local function GetFlyoutDirection(button)
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

local function UpdateBarButton(slot)
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
         local s = strfind(body, '/flyout')
         if s and s == 1 then
            Flyout_UpdateFlyoutArrow(button)
         end
      end
   end
end

local function Init()
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
end

local function HandleEvent()
   if event == 'VARIABLES_LOADED' then
      Init()
   elseif event == 'PLAYER_ENTERING_WORLD' then
      Flyout_UpdateBars()
   elseif event == 'ACTIONBAR_SLOT_CHANGED' then
      HideFlyout()
      UpdateBarButton(arg1)
   else
      HideFlyout()
      Flyout_UpdateBars()
   end
end

function Flyout_GetActionButton(action)
   for i = 1, sizeof(bars) do
      for j = 1, 12 do
         local button = _G[bars[i] .. "Button" .. j]
         local slot = ActionButton_GetPagedID(button)
         if slot == action and button:IsVisible() then
            return button
         end
      end
   end
end

function Flyout_UpdateBars()
   for i = 1, sizeof(bars) do
      for j = 1, 12 do
         local button = _G[bars[i] .. "Button" .. j]
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

function Flyout_UpdateFlyoutArrow(button)
   if not button then return end

   local direction = GetFlyoutDirection(button)

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

local _UseAction = UseAction
function UseAction(slot, checkCursor)
   _UseAction(slot, checkCursor)

   if active then
      if active == slot then
         HideFlyout()
         return
      end

      HideFlyout()
   end

   active = slot

   local macro = GetActionText(slot)
   if macro then
      local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
      local s, e = strfind(body, "/flyout")
      if s and s == 1 then
         local button = Flyout_GetActionButton(slot)
         if button then
            local direction = GetFlyoutDirection(button)
            local size = Flyout_Config['button_size']
            local offset = size

            body = strsub(body, e + 1)
            for i, n in (strsplit(body, ';')) do
               local spell = GetSpellSlotByName(n)
               if spell then
                  local b = _G['FlyoutButton' .. i] or CreateFrame('CheckButton', 'FlyoutButton' .. i, UIParent, 'FlyoutButtonTemplate')
                  b:Show()
                  b:ClearAllPoints()
                  b:SetWidth(Flyout_Config['button_size'])
                  b:SetHeight(Flyout_Config['button_size'])

                  _G[b:GetName() .. 'BorderTexture']:SetVertexColor(Flyout_Config['border_color']['r'], Flyout_Config['border_color']['g'], Flyout_Config['border_color']['b'])

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
                  b.texture:SetPoint('TOPLEFT', b, 1, -1)
                  b.texture:SetPoint('BOTTOMRIGHT', b, -1, 1)
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
handler:SetScript('OnEvent', HandleEvent)