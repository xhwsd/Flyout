
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

local ARROW_RATIO = 0.6  -- 高度与宽度之比。

--[[ 帮助函数 ]]

---字符串修剪
---@param str string 字符串
---@return string trimmed 修剪后的字符串
local function strtrim(str)
	local _, e = string.find(str, "^%s*")
	local s, _ = string.find(str, "%s*$", e + 1)
	return string.sub(str, e + 1, s - 1)
end

---表清空
---@param tbl table 表
local function tblclear(tbl)
	if type(tbl) ~= "table" then
		return
	end

	-- 先清空数组类型的表，确保 table.insert 从索引 1 开始。
	for index = table.getn(tbl), 1, -1 do
		table.remove(tbl, index)
	end

	-- 删除所有剩余的关联表元素。
	for index in next, tbl do
		rawset(tbl, index, nil)
	end
end

-- 当不使用fillTable参数时，strsplit() 的可重用表。
local strSplitReturn = {} 

---字符串分割
---@param str string 字符串
---@param delimiter string 分隔符
---@param fillTable table? 填充表
---@return table tbl 分割后的表
local function strsplit(str, delimiter, fillTable)
	fillTable = fillTable or strSplitReturn
	tblclear(fillTable)
	---@diagnostic disable-next-line
	string.gsub(str, "([^" .. delimiter .. "]+)", function(value)
		table.insert(fillTable, strtrim(value))
	end)
	return fillTable
end

---名称到法术插槽索引
---@param name string 名称
---@return number index 索引
local function GetSpellSlotByName(name)
	name = string.lower(name)
	local start, _, rank = string.find(name, "%(%s*等级%s+(%d+)%s*%)")
	if start then 
		name = (start > 1) and strtrim(string.sub(name, 1, start - 1)) or ""
	end

	-- 遍历法术标签页
	for tabIndex = GetNumSpellTabs(), 1, -1 do
		-- 遍历标签页下法术
		local _, _, offset, count = GetSpellTabInfo(tabIndex)
		for index = offset + count, offset + 1, -1 do
			local spell, subSpell = GetSpellName(index, "spell")
			spell = string.lower(spell)
			if name == spell and (not rank or subSpell == "等级 " .. rank) then
				return index
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
---@param name string 链接或名称
---@return number? slot
local function FindInventory(name)
	if not name or name == "" then
		return
	end

	-- 链接到名称
	name = string.lower(ItemLinkToName(name))

	-- 遍历装备
	for index = 1, 23 do
		local link = GetInventoryItemLink("player", index)
		if link then
			if name == string.lower(ItemLinkToName(link)) then
				return index
			end
		end
	end
end

---查找包中物品
---@param name string 名称或链接
---@return number bag
---@return number slot
local function FindItem(name)
	if not name or name == "" then
		return
	end

	-- 链接到物品名称
	name = string.lower(ItemLinkToName(name))

	-- 遍历背包物品
	for bag = 0, NUM_BAG_FRAMES do
		for slot = 1, MAX_CONTAINER_ITEMS do
			local link = GetContainerItemLink(bag, slot)
			if link and name == string.lower(ItemLinkToName(link)) then
				return bag, slot
			end
		end
	end
end

---取弹出动作信息
---@param action string 动作
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
	-- 覆盖方向
	if Flyout_Config["DIRECTION_OVERRIDE"] then
		return Flyout_Config["DIRECTION_OVERRIDE"]
	end
	
	-- 原始动态计数
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
	return direction
end

---弹出栏按钮鼠标离开事件
local function FlyoutBarButton_OnLeave()
	this.updateTooltip = nil
	GameTooltip:Hide()

	local focus = GetMouseFocus()
	if focus and not string.find(focus:GetName(), "Flyout") then
		Flyout_Hide()
	end
end

---弹出栏按钮鼠标进入事件
local function FlyoutBarButton_OnEnter()
	ActionButton_SetTooltip()
	Flyout_Show(this)
end

