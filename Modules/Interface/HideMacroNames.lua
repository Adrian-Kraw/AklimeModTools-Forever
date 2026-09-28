-- Modules/Interface/HideMacroNames.lua
-- Hides macro names on all action buttons.
-- Uses hooksecurefunc on ActionButton_UpdateName so that
-- newly created or changed macros are hidden immediately too.

local function GetDB()
    return AklimeModDB and AklimeModDB.hideMacroNames
end

local function IsEnabled()
    local db = GetDB()
    return db and db.enabled
end

-- All standard action button names
local function GetAllButtons()
    local buttons = {}
    -- Main bar + MultiBar buttons
    local bars = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
        "MultiBar5Button",
        "MultiBar6Button",
        "MultiBar7Button",
    }
    for _, prefix in ipairs(bars) do
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn then buttons[#buttons + 1] = btn end
        end
    end
    return buttons
end

local function Apply()
    for _, btn in ipairs(GetAllButtons()) do
        if btn.Name then btn.Name:Hide() end
    end
end

local function Remove()
    for _, btn in ipairs(GetAllButtons()) do
        if btn.Name then btn.Name:Show() end
    end
    -- Name visibility is controlled by Blizzard via UpdateName
    -- after Remove, just let them all re-evaluate
    for i = 1, 12 do
        local btn = _G["ActionButton" .. i]
        if btn and btn.UpdateName then btn:UpdateName() end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "AklimeModTools" then
        -- In 12.0 there is no global ActionButton_UpdateName anymore
        -- We hook UpdateName directly on each button
        C_Timer.After(0.5, function()
            for _, btn in ipairs(GetAllButtons()) do
                if btn.UpdateName then
                    hooksecurefunc(btn, "UpdateName", function(self)
                        if IsEnabled() and self.Name then
                            self.Name:Hide()
                        end
                    end)
                end
            end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        if IsEnabled() then Apply() end
    end
end)

AklimeMod_HideMacroNames = {
    IsEnabled  = function() return IsEnabled() end,
    SetEnabled = function(v)
        local db = GetDB()
        if db then db.enabled = v end
        if v then Apply() else Remove() end
    end,
}