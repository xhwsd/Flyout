
-- Bongos
local function GetActionButton_Bongos(action)
    return getglobal('BActionButton' .. action)
end

-- pfUI
local function GetActionButton_PF(action)
    local bar = nil

    if action < 13 then
        bar = 'pfActionBarMain'
    elseif action < 25 then
        bar = 'pfActionBarPaging'
    elseif action < 37 then
        bar = 'pfActionBarRight'
    elseif action < 49 then
        bar = 'pfActionBarVertical'
    elseif action < 61 then
        bar = 'pfActionBarLeft'
    elseif action < 73 then
        bar = 'pfActionBarTop'
    elseif action < 85 then
        bar = 'pfActionBarStanceBar1'
    elseif action < 97 then
        bar = 'pfActionBarStanceBar2'
    elseif action < 109 then
        bar = 'pfActionBarStanceBar3'
    elseif action < 121 then
        bar = 'pfActionBarStanceBar4'
    else
        bar = 'pfActionBarMain'
    end

    local i = 1
    if math.mod(action, 12) ~= 0 then
        i = math.mod(action, 12)
    else
        i = 12
    end

    return getglobal(bar .. 'Button' .. i)
end

-- override original functions
local handler = CreateFrame('Frame')
handler:RegisterEvent('VARIABLES_LOADED')
handler:SetScript('OnEvent', function()
    if IsAddOnLoaded('Bongos') and IsAddOnLoaded('Bongos_ActionBar') then
        Flyout_GetActionButton = GetActionButton_Bongos
    end

    if IsAddOnLoaded('pfUI') then
        Flyout_GetActionButton = GetActionButton_PF
    end
end)
