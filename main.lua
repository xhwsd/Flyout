-- 原始UseAction
local originalUseAction = UseAction

local revision = 1.0

local bars = {
   "Action",
   "BonusAction",
   "MultiBarBottomLeft",
   "MultiBarBottomRight",
   "MultiBarRight",
   "MultiBarLeft"
}

FLYOUT_DEFAULT_CONFIG = {
   ["REVISION"] = revision,
   ["BUTTON_SIZE"] = 28,
   ["BORDER_COLOR"] = { 0, 0, 0 },
   ["ARROW_SCALE"] = 5 / 9,
   ["DIRECTION_OVERRIDE"] = nil, 
}

-- 箭头高度与宽度的比例。
local ARROW_RATIO = 0.6 

--[[ 辅助函数 ]]

local function strtrim(str)
   local _, e = string.find(str, "^%s*")
   local s, _ = string.find(str, "%s*$", e + 1)
   return string.sub(str, e + 1, s - 1)
end

local function tblclear(tbl)
	if type(tbl) ~= "table" then
		return
	end

	-- 首先清除数组类型的表，因此table.insert将从1开始。
	for index = table.getn(tbl), 1, -1 do
		table.remove(tbl, index)
	end

	-- table.remove 不会删除关联表中的元素，因此我们必须手动删除它们。
	for key in next, tbl do
		rawset(tbl, key, nil)
	end
end

---字符串分割
---@param str string 字符串
---@param delimiter string 分隔符
---@param fillTable table? 填充表
---@return table tbl 填充表
local function strsplit(str, delimiter, fillTable)
   fillTable = fillTable or {}
   tblclear(fillTable)
   string.gsub(str, "([^" .. delimiter .. "]+)", function(value)
      table.insert(fillTable, strtrim(value))
   end)
   return fillTable
end

---法术插槽到名称
---参考来源：https://github.com/DanielAdolfsson/CleverMacro
---@param name string 法术名称
---@return number index 法术索引
local function GetSpellSlotByName(name)
   name = string.lower(name)
   local position, _, rank = string.find(name, "%(%s*等级%s+(%d+)%s*%)")
   if position then 
      name = (position > 1) and strtrim(string.sub(name, 1, position - 1)) or ""
   end

   for tabIndex = GetNumSpellTabs(), 1, -1 do
      local _, _, offset, count = GetSpellTabInfo(tabIndex)
      for spellIndex = offset + count, offset + 1, -1 do
         local spellName, spellRank = GetSpellName(spellIndex, "spell")
         spellName = string.lower(spellName)
         if name == spellName and (not rank or spellRank == "等级 " .. rank) then
            return spellIndex
         end
      end
   end
end

---链接到名称
---@param link string 链接
---@return string name 名称
local function ItemLinkToName(link)
	if link and link ~= "" then
      ---@diagnostic disable-next-line
		return string.gsub(link, "^.*%[(.*)%].*$", "%1")
	end
end

---查找身上装备
---@param item string 物品链接或物品名称
---@return number? slot
local function FindInventory(item)
   if not item or item == "" then
      return
   end

   -- 链接到装备名称
	item = string.lower(ItemLinkToName(item))

   -- 遍历装备
	for index = 1, 23 do
		local link = GetInventoryItemLink("player", index)
		if link then
			if item == string.lower(ItemLinkToName(link)) then
				return index
			end
		end
	end
end

---查找包中物品
---@param item string 物品链接或物品名称
---@return number bag
---@return number slot
local function FindItem(item)
   if not item or item == "" then
      return
   end

   -- 链接到物品名称
	item = string.lower(ItemLinkToName(item))

   -- 遍历背包物品
	for bag = 0, NUM_BAG_FRAMES do
		for slot = 1, MAX_CONTAINER_ITEMS do
			local link = GetContainerItemLink(bag, slot)
			if link and item == string.lower(ItemLinkToName(link)) then
				return bag, slot
			end
		end
	end
end

---取弹出动作信息
---@param action string 动作内容
---@return any value 动作值；因动作类型不同而不同
---@return number actionType 动作类型；可选值：0.法术、1.普通宏、2.物品、3.装备、4.超级宏
local function GetFlyoutActionInfo(action)
   if not action or action == "" then
      return
   end

   -- 法术
   local spellName = GetSpellSlotByName(action)
   if spellName then
      return spellName, 0
   end

   -- 普通宏
   local macroIndex = GetMacroIndexByName(action)
   if macroIndex > 0 then
      return macroIndex, 1
   end

   -- 物品
   local bag, slot = FindItem(action)
   if bag and slot then
      -- 物品
      return {bag, slot}, 2
   end

   -- 装备
   local slotIndex = FindInventory(action)
   if slotIndex then
      return slotIndex, 3
   end

   -- 超级宏
   if GetSuperMacroInfo then
      local macroName = GetSuperMacroInfo(action, "name")
      if macroName then
         return macroName, 4
      end
   end
