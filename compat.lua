-- 取 Bongos 的动作按钮
---@param action number 动作
---@return Frame|table|nil button 按钮
local function GetActionButton_Bongos(action)
    return getglobal("BActionButton" .. action)
end

-- 取 pfUI 的动作按钮
---@param action number 动作
---@return Frame|table|nil button 按钮
local function GetActionButton_PF(action)
    local bar = nil
    if action < 13 then
        bar = "pfActionBarMain"
    elseif action < 25 then
        bar = "pfActionBarPaging"
    elseif action < 37 then
        bar = "pfActionBarRight"
    elseif action < 49 then
        bar = "pfActionBarVertical"
    elseif action < 61 then
        bar = "pfActionBarLeft"
    elseif action < 73 then
        bar = "pfActionBarTop"
    elseif action < 85 then
        bar = "pfActionBarStanceBar1"
    elseif action < 97 then
        bar = "pfActionBarStanceBar2"
    elseif action < 109 then
        bar = "pfActionBarStanceBar3"
    elseif action < 121 then
        bar = "pfActionBarStanceBar4"
    else
        bar = "pfActionBarMain"
    end

    local index = 1
    if math.mod(action, 12) ~= 0 then
        index = math.mod(action, 12)
    else
        index = 12
    end

    return getglobal(bar .. "Button" .. index)
end

-- 覆盖原有功能
local handler = CreateFrame("Frame")
handler:RegisterEvent("VARIABLES_LOADED")
handler:SetScript("OnEvent", function()
    if IsAddOnLoaded("Bongos") and IsAddOnLoaded("Bongos_ActionBar") then
        Flyout_GetActionButton = GetActionButton_Bongos
    end

    if IsAddOnLoaded("pfUI") then
        Flyout_GetActionButton = GetActionButton_PF
    end
end)