---更新弹出栏按钮
---@param slot number 插槽
local function UpdateBarButton(slot)
	-- 取动作按钮
	local button = Flyout_GetActionButton(slot)
	if button then
		-- 隐藏箭头
		local arrow = getglobal(button:GetName() .. "FlyoutArrow")
		if arrow then
			arrow:Hide()
		end

		-- 非空插槽
		if HasAction(slot) then
			button.sticky = false
			-- 是否是宏插槽
			local macro = GetActionText(slot)
			if macro then
				-- 在超级宏加载后，执行 GetMacroInfo 返回 body 可能为空 xhwsd@qq.com 2025-10-21
				local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
				if body then
					-- 宏内容是否是 /flyout 开头
					local s, e = string.find(body, "/flyout")
					if s and s == 1 and e == 7 then
						if not button.preFlyoutOnEnter then
							button.preFlyoutOnEnter = button:GetScript("OnEnter")
							button.preFlyoutOnLeave = button:GetScript("OnLeave")
						end

						-- 粘性菜单
						if string.find(body, "%[sticky%]") then
							body = string.gsub(body, "%[sticky%]", "")
							button.sticky = true
						end

						-- 图标菜单
						if string.find(body, "%[icon%]") then
							body = string.gsub(body, "%[icon%]", "")
						end

						-- 分割弹出项
						body = string.sub(body, e + 1)
						if not button.flyoutActions then
							button.flyoutActions = {}
						end
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
			end
		else
			-- 重置按钮到飞出前状态。
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

		-- 初始化默认值
		for key, value in pairs(FLYOUT_DEFAULT_CONFIG) do
			if not Flyout_Config[key] then
				Flyout_Config[key] = value
			end
		end
	elseif event == "ACTIONBAR_SLOT_CHANGED" then
		-- 插槽内容改变
		Flyout_Hide(true) -- 保持粘性菜单打开。
		---@diagnostic disable-next-line
		UpdateBarButton(arg1)
	elseif event == "PLAYER_ENTERING_WORLD" or event == "ACTIONBAR_PAGE_CHANGED" then
		-- 当玩家登录时 动作条页面改变
		Flyout_Hide()
		Flyout_UpdateBars()
	end
end)

--[[ 全局 ]]

---单击事件
---@param button Frame|table 按钮
function Flyout_OnClick(button)
	if not button or not button.flyoutActionType or not button.flyoutAction then
		return
	end

	if arg1 == nil or arg1 == "LeftButton" then
		-- 左键单击
		if button.flyoutActionType == 0 then
			-- 法术
			CastSpell(button.flyoutAction, "spell")
		elseif button.flyoutActionType == 1 then
			-- 普通宏
			Flyout_ExecuteMacro(button.flyoutAction)
		elseif button.flyoutActionType == 2 then
			-- 物品
			UseContainerItem(button.flyoutAction[1], button.flyoutAction[2])
		elseif button.flyoutActionType == 3 then
			-- 装备
			UseInventoryItem(button.flyoutAction)
		elseif button.flyoutActionType == 4 then
			-- 超级宏
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
			-- print("1.icon=", icon)
			local as, ae = string.find(body, oldAction, 1, true)
			local bs, be = string.find(body, newAction, 1, true)
			if as and bs then
				-- 法术纹理到图标索引
				if string.find(body, "%[icon%]") then
					local texture = button:GetNormalTexture():GetTexture()
					-- print("texture=", icon)
					for index = 1, GetNumMacroIcons() do
						if GetMacroIconInfo(index) == texture then
							icon = index
							break
						end
					end
				end
				-- print("2.icon=", icon)
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

---执行普通宏
---@param macro string|number 宏名称或索引
function Flyout_ExecuteMacro(macro)
	local _, _, body = GetMacroInfo(macro)
	local commands = strsplit(body, "\n")
	for index = 1, table.getn(commands) do
		ChatFrameEditBox:SetText(commands[index])
		ChatEdit_SendText(ChatFrameEditBox)
	end
end

---隐藏弹出按钮
function Flyout_Hide(keepOpenIfSticky)
	---遍历所有弹出按钮
	local index = 1
	local button = getglobal("FlyoutButton" .. index)
	while button do
		if not keepOpenIfSticky or (keepOpenIfSticky and not button.sticky) then
			button:Hide()
			button:GetNormalTexture():SetTexture(nil)
			button:GetPushedTexture():SetTexture(nil)
		end

		-- Un-highlight if no longer needed.
		if button.flyoutActionType ~= 0 or not IsCurrentCast(button.flyoutAction, "spell") then
			button:SetChecked(false)
		end

		-- 取下个按钮
		index = index + 1
		button = getglobal("FlyoutButton" .. index)
	end

	-- 将箭头恢复到原始图层（在 Flyout_Show() 中移动到 FULLSCREEN ）
	button = getglobal("FlyoutButton1")
	if button and not button:IsVisible() and button.flyoutParent then
		local arrow = getglobal(button.flyoutParent:GetName() .. "FlyoutArrow")
		arrow:SetFrameStrata(arrow.flyoutOriginalStrata)
	end
end

---弹出栏按钮更新冷却时间
---@param button Frame|table 按钮
---@param reset? boolean 重置
local function FlyoutBarButton_UpdateCooldown(button, reset)
	button = button or this

	if button.flyoutActionType == 0 then
		-- 法术
		local start, duration, enable = GetSpellCooldown(button.flyoutAction, BOOKTYPE_SPELL)
		if start > 0 and duration > 0 then
			CooldownFrame_SetTimer(button.cooldown, start, duration, enable)
		elseif reset then
			button.cooldown:Hide()
		end
	elseif button.flyoutActionType == 2 then
		-- 物品
		local start, duration, enable = GetContainerItemCooldown(button.flyoutAction[1], button.flyoutAction[2])
		if start > 0 and duration > 0 then
			CooldownFrame_SetTimer(button.cooldown, start, duration, enable)
		elseif reset then
			button.cooldown:Hide()
		end
	elseif button.flyoutActionType == 3 then
		-- 装备
		local start, duration, enable = GetInventoryItemCooldown("player", button.flyoutAction)
		if start > 0 and duration > 0 then
			CooldownFrame_SetTimer(button.cooldown, start, duration, enable)
		elseif reset then
			button.cooldown:Hide()
		end
	else
		button.cooldown:Hide()
	end