end

---取弹出方向
---@param button Frame 按钮
---@return string direction 方向
local function GetFlyoutDirection(button)
   -- 检查是否有方向覆盖
   if Flyout_Config["DIRECTION_OVERRIDE"] then
      --print("Using override direction: " .. tostring(Flyout_Config["DIRECTION_OVERRIDE"]))
      return Flyout_Config["DIRECTION_OVERRIDE"]
   end
   
   -- Original dynamic calculation code
   local horizontal = false
   local bar = button:GetParent()
   if bar:GetWidth() > bar:GetHeight() then
      horizontal = true
   end

   local direction = horizontal and "TOP" or "LEFT"

   local centerX, centerY = button:GetCenter()
   if centerX and centerY then
      if horizontal then
         local halfScreen = GetScreenHeight() / 2
         direction = centerY < halfScreen and "TOP" or "BOTTOM"
      else
         local halfScreen = GetScreenWidth() / 2
         direction = centerX > halfScreen and "LEFT" or "RIGHT"
      end
   end
   -- print("Flyout direction: " .. tostring(direction))
   return direction
end

local function FlyoutBarButton_OnLeave()
   this.updateTooltip = nil
   GameTooltip:Hide()

   local focus = GetMouseFocus()
   if focus and not string.find(focus:GetName(), "Flyout") then
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
      local arrow = getglobal(button:GetName() .. "FlyoutArrow")
      if arrow then
         arrow:Hide()
      end

      if HasAction(slot) then
         -- 非空插槽
         button.sticky = false

         local macro = GetActionText(slot)
         if macro then
            -- 是宏插槽
            local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
            local s, e = string.find(body, "/flyout")
            if s and s == 1 and e == 7 then
               if not button.preFlyoutOnEnter then
                  button.preFlyoutOnEnter = button:GetScript("OnEnter")
                  button.preFlyoutOnLeave = button:GetScript("OnLeave")
               end

               -- Identify sticky menus.
               if string.find(body, "%[sticky%]") then
                  body = string.gsub(body, "%[sticky%]", "")
                  button.sticky = true
               end

               if string.find(body, "%[icon%]") then
                  body = string.gsub(body, "%[icon%]", "")
               end

               body = string.sub(body, e + 1)

               if not button.flyoutActions then
                  button.flyoutActions = {}
               end

               -- 分割项
               strsplit(body, ";", button.flyoutActions)

               if table.getn(button.flyoutActions) > 0 then
                  -- 使用第一个项为动作和类型
                  button.flyoutAction, button.flyoutActionType = GetFlyoutActionInfo(button.flyoutActions[1])
               end

               Flyout_UpdateFlyoutArrow(button)

               button:SetScript("OnLeave", FlyoutBarButton_OnLeave)
               button:SetScript("OnEnter", FlyoutBarButton_OnEnter)
            end
         end

      else
         -- 将按钮重置为弹出前状态。
         button.flyoutActionType = nil
         button.flyoutAction = nil
         if button.preFlyoutOnEnter then
            button:SetScript("OnEnter", button.preFlyoutOnEnter)
            button:SetScript("OnLeave", button.preFlyoutOnLeave)
            button.preFlyoutOnEnter = nil
            button.preFlyoutOnLeave = nil
         end
      end
   end
end

local handler = CreateFrame("Frame")
-- 变量载入 https://warcraft.wiki.gg/wiki/VARIABLES_LOADED
handler:RegisterEvent("VARIABLES_LOADED")
-- 插槽内容改变 https://warcraft.wiki.gg/wiki/ACTIONBAR_SLOT_CHANGED
handler:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
-- 当玩家登录时 https://warcraft.wiki.gg/wiki/PLAYER_ENTERING_WORLD
handler:RegisterEvent("PLAYER_ENTERING_WORLD")
-- 动作条页面改变 https://warcraft.wiki.gg/wiki/ACTIONBAR_PAGE_CHANGED
handler:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
handler:SetScript("OnEvent", function()
   if event == "VARIABLES_LOADED" then
      -- 变量载入
      if not Flyout_Config or (Flyout_Config["REVISION"] == nil or Flyout_Config["REVISION"] ~= revision) then
         Flyout_Config = {}
      end

      -- 如果不存在，则初始化默认值。
      for key, value in pairs(FLYOUT_DEFAULT_CONFIG) do
         if not Flyout_Config[key] then
            Flyout_Config[key] = value
         end
      end
   elseif event == "ACTIONBAR_SLOT_CHANGED" then
      -- 插槽内容改变
      Flyout_Hide(true)  -- Keep sticky menus open.
      UpdateBarButton(arg1)
   else
      -- 当玩家登录时、动作条页面改变
      Flyout_Hide()
      Flyout_UpdateBars()
   end
end)

