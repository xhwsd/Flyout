local _G = getfenv(0)

local Config = {
    COMMAND = '/flyout',
    MAX_BUTTONS = 12,
    BUTTON_SIZE = 30,
    DELIMITER = ';',
}
local ActionBars = { 'Action', 'BonusAction', 'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft' }
local Active = nil

-- placeholder slash command
SLASH_FLYOUT1 = Config.COMMAND
SlashCmdList['FLYOUT'] = function()
    return nil
end

local function strtrim(str)
    local _, e = string.find(str, "^%s*")
    local s, _ = string.find(str, "%s*$", e + 1)
    return string.sub(str, e + 1, s - 1)
end

local function strsplit(str, delimiter)
    local t = {}
    gsub(str, '([^' .. delimiter .. ']+)',
        function(value)
            table.insert(t, strtrim(value))
        end
    )
    return t
end

-- credit: https://github.com/DanielAdolfsson/CleverMacro
local function GetSpellSlotByName(name)
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

local function GetActionButton(action)
	for _, bar in pairs(ActionBars) do
		for i = 1, 12 do
			local button = _G[bar .. "Button" .. i]
			local slot = ActionButton_GetPagedID(button)
			if slot == action then
				return button
			end
		end
	end
end

local function GetFlyoutDirection(button)
    local isHorizontal = false
    local bar = button:GetParent()
    if bar:GetWidth() > bar:GetHeight() then
        isHorizontal = true
    end

    local direction = isHorizontal and 'TOP' or 'LEFT'

    local centerX, centerY = button:GetCenter()
    if centerX and centerY then
        if isHorizontal then
            local halfScreen = GetScreenHeight() / 2
            direction = centerY < halfScreen and 'TOP' or 'BOTTOM'
        else
            local halfScreen = GetScreenWidth() / 2
            direction = centerX > halfScreen and 'LEFT' or 'RIGHT'
        end
    end
    return direction
end

local function UpdateFlyoutArrow(button)
    if not button then return end

    local direction = GetFlyoutDirection(button)

    button.arrow = _G[button:GetName() .. 'FlyoutArrow'] or button:CreateTexture(button:GetName() .. 'FlyoutArrow', 'OVERLAY')
    button.arrow:Show()
    button.arrow:ClearAllPoints()
    button.arrow:SetTexture('Interface\\AddOns\\Flyout\\assets\\FlyoutButton')
    
    if direction == 'BOTTOM' then
        button.arrow:SetHeight(12)
        button.arrow:SetWidth(20)
        button.arrow:SetTexCoord(0.53125, 0.8125, 0.375, 0)
        button.arrow:SetPoint('BOTTOM', button, 0, -5)

    elseif direction == 'LEFT' then
        button.arrow:SetHeight(20)
        button.arrow:SetWidth(12)
        button.arrow:SetTexCoord(0.53125, 0.703125, 0.375, 1)
        button.arrow:SetPoint('LEFT', button, -5, 0)

    elseif direction == 'RIGHT' then
        button.arrow:SetHeight(20)
        button.arrow:SetWidth(12)
        button.arrow:SetTexCoord(0.703125, 0.53125, 0.375, 1)
        button.arrow:SetPoint('RIGHT', button, 5, 0)

    else
        button.arrow:SetHeight(12)
        button.arrow:SetWidth(20)
        button.arrow:SetTexCoord(0.53125, 0.8125, 0, 0.375)
        button.arrow:SetPoint('TOP', button, 0, 5)
    end
end

local function HideFlyout()
    for i = 1, Config.MAX_BUTTONS do
        local button = _G['FlyoutButton' .. i]
        if button then
            button:SetChecked(false)
            button:Hide()
            _G[button:GetName() .. 'NormalTexture']:SetTexture(nil)

            Active = nil
        end
    end
end

