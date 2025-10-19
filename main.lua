local _G = getfenv(0)

local revision = 1.0
local bars = {
   'Action',
   'BonusAction',
   'MultiBarBottomLeft',
   'MultiBarBottomRight',
   'MultiBarRight',
   'MultiBarLeft'
}

FLYOUT_DEFAULT_CONFIG = {
   ['REVISION'] = revision,
   ['BUTTON_SIZE'] = 28,
   ['BORDER_COLOR'] = { 0, 0, 0 },
   ['ARROW_SCALE'] = 5/9,
   ['DIRECTION_OVERRIDE'] = nil, 
}

-- 物品缓存相关变量
local itemCache = {}  -- 物品位置信息缓存
local itemCountCache = {}  -- 物品数量缓存
local bagScanCache = {}  -- 背包扫描状态缓存
local cacheTimestamp = 0  -- 缓存时间戳
local CACHE_DURATION = 5  -- 缓存持续时间（秒）

local ARROW_RATIO = 0.6  -- Height to width.

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
local rawset = rawset
local remove = table.remove
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

local function tblclear(tbl)
	if type(tbl) ~= 'table' then
		return
	end

	-- Clear array-type tables first so table.insert will start over at 1.
	for i = sizeof(tbl), 1, -1 do
		remove(tbl, i)
	end

	-- Remove any remaining associative table elements.
	-- Credit: https://stackoverflow.com/a/27287723
	for k in next, tbl do
		rawset(tbl, k, nil)
	end
end

local strSplitReturn = {}  -- Reusable table for strsplit() when fillTable parameter isn't used.
local function strsplit(str, delimiter, fillTable)
   fillTable = fillTable or strSplitReturn
   tblclear(fillTable)
   strgsub(str, '([^' .. delimiter .. ']+)', function(value)
      insert(fillTable, strtrim(value))
   end)

   return fillTable
end

-- 清理物品缓存
local function ClearItemCache()
   tblclear(itemCache)
   tblclear(itemCountCache)
   tblclear(bagScanCache)
   cacheTimestamp = GetTime()
end

-- 检查缓存是否有效
local function IsCacheValid()
   return (GetTime() - cacheTimestamp) < CACHE_DURATION
end

-- 扫描所有背包并缓存物品信息
local function ScanAllBags()
   if IsCacheValid() and bagScanCache.scanned then
      return
   end
   
   if not IsCacheValid() then
      ClearItemCache()
   end
   
   -- 遍历所有背包
   for bagIndex = 0, 4 do
      local bagSlots = GetContainerNumSlots(bagIndex)
      if bagSlots and bagSlots > 0 then
         for slotIndex = 1, bagSlots do
            local itemLink = GetContainerItemLink(bagIndex, slotIndex)
            if itemLink then
               -- 从物品链接解析物品名称
               local itemName = string.match(itemLink, "%[(.+)%]")
               if itemName then
                  local lowerItemName = strlower(itemName)
                  
                  -- 缓存第一个找到的物品位置
                  if not itemCache[lowerItemName] then
                     itemCache[lowerItemName] = {
                        bagIndex = bagIndex,
                        slotIndex = slotIndex,
                        itemLink = itemLink
                     }
                  end
                  
                  -- 累计同名物品总数量
                  local _, itemCount = GetContainerItemInfo(bagIndex, slotIndex)
                  itemCountCache[lowerItemName] = (itemCountCache[lowerItemName] or 0) + (itemCount or 0)
               end
            end
         end
      end
   end
   
   bagScanCache.scanned = true
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

-- 根据物品名称搜索背包中的物品
local function GetItemByName(name)
   name = strlower(name)
   
   ScanAllBags()
   
   if itemCache[name] then
      return itemCache[name].bagIndex, itemCache[name].slotIndex, itemCache[name].itemLink
   end
   
   return nil
end