end

---弹出按钮更新
local function FlyoutButton_OnUpdate()
	-- 更新工具提示
	if GetMouseFocus() == this and (not this.lastUpdate or GetTime() - this.lastUpdate > 1) then
		this:GetScript("OnEnter")()
		this.lastUpdate = GetTime()
	end

	-- 更新冷却时间
	FlyoutBarButton_UpdateCooldown(this)
end

---显示
---@param button Frame|table 按钮
function Flyout_Show(button)
	local direction = GetFlyoutDirection(button)
	local size = Flyout_Config["BUTTON_SIZE"]
	local offset = size

	-- 将箭头放在弹出按钮上方。
	getglobal(button:GetName() .. "FlyoutArrow"):SetFrameStrata("FULLSCREEN")

	for index, action in button.flyoutActions do
		local item = getglobal("FlyoutButton" .. index)
		if not item then
			item = CreateFrame("CheckButton", "FlyoutButton" .. index, UIParent, "FlyoutButtonTemplate")
			item:SetID(index)
		end

		item.flyoutParent = button

		-- 仅需执行一次
		if not item.cooldown then
			item.cooldown = getglobal("FlyoutButton" .. index .. "Cooldown")
			item:SetScript("OnUpdate", FlyoutButton_OnUpdate)
		end

		item.sticky = button.sticky
		item.flyoutAction, item.flyoutActionType = GetFlyoutActionInfo(action)
		
		local texture = nil
		if item.flyoutActionType == 0 then
			-- 法术
			texture = GetSpellTexture(item.flyoutAction, "spell")
		elseif item.flyoutActionType == 1 then
			-- 普通宏
			_, texture = GetMacroInfo(item.flyoutAction)
		elseif item.flyoutActionType == 2 then
			-- 物品
			texture = GetContainerItemInfo(item.flyoutAction[1], item.flyoutAction[2])
		elseif item.flyoutActionType == 3 then
			-- 装备
			texture = GetInventoryItemTexture("player", item.flyoutAction)
		elseif item.flyoutActionType == 4 then
			-- 超级宏
			texture = GetSuperMacroInfo(b.flyoutAction, "texture")
		end

		if texture then
			item:ClearAllPoints()
			---@diagnostic disable-next-line
			item:SetWidth(size)
			---@diagnostic disable-next-line
			item:SetHeight(size)

			-- 调整冷却时间，使其保持在按钮的中心位置。
			item.cooldown:SetScale(size / item.cooldown:GetWidth())
			item:SetBackdropColor(Flyout_Config["BORDER_COLOR"][1], Flyout_Config["BORDER_COLOR"][2], Flyout_Config["BORDER_COLOR"][3])
			item:Show()

			item:GetNormalTexture():SetTexture(texture)
			-- 如果没有这个，点击图标就会消失。
			item:GetPushedTexture():SetTexture(texture)

			-- 高亮当前施法
			if item.flyoutActionType == 0 and IsCurrentCast(item.flyoutAction, "spell") then
				item:SetChecked(true)
			end

			-- 强制立即更新。
			this.lastUpdate = nil
			FlyoutBarButton_UpdateCooldown(item, true)

			if direction == "BOTTOM" then
				item:SetPoint("BOTTOM", button, 0, -offset)
			elseif direction == "LEFT" then
				item:SetPoint("LEFT", button, -offset, 0)
			elseif direction == "RIGHT" then
				item:SetPoint("RIGHT", button, offset, 0)
			else
				item:SetPoint("TOP", button, 0, offset)
			end

			offset = offset + size
		end
	end
end

---取操作按钮
---@param action integer 操作
---@return Frame|table 按钮
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

---更新动作栏
function Flyout_UpdateBars()
	for index = 1, 120 do
		UpdateBarButton(index)
	end
end

---更新弹出箭头
---@param button Frame|table 按钮
function Flyout_UpdateFlyoutArrow(button)
	if not button then
		return
	end

	-- 取箭头
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

-- 记录原`UseAction`
local oldUseAction = UseAction

---覆盖全局`UseAction`函数
---@param slot number 槽位
---@param checkCursor boolean 检查鼠标
---@param onSelf boolean 自身
function UseAction(slot, checkCursor, onSelf)
	oldUseAction(slot, checkCursor, onSelf)
	Flyout_OnClick(Flyout_GetActionButton(slot))
	Flyout_Hide()
end
