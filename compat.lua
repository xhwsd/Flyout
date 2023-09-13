local _G = getfenv(0)

-- upvalues
local GetActionText = GetActionText
local HasAction = HasAction
local GetMacroIndexByName = GetMacroIndexByName
local GetMacroInfo = GetMacroInfo
local IsAddOnLoaded = IsAddOnLoaded

local floor = math.floor

local strfind = string.find

-- utils
local function modulo(a, b)
    return a - floor(a / b) * b
end

-- Bongos
local function GetActionButton_Bongos(action)
    local button = _G['BActionButton' .. action]
    if button then
        return button
    end
    
    return nil
end

local function UpdateBars_Bongos()
    for action = 1, 120 do
        local button = GetActionButton_Bongos(action)

        if button then
            if HasAction(action) then
                local macro = GetActionText(action)
                if macro then
                    local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
                    local s = strfind(body, '/flyout')
                    if s and s == 1 then
                        Flyout_UpdateFlyoutArrow(button)
                    end
                end
            end
        end
    end
end

-- pfUI
local function GetActionButton_PF(action)
    local bar = nil

    if action < 25 then
        bar = 'pfActionBarMain'
    elseif  action < 37 then
        bar = 'pfActionBarRight'
    elseif  action < 49 then
        bar = 'pfActionBarVertical'
    elseif  action < 61 then
        bar = 'pfActionBarLeft'
    elseif  action < 73 then
        bar = 'pfActionBarTop'
    elseif  action < 85 then
        bar = 'pfActionBarStanceBar1'
    elseif  action < 97 then
        bar = 'pfActionBarStanceBar2'
    elseif  action < 109 then
        bar = 'pfActionBarStanceBar3'
    elseif  action < 121 then
        bar = 'pfActionBarStanceBar4'
    else
        bar = 'pfActionBarMain'
    end
    
    local i = 1
    if modulo(action, 12) ~= 0 then i = modulo(action, 12) else i = 12 end
    
    local button = _G[bar .. 'Button' .. i]
    if button then
        return button
    end

    return nil
end

local function UpdateBars_PF()
    for action = 1, 120 do
        local button = GetActionButton_PF(action)

        if button then
            if HasAction(action) then
                local macro = GetActionText(action)
                if macro then
                    local _, _, body = GetMacroInfo(GetMacroIndexByName(macro))
                    local s = strfind(body, '/flyout')
                    if s and s == 1 then
                        Flyout_UpdateFlyoutArrow(button)
                    end
                end
            end
        end
    end
end

-- override original functions
local handler = CreateFrame('Frame')
handler:RegisterEvent('VARIABLES_LOADED')
handler:SetScript('OnEvent',
    function()
        -- Bongos
        if IsAddOnLoaded('Bongos') and IsAddOnLoaded('Bongos_ActionBar') then
            Flyout_GetActionButton = GetActionButton_Bongos
            Flyout_UpdateBars = UpdateBars_Bongos
        end
        
        -- pfUI
        if IsAddOnLoaded('pfUI') then
            Flyout_GetActionButton = GetActionButton_PF
            Flyout_UpdateBars = UpdateBars_PF
        end
    end
)