-- 获取指定物品的总数量
local function GetItemTotalCount(name)
   name = strlower(name)
   
   ScanAllBags()
   
   return itemCountCache[name] or 0
end

-- 根据动作名称获取动作信息和类型
-- 返回值：动作数据, 动作类型 (0=法术, 1=宏, 2=物品)
local function GetFlyoutActionInfo(action)
   local spellSlot = GetSpellSlotByName(action)
   if spellSlot then
      return spellSlot, 0
   end
   
   local macroIndex = GetMacroIndexByName(action)
   if macroIndex and macroIndex > 0 then
      return macroIndex, 1
   end
   
   local bagIndex, slotIndex, itemLink = GetItemByName(action)
   if bagIndex then
      return {bagIndex = bagIndex, slotIndex = slotIndex, itemLink = itemLink}, 2
   end
   
   return nil
end

local function GetFlyoutDirection(button)
   -- Check if there's a direction override first
   if Flyout_Config['DIRECTION_OVERRIDE'] then
      --print("Using override direction: " .. tostring(Flyout_Config['DIRECTION_OVERRIDE']))
      return Flyout_Config['DIRECTION_OVERRIDE']
   end
   
   -- Original dynamic calculation code
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
   -- print("Flyout direction: " .. tostring(direction))
   return direction
end

local function FlyoutBarButton_OnLeave()
   this.updateTooltip = nil
   GameTooltip:Hide()

   local focus = GetMouseFocus()
   if focus and not strfind(focus:GetName(), 'Flyout') then
      Flyout_Hide()
   end
end

local function FlyoutBarButton_OnEnter()
   ActionButton_SetTooltip()
   Flyout_Show(this)
 end

local function UpdateBarButton(slot)
   local button = Flyout_GetActionButton(slot)
   if button then
      local arrow = _G[button:GetName() .. 'FlyoutArrow']
      if arrow then
         arrow:Hide()
      end

      if HasAction(slot) then
         button.sticky = false

         local macro = GetActionText(slot)
         if macro then
            local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
            local s, e = strfind(body, '/flyout')
            if s and s == 1 and e == 7 then
               if not button.preFlyoutOnEnter then
                  button.preFlyoutOnEnter = button:GetScript('OnEnter')
                  button.preFlyoutOnLeave = button:GetScript('OnLeave')
               end

               -- Identify sticky menus.
               if strfind(body, '%[sticky%]') then
                  body = strgsub(body, '%[sticky%]', '')
                  button.sticky = true
               end

               if strfind(body, '%[icon%]') then
                  body = strgsub(body, '%[icon%]', '')
               end

               body = strsub(body, e + 1)

               if not button.flyoutActions then
                  button.flyoutActions = {}
               end

               strsplit(body, ';', button.flyoutActions)

               if table.getn(button.flyoutActions) > 0 then
                  button.flyoutAction, button.flyoutActionType = GetFlyoutActionInfo(button.flyoutActions[1])
               end

               Flyout_UpdateFlyoutArrow(button)

               button:SetScript('OnLeave', FlyoutBarButton_OnLeave)
               button:SetScript('OnEnter', FlyoutBarButton_OnEnter)
            end
         end

      else
         -- Reset button to pre-Flyout condition.
         button.flyoutActionType = nil
         button.flyoutAction = nil
         if button.preFlyoutOnEnter then
            button:SetScript('OnEnter', button.preFlyoutOnEnter)
            button:SetScript('OnLeave', button.preFlyoutOnLeave)
            button.preFlyoutOnEnter = nil
            button.preFlyoutOnLeave = nil
         end
      end
   end
end