local _UseAction = UseAction
function UseAction(slot, checkCursor)
    _UseAction(slot, checkCursor)

    if Active then
        if Active == slot then
            HideFlyout()
            Active = nil
            return
        else
            HideFlyout()
        end
    end

    Active = slot

    local macro = GetActionText(slot)
    if macro then
        local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
        local s, e = strfind(body, Config.COMMAND)
        if s and s == 1 then
            local button = GetActionButton(slot)
            if button then
                --button:SetFrameStrata('TOOLTIP')
                local direction = GetFlyoutDirection(button)
                local offset = Config.BUTTON_SIZE

                body = strsub(body, e + 1)
                for i, n in ipairs(strsplit(body, Config.DELIMITER)) do
                    local spell = GetSpellSlotByName(n)
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

                                HideFlyout()
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

                        offset = offset + Config.BUTTON_SIZE
                    end
                end
            end
        end
    end
end

local Flyout = CreateFrame('Frame', nil, UIParent)
Flyout:RegisterEvent('PLAYER_ENTERING_WORLD')
Flyout:RegisterEvent('ACTIONBAR_SLOT_CHANGED')
Flyout:RegisterEvent('ACTIONBAR_PAGE_CHANGED')
Flyout:RegisterEvent('UPDATE_MACROS')
Flyout:SetScript('OnEvent',
    function()
        if event == 'PLAYER_ENTERING_WORLD' then
            for i = 1, Config.MAX_BUTTONS do
                local button = CreateFrame('CheckButton', 'FlyoutButton' .. i, UIParent, 'ActionButtonTemplate')
                button:SetHeight(Config.BUTTON_SIZE)
                button:SetWidth(Config.BUTTON_SIZE)
                button:Hide()

                button.border = button:CreateTexture('FlyoutButton' .. i .. 'Texture', 'BACKGROUND')
                button.border:SetTexture('Interface\\AddOns\\Flyout\\assets\\FlyoutButton')
                button.border:SetTexCoord(0, 0.515625, 0, 1)
                button.border:SetPoint('TOPLEFT', button, -1, 1)
                button.border:SetPoint('BOTTOMRIGHT', button, 1, -1)
            end
        
            for _, bar in ipairs(ActionBars) do
                for i = 1, 12 do
                    local button = _G[bar .. "Button" .. i]
                    local slot = ActionButton_GetPagedID(button)
                    if HasAction(slot) then
                        local macro = GetActionText(slot)
                        if macro then
                            local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
                            local s = strfind(body, Config.COMMAND)
                            if s and s == 1 then
                                UpdateFlyoutArrow(button)
                            end
                        end
                    end
                end
            end

        elseif event == 'ACTIONBAR_SLOT_CHANGED' then
            local slot = arg1
            
            HideFlyout()

            local button = GetActionButton(slot)
            if button then
                local arrow = _G[button:GetName() .. 'FlyoutArrow']
                if arrow then
                    if arrow:IsVisible() then
                        arrow:Hide()
                        return
                    end
                end
            end

            local macro = GetActionText(slot)
            if macro then
                local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
                local s = strfind(body, Config.COMMAND)
                if s and s == 1 then
                    UpdateFlyoutArrow(button)
                end
            end
        
        elseif event == 'ACTIONBAR_PAGE_CHANGED' or event == 'UPDATE_MACROS' then
            HideFlyout()
            
            for _, bar in ipairs(ActionBars) do
                for i = 1, 12 do
                    local button = _G[bar .. "Button" .. i]
                    local slot = ActionButton_GetPagedID(button)
                    local arrow = _G[button:GetName() .. 'FlyoutArrow']
                    if arrow then arrow:Hide() end
                    if HasAction(slot) then
                        local macro = GetActionText(slot)
                        if macro then
                            local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
                            local s = strfind(body, Config.COMMAND)
                            if s and s == 1 then
                                UpdateFlyoutArrow(button)
                            end
                        end
                    end
                end
            end
        end
    end
)