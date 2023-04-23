Flyout = CreateFrame('Frame', 'Flyout')

Flyout.COMMAND = '/flyout'
Flyout.MAX_BUTTONS = 12
Flyout.DELIMITER = ';'

local _G = getfenv(0)

local bars = { 'Action', 'BonusAction', 'MultiBarBottomLeft', 'MultiBarBottomRight', 'MultiBarRight', 'MultiBarLeft' }
local active = nil

-- placeholder slash command
SLASH_FLYOUT1 = Flyout.COMMAND
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
function Flyout.GetSpellSlotByName(name)
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

function Flyout.GetActionButton(action)
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

function Flyout.GetFlyoutDirection(button)
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

function Flyout.UpdateFlyoutArrow(button)
    if not button then return end
    
    local direction = Flyout.GetFlyoutDirection(button)

    button.arrow = _G[button:GetName() .. 'FlyoutArrow'] or button:CreateTexture(button:GetName() .. 'FlyoutArrow', 'OVERLAY')
    button.arrow:ClearAllPoints()
    button.arrow:SetTexture('Interface\\AddOns\\Flyout\\assets\\FlyoutButton')
    button.arrow:Show()

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

function Flyout.UpdateBars()
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
                    local s = strfind(body, Flyout.COMMAND)
                    if s and s == 1 then
                        Flyout.UpdateFlyoutArrow(button)
                    end
                end
            end
        end
    end
end

function Flyout.HideFlyout()
    for i = 1, Flyout.MAX_BUTTONS do
        local button = _G['FlyoutButton' .. i]
        if button then
            button:SetChecked(false)
            button:Hide()
            _G[button:GetName() .. 'NormalTexture']:SetTexture(nil)
        end
    end

    active = nil
end

local _UseAction = UseAction
function UseAction(slot, checkCursor)
    _UseAction(slot, checkCursor)
    
    if active then
        if active == slot then
            Flyout.HideFlyout()
            return
        end
        
        Flyout.HideFlyout()
    end

    active = slot

    local macro = GetActionText(slot)
    if macro then
        local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
        local s, e = strfind(body, Flyout.COMMAND)
        if s and s == 1 then
            local button = Flyout.GetActionButton(slot)
            if button then
                local direction = Flyout.GetFlyoutDirection(button)
                local offset = button:GetHeight() - 4

                body = strsub(body, e + 1)
                for i, n in ipairs(strsplit(body, Flyout.DELIMITER)) do
                    local spell = Flyout.GetSpellSlotByName(n)
                    if spell then
                        local b = _G['FlyoutButton' .. i]
                        b:Show()
                        b:SetHeight(button:GetHeight() - 4)
                        b:SetWidth(button:GetWidth() - 4)
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

                                Flyout.HideFlyout()
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

                        offset = offset + (button:GetHeight() - 4)
                    end
                end
            end
        end
    end
end

Flyout:RegisterEvent('PLAYER_LOGIN')
Flyout:RegisterEvent('ACTIONBAR_SLOT_CHANGED')
Flyout:RegisterEvent('ACTIONBAR_PAGE_CHANGED')
Flyout:RegisterEvent('UPDATE_MACROS')
Flyout:SetScript('OnEvent',
    function()
        if event == 'PLAYER_LOGIN' then
            for i = 1, Flyout.MAX_BUTTONS do
                local button = CreateFrame('CheckButton', 'FlyoutButton' .. i, UIParent, 'ActionButtonTemplate')
                button:Hide()

                button.border = button:CreateTexture('FlyoutButton' .. i .. 'BorderTexture', 'BACKGROUND')
                button.border:SetTexture('Interface\\AddOns\\Flyout\\assets\\FlyoutButton')
                button.border:SetTexCoord(0, 0.515625, 0, 1)
                button.border:SetPoint('TOPLEFT', button, -1, 1)
                button.border:SetPoint('BOTTOMRIGHT', button, 1, -1)
            end
        
            Flyout.UpdateBars()

        elseif event == 'ACTIONBAR_SLOT_CHANGED' then
            Flyout.HideFlyout()
            
            local slot = arg1
            local button = Flyout.GetActionButton(slot)
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
                    local s = strfind(body, Flyout.COMMAND)
                    if s and s == 1 then
                        Flyout.UpdateFlyoutArrow(button)
                    end
                end
            end

        elseif event == 'ACTIONBAR_PAGE_CHANGED' or event == 'UPDATE_MACROS' then
            Flyout.HideFlyout()
            Flyout.UpdateBars()
        end
    end
)