local function HandleEvent()
   if event == 'VARIABLES_LOADED' then
      if not Flyout_Config or (Flyout_Config['REVISION'] == nil or Flyout_Config['REVISION'] ~= revision) then
         Flyout_Config = {}
      end
      -- Initialize defaults if not present.
      for key, value in pairs(FLYOUT_DEFAULT_CONFIG) do
         if not Flyout_Config[key] then
            Flyout_Config[key] = value
         end
      end
   elseif event == 'ACTIONBAR_SLOT_CHANGED' then
      Flyout_Hide(true)  -- Keep sticky menus open.
      UpdateBarButton(arg1)
   elseif event == 'BAG_UPDATE' then
      -- 背包内容变化时清理缓存
      ClearItemCache()
      Flyout_Hide()
      Flyout_UpdateBars()
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
handler:RegisterEvent('BAG_UPDATE')
handler:SetScript('OnEvent', HandleEvent)

-- globals
function Flyout_OnClick(button)
   if not button or not button.flyoutActionType or not button.flyoutAction then
      return
   end

   if arg1 == nil or arg1 == 'LeftButton' then
      if button.flyoutActionType == 0 then
         CastSpell(button.flyoutAction, 'spell')
      elseif button.flyoutActionType == 1 then
         Flyout_ExecuteMacro(button.flyoutAction)
      elseif button.flyoutActionType == 2 then
         -- 使用背包中的物品
         local itemInfo = button.flyoutAction
         if itemInfo and itemInfo.bagIndex and itemInfo.slotIndex then
            UseContainerItem(itemInfo.bagIndex, itemInfo.slotIndex)
         end
      end

      Flyout_Hide(true)
   elseif arg1 == 'RightButton' and button.flyoutParent then
      local parent = button.flyoutParent
      local oldAction = parent.flyoutActions[1]
      local newAction = parent.flyoutActions[button:GetID()]
      if oldAction ~= newAction then
         local slot = ActionButton_GetPagedID(parent)
         local macro = GetActionText(slot)
         local name, icon, body, isLocal = GetMacroInfo(GetMacroIndexByName(macro))

         local as, ae = string.find(body, oldAction, 1, true)
         local bs, be = string.find(body, newAction, 1, true)
         if as and bs then
            if strfind(body, '%[icon%]') then
               local texture = button:GetNormalTexture():GetTexture()
               for i = 1, GetNumMacroIcons() do
                  if GetMacroIconInfo(i) == texture then
                     icon = i
                     break
                  end
               end
            end

            body =
               string.sub(body, 1, as - 1)
               .. newAction
               .. string.sub(body, ae + 1, bs - 1)
               .. oldAction
               .. string.sub(body, be + 1)

            EditMacro(GetMacroIndexByName(macro), macro, icon, body, isLocal)

            Flyout_Show(parent)
         end
      else
         button:SetChecked(0)
      end
   end
end

function Flyout_ExecuteMacro(macro)
   local _, _, body = GetMacroInfo(macro)
   local commands = strsplit(body, '\n')
   for i = 1, sizeof(commands) do
      ChatFrameEditBox:SetText(commands[i])
      ChatEdit_SendText(ChatFrameEditBox)
   end
end

function Flyout_Hide(keepOpenIfSticky)
   local i = 1
   local button = _G['FlyoutButton' .. i]
   while button do
      i = i + 1

      if not keepOpenIfSticky or (keepOpenIfSticky and not button.sticky) then
         button:Hide()
         button:GetNormalTexture():SetTexture(nil)
         button:GetPushedTexture():SetTexture(nil)
      end
      -- Un-highlight if no longer needed.
      if button.flyoutActionType ~= 0 or not IsCurrentCast(button.flyoutAction, 'spell') then
         button:SetChecked(false)
      end

      button = _G['FlyoutButton' .. i]
   end

   -- Restore arrow to original strata (it was moved to FULLSCREEN in Flyout_Show())
   if _G['FlyoutButton1'] and not _G['FlyoutButton1']:IsVisible() and _G['FlyoutButton1'].flyoutParent then
      local arrow = _G[_G['FlyoutButton1'].flyoutParent:GetName() .. 'FlyoutArrow']
      arrow:SetFrameStrata(arrow.flyoutOriginalStrata)
   end
