local _G = getfenv(0)

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
local ChatEdit_SendText = ChatEdit_SendText
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
   strgsub(str, '([^' .. delimiter .. ']+)', function(value)
      insert(t, strtrim(value))
   end)

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

-- local functions
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
         arrow:Hide()
      end

      if button.onEnter then
         button:SetScript('OnEnter', button.onEnter)

         button.flyout = nil
         button.onEnter = nil
      end

      if HasAction(slot) then
         local macro = GetActionText(slot)
         if macro then
            local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
            local s, e = strfind(body, '/flyout')
            if s and s == 1 and e == 7 then
               button.onEnter = button:GetScript('OnEnter')
               button:SetCheckedTexture(nil)

               local delim = strfind(body, ';') or strlen(body)
               local firstAction = strsub(body, e + 2, delim - 1)
               local slot = GetSpellSlotByName(firstAction)
               if slot then
                  button.flyout = { 0, slot }
               else
                  button.flyout = { 1, GetMacroIndexByName(firstAction) }
               end

               Flyout_UpdateFlyoutArrow(button)

               button:SetScript('OnLeave', function()
                  this.updateTooltip = nil
                  GameTooltip:Hide()

                  local focus = GetMouseFocus()
                  if focus and not strfind(focus:GetName(), 'Flyout') then
                     Flyout_Hide()
                  end
               end)

               button:SetScript('OnEnter', function()
                  ActionButton_SetTooltip()

                  Flyout_Show(this, strsub(body, e + 1))
               end)
            end
         end
      end
   end
end

local function HandleEvent()
   if event == 'VARIABLES_LOADED' then
      if not Flyout_Config or Flyout_Config['hover'] then
         Flyout_Config =
         {
            ['BUTTON_SIZE'] = 24,
            ['BORDER_COLOR'] = { 0, 0, 0 },
         }
      end
   elseif event == 'ACTIONBAR_SLOT_CHANGED' then
      Flyout_Hide()
      UpdateBarButton(arg1)
   else
      Flyout_Hide()
      Flyout_UpdateBars()
   end
end

local handler = CreateFrame('Frame')
handler:RegisterEvent('VARIABLES_LOADED')
handler:RegisterEvent('PLAYER_ENTERING_WORLD')
handler:RegisterEvent('ACTIONBAR_SLOT_CHANGED')
handler:RegisterEvent('ACTIONBAR_PAGE_CHANGED')
handler:SetScript('OnEvent', HandleEvent)

-- globals
function Flyout_ExecuteMacro(macro)
   local _, _, body = GetMacroInfo(macro)
   local commands = strsplit(body, '\n')
   for i = 1, sizeof(commands) do
      ChatFrameEditBox:SetText(commands[i])
      ChatEdit_SendText(ChatFrameEditBox)
   end
end

function Flyout_Hide()
   local i = 1
   local button = _G['FlyoutButton' .. i]
   while button do
      i = i + 1

      button:Hide()
      button:SetChecked(false)
      button:GetNormalTexture():SetTexture(nil)

      button = _G['FlyoutButton' .. i]
   end
end

function Flyout_Show(button, spells)
   local direction = GetFlyoutDirection(button)
   local size = Flyout_Config['BUTTON_SIZE']
   local offset = size

   for i, n in (strsplit(spells, ';')) do
      local b = _G['FlyoutButton' .. i] or CreateFrame('CheckButton', 'FlyoutButton' .. i, UIParent, 'FlyoutButtonTemplate')
      b:ClearAllPoints()
      b:SetWidth(size)
      b:SetHeight(size)
      b:SetBackdropColor(Flyout_Config['BORDER_COLOR'][1], Flyout_Config['BORDER_COLOR'][2], Flyout_Config['BORDER_COLOR'][3])
      b:Show()

      local texture = nil
      if GetSpellSlotByName(n) then
         local spellName = GetSpellSlotByName(n)

         b.action = spellName
         b.actionType = 0

         texture = GetSpellTexture(spellName, 'spell')
      elseif GetMacroIndexByName(n) then
         local macroIndex = GetMacroIndexByName(n)
         b.action = macroIndex
         b.actionType = 1

         _, texture = GetMacroInfo(macroIndex)
      end

      b:GetNormalTexture():SetTexture(texture)

      if direction == 'BOTTOM' then
         b:SetPoint('BOTTOM', button, 0, -offset)
      elseif direction == 'LEFT' then
         b:SetPoint('LEFT', button, -offset, 0)
      elseif direction == 'RIGHT' then
         b:SetPoint('RIGHT', button, offset, 0)
      else
         b:SetPoint('TOP', button, 0, offset)
      end

      offset = offset + size
   end
end

function Flyout_GetActionButton(action)
   for i = 1, sizeof(bars) do
      for j = 1, 12 do
         local button = _G[bars[i] .. 'Button' .. j]
         local slot = ActionButton_GetPagedID(button)
         if slot == action and button:IsVisible() then
            return button
         end
      end
   end
end

function Flyout_UpdateBars()
   for i = 1, 120 do
      UpdateBarButton(i)
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
      button.arrow:SetWidth(18)
      button.arrow:SetHeight(10)
      button.arrow:SetTexCoord(0, 0.565, 0.315, 0)
      button.arrow:SetPoint('BOTTOM', button, 0, -5)
   elseif direction == 'LEFT' then
      button.arrow:SetWidth(10)
      button.arrow:SetHeight(18)
      button.arrow:SetTexCoord(0, 0.315, 0.375, 1)
      button.arrow:SetPoint('LEFT', button, -5, 0)
   elseif direction == 'RIGHT' then
      button.arrow:SetWidth(10)
      button.arrow:SetHeight(18)
      button.arrow:SetTexCoord(0.315, 0, 0.375, 1)
      button.arrow:SetPoint('RIGHT', button, 5, 0)
   else
      button.arrow:SetWidth(18)
      button.arrow:SetHeight(10)
      button.arrow:SetTexCoord(0, 0.565, 0, 0.315)
      button.arrow:SetPoint('TOP', button, 0, 5)
   end
end

local Flyout_UseAction = UseAction
function UseAction(slot, checkCursor)
   Flyout_UseAction(slot, checkCursor)

   local button = Flyout_GetActionButton(slot)
   if button and button.flyout then
      if button.flyout[1] == 0 then
         CastSpell(button.flyout[2], 'spell')
      else
         Flyout_ExecuteMacro(button.flyout[2])
      end
   end

   Flyout_Hide()
end