--[[ 全局 ]] 

function Flyout_OnClick(button)
   if not button or not button.flyoutActionType or not button.flyoutAction then
      return
   end

   if arg1 == nil or arg1 == "LeftButton" then
      -- 左键单击
      if button.flyoutActionType == 0 then
         -- 使用法术
         CastSpell(button.flyoutAction, "spell")
      elseif button.flyoutActionType == 1 then
         -- 执行普通宏
         Flyout_ExecuteMacro(button.flyoutAction)
      elseif button.flyoutActionType == 2 then
         -- 使用包中物品
         UseContainerItem(button.flyoutAction[1], button.flyoutAction[2])
      elseif button.flyoutActionType == 3 then
         -- 使用身上装备
         UseInventoryItem(button.flyoutAction)
      elseif button.flyoutActionType == 4 then
         -- 使用超级宏
         RunSuperMacro(button.flyoutAction)
      end

      Flyout_Hide(true)
   elseif arg1 == "RightButton" and button.flyoutParent then
      -- 右键单击
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
            if string.find(body, "%[icon%]") then
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
   local commands = strsplit(body, "\n")
   for index = 1, table.getn(commands) do
      ChatFrameEditBox:SetText(commands[index])
      ChatEdit_SendText(ChatFrameEditBox)
   end
end

function Flyout_Hide(keepOpenIfSticky)
   local index = 1
   local button = getglobal("FlyoutButton" .. index)
   while button do
      index = index + 1

      if not keepOpenIfSticky or (keepOpenIfSticky and not button.sticky) then
         button:Hide()
         button:GetNormalTexture():SetTexture(nil)
         button:GetPushedTexture():SetTexture(nil)
      end

      -- 如果不再需要，则取消突出显示。
      if button.flyoutActionType ~= 0 or not IsCurrentCast(button.flyoutAction, "spell") then
         button:SetChecked(false)
      end

      button = getglobal("FlyoutButton" .. index)
   end

   -- 将箭头恢复到原始图层（在Flyout_Show（）中移动到FULLSCREEN）
   button = getglobal("FlyoutButton1")
   if button and not button:IsVisible() and button.flyoutParent then
      local arrow = getglobal(button.flyoutParent:GetName() .. "FlyoutArrow")
      arrow:SetFrameStrata(arrow.flyoutOriginalStrata)
   end
end

local function FlyoutBarButton_UpdateCooldown(button, reset)
   button = button or this

   if button.flyoutActionType == 0 then
      local cooldownStart, cooldownDuration, cooldownEnable = GetSpellCooldown(button.flyoutAction, BOOKTYPE_SPELL)
      if cooldownStart > 0 and cooldownDuration > 0 then
         -- Start/Duration check is needed to get the shine animation.
         CooldownFrame_SetTimer(button.cooldown, cooldownStart, cooldownDuration, cooldownEnable)
      elseif reset then
         -- When switching flyouts, need to hide cooldown if it shouldn"t be visible.
         button.cooldown:Hide()
      end
   else
      button.cooldown:Hide()
   end
end

local function FlyoutButton_OnUpdate()
   -- 更新工具提示。
   if GetMouseFocus() == this and (not this.lastUpdate or GetTime() - this.lastUpdate > 1) then
      this:GetScript("OnEnter")()
      this.lastUpdate = GetTime()
   end
   FlyoutBarButton_UpdateCooldown(this)
end