end

-- Reusable variables for FlyoutBarButton_UpdateCooldown().
local cooldownStart, cooldownDuration, cooldownEnable

local function FlyoutBarButton_UpdateCooldown(button, reset)
   button = button or this

   if button.flyoutActionType == 0 then
      cooldownStart, cooldownDuration, cooldownEnable = GetSpellCooldown(button.flyoutAction, BOOKTYPE_SPELL)
      if cooldownStart > 0 and cooldownDuration > 0 then
         -- Start/Duration check is needed to get the shine animation.
         CooldownFrame_SetTimer(button.cooldown, cooldownStart, cooldownDuration, cooldownEnable)
      elseif reset then
         -- When switching flyouts, need to hide cooldown if it shouldn't be visible.
         button.cooldown:Hide()
      end
   elseif button.flyoutActionType == 2 then
      -- 处理物品冷却时间
      local itemInfo = button.flyoutAction
      if itemInfo and itemInfo.bagIndex and itemInfo.slotIndex then
         cooldownStart, cooldownDuration, cooldownEnable = GetContainerItemCooldown(itemInfo.bagIndex, itemInfo.slotIndex)
         if cooldownStart > 0 and cooldownDuration > 0 then
            CooldownFrame_SetTimer(button.cooldown, cooldownStart, cooldownDuration, cooldownEnable)
         elseif reset then
            button.cooldown:Hide()
         end
      else
         button.cooldown:Hide()
      end
   else
      button.cooldown:Hide()
   end
end

local function FlyoutButton_OnUpdate()
   -- Update tooltip.
   if GetMouseFocus() == this and (not this.lastUpdate or GetTime() - this.lastUpdate > 1) then
      this:GetScript('OnEnter')()
      this.lastUpdate = GetTime()
   end
   FlyoutBarButton_UpdateCooldown(this)
end

function Flyout_Show(button)
   local direction = GetFlyoutDirection(button)
   local size = Flyout_Config['BUTTON_SIZE']
   local offset = size

   -- Put arrow above the flyout buttons.
   _G[button:GetName() .. 'FlyoutArrow']:SetFrameStrata('FULLSCREEN')

   for i, n in button.flyoutActions do
      local b = _G['FlyoutButton' .. i]
      if not b then
         b = CreateFrame('CheckButton', 'FlyoutButton' .. i, UIParent, 'FlyoutButtonTemplate')
         b:SetID(i)
      end

      b.flyoutParent = button

      -- Things that only need to happen once.
      if not b.cooldown then
         b.cooldown = _G['FlyoutButton' .. i .. 'Cooldown']
         b:SetScript('OnUpdate', FlyoutButton_OnUpdate)
      end

      b.sticky = button.sticky
      local texture = nil

      b.flyoutAction, b.flyoutActionType = GetFlyoutActionInfo(n)

      if b.flyoutActionType == 0 then
         texture = GetSpellTexture(b.flyoutAction, 'spell')
      elseif b.flyoutActionType == 1 then
         _, texture = GetMacroInfo(b.flyoutAction)
      elseif b.flyoutActionType == 2 then
         -- 获取物品图标
         local itemInfo = b.flyoutAction
         if itemInfo and itemInfo.itemLink then
            texture, _, _, _, _ = GetContainerItemInfo(itemInfo.bagIndex, itemInfo.slotIndex)
         end
      end

      if texture then
         b:ClearAllPoints()
         b:SetWidth(size)
         b:SetHeight(size)
         b.cooldown:SetScale(size / b.cooldown:GetWidth())  -- Scale cooldown so it will stay centered on the button.
         b:SetBackdropColor(Flyout_Config['BORDER_COLOR'][1], Flyout_Config['BORDER_COLOR'][2], Flyout_Config['BORDER_COLOR'][3])
         b:Show()

         b:GetNormalTexture():SetTexture(texture)
         b:GetPushedTexture():SetTexture(texture)  -- Without this, icons disappear on click.

         -- 为物品按钮添加数量显示
         if b.flyoutActionType == 2 then
            if not b.countText then
               b.countText = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
               b.countText:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
            end
            
            local itemInfo = b.flyoutAction
            if itemInfo and itemInfo.itemLink then
               local itemName = string.match(itemInfo.itemLink, "%[(.+)%]")
               if itemName then
                  local totalCount = GetItemTotalCount(itemName)
                  if totalCount > 1 then
                     b.countText:SetText(totalCount)
                     b.countText:Show()
                  else
                     b.countText:Hide()
                  end
               end
            end
         else
            if b.countText then
               b.countText:Hide()
            end
         end

         -- Highlight professions and channeled casts.
         if b.flyoutActionType == 0 and IsCurrentCast(b.flyoutAction, 'spell') then
            b:SetChecked(true)
         end

         -- Force an instant update.
         this.lastUpdate = nil
         FlyoutBarButton_UpdateCooldown(b, true)

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

   local arrow = _G[button:GetName() .. 'FlyoutArrow']
   if not arrow then
      arrow = CreateFrame('Frame', button:GetName() .. 'FlyoutArrow', button)
      arrow:SetPoint('TOPLEFT', button)
      arrow:SetPoint('BOTTOMRIGHT', button)
      arrow.flyoutOriginalStrata = arrow:GetFrameStrata()
      arrow.texture = arrow:CreateTexture(arrow:GetName() .. 'Texture', 'ARTWORK')
      arrow.texture:SetTexture('Interface\\AddOns\\Flyout\\assets\\FlyoutButton')
   end

   arrow:Show()
   arrow.texture:ClearAllPoints()

   local arrowWideDimension = (button:GetWidth() or 36) * Flyout_Config['ARROW_SCALE']
   local arrowShortDimension = arrowWideDimension * ARROW_RATIO

   if direction == 'BOTTOM' then
      arrow.texture:SetWidth(arrowWideDimension)
      arrow.texture:SetHeight(arrowShortDimension)
      arrow.texture:SetTexCoord(0, 0.565, 0.315, 0)
      arrow.texture:SetPoint('BOTTOM', arrow, 0, -6)
   elseif direction == 'LEFT' then
      arrow.texture:SetWidth(arrowShortDimension)
      arrow.texture:SetHeight(arrowWideDimension)
      arrow.texture:SetTexCoord(0, 0.315, 0.375, 1)
      arrow.texture:SetPoint('LEFT', arrow, -6, 0)
   elseif direction == 'RIGHT' then
      arrow.texture:SetWidth(arrowShortDimension)
      arrow.texture:SetHeight(arrowWideDimension)
      arrow.texture:SetTexCoord(0.315, 0, 0.375, 1)
      arrow.texture:SetPoint('RIGHT', arrow, 6, 0)
   else
      arrow.texture:SetWidth(arrowWideDimension)
      arrow.texture:SetHeight(arrowShortDimension)
      arrow.texture:SetTexCoord(0, 0.565, 0, 0.315)
      arrow.texture:SetPoint('TOP', arrow, 0, 6)
   end
end

local Flyout_UseAction = UseAction
function UseAction(slot, checkCursor)
   Flyout_UseAction(slot, checkCursor)
   -- 临时取消宏触发直接使用第一个技能/宏/物品的功能，这个会被触发使用物品的BUG
   -- Flyout_OnClick(Flyout_GetActionButton(slot))
   -- Flyout_Hide()
   
   -- 只有当按钮有flyout配置时才处理
   local button = Flyout_GetActionButton(slot)
   if button and button.flyoutActions and table.getn(button.flyoutActions) > 0 then
      -- 不自动执行flyout点击，只隐藏飞出菜单
      Flyout_Hide()
   end
end