function Flyout_Show(button)
   local direction = GetFlyoutDirection(button)
   local size = Flyout_Config["BUTTON_SIZE"]
   local offset = size

   -- 将箭头放在弹出按钮上方。
   getglobal(button:GetName() .. "FlyoutArrow"):SetFrameStrata("FULLSCREEN")

   for i, n in button.flyoutActions do
      local b = getglobal("FlyoutButton" .. i)
      if not b then
         b = CreateFrame("CheckButton", "FlyoutButton" .. i, UIParent, "FlyoutButtonTemplate")
         b:SetID(i)
      end

      b.flyoutParent = button

      -- Things that only need to happen once.
      if not b.cooldown then
         b.cooldown = getglobal("FlyoutButton" .. i .. "Cooldown")
         b:SetScript("OnUpdate", FlyoutButton_OnUpdate)
      end

      b.sticky = button.sticky
      local texture = nil

      b.flyoutAction, b.flyoutActionType = GetFlyoutActionInfo(n)
      if b.flyoutActionType == 0 then
         -- 法术
         texture = GetSpellTexture(b.flyoutAction, "spell")
      elseif b.flyoutActionType == 1 then
         -- 普通宏
         _, texture = GetMacroInfo(b.flyoutAction)
      elseif b.flyoutActionType == 2 then
         -- 物品
         texture = GetContainerItemInfo(b.flyoutAction[1], b.flyoutAction[2])
      elseif b.flyoutActionType == 3 then
         -- 装备
         texture = GetInventoryItemTexture("player", b.flyoutAction)
      elseif b.flyoutActionType == 4 then
         -- 超级宏
         texture = GetSuperMacroInfo(b.flyoutAction, "texture")
      end

      if texture then
         b:ClearAllPoints()
         b:SetWidth(size)
         b:SetHeight(size)
         b.cooldown:SetScale(size / b.cooldown:GetWidth())  -- Scale cooldown so it will stay centered on the button.
         b:SetBackdropColor(Flyout_Config["BORDER_COLOR"][1], Flyout_Config["BORDER_COLOR"][2], Flyout_Config["BORDER_COLOR"][3])
         b:Show()

         b:GetNormalTexture():SetTexture(texture)
         b:GetPushedTexture():SetTexture(texture)  -- Without this, icons disappear on click.

         -- Highlight professions and channeled casts.
         if b.flyoutActionType == 0 and IsCurrentCast(b.flyoutAction, "spell") then
            b:SetChecked(true)
         end

         -- Force an instant update.
         this.lastUpdate = nil
         FlyoutBarButton_UpdateCooldown(b, true)

         if direction == "BOTTOM" then
            b:SetPoint("BOTTOM", button, 0, -offset)
         elseif direction == "LEFT" then
            b:SetPoint("LEFT", button, -offset, 0)
         elseif direction == "RIGHT" then
            b:SetPoint("RIGHT", button, offset, 0)
         else
            b:SetPoint("TOP", button, 0, offset)
         end

         offset = offset + size
      end
   end
end

---取动作按钮
---@param action number 动作
---@return Frame|table|nil button 按钮
function Flyout_GetActionButton(action)
   for barIndex = 1, table.getn(bars) do
      for buttonIndex = 1, 12 do
         local button = getglobal(bars[barIndex] .. "Button" .. buttonIndex)
         local slot = ActionButton_GetPagedID(button)
         if slot == action and button:IsVisible() then
            return button
         end
      end
   end
end

function Flyout_UpdateBars()
   for index = 1, 120 do
      UpdateBarButton(index)
   end
end

function Flyout_UpdateFlyoutArrow(button)
   if not button then
      return
   end

   local arrow = getglobal(button:GetName() .. "FlyoutArrow")
   if not arrow then
      arrow = CreateFrame("Frame", button:GetName() .. "FlyoutArrow", button)
      arrow:SetPoint("TOPLEFT", button)
      arrow:SetPoint("BOTTOMRIGHT", button)
      arrow.flyoutOriginalStrata = arrow:GetFrameStrata()
      arrow.texture = arrow:CreateTexture(arrow:GetName() .. "Texture", "ARTWORK")
      arrow.texture:SetTexture("Interface\\AddOns\\Flyout\\assets\\FlyoutButton")
   end

   arrow:Show()
   arrow.texture:ClearAllPoints()

   local arrowWideDimension = (button:GetWidth() or 36) * Flyout_Config["ARROW_SCALE"]
   local arrowShortDimension = arrowWideDimension * ARROW_RATIO

   local direction = GetFlyoutDirection(button)
   if direction == "BOTTOM" then
      arrow.texture:SetWidth(arrowWideDimension)
      arrow.texture:SetHeight(arrowShortDimension)
      arrow.texture:SetTexCoord(0, 0.565, 0.315, 0)
      arrow.texture:SetPoint("BOTTOM", arrow, 0, -6)
   elseif direction == "LEFT" then
      arrow.texture:SetWidth(arrowShortDimension)
      arrow.texture:SetHeight(arrowWideDimension)
      arrow.texture:SetTexCoord(0, 0.315, 0.375, 1)
      arrow.texture:SetPoint("LEFT", arrow, -6, 0)
   elseif direction == "RIGHT" then
      arrow.texture:SetWidth(arrowShortDimension)
      arrow.texture:SetHeight(arrowWideDimension)
      arrow.texture:SetTexCoord(0.315, 0, 0.375, 1)
      arrow.texture:SetPoint("RIGHT", arrow, 6, 0)
   else
      arrow.texture:SetWidth(arrowWideDimension)
      arrow.texture:SetHeight(arrowShortDimension)
      arrow.texture:SetTexCoord(0, 0.565, 0, 0.315)
      arrow.texture:SetPoint("TOP", arrow, 0, 6)
   end
end

---挂接UseAction
---@param slot number 动作槽位
---@param checkCursor boolean 是否检查光标
function Flyout_UseAction(slot, checkCursor)
   originalUseAction(slot, checkCursor)
   Flyout_OnClick(Flyout_GetActionButton(slot))
   Flyout_Hide()
end
UseAction = Flyout_UseAction